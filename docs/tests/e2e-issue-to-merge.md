# E2E テスト: issue 起票 → ブランチ → 自動 PR → レビュー → マージ → issue クローズ

Gitea の画面操作（人間）と Gitea Actions（自動）を組み合わせた、複数人での開発フローを
通しで検証するテスト。REST API 単体の E2E（`MANUAL.md` 5 章）とは別に、
**「画面から始まる実運用に近い流れ」**が成立することを確認する。

- 対象環境: `infra/` の Docker 試験環境（Gitea + gitea-runner）
- 対象リポジトリ: `${GITEA_OWNER}/${GITEA_REPO}`（既定 `testorg/sample-app`）
- 所要時間: 15〜25 分（runner のジョブ待ちを含む）
- このファイルはリポジトリ専用（配布物ではない。`docs/ai/DISTRIBUTION.md` 参照）

## 登場人物

| 役割 | Gitea ユーザー | やること |
|---|---|---|
| 田中 | `tanaka` | issue 起票、ブランチ作成、レビュー、マージ、クローズ確認 |
| 山田 | `yamada` | ブランチ上のコード修正・push |
| （自動） | Actions runner | PR の自動作成、issue の自動クローズ |

同一人物が両アカウントを操作してよい（ブラウザのプロファイルを分けると楽）。

## 検証したいこと

| # | 観点 | 合格条件 |
|---|---|---|
| V1 | 画面からの issue 起票 | issue が `open` で作成される |
| V2 | 画面からのブランチ作成 | `feature/<issue番号>-<slug>` が作られる |
| V3 | Actions による PR 自動作成 | **タイミング A（ブランチ作成時）または B（初回 push 時）のどちらか**で PR が 1 本だけ作られる |
| V4 | 別ユーザーのコード修正 | 山田のコミットが PR に反映される |
| V5 | レビューとマージ | 田中の approve が付き、マージできる |
| V6 | issue のクローズ | Gitea の自動クローズ、または Actions のどちらかで issue が `closed` になる |

V3 と V6 は「どちらの経路で成立したか」を記録する（どちらでも合格）。

---

## 事前準備

### P1. 試験環境と runner

`MANUAL.md` の 1〜2 章を実施済みであること。特に **2-4（Actions runner の登録）は必須**。

```bash
cd infra
docker compose ps                                   # gitea / gitea-runner が Up
docker compose logs --tail=5 gitea-runner           # registered successfully
```

Gitea 側で Actions が有効になっていること（管理画面 → リポジトリ設定 → Actions）。

### P2. テスト用ユーザーの作成

```bash
cd infra
for u in tanaka yamada; do
  docker compose exec -u git gitea gitea admin user create \
    --username "$u" --password "${u}_pass" --email "${u}@example.com" \
    --must-change-password=false
done
```

作成後、Gitea 画面で `testorg` の Owners / Developers チームに 2 人を追加する
（`http://localhost:3000/org/testorg/teams`）。田中はマージ権限が要るので
Owners か、書き込み + マージ可能なチームに入れる。

> パスワードは試験環境専用。`.env` やドキュメントに実値を書き足さないこと。

### P3. ワークフローの配置

`infra/workflows/` の 2 ファイルを、対象リポジトリの `.gitea/workflows/` に置いて
`main` へ push する。

```bash
git clone http://localhost:3000/testorg/sample-app.git /tmp/sample-app
mkdir -p /tmp/sample-app/.gitea/workflows
cp infra/workflows/auto-pr.yml infra/workflows/close-issue-on-merge.yml \
   /tmp/sample-app/.gitea/workflows/
cd /tmp/sample-app
git add .gitea/workflows
git commit -m "add auto-pr / close-issue-on-merge workflows"
git push origin main
```

配置後、`http://localhost:3000/testorg/sample-app/actions` に 2 つのワークフローが
表示されることを確認する。

### P4. 確認用の環境変数

検証コマンド（API 参照）用に、リポジトリルートで `.env` を読み込んでおく。

```bash
set -a; [ -f ~/.env ] && . ~/.env; [ -f .env ] && . .env; set +a
for v in GITEA_BASE_URL GITEA_API_TOKEN GITEA_OWNER GITEA_REPO; do
  [ -n "${!v:-}" ] || echo "MISSING: $v"
done
API="${GITEA_BASE_URL}/api/v1/repos/${GITEA_OWNER}/${GITEA_REPO}"
AUTH=(-H "Authorization: token ${GITEA_API_TOKEN}")
```

```powershell
# PowerShell
$api = "$env:GITEA_BASE_URL/api/v1/repos/$env:GITEA_OWNER/$env:GITEA_REPO"
$hdr = @('-H', "Authorization: token $env:GITEA_API_TOKEN")
```

API は**確認のためだけ**に使う。テスト本体の操作は画面から行う（そこが検証対象）。

---

## テスト手順

### S1. 田中：画面から issue を起票（V1）

1. `tanaka` でログイン → `testorg/sample-app` → Issues → New Issue
2. タイトル: `sample.txt にテスト行を追加する`
3. 本文: 任意（例: `E2E テスト用。auto-pr / close-issue-on-merge の確認。`）
4. Create Issue

採番された番号を `ISSUE` として控える。

```bash
ISSUE=<採番された番号>
curl -sf "${AUTH[@]}" "${API}/issues/${ISSUE}" | jq '{number, title, state, user: .user.login}'
# => state: "open", user: "tanaka"
```

### S2. 田中：画面からブランチを作成（V2）

Gitea 画面 → リポジトリトップのブランチ選択 → ブランチ名を入力 → 「Create branch ... from main」
（または Branches 画面の「New Branch」）。

**ブランチ名は `feature/<ISSUE>-<slug>` にする**（例: `feature/12-add-test-line`）。
ワークフローはこの番号から issue を特定する。

```bash
BRANCH="feature/${ISSUE}-add-test-line"
curl -sf "${AUTH[@]}" "${API}/branches/${BRANCH}" | jq '{name, commit: .commit.id}'
```

### S3. Actions：PR の自動作成（タイミング A）（V3）

ブランチ作成をトリガーに `auto-pr` が動く。**この時点では main との差分が無いため、
ワークフローは PR を作らずに正常終了する**（Gitea は差分ゼロの PR を作れない）。
ログに `skip: no diff against main yet` が出れば期待どおり。

```bash
docker compose -f infra/docker-compose.yml logs --tail=30 gitea-runner | grep -i "auto-pr" || true
# 画面: http://localhost:3000/testorg/sample-app/actions
```

> Gitea のバージョンによっては `create` イベントが発火しない。その場合はここは空振りで、
> 次の S5（push）で PR が作られる。どちらでも V3 は合格。

### S4. 山田：ブランチのコードを修正（V4）

`yamada` で作業する。画面のエディタ（ブランチを選択 → ファイル → 編集 → Commit）でも、
`git` でもよい。`git` の場合:

```bash
git clone http://localhost:3000/testorg/sample-app.git /tmp/yamada-work
cd /tmp/yamada-work
git config user.name yamada; git config user.email yamada@example.com
git switch "feature/${ISSUE}-add-test-line"
echo "e2e test line (issue #${ISSUE})" >> sample.txt
git add sample.txt
git commit -m "sample.txt にテスト行を追加 (refs #${ISSUE})"
git push origin "feature/${ISSUE}-add-test-line"   # 認証: yamada / yamada_pass
```

### S5. Actions：PR の自動作成（タイミング B）（V3）

push をトリガーに `auto-pr` が再度動き、今度は差分があるので PR を作る。
ログに `created: PR #<n>` が出る。既に A で作られていた場合は
`skip: HTTP 409` / `skip: HTTP 422` となり、**PR は 1 本のまま**。

```bash
curl -sf "${AUTH[@]}" "${API}/pulls?state=open" \
  | jq '[.[] | {number, title, head: .head.ref, base: .base.ref, body}]'
# => head が feature/<ISSUE>-... の PR が 1 本、body に "Closes #<ISSUE>"
PR=<PR 番号>
```

```powershell
curl.exe -sf @hdr "$api/pulls?state=open" | jq.exe '[.[] | {number, head: .head.ref, body}]'
```

PR 本文に `Closes #<ISSUE>` が入っていること（S7 の自動クローズ経路がここで決まる）。

### S6. 田中：レビューして承認・マージ（V5）

1. `tanaka` でログイン → 該当 PR → Files changed → 山田の差分を確認
2. Review → **Approve** → Submit review
3. Merge Pull Request（Create merge commit / Squash どちらでも可）

```bash
curl -sf "${AUTH[@]}" "${API}/pulls/${PR}" \
  | jq '{number, state, merged, merged_by: .merged_by.login}'
# => state: "closed", merged: true, merged_by: "tanaka"
curl -sf "${AUTH[@]}" "${API}/pulls/${PR}/reviews" \
  | jq '[.[] | {user: .user.login, state}]'
# => tanaka の APPROVED
```

### S7. issue のクローズ（V6）

次のどちらかで issue が閉じる。

- **経路 1（Gitea 本体）**: PR 本文の `Closes #<ISSUE>` により、`main` へのマージ時に
  Gitea が自動で閉じる。issue のタイムラインに「referenced / closed」の記録が残る。
- **経路 2（Actions）**: `close-issue-on-merge` が `pull_request: closed` + `merged == true`
  で動き、まだ open ならコメントを付けて閉じる。既に閉じていればログに
  `already closed by Gitea` と出て何もしない。

```bash
curl -sf "${AUTH[@]}" "${API}/issues/${ISSUE}" | jq '{number, state, closed_at}'
# => state: "closed"
curl -sf "${AUTH[@]}" "${API}/issues/${ISSUE}/comments" | jq '[.[] | .body]'
# 経路 2 の場合は close-issue-on-merge のコメントが入る
```

runner ログでどちらの経路だったかを確認する。

```bash
docker compose -f infra/docker-compose.yml logs --tail=50 gitea-runner \
  | grep -iE "close-issue|already closed|closed by workflow" || true
```

---

## 合格判定

すべて満たせば合格。

- [ ] V1 issue が `tanaka` により作成され `open`
- [ ] V2 `feature/<ISSUE>-<slug>` が存在
- [ ] V3 PR が **1 本だけ** open で作られた（タイミング A / B のどちらか。重複無し）
- [ ] V4 PR の差分に `yamada` のコミットが含まれる
- [ ] V5 `tanaka` の APPROVED があり `merged: true` / `merged_by: tanaka`
- [ ] V6 issue が `closed`（経路 1 / 経路 2 のどちらか）
- [ ] ワークフローのログにトークン・パスワードの値が出ていない

## 結果記録テンプレート

`docs/memory/yyyyMMdd_NN_*.md` に貼る。

```
## E2E: issue → 自動PR → マージ → クローズ
- 実施日 / Gitea バージョン / runner イメージ:
- ISSUE #  / BRANCH  / PR #
- V1: OK/NG   V2: OK/NG
- V3: OK/NG（PR 作成タイミング: A=ブランチ作成 / B=初回push）
- V4: OK/NG   V5: OK/NG
- V6: OK/NG（クローズ経路: 1=Gitea自動 / 2=Actions）
- 失敗・逸脱:
```

## 想定される失敗と対処

| 症状 | 原因 | 対処 |
|---|---|---|
| ワークフローが 1 つも動かない | runner 未登録、リポジトリの Actions が無効 | `MANUAL.md` 2-4 を再実施。リポジトリ設定 → Actions を有効化 |
| `auto-pr` が 401 / 403 | `secrets.GITEA_TOKEN` が使えない構成 | リポジトリ Secret を作り、ワークフローの `GITEA_TOKEN:` を `${{ secrets.AUTO_PR_TOKEN }}` に差し替える |
| PR が作られない（ログに `skip: no diff`） | ブランチに差分が無い（タイミング A の正常動作） | S4 の push まで進める |
| PR が 2 本できた | 手動でも PR を作った | 余分な PR を閉じてから再実行。ワークフロー自体は 409/422 を握るので重複しない |
| issue が閉じない | ブランチ名に issue 番号が無い / PR 本文に `Closes` が無い | ブランチ名を `feature/<ISSUE>-<slug>` に直して再実行。`close-issue-on-merge` のログで抽出結果（`no linked issue`）を確認 |
| ジョブが起動直後に落ちる | runner が rootless podman 上で DinD 以外 | `gitea/runner:3.3.1-dind` を使う（`MANUAL.md` 2-4 の注記） |
| 実行結果を API で取れない | Gitea 1.22 に Actions の REST API が無い | 画面か runner ログで確認（`MANUAL.md`「ワークフロー実行結果の取得」） |

## 後片付け

```bash
# ブランチ削除（マージ時に画面から削除していれば不要）
curl -sf "${AUTH[@]}" -X DELETE "${API}/branches/feature%2F${ISSUE}-add-test-line" \
  -o /dev/null -w '%{http_code}\n'
rm -rf /tmp/yamada-work /tmp/sample-app
```

issue と PR は履歴として残してよい。ユーザーやワークフローの削除は破壊的操作なので、
実施前に確認を取る。
