# Redmine：チケット作成・更新（REST API / curl）

すべて `curl` + Redmine REST API（JSON）。

`rtk` がある環境では `curl` に `rtk` を前置してよい（`jq` パースも可）。詳細は `common.md`。

以下は bash。**PowerShell は末尾「PowerShell 版」を使う**（`curl` → `curl.exe`、
配列とヒアドキュメントは使わない）。

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

## PowerShell 版

```powershell
$base = $env:REDMINE_BASE_URL
$hdr  = @('-H', "X-Redmine-API-Key: $env:REDMINE_API_KEY", '-H', 'Content-Type: application/json')
$proj = $env:REDMINE_PROJECT

# 0. 接続確認
curl.exe -sf @hdr "$base/users/current.json" | jq.exe '.user | {id, login}'

# 1. 参照 ID
curl.exe -sf @hdr "$base/trackers.json"       | jq.exe '.trackers[] | {id, name}'
curl.exe -sf @hdr "$base/issue_statuses.json" | jq.exe '.issue_statuses[] | {id, name}'

# 2. チケット作成
$body = @"
{ "issue": { "project_id": "$proj", "subject": "AI テスト: 変更対応",
  "description": "対応内容。", "tracker_id": 1, "priority_id": 2 } }
"@
$resp = curl.exe -s -w "`n%{http_code}" @hdr -X POST "$base/issues.json" --data $body
$resp                                   # 最終行が HTTP（201）、手前が JSON
($resp -split "`n")[0..($resp.Split("`n").Count-2)] -join "`n" | jq.exe -r '.issue.id'

# 3. チケット更新（notes = コメント、status_id 変更）。成功は 204
$upd = '{ "issue": { "notes": "PR を作成しました: <URL>", "status_id": 2 } }'
curl.exe -s -o $null -w "%{http_code}`n" @hdr -X PUT "$base/issues/123.json" --data $upd

# 反映確認
curl.exe -sf @hdr "$base/issues/123.json?include=journals" |
  jq.exe '.issue | {id, status: .status.name, last_note: (.journals[-1].notes)}'
```

## エラー対応早見

- `401`: `REDMINE_API_KEY` が無効。
- `403`: REST 未有効、またはユーザーにプロジェクト権限がない。
- `404`: `PROJECT` 識別子または `ISSUE_ID` が誤り。
- `422`: 必須フィールド不足（`errors` 配列に理由）。よくあるのは `tracker_id` 未指定。
