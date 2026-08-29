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

## 追記: スキル実行時に .env を読み込む方式へ

会話で手動スニペットを案内する運用は無駄、との指摘。各スキルの「進め方」1 番目に
`.env` 読み込みを組み込み、そのタスクで使う変数だけをチェックする方式に統一。

- 全 SKILL.md（`gitea-pr` / `github-pr` / `redmine-ticket` / `pr-and-ticket` × `.claude` `.github` = 8）
  の step1 を統一:
  「`set -a; [ -f ~/.env ] && . ~/.env; [ -f .env ] && . .env; set +a` で読み込み →
  `.env` も `~/.env` も無ければ中断し `cp .env.example .env` と該当変数の記入を依頼 →
  読み込み後、そのスキルで使う変数のみ未設定チェック、`MISSING:` は変数名だけ伝えて中断」
- `docs/ai/env-vars.md`「AI が最初に実行する」に「タスク別の必要変数」表を追加
  （gitea-pr=GITEA_*4、github-pr=GITHUB_*4、redmine=REDMINE_*3、Git=GIT_USERNAME/PASSWORD、
  SVN=SVN_*3、pr-and-ticket=使う分だけ）。全変数一括チェックはやめる。
- `docs/ai/common.md` step1 / `docs/ai/healthcheck.md` 手順 0 も「使う変数だけ」に修正。
- `.env.example` ヘッダに「使うサービスのブロックだけ埋めればよい」を明記。

## 残（本日）

- C: GitHub PR 手順の手動テスト（ユーザー実施待ち）
- D: cockpit の実操作確認
- F: 監査ログ・操作履歴
- A: PR #3 マージ（ユーザー操作）
