# 20260830_04 AI 環境変数を .env ロード規約に変更

## 変更した前提

AI 実行用の環境変数は「OS / runner 側に注入」から「`.env` ファイルから読み込む」に変更。

- ロード順（後勝ちで上書き）:
  1. `~/.env` — 全プロジェクト共通の既定値（任意）
  2. プロジェクトルート `./.env` — プロジェクト固有
- AI は処理開始時に次を実行してから未設定チェックへ:

  ```bash
  set -a
  [ -f "$HOME/.env" ] && . "$HOME/.env"
  [ -f .env ] && . .env
  set +a
  ```

- `.env` は認証情報を含むので必ず `.gitignore`。コミットするのは `.env.example` のみ。
- `infra/.env.example`（Docker 起動用）と、ルートの `.env.example`（AI 用）は別ファイル・別用途。
- CI / runner では `.env` の代わりに Secrets / `EnvironmentFile` で同名変数を注入してよい。

## 実施

- 新規 `.env.example`（リポジトリルート、配布物）: AI 用の全変数の空テンプレ。
  `GITHUB_API_URL` は既定値 `https://api.github.com` 入り。冒頭に読み込み順と
  `infra/.env.example` との違いを明記。
- `docs/ai/env-vars.md`: 「方針」を `.env` ロード規約に書き換え。「実運用での設定」を
  「値の設定方法」に改め、ローカルは `.env`（`~/.env` → `<repo>/.env`）、CI は Secrets、
  常駐は `EnvironmentFile` に整理。「AI が最初に実行する」節に `.env` 読み込みスニペットを追加。
- `docs/ai/common.md`: 前提と実行フロー step1 に `.env` 読み込みを追加。
- `docs/ai/healthcheck.md`: 手順 0 を「読み込みと存在確認」に変更、スニペット追加。
- 入口ファイル（`CLAUDE.md` / `.claude/rules/ai-execution.md` /
  `.github/copilot-instructions.md` / `.github/instructions/ai-execution.instructions.md`）の
  「実処理前」手順に `.env` 読み込みを追加。
- `infra/.env.example` ヘッダ: AI 用はルート `.env.example` と明記。
- `scripts/export-ai-config.sh`: 配布物に `.env.example` を追加。
- `docs/ai/DISTRIBUTION.md` / `README.md`: 配布物リストに `.env.example`、導入手順を `.env` 方式に。
- `MANUAL.md` 手順 3: `export` 列挙から `cp .env.example .env` + 読み込みスニペットに変更。
- `.gitignore`: ルート `.env` は既に無視、`.env.example` は追跡（確認済み）。

## GitHub PR 手動テスト（Copilot Chat）向け

- `.github/skills/github-pr/` と `.claude/skills/github-pr/` を追加済み（commit 573e04f）。
- ユーザーがトークンを用意済み。環境変数は `<repo>/.env`（または `~/.env`）に置き、
  Copilot Agent モードのターミナルで上記スニペットで読み込む。
- テスト実施はユーザー、結果はユーザーから共有される。

## 残（本日）

- C: GitHub PR 手順の手動テスト（ユーザー実施待ち）
- D: cockpit の実操作確認
- F: 監査ログ・操作履歴
- A: PR #3 マージ（ユーザー操作）
