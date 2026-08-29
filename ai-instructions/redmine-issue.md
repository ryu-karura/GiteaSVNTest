# Redmine：チケット作成・更新（REST API / curl）

すべて `curl` + Redmine REST API（JSON）。

```bash
BASE="${REDMINE_BASE_URL}"
AUTH=(-H "X-Redmine-API-Key: ${REDMINE_API_KEY}" -H "Content-Type: application/json")
PROJECT="${REDMINE_PROJECT}"     # 例: ai-test
```

前提: 管理画面「設定 > API」で REST API が有効。試験環境では
`infra/seed/redmine_bootstrap.rb` で有効化済み。

## 0. 接続確認

```bash
curl -sf "${AUTH[@]}" "${BASE}/users/current.json" | jq '.user | {id, login}'
```

## 1. 参照情報の取得（トラッカー / ステータス / 優先度の ID）

```bash
curl -sf "${AUTH[@]}" "${BASE}/trackers.json"        | jq '.trackers[]  | {id, name}'
curl -sf "${AUTH[@]}" "${BASE}/issue_statuses.json"  | jq '.issue_statuses[] | {id, name}'
curl -sf "${AUTH[@]}" "${BASE}/enumerations/issue_priorities.json" \
  | jq '.issue_priorities[] | {id, name}'
```

## 2. チケット作成

```bash
RESP=$(curl -s -w '\n%{http_code}' "${AUTH[@]}" -X POST "${BASE}/issues.json" -d @- <<JSON
{
  "issue": {
    "project_id": "${PROJECT}",
    "subject": "AI テスト: 変更対応",
    "description": "対応内容。関連 PR は作成後に追記する。",
    "tracker_id": 1,
    "priority_id": 2
  }
}
JSON
)
CODE=$(printf '%s' "$RESP" | tail -n1)
ISSUE_ID=$(printf '%s' "$RESP" | sed '$d' | jq -r '.issue.id')
echo "HTTP ${CODE}  issue #${ISSUE_ID}"      # 201 で成功
echo "URL: ${BASE}/issues/${ISSUE_ID}"
```

## 3. チケット更新（コメント追加 + ステータス変更）

更新は `PUT /issues/{id}.json`。成功時のレスポンスボディは空、HTTP `204`。
`notes` がコメント（履歴に残る）。

```bash
ISSUE_ID=123
PR_URL="https://gitea.example/testorg/sample-app/pulls/42"

curl -s -o /dev/null -w '%{http_code}\n' "${AUTH[@]}" -X PUT "${BASE}/issues/${ISSUE_ID}.json" -d @- <<JSON
{
  "issue": {
    "notes": "PR を作成しました: ${PR_URL}",
    "status_id": 2
  }
}
JSON
```

`204` で成功。反映確認:

```bash
curl -sf "${AUTH[@]}" "${BASE}/issues/${ISSUE_ID}.json?include=journals" \
  | jq '.issue | {id, subject, status: .status.name, last_note: (.journals[-1].notes)}'
```

## 4. カスタムフィールドを使う場合

```json
{ "issue": { "custom_fields": [ { "id": 5, "value": "42" } ] } }
```

`GET /custom_fields.json`（管理者権限）で ID を確認。

## エラー対応早見

- `401`: `REDMINE_API_KEY` が無効。
- `403`: REST 未有効、またはユーザーにプロジェクト権限がない。
- `404`: `PROJECT` 識別子または `ISSUE_ID` が誤り。
- `422`: 必須フィールド不足（`errors` 配列に理由）。よくあるのは `tracker_id` 未指定。
