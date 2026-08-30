---
name: github-pr
description: GitHub のプルリクエストを REST API（curl）で作成・検索・コメントする。gh コマンドは使わない。push 済みブランチから PR を立てるときに使う。
---

# GitHub PR 作成（curl）

`gh` コマンド禁止。`curl` + GitHub REST API（`2022-11-28`）のみ。

## 進め方

1. `.env` を読み込む。bash: `set -a; [ -f ~/.env ] && . ~/.env; [ -f .env ] && . .env; set +a` / PowerShell: `docs/ai/common.md`「共通パターン（PowerShell）」の .env 読み込み
   （`~/.env` → `./.env` の順、後勝ち）。`.env` も `~/.env` も無ければ中断し、
   `cp .env.example .env` の実行と次の変数の記入をユーザーに依頼する:
   `GITHUB_API_URL` `GITHUB_TOKEN` `GITHUB_OWNER` `GITHUB_REPO`。
   読み込み後、この 4 つに未設定があれば変数名だけ伝えて中断。
2. `docs/ai/healthcheck.md` の「2. GitHub」を実行し、`permissions.push == true` を確認。
3. ヘッドブランチが GitHub 上に push 済みであることを確認（未 push なら先に `git push`）。
4. `docs/ai/github-pr.md` の「2. PR 作成」を実行。`201` で成功、`number` と `html_url` を控える。
5. `422`（head/base 不正・PR 重複・差分なし）の場合は同ファイル「3. 既存 PR の検索」で番号を取得。
6. `docs/ai/common.md` の報告様式で結果を出す。

PR をクローズする場合は `docs/ai/github-pr.md`「5. PR のクローズ」
（`PATCH /pulls/{n}` に `{"state":"closed"}`、`200` / `state=closed` / `merged=false`）。
マージ・ブランチ削除はユーザー承認を得てから。

curl レシピとエラー早見表は `docs/ai/github-pr.md` に全て記載。

## してはいけないこと

- `gh` コマンドの使用
- `GITHUB_TOKEN` の値を出力すること
- ユーザー承認のないマージ
