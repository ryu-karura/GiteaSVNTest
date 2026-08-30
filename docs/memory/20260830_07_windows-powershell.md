# 20260830_07 Windows（PowerShell）対応: 全レシピに PS 版を併記

## 背景

現状の指示・スニペットは bash 前提（`set -a` / `. .env` / `${!v}` / `for v in` /
ヒアドキュメント `<<JSON` / bash 配列 `AUTH=(…)` `"${AUTH[@]}"` / `printf` `sed` `grep`
`/dev/null` / `~` 展開）。WSL2 と Git Bash では動くが、Windows ネイティブの
PowerShell / cmd では大半が動かない。静的検証で確認。

方針（ユーザー選択）: **PowerShell 版を併記**。cmd は非対象。

## 実施

### 共通パターンの集約

`docs/ai/common.md` に「## シェル」節を追加:
- bash 系（WSL2 / Git Bash / macOS / Linux）と PowerShell 5.1+ / 7 の両対応、cmd 非対象
- PowerShell の注意: `curl` → **`curl.exe`**（PS5.1 は `Invoke-WebRequest` の別名）、
  `jq` → `jq.exe`、`~` → `$HOME`、`/dev/null` → `$null`
- 「共通パターン（PowerShell）」: `.env` 読み込み / 未設定チェック / API 呼び出し
  （`-H` を直接並べ、本文は here-string、`-w "`n%{http_code}"` でステータス併記）

### 各レシピに PowerShell 版を追加

- `docs/ai/env-vars.md`: `.env` 読み込みと未設定チェックに PS 版を併記
- `docs/ai/healthcheck.md`: 手順 0〜5 に PS 版（`curl.exe` / `jq.exe`、svn/git はそのまま `$env:`）
- `docs/ai/gitea-pr.md` / `github-pr.md` / `redmine-issue.md`: 末尾に「## PowerShell 版」
  （事前確認〜作成〜検索〜コメント〜クローズ/マージを 1 ブロックで）
- `docs/ai/git-svn-ops.md`: 「## PowerShell 版」（`$env:` 参照、SVN は PS 配列 + splat
  `svn @svnauth …`。`git -c` の helper 文字列は Git Bash 前提のため、PS 単独環境では
  `git config --global credential.helper store` を使う注記）
- `docs/ai/scenario-pr-and-ticket.md`: 手順 3〜5 の PS 版

### 入口ファイル

`CLAUDE` 系（`.claude/rules/ai-execution.md` / `.github/copilot-instructions.md` /
`.github/instructions/ai-execution.instructions.md`）に「コマンド例は bash / PowerShell
併記。実行シェルに合う方を使う」を追記。`MANUAL.md` 手順 3 にも PS 版への導線。
`docs/ai/DISTRIBUTION.md` 冒頭に「対応シェル: bash 系 と PowerShell 5.1+/7」。

### 改行コード

`.gitattributes` を新規追加:
- `*.sh` / `*.env` / `.env.example` / `infra/.env.example` → `eol=lf`
  （Windows で `core.autocrlf=true` でも `export-ai-config.sh` が CRLF 化しない）
- `*.ps1` → `eol=crlf`

### PowerShell 版スクリプト

`scripts/export-ai-config.ps1` を追加（`export-ai-config.sh` の PS 移植、`-Dest` / `-DryRun`）。

## 未検証

実機 Windows での動作確認は未（ユーザーが Windows でチェックアウトしてテスト予定）。
本コミットは静的レビュー + PS 版の追記まで。

## 残

なし（F は不要と確認済み。D は cockpit 除外で消滅）。
