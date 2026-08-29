# 20260829_05 AI 指示例

## 成果（ai-instructions/）

ツール非依存の手順集。Claude 用（.claude/）と Copilot 用（.github/）の両定義から引用する。

- `README.md` … 構成と原則
- `common.md` … 前提・実行フロー（README 指示例 1〜5 対応）・報告様式・禁止事項
- `gitea-pr.md` … curl で Gitea PR 作成／既存 PR 検索／コメント／マージ／エラー早見（tea 禁止）
- `github-pr.md` … curl で GitHub PR 作成（gh 禁止）
- `redmine-issue.md` … curl でチケット作成（POST 201）・更新（PUT 204、notes=コメント）・参照 ID 取得
- `git-svn-ops.md` … git/svn 標準コマンド。credential.helper で認証情報を渡す（URL 埋め込み禁止）。force push 禁止
- `scenario-pr-and-ticket.md` … 取得→変更→push→Gitea PR→Redmine 更新→報告→メモリ更新の一連例

## 次

作業6: Claude 定義（.claude/）、作業7: Copilot 定義（.github/）。方針は「完全に別々」。
