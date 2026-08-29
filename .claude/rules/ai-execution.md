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
- 認証情報は `docs/env-vars.md` の環境変数から参照する。値をログ・PR 本文・チケット・報告に出力しない。
- 本処理の前に必ず順に実行する:
  1. `docs/env-vars.md` の未設定チェック（`MISSING:` があれば中断して報告）
  2. `docs/healthcheck.md` の対象サービス疎通確認（失敗したら中断して報告）
- force push、リモートブランチ削除、チケット削除などの破壊的操作はユーザー承認を得てから。

## 手順の参照先

- 全体フロー・報告様式: `ai-instructions/common.md`
- Gitea PR: `ai-instructions/gitea-pr.md`
- GitHub PR: `ai-instructions/github-pr.md`
- Redmine チケット: `ai-instructions/redmine-issue.md`
- Git / SVN: `ai-instructions/git-svn-ops.md`
- 一連のシナリオ: `ai-instructions/scenario-pr-and-ticket.md`

## 途中経過の記録

- `docs/memory/index.md` に 1 行要約を追記し、`docs/memory/yyyyMMdd_NN_*.md` に詳細を残す。
- メモリが 10 件を超えたら、同一内容・完了済みファイルの削除をユーザーに提案する。

## 確認事項の出し方

不明点は 1〜3 件に絞り、箇条書きで簡潔に確認してから進める。
