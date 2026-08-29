# 作業メモリ 目次

途中経過の記録。各行 = ファイル名 + 1行要約。10 件超過時は同一内容・完了済みメモリを削除する。

| ファイル | 要約 |
|---|---|
| 20260829_01_kickoff.md | README から作業項目8件を決定。確認事項3件の回答: 環境変数は標準化、初期データ投入まで含める、定義ファイルはCopilot/Claude完全別々。 |
| 20260829_02_env-vars.md | docs/env-vars.md 作成。Gitea/GitHub/Redmine/SVN/Git の環境変数名を標準化。未設定チェックスクリプト同梱。 |
| 20260829_03_docker-compose.md | infra/ に Compose 定義（Docker0-6）+ svn-apache/git-apache Dockerfile + seed（初期データ投入・冪等）+ redmine_bootstrap.rb。config 検証済み。 |
| 20260829_04_healthcheck.md | docs/healthcheck.md 作成。AI 経路での Gitea/Redmine/SVN/Git 疎通確認手順と終了条件。 |
| 20260829_05_ai-instructions.md | ai-instructions/ にツール非依存の手順集7ファイル（common/gitea-pr/github-pr/redmine-issue/git-svn-ops/scenario）。 |
| 20260829_06_ai-definitions.md | .claude/（rules+skills3+CLAUDE.md追記）と .github/（copilot-instructions+instructions+skills3）を個別記述。作業1〜7完了。 |
| 20260829_07_verify-run.md | podman で実コンテナ検証。healthcheck/gitea admin/secret_key_base/Redmineデフォルトデータ/APIキー生成/seed tracker の不具合を修正。E2E（curl で PR #1 作成 + Redmine #1 更新）までパス。 |
