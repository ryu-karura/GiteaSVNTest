---
name: 'AI 実行ルール'
description: 'PR 作成・Redmine 操作・Git/SVN 操作の必須ルールと参照先'
applyTo: '**'
---

- PR 作成は REST API + `curl` のみ。`gh` / `tea` は使わない。
- Redmine 操作も REST API + `curl`。
- ソース操作は `git` / `svn` の標準コマンド。
- 認証情報は `docs/ai/env-vars.md` の環境変数から参照。値を出力しない。
- 実処理前に `docs/ai/env-vars.md` の未設定チェック → `docs/ai/healthcheck.md` の疎通確認。
  失敗時は中断して報告。
- 取り消し困難な操作はユーザー承認後に実行。
- `rtk` がある環境では `git` / `svn` / `curl` に `rtk` を前置（トークン節約。無ければそのまま）。
- 途中経過は `docs/memory/index.md` と `docs/memory/yyyyMMdd_NN_*.md`。10 件超で削除提案。
- 手順の詳細は `docs/ai/` 配下（`common.md` / `gitea-pr.md` / `github-pr.md` /
  `redmine-issue.md` / `git-svn-ops.md` / `scenario-pr-and-ticket.md`）を読む。
- 配布物（`CLAUDE.md` / `.claude/` / `.github/` / `docs/ai/`）とリポジトリ専用物
  （`infra/` / `docs/memory/` / `PLAN.md` / `MANUAL.md` / `README.md` / `scripts/`）を
  混在させない。正リストは `docs/ai/DISTRIBUTION.md`。
