# 共通：前提・実行フロー・報告様式

## 前提

- 参照する環境変数は `docs/ai/env-vars.md` に定義。処理開始時に `.env` から読み込む
  （`~/.env` → `./.env` の順、後勝ち）。CI / runner では Secrets や `EnvironmentFile` で
  同名の変数を注入してよい。
- 疎通確認は `docs/ai/healthcheck.md` の手順に従う。
- `curl` は常に `-sf`（サイレント + HTTP エラーで非 0 終了）を基本にする。
  レスポンス本文が必要なときは `-s` にして `-w '\n%{http_code}'` で status を併記。

## シェル

各レシピは **bash 版と PowerShell 版を併記**する。実行環境のシェルに合う方を使う。

- **bash 系**（WSL2 / Git Bash / macOS / Linux）: レシピの bash ブロックをそのまま。
- **Windows ネイティブ（PowerShell 5.1+ / 7）**: レシピの PowerShell ブロック。以下に注意:
  - `curl` は PowerShell 5.1 で `Invoke-WebRequest` の別名。**必ず `curl.exe` と書く**。
  - `jq` は `jq.exe` を PATH に入れる（未導入なら `winget install jqlang.jq`）。
  - `~` は展開されない。`$HOME` を使う。`/dev/null` は `$null`。
- `cmd.exe` は非対象。PowerShell か bash を使う。

### 共通パターン（PowerShell）

**.env の読み込み**（`~/.env` → `./.env`、後勝ち）:

```powershell
foreach ($f in @("$HOME\.env", ".\.env")) {
  if (Test-Path $f) {
    Get-Content $f | Where-Object { $_ -match '^\s*[^#].*?=' } | ForEach-Object {
      $k, $v = $_ -split '=', 2
      Set-Item -Path "Env:$($k.Trim())" -Value $v.Trim().Trim('"')
    }
  }
}
```

**未設定チェック**（そのタスクで使う変数だけ）:

```powershell
foreach ($v in 'GITHUB_API_URL','GITHUB_TOKEN','GITHUB_OWNER','GITHUB_REPO') {
  if (-not [Environment]::GetEnvironmentVariable($v)) { "MISSING: $v" }
}
```

**API 呼び出し**（ヘッダを直接並べ、本文は here-string、ステータスを併記）:

```powershell
$body = @'
{ "title": "変更の要約", "head": "feature/x", "base": "main", "body": "説明。" }
'@
curl.exe -s -w "`n%{http_code}" `
  -H "Authorization: Bearer $env:GITHUB_TOKEN" `
  -H "Accept: application/vnd.github+json" `
  -H "X-GitHub-Api-Version: 2022-11-28" `
  -X POST "$env:GITHUB_API_URL/repos/$env:GITHUB_OWNER/$env:GITHUB_REPO/pulls" `
  --data $body
# 最終行が HTTP ステータス。手前が JSON 本文。
```

**JSON パース**: `... | jq.exe '.number'` か、`curl.exe` の本文を `ConvertFrom-Json` に渡す。

## RTK（利用可能なら使う）

- 実行環境に `rtk`（Rust Token Killer）がある場合、`git` / `svn` / `curl` コマンドは
  `rtk` を前置して実行する（例: `rtk git status`、`rtk svn info ...`、`rtk curl ...`）。
  出力が圧縮され、トークン消費を抑えられる。`rtk` は専用フィルタが無いコマンドは
  素通しするため、前置しても動作は変わらない。
- Claude Code の環境では PreToolUse フックが `git` / `curl` を自動で `rtk ...` に
  書き換える。手順内のコマンドは `rtk` 無しで書いてよい（フックが付与する）。
  `svn` はフック対象外なので、`rtk` があるなら明示的に `rtk svn ...` とする。
- **JSON レスポンスを `jq` でパースする `curl`（PR 作成、チケット作成の結果取得など）も
  `rtk curl` で問題ない**（パイプ先がある場合、`rtk` はレスポンスをそのまま渡す）。
  念のため生の応答が必要なときは `rtk proxy curl ...` でフィルタを外して実行する。
- `rtk` が無い環境（一部の CI / Copilot 実行環境など）では、そのまま `git` / `svn` /
  `curl` を使う。手順の可搬性のため、レシピ本文は `rtk` 無しで記載する。

## 実行フロー（PLAN.md「指示例」1〜5 に対応）

1. **環境変数の読み込み + チェック** — `.env` を `~/.env` → `./.env` の順に読み込む。
   - bash: `set -a; [ -f ~/.env ] && . ~/.env; [ -f .env ] && . .env; set +a`
   - PowerShell: 上記「共通パターン（PowerShell）」の `.env` 読み込み
   `.env` も `~/.env` も無ければ中断し、`cp .env.example .env` と該当変数の記入を依頼。
   読み込み後、**このタスクで使う変数だけ**（`docs/ai/env-vars.md`「タスク別の必要変数」）
   未設定チェックし、`MISSING:` があればその変数名を報告して中断。
2. **疎通確認** — `docs/ai/healthcheck.md` の対象サービス分を実行。失敗したらサービス名・
   ステータス・エラーコードを報告して中断。
3. **ソース操作** — `git-svn-ops.md` に従い、取得 / 変更 / 差分確認 / コミット / push。
4. **PR 作成** — Gitea は `gitea-pr.md`、GitHub は `github-pr.md`。作成した PR 番号と URL を控える。
5. **チケット作成 / 更新** — `redmine-issue.md`。PR 番号・URL をチケットに紐付ける。
6. **報告** — 下記样式。

## 報告様式

```
## 実行結果
- 環境変数チェック: OK / MISSING: <名前>
- 疎通確認: Gitea=OK Redmine=OK SVN=OK Git=OK
- ソース操作: <ブランチ名> に <n> ファイル変更、push 済み
- PR: #<番号> <URL>（Gitea / GitHub）
- チケット: #<ID> <URL>（新規作成 / 更新）

## API 応答（要点）
- <エンドポイント>: <status> <キーとなる値>

## エラー
- なし / <内容と対処>
```

## 禁止事項

- `tea`, `gh` コマンドの使用（PR 作成は curl）。
- 認証トークン・パスワード・API キーの値を出力すること（PR 本文・チケット・ログ・報告すべて）。
- 疎通確認をスキップした状態での本処理実行。
- ユーザー確認なしでの破壊的操作（force push、ブランチ削除、チケット削除）。

## 確認の出し方

不明点は 1〜3 件、箇条書きで簡潔に。例:

- 対象ブランチ名は `feature/<ticket-id>-<slug>` でよいか
- PR のベースブランチは `main` でよいか
- 更新対象の Redmine チケット番号
