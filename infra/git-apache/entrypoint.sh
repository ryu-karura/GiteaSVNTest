#!/bin/sh
# ミラー用の空 bare リポジトリを初回のみ作成する。
set -e

GIT_ROOT=/var/www/git
mkdir -p "$GIT_ROOT"

for repo in mirror1.git mirror2.git; do
  if [ ! -d "$GIT_ROOT/$repo" ]; then
    git init --bare "$GIT_ROOT/$repo"
    # Smart HTTP の push を許可
    git -C "$GIT_ROOT/$repo" config http.receivepack true
    touch "$GIT_ROOT/$repo/git-daemon-export-ok"
  fi
done

chown -R www-data:www-data "$GIT_ROOT"

exec "$@"
