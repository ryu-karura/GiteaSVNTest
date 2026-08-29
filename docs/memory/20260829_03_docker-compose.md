# 20260829_03 Docker Compose 定義 + 初期データ投入

## 成果（infra/）

- `docker-compose.yml` … Docker0-6 対応。project name `giteasvntest`。
  - cockpit / redmine / redmine-db / gitea / gitea-db / git-apache / svn1 / svn2 / gitea-runner / seed(profile)
  - 各サービスに healthcheck。redmine は redmine-db healthy 待ち、runner は gitea healthy 待ち。
- `.env.example` … 起動用の値。`infra/.env` はコミット禁止（.gitignore 追加済み）。
- `svn-apache/`（Dockerfile / svn.conf / entrypoint.sh）… httpd:2.4 + mod_dav_svn。
  entrypoint で htpasswd と svnadmin create、標準レイアウト import。`SVN_REPOS` 環境変数でリポジトリ名指定。
- `git-apache/`（Dockerfile / git.conf / entrypoint.sh）… httpd + git-http-backend（Smart HTTP）。
  bare mirror1.git / mirror2.git を初回生成。Gitea とは別系統。ポート 8090。
- `seed/`（Dockerfile / seed.sh / redmine_bootstrap.rb）
  - seed.sh: Gitea トークン発行→testorg / sample-app / feature/seed-change、SVN trunk/sample.txt、Redmine ai-test + チケット2件。冪等。
  - redmine_bootstrap.rb: `rails runner` で REST 有効化・admin パスワード強制変更解除・API キーを REDMINE_SEED_API_KEY に固定。

## 起動順（infra/README.md に記載）

1. `docker compose up -d`
2. `redmine_bootstrap.rb` を rails runner で実行
3. `docker compose --profile seed run --rm seed`（ログの GITEA_API_TOKEN を控える）
4. Gitea 管理画面で runner 登録トークン取得 → `.env` → `gitea-runner` 再作成

## 検証

`docker compose config --quiet` OK（podman-compose 環境）。実コンテナ起動は未実施。

## 次

作業4 完了（docs/healthcheck.md）。次は作業5 AI 指示例（ai-instructions/）。
