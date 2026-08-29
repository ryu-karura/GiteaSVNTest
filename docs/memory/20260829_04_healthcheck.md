# 20260829_04 ヘルスチェック手順

## 成果

`docs/healthcheck.md` 作成。

## 内容

AI が使う経路（REST API / コマンド）での疎通確認。

- 0: 環境変数の存在確認（未設定は MISSING 出力）
- 1: Gitea `/api/healthz` + `repos/OWNER/REPO`（permissions.push 確認）
- 2: GitHub（使用時のみ）
- 3: Redmine `/login` + `/users/current.json`（401 → bootstrap 未実行）+ プロジェクト確認
- 4: SVN `svn info`（エラーコード別の意味を記載）
- 5: Git `git ls-remote`
- 終了条件: 1・3・4・5 全成功で AI 実行可。失敗時は詳細報告し後続停止。
