# GiteaSVNTest — 計画

gitea pr test & redmine issue update test

> この文書は当初の計画・設計方針の記録。
> 現在の状態は [README.md](README.md)、セットアップと使い方は [MANUAL.md](MANUAL.md) を参照。

## 目的

試験環境を用意したうえで、AI 実行時に REST API を利用し、Claude / GitHub Copilot の両方で以下を実行できる構成・指示を整理する。

- PR 作成（Gitea,github）.  teaやghコマンドは使用禁止。curlで実行する。
- チケット作成・更新（Redmine）.  curlで実行する。
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

## この観点で追加検討したい事項（対応状況）

- 環境変数の命名規則と読み込み方法 → `docs/ai/env-vars.md` で標準化。OS / runner 側で注入。
- Gitea / Redmine / SVN / Git の疎通確認用ヘルスチェック手順 → `docs/ai/healthcheck.md`。
- 失敗時の再実行方針、操作履歴 → `docs/ai/common.md`（報告様式・再実行）、
  `docs/memory/` に途中経過。

## 確認事項（1～3 件）— 回答済み

1. 環境変数名は標準化して定義する（`docs/ai/env-vars.md`）。
2. Docker 定義に初期データ投入まで含める（`infra/seed/` に冪等な投入スクリプト）。
3. Copilot 用と Claude 用の定義ファイルは完全に別々に記述する（手順本体は `docs/ai/` を共用）。
