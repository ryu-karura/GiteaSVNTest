# 環境変数 標準定義

AI 実行時（Claude / GitHub Copilot）が参照する環境変数の命名規則と一覧。

## 方針

- AI が参照するのは下記の変数名のみ。**処理開始時に `.env` から読み込む**。
- ロード順（後勝ちで上書き）:
  1. `~/.env` — 全プロジェクト共通の既定値（任意）
  2. プロジェクトルートの `./.env` — このプロジェクト固有の値
- `.env` は認証情報を含むので**必ず `.gitignore`**。コミットしてよいのは
  `.env.example`（値は空またはダミー）だけ。
- `infra/.env.example` は **Docker 試験環境の起動専用**。AI 用の `.env` とは
  別ファイル・別用途（`GITEA_API_TOKEN` / `REDMINE_API_KEY` は含まない）。
- CI / runner では `.env` の代わりに Secrets / `EnvironmentFile` で同名の変数を
  注入してよい（読み込み方法が違うだけで、変数名と参照方法は同じ）。
- 変数が未設定なら処理を中断し、未設定の変数名を報告する。

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

## 値の設定方法

変数名は固定（AI が参照するインターフェース）。値の入れ方だけ環境で変える。

### ローカル（Claude Code / Copilot）

`.env` を使う。共通の既定は `~/.env`、プロジェクト固有は `<repo>/.env`。

1. テンプレをコピーして値を記入:

   ```bash
   cp .env.example .env      # <repo>/.env。GIT で追跡されない（.gitignore 済み）
   ```

2. 形式は `KEY=value`。値にスペース・`#` を含むなら `KEY="..."`。

3. AI（または操作者）は処理開始時にこの順で読み込む:

   ```bash
   set -a
   [ -f "$HOME/.env" ] && . "$HOME/.env"
   [ -f .env ] && . .env
   set +a
   ```

   `~/.env` に全プロジェクト共通の値（例: `GITHUB_TOKEN`）を置き、`<repo>/.env` で
   プロジェクト固有の値（`*_OWNER` / `*_REPO` / 各 `*_BASE_URL`）を上書きする使い分けができる。

`direnv` を使う場合は `.envrc` に `dotenv` と書けば同じ `.env` を自動ロードできる
（`.envrc` も `.gitignore` 済み）。

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

## AI が最初に実行する（.env 読み込み + 未設定チェック）

各スキル / タスクの「進め方」1 番目で必ず行う。全変数ではなく、**そのタスクで使う変数だけ**確認する。

1. `.env` を読み込む（`~/.env` → プロジェクトルート `./.env` の順、後勝ち）:

   ```bash
   set -a
   [ -f "$HOME/.env" ] && . "$HOME/.env"
   [ -f .env ] && . .env
   set +a
   ```

2. `.env` も `~/.env` も無ければ**中断**し、ユーザーに依頼する:
   「`cp .env.example .env` を実行し、下表のうち今回のタスクで使う変数だけ記入してください」。

3. 今回のタスクで使う変数だけ未設定チェックする:

   ```bash
   # 例: GitHub PR のタスク
   for v in GITHUB_API_URL GITHUB_TOKEN GITHUB_OWNER GITHUB_REPO; do
     [ -z "${!v}" ] && echo "MISSING: $v"
   done
   ```

   `MISSING:` が出たら中断し、その変数名だけをユーザーに伝えて `.env` への追記を依頼する。

### タスク別の必要変数

| タスク（スキル） | 必要な変数 |
|---|---|
| Gitea PR（`gitea-pr`） | `GITEA_BASE_URL` `GITEA_API_TOKEN` `GITEA_OWNER` `GITEA_REPO` |
| GitHub PR（`github-pr`） | `GITHUB_API_URL` `GITHUB_TOKEN` `GITHUB_OWNER` `GITHUB_REPO` |
| Redmine チケット（`redmine-ticket`） | `REDMINE_BASE_URL` `REDMINE_API_KEY` `REDMINE_PROJECT` |
| Git 操作 | `GIT_USERNAME` `GIT_PASSWORD`（コミットするなら `GIT_AUTHOR_NAME` `GIT_AUTHOR_EMAIL` も） |
| SVN 操作 | `SVN_BASE_URL` `SVN_USERNAME` `SVN_PASSWORD` |
| 一連（`pr-and-ticket`） | 上記のうち実際に使うサービス分だけ |
