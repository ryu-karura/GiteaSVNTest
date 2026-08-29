# Gitea：PR 作成（REST API / curl）

`tea` コマンドは使わない。すべて `curl` + Gitea REST API v1。

- API ルート: `${GITEA_BASE_URL}/api/v1`
- 認証ヘッダ: `-H "Authorization: token ${GITEA_API_TOKEN}"`
- 対象: `${GITEA_OWNER}/${GITEA_REPO}`

共通の変数定義:

```bash
API="${GITEA_BASE_URL}/api/v1"
REPO="repos/${GITEA_OWNER}/${GITEA_REPO}"
AUTH=(-H "Authorization: token ${GITEA_API_TOKEN}" -H "Content-Type: application/json")
```

## 1. 事前確認

```bash
# リポジトリと push 権限
curl -sf "${AUTH[@]}" "${API}/${REPO}" | jq '{full_name, default_branch, permissions}'

# ヘッドブランチが push 済みで存在するか
curl -sf "${AUTH[@]}" "${API}/${REPO}/branches/$(jq -rn --arg b "$HEAD_BRANCH" '$b|@uri')" \
  | jq '{name, commit: .commit.id}'
```

`HEAD_BRANCH`（変更を積んだブランチ）は事前に `git push` 済みであること（`git-svn-ops.md`）。

## 2. PR 作成

```bash
HEAD_BRANCH="feature/xxx"
BASE_BRANCH="main"
TITLE="変更の要約"
BODY="変更内容の説明。Redmine #123 と関連。"

RESP=$(curl -s -w '\n%{http_code}' "${AUTH[@]}" -X POST "${API}/${REPO}/pulls" -d @- <<JSON
{
  "head": "${HEAD_BRANCH}",
  "base": "${BASE_BRANCH}",
  "title": "${TITLE}",
  "body": "${BODY}"
}
JSON
)
CODE=$(printf '%s' "$RESP" | tail -n1)
JSONBODY=$(printf '%s' "$RESP" | sed '$d')
echo "HTTP ${CODE}"
printf '%s' "$JSONBODY" | jq '{number, html_url, state}'
```

- 成功: `201`。`number` と `html_url` を控える。
- `422` + `"pull request already exists"`: 既存 PR を取得する（下記）。
- `409`: base/head が同一、または head が base より進んでいない。

## 3. 既存 PR の検索（再実行時）

```bash
curl -sf "${AUTH[@]}" \
  "${API}/${REPO}/pulls?state=open&head=${GITEA_OWNER}:${HEAD_BRANCH}" \
  | jq '.[0] | {number, html_url, state}'
```

## 4. PR にコメント追加（任意：チケット番号の追記など）

```bash
PR_NUMBER=42
curl -sf "${AUTH[@]}" -X POST "${API}/${REPO}/issues/${PR_NUMBER}/comments" \
  -d '{"body":"Redmine チケット #123 を更新しました。"}' | jq '{id, html_url}'
```

## 5. マージ（ユーザー承認がある場合のみ）

```bash
curl -sf "${AUTH[@]}" -X POST "${API}/${REPO}/pulls/${PR_NUMBER}/merge" \
  -d '{"Do":"merge"}' -o /dev/null -w '%{http_code}\n'   # 200 で成功
```

## エラー対応早見

- `401`: `GITEA_API_TOKEN` が無効。
- `403`: トークンのスコープ不足（`write:repository` が必要）。
- `404`: `GITEA_OWNER` / `GITEA_REPO` が誤り、または private でトークン権限なし。
- `422`: 入力不正（head/base 未存在、PR 重複）。レスポンスの `message` を確認。
