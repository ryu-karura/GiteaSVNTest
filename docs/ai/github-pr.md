# GitHub：PR 作成（REST API / curl）

`gh` コマンドは使わない。すべて `curl` + GitHub REST API。

`rtk` がある環境では `curl` に `rtk` を前置してよい（`jq` パースも可）。詳細は `common.md`。

```bash
API="${GITHUB_API_URL}"          # 例: https://api.github.com
REPO="repos/${GITHUB_OWNER}/${GITHUB_REPO}"
AUTH=(-H "Authorization: Bearer ${GITHUB_TOKEN}"
      -H "Accept: application/vnd.github+json"
      -H "X-GitHub-Api-Version: 2022-11-28")
```

## 1. 事前確認

```bash
curl -sf "${AUTH[@]}" "${API}/${REPO}" | jq '{full_name, default_branch, permissions}'
```

`permissions.push == true` を確認。

## 2. PR 作成

```bash
HEAD_BRANCH="feature/xxx"     # 同一リポジトリのブランチ。fork の場合は "owner:branch"
BASE_BRANCH="main"

RESP=$(curl -s -w '\n%{http_code}' "${AUTH[@]}" -X POST "${API}/${REPO}/pulls" -d @- <<JSON
{
  "title": "変更の要約",
  "head": "${HEAD_BRANCH}",
  "base": "${BASE_BRANCH}",
  "body": "変更内容の説明。Redmine #123 と関連。"
}
JSON
)
CODE=$(printf '%s' "$RESP" | tail -n1)
printf '%s' "$RESP" | sed '$d' | jq '{number, html_url, state}'
echo "HTTP ${CODE}"      # 201 で成功
```

## 3. 既存 PR の検索（再実行時）

```bash
curl -sf "${AUTH[@]}" \
  "${API}/${REPO}/pulls?state=open&head=${GITHUB_OWNER}:${HEAD_BRANCH}" \
  | jq '.[0] | {number, html_url}'
```

## 4. PR へコメント

```bash
PR_NUMBER=42
curl -sf "${AUTH[@]}" -X POST "${API}/${REPO}/issues/${PR_NUMBER}/comments" \
  -d '{"body":"Redmine #123 を更新しました。"}' | jq '{id, html_url}'
```

## 5. PR のクローズ（マージしない）

```bash
PR_NUMBER=42
curl -s -w '\n%{http_code}' "${AUTH[@]}" -X PATCH "${API}/${REPO}/pulls/${PR_NUMBER}" \
  -d '{"state":"closed"}' | jq '{number, state, merged}'
# 200 / state=closed / merged=false を確認
```

- マージは含めない。マージ（`PUT /pulls/{n}/merge`）はユーザー承認が要る破壊的操作。
- クローズした PR は `-d '{"state":"open"}'` で再オープンできる。
- 作業ブランチを消す場合（クローズ後）:
  `curl -s -w '\n%{http_code}' "${AUTH[@]}" -X DELETE "${API}/${REPO}/git/refs/heads/${HEAD_BRANCH}"`
  （`204` で成功。ブランチ削除もユーザー承認を得てから）。

## エラー対応早見

- `401`: `GITHUB_TOKEN` が無効・期限切れ。
- `403` + rate limit ヘッダ: レート制限。`X-RateLimit-Reset` を確認。
- `422`: head/base 不正、PR 重複、または差分なし（`errors[].message` を確認）。
