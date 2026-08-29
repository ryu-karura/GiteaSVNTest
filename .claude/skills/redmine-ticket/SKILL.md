---
name: redmine-ticket
description: Redmine のチケットを REST API（curl）で作成・更新する。PR 番号の紐付けやステータス変更を含む。チケット操作が必要なときに使用。
---

# Redmine チケット作成・更新（curl）

`curl` + Redmine REST API（JSON）のみ。

## 手順

1. `docs/env-vars.md` の未設定チェック → `REDMINE_BASE_URL` `REDMINE_API_KEY` `REDMINE_PROJECT`。
2. `docs/healthcheck.md` の「3. Redmine」を実行。`/users/current.json` が 200 か確認
   （401 → REST 未有効。`infra/seed/redmine_bootstrap.rb` を案内）。
3. 作成: `ai-instructions/redmine-issue.md` の「2. チケット作成」（`POST /issues.json`、`201`、`tracker_id` 必須）。
4. 更新: 同「3. チケット更新」（`PUT /issues/{id}.json`、`204`、`notes` がコメント）。
5. 反映確認: `GET /issues/{id}.json?include=journals` で最新 note とステータスを確認。
6. `common.md` の報告様式で結果を出す。

## 詳細・全 curl レシピ

`ai-instructions/redmine-issue.md` を参照（参照 ID 取得、カスタムフィールド、エラー早見表）。

## 禁止

- API キーの出力
- ユーザー承認なしのチケット削除
