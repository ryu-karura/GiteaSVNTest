# 2026-09-01 / 01 — E2E テスト（issue → 自動 PR → マージ → issue クローズ）の追加

## 依頼

「田中さんが Gitea の画面で issue 追加 → 画面でブランチ作成 → action がどちらかの
タイミングで PR 作成 → 山田さんがブランチのコード修正 → 田中さんがレビュー・マージ・
クローズ → issue を自動クローズか action がクローズ」というテストを追加し、PR も作る。

## 置き場所の判断（配布物 / リポジトリ専用）

`CLAUDE.md` の分離ルールに従い、**すべてリポジトリ専用側**に置いた。
画面操作・試験環境のユーザー・runner に依存する検証手順であり、他プロジェクトへ
配布する AI 指示ではないため。`docs/ai/` は変更していない（`DISTRIBUTION.md` の
「配布しないもの」に追記したのみ）。

## 追加物

| パス | 内容 |
|---|---|
| `docs/tests/e2e-issue-to-merge.md` | テスト本体。登場人物（tanaka / yamada）、事前準備、S1〜S7 の手順、合格判定 V1〜V6、結果記録テンプレート、失敗時の対処、後片付け |
| `infra/workflows/auto-pr.yml` | ブランチ作成（`create`）/ `push` で PR を自動作成する Gitea Actions |
| `infra/workflows/close-issue-on-merge.yml` | PR マージ時に紐づく issue を閉じる Gitea Actions（Gitea 自動クローズの保険） |

参照追記: `README.md`（構成表 + 「テスト」節）、`MANUAL.md`（6 章を新設、後片付けを 7 章へ）、
`infra/README.md`（`workflows/` 節）、`docs/ai/DISTRIBUTION.md`（配布しないもの）。

## 設計上のポイント

- **PR 作成タイミングは 2 つとも扱う**。ブランチ作成直後は main と差分ゼロで、Gitea は
  差分ゼロの PR を作れないため、A（create）は `skip: no diff` で正常終了し、B（初回 push）
  で作られる。`create` イベントが発火しない Gitea バージョンでも B で成立する。
  再実行・重複発火時は 409/422 を握って正常終了するので PR は常に 1 本。
- **issue クローズも 2 経路**。PR 本文に `Closes #<issue>` を入れる（ブランチ名
  `feature/<issue>-<slug>` から番号を抽出）ので通常は Gitea 本体が閉じる。閉じていない
  場合だけワークフローがコメント + `PATCH state=closed`。冪等。
- ワークフローは **`curl` + `grep` のみ**。`jq` / `git` / 外部 action に依存しない
  （ランナーイメージを選ばず、外部ネットワークが無い試験環境でも動く）。
- トークンは `secrets.GITEA_TOKEN`。使えない構成向けに `AUTO_PR_TOKEN` への差し替えを
  ドキュメント化。値は出力しない。

## 検証状況

- YAML パース（`yaml.safe_load`）と、ブランチ名 / PR 本文からの issue 番号抽出・
  JSON の `id` / `state` / `number` 抽出の grep ロジックを手元で単体確認済み。
- **試験環境（Gitea + runner）での実行は未**。この環境から Gitea へ到達できないため。
  実施時は `docs/tests/e2e-issue-to-merge.md` の結果記録テンプレートを使ってここに追記する。

## 次にやること

- 試験環境でテストを実施し、V1〜V6 の結果と PR 作成タイミング（A / B）・クローズ経路
  （1 / 2）を記録する。
- 実施結果を `README.md`「検証済み」へ反映（テスト表の状態を「実施済み」に更新）。
