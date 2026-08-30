---
name: gitea-pr
description: Gitea のプルリクエストを REST API（curl）で作成・検索・コメントする。tea コマンドは使わない。push 済みブランチから PR を立てるときに使う。
---

# Gitea PR 作成（curl）

`tea` コマンド禁止。`curl` + Gitea REST API v1 のみ。

## 進め方

1. `.env` を読み込む。bash: `set -a; [ -f ~/.env ] && . ~/.env; [ -f .env ] && . .env; set +a` / PowerShell: `docs/ai/common.md`「共通パターン（PowerShell）」の .env 読み込み
   （`~/.env` → `./.env` の順、後勝ち）。`.env` も `~/.env` も無ければ中断し、
   `cp .env.example .env` の実行と次の変数の記入をユーザーに依頼する:
   `GITEA_BASE_URL` `GITEA_API_TOKEN` `GITEA_OWNER` `GITEA_REPO`。
   読み込み後、この 4 つに未設定があれば変数名だけ伝えて中断。
2. `docs/ai/healthcheck.md` の「1. Gitea」を実行し、`permissions.push == true` を確認。
3. ヘッドブランチが push 済みであることを確認（未 push なら `docs/ai/git-svn-ops.md` を先に）。
4. `docs/ai/gitea-pr.md` の「2. PR 作成」を実行。`201` で成功、`number` と `html_url` を控える。
5. `422 already exists` の場合は同ファイル「3. 既存 PR の検索」で番号を取得。
6. `docs/ai/common.md` の報告様式で結果を出す。

curl レシピとエラー早見表は `docs/ai/gitea-pr.md` に全て記載。

## してはいけないこと

- `tea` コマンドの使用
- `GITEA_API_TOKEN` の値を出力すること
- ユーザー承認のないマージ
