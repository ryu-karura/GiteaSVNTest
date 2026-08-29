# 20260830_03 配布物とリポジトリ専用物の分離

## 背景

`.env.example`（Docker 起動用）と `docs/env-vars.md`（AI 実行用）の違いをきっかけに、
このリポジトリの最終目的を「AI 指示ファイルの配布」と明文化し、配布物と
リポジトリ専用物が混在していた状態を整理した。

ユーザー確認（3 点）:
- 分離方式 = ディレクトリ移動 + マニフェスト + 抽出スクリプト
- 共通手順の置き場 = `docs/ai/` に集約
- ルート `CLAUDE.md` = 入口のまま。目的・分離ルールのみ追記（実体移設はしない）

## 実施

### 手順集を docs/ai/ に集約（git mv）

- `ai-instructions/*.md`（7 ファイル）→ `docs/ai/`
- `docs/env-vars.md` → `docs/ai/env-vars.md`
- `docs/healthcheck.md` → `docs/ai/healthcheck.md`
- `ai-instructions/` ディレクトリ削除

参照パスを全ライブファイルで一括更新（`ai-instructions/` → `docs/ai/`、
`docs/env-vars.md` → `docs/ai/env-vars.md`、`docs/healthcheck.md` → `docs/ai/healthcheck.md`）。
対象: `CLAUDE.md` / `PLAN.md` / `MANUAL.md` / `README.md` / `infra/README.md` /
`.claude/rules/` / `.claude/skills/*` / `.github/copilot-instructions.md` /
`.github/instructions/` / `.github/skills/*` / `docs/ai/*` 相互参照。
`docs/memory/` は履歴なので変更しない。

### 配布物マニフェスト

`docs/ai/DISTRIBUTION.md` を新規作成。内容:
- 配布物リスト（`CLAUDE.md` / `.claude/` / `.github/`（copilot-instructions・instructions・skills）/ `docs/ai/`）
- 配布しないもの（`infra/` / `docs/memory/` / `PLAN.md` / `MANUAL.md` / `README.md` / `scripts/`）
- 「なぜ 2 フォルダ + 入口ファイルなのか」= Claude Code はルート `CLAUDE.md` のみ自動ロード、
  Copilot は `.github/` 規定パスを読む。実体は `docs/ai/` 1 箇所に集約し、入口は薄く保つ。
- 導入手順（コピー → `CLAUDE.md` のプロジェクト節を書き換え → env-vars の実値化 → 変数注入 → 疎通確認）

### 抽出スクリプト

`scripts/export-ai-config.sh <対象ルート> [--dry-run]` を新規作成。
配布物（`CLAUDE.md` / `.claude/rules` / `.claude/skills` / `.github/copilot-instructions.md`
/ `.github/instructions` / `.github/skills` / `docs/ai`）を対象プロジェクトの同じ相対パスへ
コピーする。dry-run 動作確認済み。

### 入口ファイルへのルール追記

- `CLAUDE.md`「# GiteaSVNTest プロジェクト」に「## 目的」節と分離ルールを追加。
- `.claude/rules/ai-execution.md` / `.github/copilot-instructions.md` /
  `.github/instructions/ai-execution.instructions.md` に「配布物とリポジトリ専用物を分ける」を追加。

### env-vars.md に実運用の設定方法

`docs/ai/env-vars.md` に「## 実運用での設定」節を追加:
- 開発者マシン: `direnv` + `.envrc`（`.gitignore` に `.envrc` 追加済み）または shell rc
- GitHub Actions: リポジトリ / Org Secrets → workflow の `env:`。`GITHUB_TOKEN` は自動
- self-hosted / 常駐: systemd `EnvironmentFile=`（600、root 所有）

冒頭の説明も「AI 実行用。Docker 起動用は `infra/.env.example`（別物）」に修正。

## 残（本日分）

- C: GitHub PR 手順の実リポジトリ E2E（未）
- D: cockpit の実操作確認（未）
- F: 監査ログ・操作履歴の残し方（未着手）
- A: PR #3 マージ（ユーザー操作）
