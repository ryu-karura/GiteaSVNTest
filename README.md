# GiteaSVNTest

Gitea / GitHub の PR 作成、Redmine のチケット作成・更新、Git / SVN のソース操作を、
**REST API + `curl` と標準コマンドだけ**で（`tea` / `gh` を使わず）、Claude / GitHub Copilot
の両方から実行できるようにするための **AI 指示ファイル一式**。

最終目的は、この指示ファイルを他プロジェクトへ配布して開発効率・AI 実行効率を上げること。
このリポジトリは配布物の開発・検証の場。配布物の正リストと導入手順は
[docs/ai/DISTRIBUTION.md](docs/ai/DISTRIBUTION.md)。

- セットアップと使い方 → **[MANUAL.md](MANUAL.md)**
- 当初の計画・設計方針 → [PLAN.md](PLAN.md)
- 配布物の一覧・他プロジェクトへの導入 → [docs/ai/DISTRIBUTION.md](docs/ai/DISTRIBUTION.md)

## できること

- **Gitea PR 作成** — `curl` + Gitea REST API（`docs/ai/gitea-pr.md`）
- **GitHub PR 作成** — `curl` + GitHub REST API（`docs/ai/github-pr.md`）
- **Redmine チケット作成・更新** — `curl` + Redmine REST API（`docs/ai/redmine-issue.md`）
- **Git / SVN 操作** — `git` / `svn` 標準コマンド、認証情報は環境変数から（`docs/ai/git-svn-ops.md`）
- 上記を組み合わせた **一連のシナリオ**（取得→変更→PR→チケット更新）— `docs/ai/scenario-pr-and-ticket.md`

## リポジトリ構成

**配布物**（他プロジェクトにコピーする。正リストは `docs/ai/DISTRIBUTION.md`）:

| パス | 内容 |
|---|---|
| `CLAUDE.md` | Claude の入口（ルート必須）。目的・必須ルール・`docs/ai/` への参照 |
| `.env.example` | AI 実行用の環境変数テンプレート。`cp .env.example .env` で使う（`infra/.env.example` とは別物） |
| `.claude/` | Claude 用定義（`rules/`、`skills/`） |
| `.github/copilot-instructions.md` ほか | Copilot の入口＋`instructions/`・`skills/` |
| `docs/ai/` | ツール非依存の手順集・環境変数定義・疎通確認（両ツールが参照する実体） |

`docs/ai/` 内: `common.md` / `gitea-pr.md` / `github-pr.md` / `redmine-issue.md` /
`git-svn-ops.md` / `scenario-pr-and-ticket.md` / `env-vars.md` / `healthcheck.md` /
`DISTRIBUTION.md`。

**このリポジトリ専用**（配布しない）:

| パス | 内容 |
|---|---|
| `MANUAL.md` | セットアップ手順と使い方 |
| `PLAN.md` | 当初の計画・設計方針 |
| `docs/memory/` | 作業の途中経過（`index.md` = 目次、詳細は `yyyyMMdd_NN_*.md`） |
| `infra/` | Docker 試験環境（Compose、SVN 用 Apache イメージ、初期データ投入 `seed`） |
| `scripts/` | 開発補助（`export-ai-config.sh` = 配布物の抽出） |

Claude 用（`.claude/`）と Copilot 用（`.github/`）の定義は独立して記述し、
手順の実体は `docs/ai/` を双方が参照する。

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

- 8 コンテナ稼働（`cockpit` はホスト Docker ソケット依存、`DOCKER_SOCK` で切替。`gitea-runner` は DinD 版でソケット不要）
- `redmine_bootstrap.rb`（デフォルトデータ投入 + REST 有効化 + API キー取得）→ `seed`（Gitea Org/repo/ブランチ、SVN コミット、Redmine プロジェクト + サンプルチケット）
- `docs/ai/healthcheck.md` の疎通確認（Gitea / Redmine / SVN すべて到達）
- ホストから `svn`（checkout〜commit〜`svn copy` ブランチ）と `git` push（Gitea エンドポイント）を実行確認
- E2E: `curl` で Gitea PR 作成（HTTP 201）→ Redmine チケット更新（HTTP 204、コメント + ステータス変更）→ 反映確認
- Gitea Actions: `gitea/runner:3.3.1-dind` で 3 ステップジョブが完走（rootless podman 上、state=success）（`docs/memory/20260830_02_runner-dind.md`）
