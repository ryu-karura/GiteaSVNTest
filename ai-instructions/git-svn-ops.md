# Git / SVN：取得・更新・差分確認（標準コマンド）

REST API は使わず `git` / `svn` の標準コマンドを使う。認証情報は環境変数から。

## Git（Gitea / GitHub 共通）

### 認証（URL にトークンを埋めない）

一時的な credential helper で渡す:

```bash
export GIT_ASKPASS=/bin/echo   # 使わない
git -c credential.helper='!f() { echo "username=${GIT_USERNAME}"; echo "password=${GIT_PASSWORD}"; }; f' \
    clone "${GITEA_BASE_URL}/${GITEA_OWNER}/${GITEA_REPO}.git" repo
```

以降のコマンドは `repo/` 内で実行。author も環境変数から:

```bash
cd repo
git config user.name  "${GIT_AUTHOR_NAME}"
git config user.email "${GIT_AUTHOR_EMAIL}"
```

### 取得・更新

```bash
git fetch origin
git switch -c "feature/123-change" origin/main    # 作業ブランチ
# ... ファイル変更 ...
git add -A
git status --short
git diff --staged            # 差分確認（必ず内容を確認してからコミット）
git commit -m "変更の要約 (refs #123)"
```

### push（credential helper を毎回付ける）

```bash
CRED='credential.helper=!f() { echo "username=${GIT_USERNAME}"; echo "password=${GIT_PASSWORD}"; }; f'
git -c "$CRED" push -u origin "feature/123-change"
```

push 後、`gitea-pr.md` / `github-pr.md` で PR 作成。

### 禁止

- `git push --force` / `--force-with-lease`（ユーザー承認なし）
- `git branch -D` によるリモート追跡外のブランチ削除
- 認証情報を含む URL（`https://user:token@host/...`）

## SVN

### 認証

コマンドごとに指定（キャッシュしない）:

```bash
SVNAUTH=(--non-interactive --no-auth-cache
         --username "${SVN_USERNAME}" --password "${SVN_PASSWORD}")
```

### 取得・更新・差分・コミット

```bash
svn checkout "${SVNAUTH[@]}" "${SVN_BASE_URL}/repo1" wc
cd wc
svn update "${SVNAUTH[@]}"

# 変更
echo "new line" >> trunk/sample.txt
svn add --force trunk/newfile.txt 2>/dev/null || true

svn status                    # 変更一覧
svn diff                      # 差分確認（内容を確認してからコミット）

svn commit "${SVNAUTH[@]}" -m "変更の要約 (redmine #123)"
svn info "${SVNAUTH[@]}" | grep '^Revision:'    # コミット後リビジョン
```

### ブランチ / タグ（標準レイアウト）

```bash
svn copy "${SVNAUTH[@]}" \
  "${SVN_BASE_URL}/repo1/trunk" \
  "${SVN_BASE_URL}/repo1/branches/feature-123" \
  -m "branch: feature-123"
```

### 禁止

- `svn delete` によるディレクトリ削除（ユーザー承認なし）
- リビジョンの改変（`svnadmin` 操作）

## エラー対応早見

- Git `Authentication failed`: `GIT_USERNAME` / `GIT_PASSWORD`（Gitea はトークンをパスワード欄に）。
- Git `! [rejected]`: リモートが進んでいる。`git fetch` + `git rebase origin/main` を検討（force push はしない）。
- SVN `E170001`: 認証失敗。SVN `E160024`: 競合。`svn update` で解決してから再コミット。
