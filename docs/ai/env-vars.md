# 環境変数 標準定義

AI 実行時（Claude / GitHub Copilot）が参照する環境変数の命名規則と一覧。
OS / シェル / runner 側に注入する。Docker 試験環境の起動用設定は `infra/.env.example`（別物）。

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

## 実運用での設定

変数名は固定（AI が参照するインターフェース）。値の投入方法だけ環境で変える。
`infra/.env.example` は Docker 試験環境の起動用で別物（`GITEA_API_TOKEN` /
`REDMINE_API_KEY` は含まれない。環境構築後に seed / bootstrap が生成する値のため）。

### 開発者マシン（Claude Code / Copilot をローカルで使う）

`direnv` を使い、プロジェクト直下に `.envrc` を置く（`.gitignore` に `.envrc` を追加）:

```bash
# .envrc
export GITEA_BASE_URL=https://gitea.example.com
export GITEA_API_TOKEN=...      # 個人アクセストークン
export GITEA_OWNER=myteam
export GITEA_REPO=myrepo
export REDMINE_BASE_URL=https://redmine.example.com
export REDMINE_API_KEY=...
export REDMINE_PROJECT=myproject
# 以下同様
```

`direnv allow` で有効化。`direnv` が無ければ shell rc（`~/.bashrc` 等）に `export` を書く。

### GitHub Actions（ワークフローから AI 実行）

- リポジトリ / Org の Secrets に `GITEA_API_TOKEN` `REDMINE_API_KEY` 等を登録。
- workflow で `env:` に展開する:

  ```yaml
  jobs:
    ai-task:
      runs-on: ubuntu-latest
      env:
        GITEA_BASE_URL: ${{ vars.GITEA_BASE_URL }}
        GITEA_API_TOKEN: ${{ secrets.GITEA_API_TOKEN }}
        GITEA_OWNER: ${{ github.repository_owner }}
        GITEA_REPO: ${{ github.event.repository.name }}
        REDMINE_BASE_URL: ${{ vars.REDMINE_BASE_URL }}
        REDMINE_API_KEY: ${{ secrets.REDMINE_API_KEY }}
  ```

- `GITHUB_TOKEN` は Actions 標準で自動注入されるため登録不要。

### self-hosted runner / 常駐サーバー

systemd unit で環境変数ファイルを読み込む（ファイルは 600、root 所有）:

```ini
# /etc/ai-agent.env   (chmod 600)
GITEA_BASE_URL=https://gitea.example.com
GITEA_API_TOKEN=...

# service unit
[Service]
EnvironmentFile=/etc/ai-agent.env
```

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
