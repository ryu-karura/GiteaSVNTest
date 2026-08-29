# 配布物マニフェスト

このリポジトリの成果物は「AI 指示ファイル一式」。他プロジェクトへコピーして使う。
このファイルが**配布物の正リスト**。

## 配布物（コピー対象）

| パス | 種別 | 役割 |
|---|---|---|
| `CLAUDE.md` | Claude 入口 | ルート必須。Claude Code が起動時に自動ロードする唯一の入口。目的・必須ルール・`docs/ai/` への参照を持つ |
| `.env.example` | 共通 | AI 実行用の環境変数テンプレート（ルート）。コピー先で `.env` を作る。`infra/.env.example`（Docker 用）とは別物 |
| `.claude/rules/` | Claude | パス条件付きルール（`frontmatter: paths`） |
| `.claude/skills/` | Claude | スキル定義（`gitea-pr` / `redmine-ticket` / `pr-and-ticket`） |
| `.github/copilot-instructions.md` | Copilot 入口 | リポジトリ全体の指示。`docs/ai/` を参照 |
| `.github/instructions/` | Copilot | `applyTo` 条件付き指示 |
| `.github/skills/` | Copilot | スキル定義（Claude 側と対の内容） |
| `docs/ai/` | 共通実体 | ツール非依存の手順集・環境変数定義・疎通確認。両ツールの入口から参照される |

`docs/ai/` の中身:

- `README.md` — 手順集の目次
- `common.md` — 共通の前提・実行フロー・報告様式・RTK
- `gitea-pr.md` / `github-pr.md` — PR 作成（REST API + curl）
- `redmine-issue.md` — Redmine チケット
- `git-svn-ops.md` — Git / SVN 操作
- `scenario-pr-and-ticket.md` — 取得→変更→PR→チケット更新の一連
- `env-vars.md` — AI が参照する環境変数の標準定義
- `healthcheck.md` — 疎通確認手順
- `DISTRIBUTION.md` — このファイル

## 配布しないもの（このリポジトリ専用）

- `infra/` — Docker 試験環境（Compose、seed、SVN 用 Apache イメージ）
- `docs/memory/` — 作業の途中経過
- `PLAN.md` / `MANUAL.md` / `README.md` — このリポジトリの計画・手順・説明
- `scripts/` — 開発補助（`export-ai-config.sh` 含む）

## なぜ 2 フォルダ + 入口ファイルなのか

配布物の実体は `docs/ai/` の 1 フォルダに集約している。ただし各 AI ツールは
規定パスの入口ファイルを要求する:

- Claude Code: **ルート直下の `CLAUDE.md` のみ**自動ロードする。`.claude/CLAUDE.md` や
  `docs/ai/*.md` は自動では読まれない（`.claude/` 配下で読まれるのは
  `settings.json` / `rules/` / `skills/` / `agents/`）。
- GitHub Copilot: `.github/copilot-instructions.md` と `.github/instructions/*.instructions.md`
  を規定パスで読む。

そのため「`docs/ai/`（実体）＋ ツールごとの薄い入口（`CLAUDE.md` /
`.github/copilot-instructions.md` /（Claude は）`.claude/`）」という形になる。
入口ファイルは目的・必須ルール・`docs/ai/` への参照だけを持ち、手順の重複を避ける。

## 導入手順（コピー先プロジェクトで）

1. 配布物をコピー

   ```bash
   # このリポジトリのルートで
   scripts/export-ai-config.sh /path/to/target-project
   ```

   スクリプトが無い環境では手動で:
   `CLAUDE.md` / `.env.example` / `.claude/` / `.github/copilot-instructions.md` /
   `.github/instructions/` / `.github/skills/` / `docs/ai/` を対象リポジトリの同じ相対パスへコピーする。

2. コピー先で調整する

   - `CLAUDE.md` の「# GiteaSVNTest プロジェクト」節を、対象プロジェクト向けに書き換える
     （目的・必須ルール・参照ドキュメントの節構造は流用してよい）。
   - `.env.example`: コピー先に既存のものがあればマージする。
   - `docs/ai/env-vars.md` の URL / OWNER / REPO の例を対象環境の実値にする。
     トークン類は値を書かず、投入方法（後述）だけ記載する。
   - 使わないサービスの手順ファイル（例: SVN を使わないなら `git-svn-ops.md` の SVN 節）は削るか
     「対象外」と明記する。
   - `.github/` と `.claude/` の既存ファイルがある場合はマージする（上書きに注意）。

3. 環境変数を設定する（`docs/ai/env-vars.md`「値の設定方法」を参照）

   - ローカル: `cp .env.example .env` して `<repo>/.env` に値を記入。全プロジェクト共通の値は
     `~/.env` に置く（読み込み順は `~/.env` → `<repo>/.env`、後勝ち）。`.env` は `.gitignore` 済み。
   - GitHub Actions: リポジトリ / Org の Secrets に登録し、workflow の `env:` で展開
   - self-hosted runner / 常駐サーバー: systemd unit の `EnvironmentFile=`（600、root 所有）

4. 疎通確認

   `docs/ai/healthcheck.md` を実行し、対象サービスすべてに到達できることを確認する。

## 更新の流れ

配布物を直すときは、このリポジトリで編集 → 検証 → コミット。
コピー先へは再度 `scripts/export-ai-config.sh` を実行して反映する（コピー先での
ローカル調整との差分に注意）。
