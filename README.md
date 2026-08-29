# GiteaSVNTest

gitea pr test &amp; redmine issue update test

## 目的

試験環境を用意したうえで、AI 実行時に REST API を利用し、Claude / GitHub Copilot の両方で以下を実行できる構成・指示を整理する。

- PR 作成（Gitea）
- チケット作成・更新（Redmine）
- SVN / Git の操作は `svn` コマンド、`git` コマンドを利用する

## 設計方針

- API キー、アカウント、パスワードは各プロジェクト配下に置かず、ユーザー環境変数に配置する
- 不明点は確認して進める
- 確認事項は長くしすぎず、1～3 件程度に絞る
- 途中経過はdocs/memory/index.md(目次と１行要約)、yyyyMMdd_Number_*****.mdに残す。10件を超えるとと同一内容、完了事項のメモリファイルを削除するようにガイダンスする。
- Claude と GitHub Copilot の両方に対応できる[プロンプト設計・定義ファイル設計指針](copilot-claudecode-customization-2026-08.md)に従う。

## 試験環境

- Docker0: Cockpit（Docker1-N Manager）
- Docker1: Redmine 6.1.2
- Docker2: RedmineDB（MariaDB）
- Docker3: SVN + Apache Repository
- Docker4: Git + Gitea（Postgres）+ Apache Repository
- Docker5: SVN + Apache Repository
- Docker6: Action Only（Gitea-runner）Docker

## AI 実行時に想定するスキル / 指示

### 共通要件

- Gitea の PR 作成を REST API 経由で実行できること
- Redmine のチケット作成・更新を REST API 経由で実行できること
- ソース操作は Git / SVN の標準コマンドを利用すること
- 認証情報は環境変数から参照すること

### 指示例（GitHub Copilot / Claude 共通化イメージ）

1. 事前に必要な環境変数が設定されているか確認する
2. `git` / `svn` コマンドで必要な取得・更新・差分確認を行う
3. Gitea REST API で PR を作成する
4. Redmine REST API でチケットを作成または更新する
5. 実行結果、API 応答、エラー内容を簡潔に報告する

## 成果物

- Docker 各種定義ファイル
- テスト用定義ファイル
- AI テスト用指示例
- GitHub Copilot / Claude AI 定義ファイル

## この観点で追加検討したい事項

- 環境変数の命名規則と読み込み方法（例: `.env` ではなく OS / runner 側で注入するか）
- Gitea / Redmine / SVN / Git の疎通確認用ヘルスチェック手順
- 失敗時の再実行方針、監査ログ、操作履歴の残し方

## 確認事項（1～3 件）

1. Gitea / Redmine / SVN / Git へ接続する環境変数名は、あらかじめ標準化して定義してよいですか。
2. Docker 定義ファイルには、初期データ（テスト用リポジトリ、Redmine プロジェクト、サンプルチケット）投入まで含める想定ですか。
3. GitHub Copilot 用と Claude 用の定義ファイルは、同一内容をベースに最小差分で分ける方針でよいですか。
