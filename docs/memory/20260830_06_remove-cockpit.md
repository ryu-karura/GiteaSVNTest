# 20260830_06 cockpit を構成から除外

## 理由

当初計画（PLAN.md Docker0）では cockpit を「Docker1-N の管理 UI」として入れていたが、
`quay.io/cockpit/ws` は本来サーバー管理コンソール向けで、このプロジェクトの目的
（Gitea/GitHub PR・Redmine・Git/SVN を AI から REST/コマンドで操作する構成の検証）と
合わなかった。未解決 D（cockpit の実操作確認）ごと除外。

## 実施

- `infra/docker-compose.yml`: `cockpit` サービスとヘッダのサービス対応表から削除。
  `dockerN:` の採番コメントも整理（PLAN の Docker0-6 との対応注記は撤去）。
- `infra/.env.example`: `COCKPIT_PORT` と `DOCKER_SOCK` を削除
  （`DOCKER_SOCK` は cockpit 専用だった。runner は DinD 版でホスト socket 不要）。
- `infra/README.md`: サービス表から docker0 行を削除、採番列を撤去、除外の注記を追加。
  「既知の注意点」の `DOCKER_SOCK` 記述を削除し「ソケットをマウントするサービスは無い」に。
- `README.md`: 試験環境表から cockpit 行を削除、「8 コンテナ」→「7 コンテナ」、除外注記。
- `MANUAL.md`: 前提のポート一覧から 9090 を削除、手順1の `compose up` 対象から cockpit を除外、
  podman rootless 補足の `podman.socket` 有効化手順を削除（不要になった）。
- `PLAN.md`: 「試験環境」節冒頭に「Docker0（Cockpit）と Docker4 の Apache Repository は
  目的と合わず後に除外」の注記（当初計画の記録としては残す）。
- 稼働中の `gst-cockpit` コンテナを削除。

`docker compose config --services` = redmine / redmine-db / gitea / gitea-db / svn1 / svn2 /
gitea-runner の 7（+ profile の seed）。

## 残（本日）

- F: 監査ログ・操作履歴の残し方（PLAN「追加検討事項」、未着手）
