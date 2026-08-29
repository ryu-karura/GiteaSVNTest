---
name: gitea-pr
description: Gitea のプルリクエストを REST API（curl）で作成・検索・コメントする。tea コマンドは使わない。ブランチを push 済みで PR を立てたいときに使用。
---

# Gitea PR 作成（curl）

`tea` コマンド禁止。`curl` + Gitea REST API v1 のみ。

## 手順

1. `docs/ai/env-vars.md` の未設定チェック → `GITEA_BASE_URL` `GITEA_API_TOKEN` `GITEA_OWNER` `GITEA_REPO` が揃っているか。
2. `docs/ai/healthcheck.md` の「1. Gitea」を実行。`permissions.push == true` を確認。
3. ヘッドブランチが push 済みか確認（未 push なら先に `docs/ai/git-svn-ops.md`）。
4. `docs/ai/gitea-pr.md` の「2. PR 作成」を実行。`201` で成功、`number` と `html_url` を控える。
5. `422 already exists` なら同ファイル「3. 既存 PR の検索」で番号を取得。
6. `common.md` の報告様式で結果を出す。

## 詳細・全 curl レシピ

`docs/ai/gitea-pr.md` を参照（エラー早見表を含む）。

## 禁止

- `tea` コマンド
- トークン値の出力
- ユーザー承認なしのマージ
