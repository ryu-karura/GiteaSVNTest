# 作業メモリ 目次

途中経過の記録。各行 = ファイル名 + 1行要約。10 件超過時は同一内容・完了済みメモリを削除する。

2026-08-29 の詳細は `20260829_01`〜`20260829_11`（履歴として保持）。内容は
`20260830_01_carryover.md` に集約済み。目次番号は集約ファイルから振り直す。

| # | ファイル | 要約 |
|---|---|---|
| 01 | 20260830_01_carryover.md | 2026-08-29 分（環境変数標準化 / healthcheck / infra 8 コンテナ / AI 手順集・定義 / ドキュメント再編 / E2E・SVN・git push・runner 登録の検証 / RTK 明記 / PR #1-3）を集約。未解決 B〜F と PR #3 未マージ。本日順: 整理→B(DinD で Actions 完走)→E。 |
| 02 | 20260830_02_runner-dind.md | B/E 解決。runner を `gitea/runner:3.3.1-dind`（privileged、コンテナ内 root dockerd、ホスト socket 不要）に変更 → rootless podman 上で 3 ステップジョブが完走（state=success）。dind-rootless は newuidmap 権限不足で不可。結果取得は内部 JSON `POST .../actions/runs/{n}/jobs/{i}`。MANUAL/README/.env.example 反映。 |
| 03 | 20260830_03_distribution-split.md | 配布物とリポジトリ専用物を分離。目的を「AI 指示ファイルの配布」と明文化。手順集を `docs/ai/` に集約（`ai-instructions/` + `docs/env-vars.md` + `docs/healthcheck.md` を git mv、参照パス一括更新）。`docs/ai/DISTRIBUTION.md`（正リスト・導入手順）+ `scripts/export-ai-config.sh`（抽出）新規。入口ファイルに分離ルール追記。env-vars.md に実運用の設定方法（direnv/CI Secrets/systemd）追記。 |
| 04 | 20260830_04_env-dotenv-convention.md | AI 環境変数を `.env` ロード規約に変更（`~/.env` → `<repo>/.env` の順、後勝ち）。ルートに AI 用 `.env.example`（配布物）を新規追加。`infra/.env.example`（Docker 用）と別物。env-vars/common/healthcheck と全入口ファイルの「実処理前」手順に `.env` 読み込みを追加。MANUAL 手順3・DISTRIBUTION・README・export スクリプトも反映。github-pr スキル（573e04f）と併せ Copilot 手動テスト準備完了。 |
