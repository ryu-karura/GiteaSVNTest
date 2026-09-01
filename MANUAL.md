# MANUAL — セットアップと使い方

上から順に実行すれば、試験環境の構築から AI 実行（PR 作成・チケット更新）まで通せる。

- コマンドは `infra/` ディレクトリで実行する（特記あるものを除く）。
- `docker` は Docker / podman どちらでも可。podman rootless の場合は「補足: podman rootless」を先に読む。

---

## 0. 前提

- `docker` と `docker compose`（または `podman` + `podman-compose`）
- `curl`, `jq`, `git`, `svn`（クライアント側の疎通確認に使う。無ければ該当手順を読み替える）
- 空いているホストポート: 8080 / 3000 / 2222 / 8081 / 8082

---

## 1. 試験環境の起動

```bash
cd infra
cp .env.example .env          # 必要なら値を編集。infra/.env はコミットしない
docker compose up -d
```

Redmine の初回マイグレーションに 1〜2 分かかる。全サービスが healthy になるまで待つ:

```bash
watch -n5 'docker compose ps'
# gst-redmine / gst-gitea が (healthy) になれば OK
```

`gitea-runner` は DinD 版（コンテナ内 dockerd、`privileged: true`）で、ホスト socket は
不要だが登録トークン未設定だと起動に失敗する（手順 2-4 で設定する）。
まずは他サービスだけ上げてもよい:

```bash
docker compose up -d redmine-db redmine gitea-db gitea svn1 svn2
```

---

## 2. 初期データ投入

順番が重要。

### 2-1. Gitea 管理者の作成

`gitea/gitea` イメージは管理者を自動作成しない（`INSTALL_LOCK=true` で起動済み）。
CLI で作成する。**`-u git` で実行する**（root では拒否される）。

```bash
docker compose exec -u git gitea gitea admin user create --admin \
  --username giteaadmin --password giteaadmin_pass \
  --email giteaadmin@example.com --must-change-password=false
```

### 2-2. Redmine ブートストラップ

デフォルトデータ（トラッカー等）の投入、REST API の有効化、admin API キーの取得を行う。
`docker exec` は entrypoint を経由せず `REDMINE_SECRET_KEY_BASE` を解釈しないため、
`SECRET_KEY_BASE` を明示的に渡す（値は `docker-compose.yml` の `REDMINE_SECRET_KEY_BASE`）。

```bash
docker compose exec -T \
  -e SECRET_KEY_BASE=change_me_secret_key_base \
  redmine bin/rails runner - < seed/redmine_bootstrap.rb
```

出力の `admin API key = <40文字>` を控える。**これが Redmine の API キー**
（Redmine が生成した値。固定はできない）。

### 2-3. seed コンテナ（Gitea / SVN / Redmine のデータ投入）

手順 2-2 で控えた Redmine API キーを渡す。

```bash
docker compose --profile seed run --rm \
  -e REDMINE_SEED_API_KEY=<手順2-2で控えた40文字> seed
```

- Gitea: `testorg` Org、`testorg/sample-app` リポジトリ、`feature/seed-change` ブランチ（差分あり）
- SVN: `repo1` / `repo2` の `trunk/sample.txt`
- Redmine: `ai-test` プロジェクト（トラッカー紐付け済み）+ サンプルチケット 2 件

出力の `GITEA_API_TOKEN=<40文字>` を控える。**これが Gitea の API トークン**。
（2 回目以降の実行では「already exists」で再表示されない。必要なら Gitea 管理画面で再発行する。）

### 2-4. Gitea Actions runner（任意）

登録トークンを取得して `.env` に設定し、runner を起動する。

```bash
docker compose exec -u git gitea gitea actions generate-runner-token
# 出力値を infra/.env の GITEA_RUNNER_REGISTRATION_TOKEN= に設定
docker compose up -d gitea-runner
docker compose logs --tail=20 gitea-runner       # "runner: ... registered successfully" を確認
```

登録された runner は Gitea 管理画面 `http://localhost:3000/-/admin/actions/runners` でも確認できる。

ワークフローの動作確認（任意）: `testorg/sample-app` に `.gitea/workflows/ci.yml` を置いて push すると
runner がジョブを拾う（runner ログに `task N repo is testorg/sample-app` が出る）。

runner イメージは公式の `gitea/runner`（旧 `gitea/act_runner` から改名）。compose の既定は
`gitea/runner:3.3.1-dind`（コンテナ内で dockerd を起動する DinD 版、`privileged: true`）。
ホストの Docker ソケットはマウントしない。

> **podman rootless での runner**:
> - `gitea/runner:3.3.1`（ホスト socket マウント版）は、rootless podman ではソケットの uid と
>   コンテナ内 uid がずれてジョブ実行コンテナが起動できず、ジョブが完走しない。
> - `gitea/runner:3.3.1-dind-rootless` は、コンテナ内でさらに rootless dockerd を起動する際に
>   `newuidmap` が権限不足で失敗する（userns の入れ子不可）。使えない。
> - **`gitea/runner:3.3.1-dind`（既定）で解決**。`privileged: true` のコンテナ内で root の
>   dockerd が動き、userns の入れ子が無いため rootless podman 上でもジョブが完走する
>   （検証: `echo` / `uname -a` / `docker version` の 3 ステップジョブが success、約 1 分）。

#### ワークフロー実行結果の取得

Gitea 1.22 には Actions 用の REST API（`/api/v1/repos/.../actions/runs` 等）が無い。
結果は次のいずれかで確認する。

- runner ログ: `podman logs gst-gitea-runner`（`task N repo is ...` 以降）
- 管理画面: `http://localhost:3000/testorg/sample-app/actions`
- 内部 JSON エンドポイント（セッション cookie + `x-csrf-token` が必要）:

  ```bash
  # 事前に /user/login へ POST してセッション cookie（cookie jar）を取得しておく
  csrf=$(curl -s -b cj.txt "$G/testorg/sample-app/actions/runs/<RUN>" \
    | grep -oE "csrfToken:[^,]+" | grep -oE "'[^']+'" | tr -d "'")
  curl -s -b cj.txt -H "x-csrf-token: $csrf" -H 'Content-Type: application/json' \
    -X POST "$G/testorg/sample-app/actions/runs/<RUN>/jobs/0" -d '{}' \
    | jq '{state, job0: .job0.status, steps: [.jobs[0].steps[] | {summary, status}]}'
  # state == "success" で成功。各 step の status も success。
  ```

---

## 3. AI 実行用の環境変数

AI（Claude / Copilot）が参照するのは `docs/ai/env-vars.md` の変数。
`infra/.env`（Docker 起動用）とは別物。リポジトリルートの `.env.example` をコピーして
`<repo>/.env` を作り、値を記入する（`.env` は `.gitignore` 済み）。

```bash
cd ..                    # リポジトリルート
cp .env.example .env
```

`.env`（試験環境・既定構成での値）:

```bash
GITEA_BASE_URL=http://localhost:3000
GITEA_API_TOKEN=<手順2-3の GITEA_API_TOKEN>
GITEA_OWNER=testorg
GITEA_REPO=sample-app

REDMINE_BASE_URL=http://localhost:8080
REDMINE_API_KEY=<手順2-2の admin API key>
REDMINE_PROJECT=ai-test

SVN_BASE_URL=http://localhost:8081/svn      # repo2 は 8082
SVN_USERNAME=svnuser
SVN_PASSWORD=svnpass

GIT_USERNAME=giteaadmin
GIT_PASSWORD=<手順2-3の GITEA_API_TOKEN>    # Gitea はトークンをパスワード欄に使う
GIT_AUTHOR_NAME="AI Bot"
GIT_AUTHOR_EMAIL=ai-bot@example.com
```

読み込み + 未設定チェック（AI が処理開始時に実行する内容）。bash:

```bash
set -a
[ -f "$HOME/.env" ] && . "$HOME/.env"
[ -f .env ] && . .env
set +a

for v in GITEA_BASE_URL GITEA_API_TOKEN GITEA_OWNER GITEA_REPO \
         REDMINE_BASE_URL REDMINE_API_KEY \
         SVN_BASE_URL SVN_USERNAME SVN_PASSWORD \
         GIT_USERNAME GIT_PASSWORD; do
  [ -z "${!v}" ] && echo "MISSING: $v"
done
echo "env check done"
```

PowerShell 版と、各手順の `curl` の PowerShell 版は `docs/ai/common.md`「シェル」と
`docs/ai/env-vars.md` / `docs/ai/healthcheck.md` の PowerShell ブロックを参照
（`curl` → `curl.exe`、`jq` → `jq.exe`、`~` → `$HOME`）。

---

## 4. 疎通確認

`docs/ai/healthcheck.md` の手順を実行する。要点だけ抜粋:

```bash
# Gitea
curl -sf "${GITEA_BASE_URL}/api/healthz" | jq -c '.status'
curl -sf -H "Authorization: token ${GITEA_API_TOKEN}" \
  "${GITEA_BASE_URL}/api/v1/repos/${GITEA_OWNER}/${GITEA_REPO}" \
  | jq -c '{full_name, default_branch, permissions}'

# Redmine
curl -sf -H "X-Redmine-API-Key: ${REDMINE_API_KEY}" \
  "${REDMINE_BASE_URL}/users/current.json" | jq -c '.user | {id, login}'
curl -sf -H "X-Redmine-API-Key: ${REDMINE_API_KEY}" \
  "${REDMINE_BASE_URL}/projects/${REDMINE_PROJECT}.json" | jq -c '.project | {id, identifier}'

# SVN（svn クライアントがある場合）
svn info --non-interactive --no-auth-cache \
  --username "${SVN_USERNAME}" --password "${SVN_PASSWORD}" \
  "${SVN_BASE_URL}/repo1" | grep -E 'URL:|Revision:'

# Git
git ls-remote "${GITEA_BASE_URL}/${GITEA_OWNER}/${GITEA_REPO}.git" | head -3
```

すべて成功したら AI 実行の準備完了。

---

## 5. AI での実行例（一連のシナリオ）

`docs/ai/scenario-pr-and-ticket.md` の手順。ここでは `curl` で最小の E2E を示す。
seed が作った `feature/seed-change` ブランチから PR を立て、Redmine チケット #1 を更新する。

```bash
API="${GITEA_BASE_URL}/api/v1"
REPO="repos/${GITEA_OWNER}/${GITEA_REPO}"
GAUTH=(-H "Authorization: token ${GITEA_API_TOKEN}" -H "Content-Type: application/json")

# 5-1. PR 作成（tea 不使用）
RESP=$(curl -s -w '\n%{http_code}' "${GAUTH[@]}" -X POST "${API}/${REPO}/pulls" -d @- <<'JSON'
{"head":"feature/seed-change","base":"main","title":"seed change を main へ","body":"MANUAL の E2E。Redmine #1 と関連。"}
JSON
)
echo "PR HTTP $(printf '%s' "$RESP" | tail -n1)"
PR_URL=$(printf '%s' "$RESP" | sed '$d' | jq -r '.html_url')
PR_NUM=$(printf '%s' "$RESP" | sed '$d' | jq -r '.number')
echo "PR #${PR_NUM} ${PR_URL}"

# 5-2. Redmine チケット #1 を更新（PUT、notes=コメント、status_id=2）
RAUTH=(-H "X-Redmine-API-Key: ${REDMINE_API_KEY}" -H "Content-Type: application/json")
curl -s -o /dev/null -w 'issue PUT: %{http_code}\n' "${RAUTH[@]}" \
  -X PUT "${REDMINE_BASE_URL}/issues/1.json" \
  -d "{\"issue\":{\"notes\":\"PR を作成しました: ${PR_URL}\",\"status_id\":2}}"

# 5-3. 反映確認
curl -sf "${RAUTH[@]}" "${REDMINE_BASE_URL}/issues/1.json?include=journals" \
  | jq -c '.issue | {id, status: .status.name, last_note: (.journals[-1].notes)}'
```

期待: PR 作成 `201`、issue PUT `204`、反映確認でステータスが `In Progress`、
最後のコメントに PR の URL。

`422 already exists`（PR 重複）の場合は既存 PR を検索する:

```bash
curl -sf "${GAUTH[@]}" \
  "${API}/${REPO}/pulls?state=open&head=${GITEA_OWNER}:feature/seed-change" \
  | jq -c '.[0] | {number, html_url}'
```

---

## 6. E2E テスト（画面操作 + Actions）

複数人での実運用に近い流れ（issue 起票 → ブランチ作成 → Actions が PR 自動作成 →
別ユーザーが修正 → レビュー・マージ → issue クローズ）を通しで確認するテスト。
手順は **[docs/tests/e2e-issue-to-merge.md](docs/tests/e2e-issue-to-merge.md)**。

- 前提: 2-4 の Actions runner 登録が済んでいること
- 使うワークフロー: `infra/workflows/auto-pr.yml` / `infra/workflows/close-issue-on-merge.yml`
  （対象リポジトリの `.gitea/workflows/` に置く）
- テスト用ユーザー `tanaka` / `yamada` の作成手順もテスト側に記載

---

## 7. 後片付け

```bash
cd infra
docker compose down          # コンテナ停止（データは残る）
docker compose down -v       # ボリュームごと削除（完全初期化）
```

---

## 補足: podman rootless

- `docker` / `docker compose` は `podman` / `podman-compose` で読み替える。
- イメージの短縮名解決でエラーが出る場合、`~/.config/containers/registries.conf` に:

  ```ini
  unqualified-search-registries = ["docker.io"]
  short-name-mode = "permissive"
  ```

- `gitea-runner` は DinD 版のため、rootless podman では `gitea/runner:3.3.1-dind`
  （既定）を使う。`3.3.1`（ホスト socket 版）と `3.3.1-dind-rootless` は動かない
  （手順 2-4 の注意を参照）。ホストの Docker ソケットをマウントするサービスは無いので
  `podman.socket` の有効化は不要。

- `svn1` と `svn2` は同じ Dockerfile だがイメージタグが分かれる。両方をビルドする:
  `docker compose build svn1 svn2`
- `--profile` 付きサービス（`seed`）を含む一括操作でエラーが出ることがある。
  `seed` は上記の `docker compose --profile seed run --rm ... seed` で個別に実行する。

---

## 補足: トラブルシュート

| 症状 | 原因 / 対処 |
|---|---|
| healthcheck が `curl: not found` | `svn-apache` は curl 入りで再ビルド（`docker compose build svn1 svn2`）。 |
| bootstrap が `Missing secret_key_base` | `docker compose exec` に `-e SECRET_KEY_BASE=...` を付ける（手順 2-2）。 |
| Redmine チケット作成が `422 Tracker cannot be blank` | デフォルトデータ未投入。`redmine_bootstrap.rb` を実行（手順 2-2）。 |
| seed の Redmine 部分が `API キー未有効` でスキップ | 手順 2-2 の出力キーを `-e REDMINE_SEED_API_KEY=` に渡す（`.env` の値ではない）。 |
| Gitea トークンが再表示されない | 2 回目以降の seed では出ない。Gitea 管理画面で再発行するか、`docker compose down -v` で作り直す。 |
| `gitea admin user create` が `run as root` で失敗 | `docker compose exec -u git gitea ...` にする。 |
