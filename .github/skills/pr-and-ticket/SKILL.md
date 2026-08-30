---
name: pr-and-ticket
description: ソース取得→変更→push→PR 作成（Gitea/GitHub）→Redmine チケット更新までを一連で実行する。「変更して PR 出してチケット更新」の依頼で使う。
---

# 一連実行：変更 → PR → チケット更新

PLAN.md「指示例」1〜5 に対応する。

## 進め方

1. `.env` を読み込む。bash: `set -a; [ -f ~/.env ] && . ~/.env; [ -f .env ] && . .env; set +a` / PowerShell: `docs/ai/common.md`「共通パターン（PowerShell）」の .env 読み込み
   （`~/.env` → `./.env` の順、後勝ち）。`.env` も `~/.env` も無ければ中断し、
   `cp .env.example .env` の実行と、このタスクで使うサービス分の変数の記入をユーザーに依頼する:
   PR 先が Gitea なら `GITEA_BASE_URL` `GITEA_API_TOKEN` `GITEA_OWNER` `GITEA_REPO`、
   GitHub なら `GITHUB_API_URL` `GITHUB_TOKEN` `GITHUB_OWNER` `GITHUB_REPO`。
   Git 操作に `GIT_USERNAME` `GIT_PASSWORD`。Redmine 更新に
   `REDMINE_BASE_URL` `REDMINE_API_KEY` `REDMINE_PROJECT`。
   読み込み後、使う変数に未設定があれば変数名だけ伝えて中断。
2. 疎通確認（`docs/ai/healthcheck.md`）— Gitea/GitHub・Redmine・Git。失敗は中断・報告。
3. ソース操作（`docs/ai/git-svn-ops.md`）— clone、作業ブランチ作成、変更、
   `git diff --staged` で確認、commit（`refs #<ticket>`）、push。認証は credential.helper 経由。
4. PR 作成 — Gitea は `docs/ai/gitea-pr.md`、GitHub は `docs/ai/github-pr.md`。
   PR 番号・URL を控える。`422 already exists` は既存 PR を検索。
5. Redmine 更新 — `docs/ai/redmine-issue.md`。`PUT /issues/{id}.json` で
   `notes` に PR URL、必要なら `status_id` 変更（`204` を確認）。新規なら先に `POST`。
6. 報告（`docs/ai/common.md` の様式）。
7. メモリ更新（`docs/memory/`）。10 件超は削除提案。

貼り付け可能な一連スクリプトは `docs/ai/scenario-pr-and-ticket.md` にある。

## してはいけないこと

- `gh` / `tea` コマンドの使用
- 認証情報（トークン・パスワード・API キー）の出力
- 疎通確認のスキップ、ユーザー承認のない破壊的操作
