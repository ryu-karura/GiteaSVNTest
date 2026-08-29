# GiteaSVNTest

Gitea / GitHub の PR 作成、Redmine のチケット作成・更新、Git / SVN のソース操作を、
**REST API + `curl` と標準コマンドだけ**で（`tea` / `gh` を使わず）、Claude / GitHub Copilot
の両方から実行できるようにするための構成・指示一式。

- セットアップと使い方 → **[MANUAL.md](MANUAL.md)**
- 当初の計画・設計方針 → [PLAN.md](PLAN.md)

## できること

- **Gitea PR 作成** — `curl` + Gitea REST API（`ai-instructions/gitea-pr.md`）
- **GitHub PR 作成** — `curl` + GitHub REST API（`ai-instructions/github-pr.md`）
- **Redmine チケット作成・更新** — `curl` + Redmine REST API（`ai-instructions/redmine-issue.md`）
- **Git / SVN 操作** — `git` / `svn` 標準コマンド、認証情報は環境変数から（`ai-instructions/git-svn-ops.md`）
- 上記を組み合わせた **一連のシナリオ**（取得→変更→PR→チケット更新）— `ai-instructions/scenario-pr-and-ticket.md`

## リポジトリ構成

| パス | 内容 |
|---|---|
| `MANUAL.md` | セットアップ手順と使い方（この順に実行すれば動く） |
| `PLAN.md` | 当初の計画・設計方針 |
| `docs/env-vars.md` | AI 実行時に参照する環境変数の標準定義（命名規則・一覧・未設定チェック） |
| `docs/healthcheck.md` | Gitea / Redmine / SVN / Git の疎通確認手順と終了条件 |
| `docs/memory/` | 作業の途中経過（`index.md` = 目次、詳細は `yyyyMMdd_NN_*.md`） |
| `infra/` | Docker 試験環境（Compose、SVN/Git 用 Apache イメージ、初期データ投入 `seed`） |
| `ai-instructions/` | ツール非依存の手順集（両ツールの定義から参照される実体） |
| `.claude/` | Claude 用定義（`rules/`、`skills/`） |
| `.github/` | GitHub Copilot 用定義（`copilot-instructions.md`、`instructions/`、`skills/`） |

Claude 用（`.claude/`）と Copilot 用（`.github/`）の定義は独立して記述し、
手順の実体は `ai-instructions/` を双方が参照する。

## 試験環境（`infra/`）

`docker compose` で以下を起動する（PLAN.md の Docker0-6 に対応）。

| サービス | 用途 | ホストポート |
|---|---|---|
| `cockpit` | コンテナ管理 UI | 9090 |
| `redmine` / `redmine-db` | Redmine 6.1.2 / MariaDB | 8080 |
| `gitea` / `gitea-db` | Gitea / PostgreSQL | 3000, 2222(SSH) |
| `svn1` / `svn2` | SVN + Apache（`repo1` / `repo2`） | 8081 / 8082 |
| `gitea-runner` | Gitea Actions runner | - |

## 検証済み

podman（rootless）+ podman-compose 環境で以下を確認済み（`docs/memory/20260829_07_verify-run.md`）。

- 7 コンテナ healthy（`cockpit` / `gitea-runner` は Docker ソケット依存。`DOCKER_SOCK` で切替）
- `redmine_bootstrap.rb`（デフォルトデータ投入 + REST 有効化 + API キー取得）→ `seed`（Gitea Org/repo/ブランチ、SVN コミット、Redmine プロジェクト + サンプルチケット）
- `docs/healthcheck.md` の疎通確認（Gitea / Redmine / SVN すべて到達）
- ホストから `svn`（checkout〜commit〜`svn copy` ブランチ）と `git` push（Gitea エンドポイント）を実行確認
- E2E: `curl` で Gitea PR 作成（HTTP 201）→ Redmine チケット更新（HTTP 204、コメント + ステータス変更）→ 反映確認
