# docs/ai — AI 実行時の指示（配布物の実体）

Claude / GitHub Copilot の両方から参照する、ツール非依存の手順集。
Claude 用定義（`.claude/`）と Copilot 用定義（`.github/`）は、それぞれこのディレクトリの
ファイルを引用する。配布時はこのディレクトリごとコピーする（`DISTRIBUTION.md` 参照）。

## ファイル構成

| ファイル | 内容 |
|---|---|
| `common.md` | 全タスク共通の前提・実行フロー・報告様式 |
| `gitea-pr.md` | Gitea の PR 作成（REST API / curl。`tea` 禁止） |
| `github-pr.md` | GitHub の PR 作成（REST API / curl。`gh` 禁止） |
| `redmine-issue.md` | Redmine チケットの作成・更新（REST API / curl） |
| `git-svn-ops.md` | Git / SVN の取得・更新・差分確認（標準コマンド） |
| `scenario-pr-and-ticket.md` | 取得→変更→PR→チケット更新の一連の指示例 |

## 原則（PLAN.md「共通要件」より）

- PR 作成は REST API + `curl` のみ。`tea` / `gh` コマンドは使わない。
- Redmine 操作も REST API + `curl`。
- ソース操作は `git` / `svn` の標準コマンド。
- 認証情報は環境変数から参照。値をログ・PR 本文・チケットに出力しない。
- 不明点は 1〜3 件に絞って確認してから進める。
- 途中経過は `docs/memory/index.md` と `docs/memory/yyyyMMdd_NN_*.md` に残す。
  メモリが 10 件を超えたら、同一内容・完了済みのファイル削除をユーザーに提案する。
