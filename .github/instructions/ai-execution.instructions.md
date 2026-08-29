---
name: 'AI 実行ルール'
description: 'PR 作成・Redmine 操作・Git/SVN 操作の必須ルールと参照先'
applyTo: '**'
---

- PR 作成は REST API + `curl` のみ。`gh` / `tea` は使わない。
- Redmine 操作も REST API + `curl`。
- ソース操作は `git` / `svn` の標準コマンド。
- 認証情報は `docs/env-vars.md` の環境変数から参照。値を出力しない。
- 実処理前に `docs/env-vars.md` の未設定チェック → `docs/healthcheck.md` の疎通確認。
  失敗時は中断して報告。
- 取り消し困難な操作はユーザー承認後に実行。
- 途中経過は `docs/memory/index.md` と `docs/memory/yyyyMMdd_NN_*.md`。10 件超で削除提案。
- 手順の詳細は `ai-instructions/` 配下（`common.md` / `gitea-pr.md` / `github-pr.md` /
  `redmine-issue.md` / `git-svn-ops.md` / `scenario-pr-and-ticket.md`）を読む。
