# 20260829_09 ドキュメント再編 + MANUAL 手順テスト + runner

## ドキュメント再編

- `README.md`（旧・計画中心）→ `git mv` で `PLAN.md`。冒頭に README/MANUAL への導線、
  「確認事項」を対応状況付きに、リポジトリ構成節は README へ移動。
- `README.md`（新）: 現在の状態・できること・構成表・検証済み事項のサマリ。
- `MANUAL.md`: 構築〜AI 実行までの通し手順（0 前提 / 1 起動 / 2 初期データ 4 手順 /
  3 環境変数 / 4 疎通 / 5 E2E / 6 片付け / 補足 podman rootless / トラブルシュート）。
- `ai-instructions/*` と両 skills の「README『指示例』」参照を `PLAN.md` に更新。
- `infra/README.md` 冒頭に MANUAL.md への導線。

## MANUAL 手順の通しテスト（podman、clean state = down -v から）

すべて MANUAL 記載どおりで成功:

1. `cp .env.example .env`（+ podman 用に `DOCKER_SOCK` 設定）→ `docker compose up -d`（コア + cockpit）→ 6 サービス healthy
2-1. `gitea admin user create -u git` → giteaadmin 作成
2-2. `redmine bootstrap`（`-e SECRET_KEY_BASE`）→ default data + REST + API キー `062f1d…86f`
2-3. `seed`（`-e REDMINE_SEED_API_KEY=<2-2の値>`）→ **一発成功**（Gitea token `58d4f2…b6`、
     testorg/sample-app/feature/seed-change、SVN repo1/repo2、Redmine ai-test + 課題 2 件、trackers=[1,2,3]）
4. 疎通確認: Gitea healthz pass / repo push=true / Redmine users.current / project / issues total=2 / git ls-remote
5. E2E: curl で PR #1 作成（201）→ Redmine #1 PUT（204、notes + status→In Progress）→ 反映確認

## Gitea Actions runner

- 公式イメージが `gitea/act_runner` → **`gitea/runner`** に改名（https://gitea.com/gitea/runner）。
  compose を `gitea/runner:3.3.1` に統一。`/data` ボリューム追加、ラベルを公式形式
  `ubuntu-latest:docker://docker.gitea.com/runner-images:ubuntu-latest` に変更。
  → 登録成功（version v3.3.1、labels [ubuntu-latest]、daemon 稼働）。
- （旧メモ）`gitea/act_runner:0.2` は存在しないタグ。改名前は `0.6.1` が最新だった。
- 登録トークンは `gitea actions generate-runner-token`。**ANSI エスケープ（`\x1b[0m`）が
  混入すると `runner registration token not found`**。人手コピーなら問題なし。
  スクリプト抽出時は `sed 's/\x1b\[[0-9;]*m//g'` + `grep -oE '[A-Za-z0-9]{40}'` でクリーンにする。
- クリーンなトークンで再登録 → `Runner registered successfully` / daemon 起動 / labels [ubuntu-latest alpine]。
- `.gitea/workflows/ci.yml` を push → runner がジョブ受信（`task 1 repo is testorg/sample-app`）。
- **rootless podman ではジョブが完走しない**: `NewParallelExecutor: ... 0 executors` を繰り返す。
  マウントした docker.sock（= podman.sock）への書き込み権限 / uid 不一致が原因とみられる。
  通常 Docker か `act_runner:*-dind-rootless` + DinD で回避（MANUAL に注記済み）。
- Gitea 1.22 に `gitea actions runners list` サブコマンドは無い（`generate-runner-token` のみ）。
  リポジトリ level の `actions/tasks` API も 404。確認は runner ログか管理画面。

## コミット（feat/gitea-actions-runner）

- `fix(infra): act_runner タグ修正・Docker ソケットパスを可変化`
- `docs: README を PLAN.md に、最新状態の README と MANUAL.md を追加`
- 本メモリ

## PR

- GitHub PR #3: https://github.com/ryu-karura/GiteaSVNTest/pull/3
  （curl + GitHub REST API、gh 不使用、HTTP 201）

## 残

- rootless podman での Actions ジョブ完走（要 DinD 構成 or 通常 Docker）
- GitHub 側手順（github-pr.md）の実リポジトリ検証
