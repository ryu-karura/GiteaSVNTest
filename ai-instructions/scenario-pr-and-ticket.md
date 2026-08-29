# シナリオ：取得 → 変更 → PR → チケット更新

README「指示例（GitHub Copilot / Claude 共通化イメージ）」の 1〜5 を 1 本の手順にした例。
Gitea + Redmine の組み合わせを示す（GitHub の場合は手順 4 を `github-pr.md` に差し替え）。

## 入力（ユーザーから受け取る、または確認する）

- 対象リポジトリ: `${GITEA_OWNER}/${GITEA_REPO}`（環境変数）
- 変更内容の説明
- 関連する Redmine チケット番号（既存を更新する場合）／新規作成なら不要

## 手順

### 1. 環境変数チェック

`docs/env-vars.md` の未設定チェックを実行。`MISSING:` があれば変数名を報告して中断。

### 2. 疎通確認

`docs/healthcheck.md` の Gitea・Redmine・Git を実行。失敗したら報告して中断。

### 3. ソース取得・変更・push（`git-svn-ops.md`）

```bash
CRED='credential.helper=!f() { echo "username=${GIT_USERNAME}"; echo "password=${GIT_PASSWORD}"; }; f'
git -c "$CRED" clone "${GITEA_BASE_URL}/${GITEA_OWNER}/${GITEA_REPO}.git" repo
cd repo
git config user.name "${GIT_AUTHOR_NAME}"; git config user.email "${GIT_AUTHOR_EMAIL}"

TICKET=123
BRANCH="feature/${TICKET}-change"
git switch -c "$BRANCH" origin/main

# --- 変更を適用 ---
git add -A
git diff --staged        # 内容確認
git commit -m "変更の要約 (refs #${TICKET})"
git -c "$CRED" push -u origin "$BRANCH"
```

### 4. Gitea で PR 作成（`gitea-pr.md`）

```bash
API="${GITEA_BASE_URL}/api/v1"; REPO="repos/${GITEA_OWNER}/${GITEA_REPO}"
AUTH=(-H "Authorization: token ${GITEA_API_TOKEN}" -H "Content-Type: application/json")

RESP=$(curl -s -w '\n%{http_code}' "${AUTH[@]}" -X POST "${API}/${REPO}/pulls" -d @- <<JSON
{ "head": "${BRANCH}", "base": "main",
  "title": "変更の要約", "body": "Redmine #${TICKET} 対応。" }
JSON
)
PR_CODE=$(printf '%s' "$RESP" | tail -n1)
PR_JSON=$(printf '%s' "$RESP" | sed '$d')
PR_NUMBER=$(printf '%s' "$PR_JSON" | jq -r '.number')
PR_URL=$(printf '%s' "$PR_JSON" | jq -r '.html_url')
echo "PR HTTP ${PR_CODE}  #${PR_NUMBER}  ${PR_URL}"
```

`422 already exists` の場合は既存 PR を検索して `PR_NUMBER` / `PR_URL` を取得。

### 5. Redmine チケット更新（`redmine-issue.md`）

```bash
BASE="${REDMINE_BASE_URL}"
RAUTH=(-H "X-Redmine-API-Key: ${REDMINE_API_KEY}" -H "Content-Type: application/json")

curl -s -o /dev/null -w '%{http_code}\n' "${RAUTH[@]}" -X PUT "${BASE}/issues/${TICKET}.json" -d @- <<JSON
{ "issue": { "notes": "PR を作成しました: ${PR_URL}", "status_id": 2 } }
JSON
```

新規チケットが必要な場合は手順 5 の前に `POST /issues.json` で作成し、`TICKET` に採番結果を入れる。

### 6. 報告（`common.md` の様式）

- 環境変数チェック / 疎通確認の結果
- ブランチ名・変更ファイル数・push 状態
- PR 番号・URL・HTTP ステータス
- チケット番号・URL・更新結果（204 か）
- エラーの有無と対処

### 7. メモリ更新

`docs/memory/index.md` に 1 行追記し、`docs/memory/yyyyMMdd_NN_*.md` に詳細を残す。
10 件超過なら完了済み・重複メモリの削除をユーザーに提案。
