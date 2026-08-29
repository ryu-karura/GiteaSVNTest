---
name: pr-and-ticket
description: ソース取得→変更→push→PR 作成（Gitea/GitHub）→Redmine チケット更新までを一連で実行する。「変更して PR 出してチケット更新して」の依頼で使用。
---

# 一連実行：変更 → PR → チケット更新

README「指示例」1〜5 に対応。

## 手順

1. 環境変数チェック（`docs/env-vars.md`）。`MISSING:` があれば中断・報告。
2. 疎通確認（`docs/healthcheck.md`）— Gitea/GitHub・Redmine・Git。失敗は中断・報告。
3. ソース操作（`ai-instructions/git-svn-ops.md`）— clone、作業ブランチ作成、変更、
   `git diff --staged` で確認、commit（`refs #<ticket>`）、push。認証は credential.helper 経由。
4. PR 作成 — Gitea は `ai-instructions/gitea-pr.md`、GitHub は `ai-instructions/github-pr.md`。
   PR 番号・URL を控える。`422 already exists` は既存 PR を検索。
5. Redmine 更新 — `ai-instructions/redmine-issue.md`。`PUT /issues/{id}.json` で
   `notes` に PR URL、必要なら `status_id` 変更（`204` 確認）。新規なら先に `POST`。
6. 報告（`ai-instructions/common.md` の様式）。
7. メモリ更新（`docs/memory/`）。10 件超は削除提案。

## 完全な手順とコード

`ai-instructions/scenario-pr-and-ticket.md` に貼り付け可能な一連スクリプトがある。

## 禁止

- `tea` / `gh` コマンド
- 認証情報（トークン・パスワード・API キー）の出力
- 疎通確認スキップ、ユーザー承認なしの破壊的操作
