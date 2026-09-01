# infra — Docker 試験環境

PLAN.md「試験環境」の Docker0-6 を Docker Compose で再現する。

> 構築から AI 実行までの通し手順は、リポジトリルートの [MANUAL.md](../MANUAL.md) を参照。
> この文書は `infra/` 単体のリファレンス。

## サービス対応

| Compose サービス | イメージ | ホストポート | 用途 |
|---|---|---|---|
| `redmine` | redmine:6.1.2 | 8080 | Redmine |
| `redmine-db` | mariadb:11.4 | - | Redmine DB |
| `svn1` | 自前（httpd + mod_dav_svn） | 8081 | SVN リポジトリ repo1 |
| `gitea` / `gitea-db` | gitea/gitea:1.22 / postgres:16 | 3000, 2222 / - | Gitea 本体 + Postgres |
| `svn2` | 自前（httpd + mod_dav_svn） | 8082 | SVN リポジトリ repo2 |
| `gitea-runner` | gitea/runner:3.3.1-dind | - | Gitea Actions runner（DinD、privileged） |

> 当初計画（PLAN.md）の `cockpit`（Docker 管理 UI）は目的と合わなかったため構成から除外。

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

## Actions ワークフロー例（`workflows/`）

`workflows/` は、対象リポジトリの `.gitea/workflows/` に置いて使うサンプル。
このディレクトリ自体は CI として動かない（試験用の配布元）。

| ファイル | トリガー | 動作 |
|---|---|---|
| `auto-pr.yml` | `create`（ブランチ作成）/ `push` | 差分があれば `main` への PR を自動作成。差分ゼロ・PR 重複時は何もしない |
| `close-issue-on-merge.yml` | `pull_request: closed`（`merged == true`） | ブランチ名または PR 本文から issue を特定し、まだ open なら閉じる |

どちらも `curl` + `grep` のみで動き、`jq` / `git` / 外部 action に依存しない。
トークンは Gitea Actions が注入する `secrets.GITEA_TOKEN` を使う。

配置と検証の手順は [../docs/tests/e2e-issue-to-merge.md](../docs/tests/e2e-issue-to-merge.md)。

## AI 実行時の環境変数との対応

`.env` は「Docker 起動用」。AI（Claude / Copilot）が参照するのは `docs/ai/env-vars.md` の変数で、
OS / runner 側に注入する。試験環境向けの対応値:

| docs/ai/env-vars.md | 値（既定構成） |
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

- `gitea-runner` は DinD 版（`gitea/runner:3.3.1-dind`、`privileged: true`）でコンテナ内 dockerd を
  起動する。ホスト socket は不要。rootless podman 上でもジョブが完走する（`3.3.1` 無印と
  `3.3.1-dind-rootless` は rootless podman では動かない。詳細は `MANUAL.md` 手順 2-4）。
  ホストの Docker ソケットをマウントするサービスは無い。
- Git のリモート操作は Gitea のエンドポイント（`http://localhost:3000/<owner>/<repo>.git`）を使う。
- SVN は Basic 認証必須。匿名アクセスは不可。
