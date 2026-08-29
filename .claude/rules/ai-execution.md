---
name: AI 実行ルール（Gitea/Redmine/SVN/Git）
description: PR 作成・チケット操作・ソース操作の必須ルール。curl のみ、認証は環境変数、疎通確認を先行。
paths:
  - "**"
---

このリポジトリで PR 作成・Redmine チケット操作・Git/SVN 操作を行うときは、以下を必ず守る。

## 必須

- PR 作成は **REST API + `curl` のみ**。`tea` / `gh` コマンドは使わない。
- Redmine 操作も **REST API + `curl`**。
- ソース操作は `git` / `svn` の標準コマンド。
- 認証情報は `docs/ai/env-vars.md` の環境変数から参照する。値をログ・PR 本文・チケット・報告に出力しない。
- 本処理の前に必ず順に実行する:
  1. `docs/ai/env-vars.md` の未設定チェック（`MISSING:` があれば中断して報告）
  2. `docs/ai/healthcheck.md` の対象サービス疎通確認（失敗したら中断して報告）
- force push、リモートブランチ削除、チケット削除などの破壊的操作はユーザー承認を得てから。
- `rtk` がある環境では `git` / `svn` / `curl` に `rtk` を前置する（トークン削減。専用フィルタが
  無いコマンドは素通し）。Claude Code のフックが `git` / `curl` は自動で `rtk` 化する。
  `svn` はフック対象外なので明示的に `rtk svn ...` とする。詳細は `docs/ai/common.md`。

## 配布物とリポジトリ専用物を分ける

このリポジトリの目的は AI 指示ファイルの配布。指示・ルールを追加・変更するときは、
配布物側かリポジトリ専用側かを先に決めて置き場所を分ける。混在させない。

- 配布物: `CLAUDE.md`（入口）/ `.claude/`（`rules/`・`skills/`）/
  `.github/`（`copilot-instructions.md`・`instructions/`・`skills/`）/ `docs/ai/`
- リポジトリ専用: `infra/` / `docs/memory/` / `PLAN.md` / `MANUAL.md` / `README.md` / `scripts/`
- 正リストは `docs/ai/DISTRIBUTION.md`。抽出は `scripts/export-ai-config.sh`。

## 手順の参照先

- 全体フロー・報告様式: `docs/ai/common.md`
- Gitea PR: `docs/ai/gitea-pr.md`
- GitHub PR: `docs/ai/github-pr.md`
- Redmine チケット: `docs/ai/redmine-issue.md`
- Git / SVN: `docs/ai/git-svn-ops.md`
- 一連のシナリオ: `docs/ai/scenario-pr-and-ticket.md`

## 途中経過の記録

- `docs/memory/index.md` に 1 行要約を追記し、`docs/memory/yyyyMMdd_NN_*.md` に詳細を残す。
- メモリが 10 件を超えたら、同一内容・完了済みファイルの削除をユーザーに提案する。

## 確認事項の出し方

不明点は 1〜3 件に絞り、箇条書きで簡潔に確認してから進める。
