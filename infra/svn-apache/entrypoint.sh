#!/bin/sh
# SVN リポジトリと Basic 認証ユーザーを初回のみ作成する。
set -e

SVN_ROOT=/var/svn
: "${SVN_ADMIN_USER:=svnuser}"
: "${SVN_ADMIN_PASSWORD:=svnpass}"
: "${SVN_REPOS:=repo1}"

mkdir -p "$SVN_ROOT"

# Basic 認証ファイル
if [ ! -f "$SVN_ROOT/.htpasswd" ]; then
  htpasswd -bc "$SVN_ROOT/.htpasswd" "$SVN_ADMIN_USER" "$SVN_ADMIN_PASSWORD"
fi

# リポジトリ作成（スペース区切りで複数指定可）
for repo in $SVN_REPOS; do
  if [ ! -d "$SVN_ROOT/$repo" ]; then
    svnadmin create "$SVN_ROOT/$repo"
    # 標準レイアウトを投入
    tmp=$(mktemp -d)
    mkdir -p "$tmp/trunk" "$tmp/branches" "$tmp/tags"
    echo "seed" > "$tmp/trunk/README.txt"
    svn import "$tmp" "file://$SVN_ROOT/$repo" -m "init standard layout" \
      --username "$SVN_ADMIN_USER" --no-auth-cache
    rm -rf "$tmp"
  fi
done

chown -R www-data:www-data "$SVN_ROOT"

exec "$@"
