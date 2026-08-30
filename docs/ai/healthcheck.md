# 疎通ヘルスチェック手順

AI 実行前、および環境構築後の確認に使う。Docker 側のコンテナ healthcheck とは別に、
「AI が使う経路（REST API / コマンド）で到達できるか」を確認する。

`rtk` がある環境では以下の `curl` / `svn` / `git` に `rtk` を前置してよい
（`jq` パースも可）。詳細は `docs/ai/common.md`「RTK（利用可能なら使う）」。

以下のブロックは bash。**PowerShell では `curl` を `curl.exe` に置き換え**、
`docs/ai/common.md`「共通パターン（PowerShell）」の形（`-H` を直接並べる）で実行する。

前提: `docs/ai/env-vars.md` の手順で `.env` を読み込み済み。

## 0. 環境変数の読み込みと存在確認

bash:

```bash
set -a
[ -f "$HOME/.env" ] && . "$HOME/.env"
[ -f .env ] && . .env
set +a
```

PowerShell:

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

`.env` も `~/.env` も無ければ中断し、`cp .env.example .env` と該当変数の記入を依頼する。
チェックするのは**今回使うサービス分の変数だけ**（`docs/ai/env-vars.md`「タスク別の必要変数」）。
以下は全サービスを使う場合の例:

bash:

```bash
for v in GITEA_BASE_URL GITEA_API_TOKEN GITEA_OWNER GITEA_REPO \
         REDMINE_BASE_URL REDMINE_API_KEY \
         SVN_BASE_URL SVN_USERNAME SVN_PASSWORD \
         GIT_USERNAME GIT_PASSWORD; do
  [ -z "${!v}" ] && echo "MISSING: $v"
done
echo "env check done"
```

PowerShell:

```powershell
foreach ($v in 'GITEA_BASE_URL','GITEA_API_TOKEN','GITEA_OWNER','GITEA_REPO',
               'REDMINE_BASE_URL','REDMINE_API_KEY',
               'SVN_BASE_URL','SVN_USERNAME','SVN_PASSWORD',
               'GIT_USERNAME','GIT_PASSWORD') {
  if (-not [Environment]::GetEnvironmentVariable($v)) { "MISSING: $v" }
}
"env check done"
```

## 1. Gitea（REST API）

```bash
# サービス生存
curl -sf "${GITEA_BASE_URL}/api/healthz"

# 認証 + 対象リポジトリの存在
curl -sf -H "Authorization: token ${GITEA_API_TOKEN}" \
  "${GITEA_BASE_URL}/api/v1/repos/${GITEA_OWNER}/${GITEA_REPO}" \
  | jq '{full_name, default_branch, permissions}'
```

PowerShell:

```powershell
curl.exe -sf "$env:GITEA_BASE_URL/api/healthz"
curl.exe -sf -H "Authorization: token $env:GITEA_API_TOKEN" `
  "$env:GITEA_BASE_URL/api/v1/repos/$env:GITEA_OWNER/$env:GITEA_REPO" | jq.exe '{full_name, default_branch, permissions}'
```

期待: `full_name` が `OWNER/REPO`、`permissions.push == true`。

## 2. GitHub（REST API・使用時のみ）

```bash
curl -sf -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  "${GITHUB_API_URL}/repos/${GITHUB_OWNER}/${GITHUB_REPO}" \
  | jq '{full_name, default_branch, permissions}'
```

PowerShell:

```powershell
curl.exe -sf -H "Authorization: Bearer $env:GITHUB_TOKEN" `
  "$env:GITHUB_API_URL/repos/$env:GITHUB_OWNER/$env:GITHUB_REPO" | jq.exe '{full_name, default_branch, permissions}'
```

## 3. Redmine（REST API）

```bash
# サービス生存
curl -sf -o /dev/null -w '%{http_code}\n' "${REDMINE_BASE_URL}/login"

# 認証（API キー有効 + REST 有効）
curl -sf -H "X-Redmine-API-Key: ${REDMINE_API_KEY}" \
  "${REDMINE_BASE_URL}/users/current.json" | jq '.user | {id, login, admin}'

# 対象プロジェクト
curl -sf -H "X-Redmine-API-Key: ${REDMINE_API_KEY}" \
  "${REDMINE_BASE_URL}/projects/${REDMINE_PROJECT}.json" | jq '.project | {id, identifier, name}'
```

PowerShell:

```powershell
curl.exe -sf -o $null -w "%{http_code}`n" "$env:REDMINE_BASE_URL/login"
curl.exe -sf -H "X-Redmine-API-Key: $env:REDMINE_API_KEY" `
  "$env:REDMINE_BASE_URL/users/current.json" | jq.exe '.user | {id, login, admin}'
curl.exe -sf -H "X-Redmine-API-Key: $env:REDMINE_API_KEY" `
  "$env:REDMINE_BASE_URL/projects/$env:REDMINE_PROJECT.json" | jq.exe '.project | {id, identifier, name}'
```

期待: `users/current.json` が 200 で `login` を返す。401 なら API キー不正または REST 未有効
（`infra/seed/redmine_bootstrap.rb` を実行）。

## 4. SVN（`svn` コマンド）

```bash
svn info --non-interactive --no-auth-cache \
  --username "${SVN_USERNAME}" --password "${SVN_PASSWORD}" \
  "${SVN_BASE_URL}/repo1"
```

PowerShell も同じ（`svn` はクロスプラットフォーム。変数参照だけ `$env:` に）:

```powershell
svn info --non-interactive --no-auth-cache `
  --username $env:SVN_USERNAME --password $env:SVN_PASSWORD `
  "$env:SVN_BASE_URL/repo1"
```

期待: `Revision:` 行が出る。`E170013` / `E175002` は URL 誤り、`E170001` は認証失敗。

## 5. Git（`git` コマンド）

```bash
# Gitea 上のリポジトリへ HTTP で到達（認証情報は netrc / credential helper 側）
git ls-remote "${GITEA_BASE_URL}/${GITEA_OWNER}/${GITEA_REPO}.git" | head -n 3
```

PowerShell: `git ls-remote "$env:GITEA_BASE_URL/$env:GITEA_OWNER/$env:GITEA_REPO.git" | Select-Object -First 3`

期待: `HEAD` と各 ref のハッシュが返る。`fatal: Authentication failed` は
`GIT_USERNAME` / `GIT_PASSWORD` の不備。

## 一括チェックの終了条件

- 上記 1・3・4・5 がすべて成功 → AI 実行可。
- いずれか失敗 → 失敗したサービス名・HTTP ステータス・エラーコードを報告し、後続を実行しない。
