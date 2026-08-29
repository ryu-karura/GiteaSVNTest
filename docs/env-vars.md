# 環境変数 標準定義

AI 実行時（Claude / GitHub Copilot）および Docker 試験環境で参照する環境変数の命名規則と一覧。

## 方針

- API キー・アカウント・パスワードはリポジトリ配下に置かない。OS のユーザー環境変数、または runner 側のシークレット注入で渡す。
- リポジトリには `.env` を **コミットしない**。参照用に `infra/.env.example`（値は空またはダミー）のみ置く。
- AI（Claude / Copilot）は下記の変数名だけを参照する。存在しない場合は処理を中断し、未設定の変数名を報告する。

## 命名規則

- 形式: `<サービス>_<用途>`。すべて大文字、区切りは `_`。
- `<サービス>`: `GITEA` / `GITHUB` / `REDMINE` / `SVN` / `GIT`
- `<用途>`: `BASE_URL`（末尾スラッシュなし） / `API_TOKEN` / `API_KEY` / `USERNAME` / `PASSWORD` / `OWNER` / `REPO`
- 認証トークンは接尾辞を統一: Gitea/GitHub は `API_TOKEN`、Redmine は `API_KEY`（各サービスの呼称に合わせる）。

## 変数一覧

### Gitea（PR 作成: REST API / curl）

| 変数名 | 用途 | 例 |
|---|---|---|
| `GITEA_BASE_URL` | Gitea のベース URL | `http://localhost:3000` |
| `GITEA_API_TOKEN` | 個人アクセストークン | `xxxxxxxxxxxxxxxx` |
| `GITEA_OWNER` | 対象リポジトリのオーナー | `testorg` |
| `GITEA_REPO` | 対象リポジトリ名 | `sample-app` |

- API ルート: `${GITEA_BASE_URL}/api/v1`
- 認証ヘッダ: `Authorization: token ${GITEA_API_TOKEN}`

### GitHub（PR 作成: REST API / curl）

| 変数名 | 用途 | 例 |
|---|---|---|
| `GITHUB_API_URL` | API のベース URL | `https://api.github.com` |
| `GITHUB_TOKEN` | Personal Access Token | `ghp_xxxxxxxx` |
| `GITHUB_OWNER` | オーナー / Org | `example` |
| `GITHUB_REPO` | リポジトリ名 | `sample-app` |

- 認証ヘッダ: `Authorization: Bearer ${GITHUB_TOKEN}`
- `GITHUB_TOKEN` は GitHub Actions の既定変数名と一致。ローカル実行時も同名を使う。

### Redmine（チケット作成・更新: REST API / curl）

| 変数名 | 用途 | 例 |
|---|---|---|
| `REDMINE_BASE_URL` | Redmine のベース URL | `http://localhost:8080` |
| `REDMINE_API_KEY` | REST API アクセスキー | `0123456789abcdef` |
| `REDMINE_PROJECT` | 既定の対象プロジェクト識別子 | `ai-test` |

- 認証ヘッダ: `X-Redmine-API-Key: ${REDMINE_API_KEY}`
- REST API は Redmine 管理画面「設定 > API」で有効化しておく。

### SVN（`svn` コマンド）

| 変数名 | 用途 | 例 |
|---|---|---|
| `SVN_BASE_URL` | リポジトリのベース URL | `http://localhost:8081/svn` |
| `SVN_USERNAME` | 認証ユーザー | `svnuser` |
| `SVN_PASSWORD` | 認証パスワード | `svnpass` |

- コマンド例: `svn --username "$SVN_USERNAME" --password "$SVN_PASSWORD" --non-interactive checkout "$SVN_BASE_URL/repo1"`

### Git（`git` コマンド。Gitea への push 認証を含む）

| 変数名 | 用途 | 例 |
|---|---|---|
| `GIT_USERNAME` | Gitea の Git 認証ユーザー | `gituser` |
| `GIT_PASSWORD` | Gitea の Git 認証パスワード or トークン | `xxxxxxxx` |
| `GIT_AUTHOR_NAME` | コミット author 名 | `AI Bot` |
| `GIT_AUTHOR_EMAIL` | コミット author メール | `ai-bot@example.com` |

- `GIT_AUTHOR_NAME` / `GIT_AUTHOR_EMAIL` は Git の標準環境変数。`GIT_COMMITTER_*` も同値を設定してよい。
- HTTP 認証は URL 埋め込みを避け、`git -c credential.helper=...` か `~/.netrc` で渡す。

## 未設定チェック（AI が最初に実行）

```bash
for v in GITEA_BASE_URL GITEA_API_TOKEN GITEA_OWNER GITEA_REPO \
         REDMINE_BASE_URL REDMINE_API_KEY \
         SVN_BASE_URL SVN_USERNAME SVN_PASSWORD \
         GIT_USERNAME GIT_PASSWORD; do
  [ -z "${!v}" ] && echo "MISSING: $v"
done
```

`MISSING:` が 1 件でも出たら後続処理を実行せず、不足分をユーザーに報告する。
