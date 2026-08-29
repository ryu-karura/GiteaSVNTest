---
name: redmine-ticket
description: Redmine のチケットを REST API（curl）で作成・更新する。PR 番号の紐付けやステータス変更を含む。チケット操作が必要なときに使う。
---

# Redmine チケット作成・更新（curl）

`curl` + Redmine REST API（JSON）のみ。

## 進め方

1. `docs/ai/env-vars.md` の未設定チェックで `REDMINE_BASE_URL` `REDMINE_API_KEY` `REDMINE_PROJECT` を確認。
2. `docs/ai/healthcheck.md` の「3. Redmine」を実行。`/users/current.json` が 200 であること
   （401 なら REST 未有効。`infra/seed/redmine_bootstrap.rb` を案内）。
3. 作成: `docs/ai/redmine-issue.md`「2. チケット作成」（`POST /issues.json`、`201`、`tracker_id` 必須）。
4. 更新: 同「3. チケット更新」（`PUT /issues/{id}.json`、`204`、`notes` がコメント欄）。
5. 反映確認: `GET /issues/{id}.json?include=journals` で最新 note とステータスを見る。
6. `docs/ai/common.md` の報告様式で結果を出す。

参照 ID 取得・カスタムフィールド・エラー早見表は `docs/ai/redmine-issue.md` に記載。

## してはいけないこと

- `REDMINE_API_KEY` の値を出力すること
- ユーザー承認のないチケット削除
