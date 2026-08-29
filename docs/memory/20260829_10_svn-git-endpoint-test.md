# 20260829_10 SVN 操作テスト + git push を Gitea エンドポイントで検証

環境: podman、前回 MANUAL テストの環境を継続利用（volume 保持）。

## Step A: SVN コマンド操作テスト（ホストから）

`svn` 1.14.1 をホストに導入済み。`ai-instructions/git-svn-ops.md` の SVN 手順を通し実行。

- `svn checkout`（r2）→ `svn update`
- ファイル追加（`svn add`）+ 既存ファイル編集
- `svn status` / `svn diff` — 差分表示正常
- `svn commit` → **r3**
- `svn info` — URL 確認
- `svn copy` で `branches/feature-svntest` 作成 → **r4**
- `svn list branches/` で確認

結果: 全操作成功。Basic 認証（`--username/--password --no-auth-cache`）で通る。
（`svn info` の `Revision:` 行は日本語ロケールだと「リビジョン:」表記。`LANG=C` で英語。）

## Step B: git push を git-apache でなく Gitea エンドポイントで

`ai-instructions/git-svn-ops.md` どおり、`${GITEA_BASE_URL}/${GITEA_OWNER}/${GITEA_REPO}.git` に対して:

- `git clone`（credential.helper でトークンを username/password に渡す方式）
- `git switch -c feature/... origin/main` → ファイル追加 → `git commit`（`refs #1`）
- `git push -u origin <branch>` → 成功（`* [new branch]`）
- Gitea API `repos/.../branches/<branch>` でブランチとコミット ID を確認

結果: 成功。認証情報を URL に埋めず credential.helper 経由で push できる。

## 未検証項目の解消

- 「ホストからの svn 操作」→ 解消（Step A）
- 「git-apache（Smart HTTP）への実 git push」→ **Gitea エンドポイントでの git push に置き換えて検証**（Step B）

## git-apache サービスの削除（ユーザー承認済み）

Git のリモート操作は Gitea エンドポイントに一本化。`git-apache` を構成から削除。

- `infra/docker-compose.yml`: `git-apache` サービス / `git-apache-repos` volume / ヘッダcoメント削除
- `infra/git-apache/`（Dockerfile / git.conf / entrypoint.sh）を `git rm`
- `infra/.env.example`: `GIT_APACHE_PORT` 削除
- `infra/README.md`: サービス表の docker4 を gitea/gitea-db のみに、注意点を Gitea エンドポイントに
- `README.md` / `MANUAL.md`: ポート 8090 と git-apache の記述を削除、compose up の対象から除外
- コンテナ `gst-git-apache` / volume / イメージ `localhost/giteasvntest_git-apache` を削除
- `compose config` OK、残 8 コンテナ稼働

PLAN.md の Docker4 記述（「+ Apache Repository」）は当初計画の記録として保持（冒頭に
README/MANUAL 参照の注記あり）。
