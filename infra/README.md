# infra — Docker 試験環境

PLAN.md「試験環境」の Docker0-6 を Docker Compose で再現する。

> 構築から AI 実行までの通し手順は、リポジトリルートの [MANUAL.md](../MANUAL.md) を参照。
> この文書は `infra/` 単体のリファレンス。

## サービス対応

| README | Compose サービス | イメージ | ホストポート | 用途 |
|---|---|---|---|---|
| docker0 | `cockpit` | quay.io/cockpit/ws | 9090 | Docker1-N 管理 UI |
| docker1 | `redmine` | redmine:6.1.2 | 8080 | Redmine |
| docker2 | `redmine-db` | mariadb:11.4 | - | Redmine DB |
| docker3 | `svn1` | 自前（httpd + mod_dav_svn） | 8081 | SVN リポジトリ repo1 |
| docker4 | `gitea` / `gitea-db` / `git-apache` | gitea/gitea:1.22 / postgres:16 / 自前 httpd | 3000, 2222 / - / 8090 | Gitea 本体 + Postgres + Git Smart HTTP |
| docker5 | `svn2` | 自前（httpd + mod_dav_svn） | 8082 | SVN リポジトリ repo2 |
| docker6 | `gitea-runner` | gitea/runner:3.3.1 | - | Gitea Actions runner |

## 起動

```bash
cd infra
cp .env.example .env          # 値を必要に応じて編集（.env はコミット禁止）
docker compose up -d
docker compose ps             # 全サービス healthy を確認
```

初回は Redmine のマイグレーションで 1-2 分かかる。

## 初期データ投入

順番が重要。

### 1. Gitea 管理者の作成

`gitea/gitea` イメージは管理者を自動作成しない。`INSTALL_LOCK=true` で起動しているので
CLI から作成する（`-u git` で実行。root では拒否される）。

```bash
docker compose exec -u git gitea gitea admin user create --admin \
  --username giteaadmin --password giteaadmin_pass \
  --email giteaadmin@example.com --must-change-password=false
```

### 2. Redmine ブートストラップ（デフォルトデータ投入 + REST 有効化 + API キー取得）

`docker exec` は entrypoint を経由せず `REDMINE_SECRET_KEY_BASE` を解釈しないため、
`SECRET_KEY_BASE` を明示的に渡す（値は `docker-compose.yml` の `REDMINE_SECRET_KEY_BASE`）。

```bash
docker compose exec -T \
  -e SECRET_KEY_BASE=change_me_secret_key_base \
  redmine bin/rails runner - < seed/redmine_bootstrap.rb
```

出力の `admin API key = <40hex>` を控える。**この値が Redmine の API キー**
（Redmine の Token モデルが値を自前生成するため固定はできない。`.env` の
`REDMINE_SEED_API_KEY` はブートストラップでは使わない）。

### 3. seed コンテナ（Gitea / SVN / Redmine のデータ投入）

手順 2 で控えた Redmine API キーを渡して実行する。

```bash
docker compose --profile seed run --rm \
  -e REDMINE_SEED_API_KEY=<手順2で控えた40hex> seed
```

- Gitea: `testorg` Org、`testorg/sample-app` リポジトリ、`feature/seed-change` ブランチを作成。
  実行ログに出る `GITEA_API_TOKEN=...` を控える（後述の環境変数へ設定）。
- SVN: `repo1` / `repo2` の `trunk/sample.txt` をコミット。
- Redmine: `ai-test` プロジェクト（トラッカー紐付け済み）とサンプルチケット 2 件を作成。

### 4. Gitea Actions runner の登録トークン

Gitea 管理画面（`http://localhost:3000/-/admin/actions/runners`）で登録トークンを取得し、
`.env` の `GITEA_RUNNER_REGISTRATION_TOKEN` に設定して runner を再作成する。

```bash
docker compose up -d --force-recreate gitea-runner
```

登録トークンは CLI でも取得できる:

```bash
docker compose exec -u git gitea gitea actions generate-runner-token
```

## AI 実行時の環境変数との対応

`.env` は「Docker 起動用」。AI（Claude / Copilot）が参照するのは `docs/env-vars.md` の変数で、
OS / runner 側に注入する。試験環境向けの対応値:

| docs/env-vars.md | 値（既定構成） |
|---|---|
| `GITEA_BASE_URL` | `http://localhost:3000` |
| `GITEA_API_TOKEN` | seed 実行ログの `GITEA_API_TOKEN=...` |
| `GITEA_OWNER` | `testorg` |
| `GITEA_REPO` | `sample-app` |
| `REDMINE_BASE_URL` | `http://localhost:8080` |
| `REDMINE_API_KEY` | ブートストラップ出力の `admin API key = ...`（Redmine 生成値） |
| `REDMINE_PROJECT` | `ai-test` |
| `SVN_BASE_URL` | `http://localhost:8081/svn`（repo2 は 8082） |
| `SVN_USERNAME` / `SVN_PASSWORD` | `.env` の `SVN_ADMIN_USER` / `SVN_ADMIN_PASSWORD` |
| `GIT_USERNAME` / `GIT_PASSWORD` | Gitea ユーザー（`giteaadmin` 等）と対応するパスワード / トークン |

## 破棄

```bash
docker compose down -v      # ボリュームごと削除（初期化やり直し）
```

## 既知の注意点

- `cockpit` と `gitea-runner` は Docker ソケットをマウントする。パスは `.env` の `DOCKER_SOCK` で切り替える。
  - 通常の Docker: `/var/run/docker.sock`（既定）
  - rootless podman: `systemctl --user enable --now podman.socket` を実行し、
    `DOCKER_SOCK=/run/user/<UID>/podman/podman.sock` を設定する。
- Smart HTTP Git（`git-apache`, ポート 8090）は Gitea とは別系統のミラー配信用。`http://localhost:8090/git/mirror1.git`。
- SVN は Basic 認証必須。匿名アクセスは不可。
