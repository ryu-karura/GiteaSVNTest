# GitHub Copilot 向けリポジトリ指示

このリポジトリは、Gitea / GitHub の PR 作成、Redmine のチケット作成・更新、
Git / SVN のソース操作を REST API とコマンドで自動化するための構成・指示を整備する。

## 絶対規則

- PR は REST API を `curl` で叩いて作成する。`gh` コマンド・`tea` コマンドは使用しない。
- Redmine のチケット操作も REST API + `curl` で行う。
- ソースの取得・更新・差分・コミットは `git` / `svn` の標準コマンドを使う。
- 認証情報（トークン・パスワード・API キー）は `docs/ai/env-vars.md` に定義した環境変数から
  参照する。値をコード・PR 本文・チケット・チャット出力に絶対に含めない。
- 実処理の前に、必ずこの順で確認する:
  1. `docs/ai/env-vars.md` の未設定チェックスクリプトを実行し、`MISSING:` が無いこと。
  2. `docs/ai/healthcheck.md` の該当サービス手順を実行し、疎通できること。
  いずれか失敗したら処理を止め、失敗内容（サービス名・HTTP ステータス・エラーコード）を報告する。
- force push、リモートブランチ削除、チケット削除などの取り消し困難な操作は、
  ユーザーの明示的な承認を得てから実行する。
- 実行環境に `rtk`（Rust Token Killer）がある場合は `git` / `svn` / `curl` に `rtk` を
  前置して実行する（出力が圧縮されトークンを節約できる。専用フィルタが無いコマンドは
  素通しするので動作は変わらない）。無ければそのまま実行する。詳細は
  `docs/ai/common.md`「RTK（利用可能なら使う）」。

## 作業手順の参照先

具体的な curl コマンド・エラー対応は次のファイルにある。処理前に該当ファイルを読むこと。

- 実行フロー全体と報告様式: [docs/ai/common.md](../docs/ai/common.md)
- Gitea の PR 作成: [docs/ai/gitea-pr.md](../docs/ai/gitea-pr.md)
- GitHub の PR 作成: [docs/ai/github-pr.md](../docs/ai/github-pr.md)
- Redmine チケット: [docs/ai/redmine-issue.md](../docs/ai/redmine-issue.md)
- Git / SVN 操作: [docs/ai/git-svn-ops.md](../docs/ai/git-svn-ops.md)
- 一連のシナリオ: [docs/ai/scenario-pr-and-ticket.md](../docs/ai/scenario-pr-and-ticket.md)

## 配布物とリポジトリ専用物を分ける

このリポジトリの目的は AI 指示ファイルを他プロジェクトへ配布すること。指示・ルールを
追加・変更するときは、配布物側かリポジトリ専用側かを先に決めて置き場所を分ける。

- 配布物: `CLAUDE.md` / `.claude/` / `.github/copilot-instructions.md` /
  `.github/instructions/` / `.github/skills/` / `docs/ai/`
- リポジトリ専用: `infra/` / `docs/memory/` / `PLAN.md` / `MANUAL.md` / `README.md` / `scripts/`
- 正リストと導入手順は [docs/ai/DISTRIBUTION.md](../docs/ai/DISTRIBUTION.md)。

## 試験環境

`infra/` に Docker Compose 定義がある。構築・初期データ投入手順は
[infra/README.md](../infra/README.md) を参照。

## 途中経過の記録

- `docs/memory/index.md` に 1 行要約を追記し、`docs/memory/yyyyMMdd_NN_タイトル.md` に詳細を書く。
- メモリファイルが 10 件を超えたら、完了済み・内容が重複するファイルの削除をユーザーに提案する。

## 確認の出し方

不明点は 1〜3 件に絞り、箇条書きで簡潔に質問してから着手する。
