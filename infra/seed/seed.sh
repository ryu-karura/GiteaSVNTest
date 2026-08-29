#!/usr/bin/env bash
# 初期データ投入（冪等）。docker compose --profile seed run --rm seed で実行。
#
#  - Gitea : 管理者トークン発行 → Org / リポジトリ作成 → PR 作成用の feature ブランチ生成
#  - SVN   : repo1 / repo2 に trunk 配下のサンプルファイルをコミット
#  - Redmine: プロジェクト / サンプルチケットを作成
#             （事前に redmine_bootstrap.rb を rails runner で実行し REST 有効化と
#              管理者 API キー固定を済ませておくこと。infra/README.md 参照）
set -euo pipefail

log() { echo "[seed] $*"; }

# ---------------------------------------------------------------- Gitea
gitea_seed() {
  local base="${GITEA_BASE_URL}"
  log "wait gitea: $base"
  until curl -sf "$base/api/healthz" >/dev/null; do sleep 3; done

  local api="$base/api/v1"
  local -a admin=(-u "${GITEA_ADMIN_USER}:${GITEA_ADMIN_PASSWORD}")

  local existing
  existing=$(curl -sf "${admin[@]}" "$api/users/${GITEA_ADMIN_USER}/tokens" \
              | jq -r ".[] | select(.name==\"${GITEA_SEED_TOKEN_NAME}\") | .name" || true)

  local GITEA_TOKEN=""
  if [ -z "$existing" ]; then
    log "create gitea token: ${GITEA_SEED_TOKEN_NAME}"
    GITEA_TOKEN=$(curl -sf "${admin[@]}" -X POST "$api/users/${GITEA_ADMIN_USER}/tokens" \
      -H 'Content-Type: application/json' \
      -d "{\"name\":\"${GITEA_SEED_TOKEN_NAME}\",\"scopes\":[\"write:repository\",\"write:organization\",\"write:user\"]}" \
      | jq -r '.sha1')
    log "=> GITEA_API_TOKEN=${GITEA_TOKEN}"
    log "   docs/env-vars.md の GITEA_API_TOKEN にこの値を設定する"
  else
    log "gitea token already exists: ${GITEA_SEED_TOKEN_NAME}"
    log "   既存トークンの値は再表示不可。必要なら Gitea 管理画面で再発行する"
    return 0
  fi

  local -a h=(-H "Authorization: token ${GITEA_TOKEN}")

  curl -sf "${h[@]}" "$api/orgs/testorg" >/dev/null 2>&1 || \
    curl -sf "${h[@]}" -X POST "$api/orgs" -H 'Content-Type: application/json' \
      -d '{"username":"testorg","visibility":"public"}' >/dev/null
  log "gitea org: testorg"

  curl -sf "${h[@]}" "$api/repos/testorg/sample-app" >/dev/null 2>&1 || \
    curl -sf "${h[@]}" -X POST "$api/orgs/testorg/repos" -H 'Content-Type: application/json' \
      -d '{"name":"sample-app","auto_init":true,"default_branch":"main","private":false}' >/dev/null
  log "gitea repo: testorg/sample-app"

  if ! curl -sf "${h[@]}" "$api/repos/testorg/sample-app/branches/feature%2Fseed-change" >/dev/null 2>&1; then
    curl -sf "${h[@]}" -X POST "$api/repos/testorg/sample-app/branches" \
      -H 'Content-Type: application/json' \
      -d '{"new_branch_name":"feature/seed-change","old_branch_name":"main"}' >/dev/null
    curl -sf "${h[@]}" -X POST "$api/repos/testorg/sample-app/contents/seed.txt" \
      -H 'Content-Type: application/json' \
      -d "{\"branch\":\"feature/seed-change\",\"content\":\"$(printf 'seed change' | base64)\",\"message\":\"add seed.txt\"}" >/dev/null
    log "gitea branch: feature/seed-change（PR 作成テスト用の差分あり）"
  else
    log "gitea branch feature/seed-change already exists"
  fi
}

# ---------------------------------------------------------------- SVN
svn_seed() {
  local u="${SVN_ADMIN_USER}" p="${SVN_ADMIN_PASSWORD}"
  local -a svnauth=(--non-interactive --no-auth-cache --username "$u" --password "$p")
  for url in "${SVN1_BASE_URL}" "${SVN2_BASE_URL}"; do
    log "wait svn: $url"
    until curl -sf -u "$u:$p" "$url" >/dev/null; do sleep 3; done
    local wc; wc=$(mktemp -d)
    svn checkout "${svnauth[@]}" "$url" "$wc" >/dev/null
    if [ ! -f "$wc/trunk/sample.txt" ]; then
      echo "svn sample $(date -u +%FT%TZ)" > "$wc/trunk/sample.txt"
      svn add "$wc/trunk/sample.txt" >/dev/null
      svn commit "${svnauth[@]}" -m "seed: add trunk/sample.txt" "$wc" >/dev/null
      log "svn commit: $url/trunk/sample.txt"
    else
      log "svn already seeded: $url"
    fi
    rm -rf "$wc"
  done
}

# ---------------------------------------------------------------- Redmine
redmine_seed() {
  local base="${REDMINE_BASE_URL}" key="${REDMINE_SEED_API_KEY}"
  log "wait redmine: $base"
  until curl -sf "$base/login" >/dev/null; do sleep 3; done

  if ! curl -sf -H "X-Redmine-API-Key: $key" "$base/users/current.json" >/dev/null 2>&1; then
    log "redmine API キー未有効。infra/README.md の redmine_bootstrap.rb を先に実行すること。スキップ。"
    return 0
  fi

  local -a h=(-H "X-Redmine-API-Key: ${key}")

  # デフォルトデータ（トラッカー等）が入っているか
  local tracker_id
  tracker_id=$(curl -sf "${h[@]}" "$base/trackers.json" | jq -r '.trackers[0].id // empty')
  if [ -z "$tracker_id" ]; then
    log "redmine トラッカー未投入。redmine_bootstrap.rb を先に実行すること。スキップ。"
    return 0
  fi
  local tracker_ids
  tracker_ids=$(curl -sf "${h[@]}" "$base/trackers.json" | jq -c '[.trackers[].id]')

  if ! curl -sf "${h[@]}" "$base/projects/ai-test.json" >/dev/null 2>&1; then
    curl -sf "${h[@]}" -X POST "$base/projects.json" -H 'Content-Type: application/json' \
      -d "{\"project\":{\"name\":\"AI Test\",\"identifier\":\"ai-test\",\"description\":\"AI 実行テスト用\",\"enabled_module_names\":[\"issue_tracking\"],\"tracker_ids\":${tracker_ids}}}" >/dev/null
    log "redmine project: ai-test (trackers=${tracker_ids})"
  else
    log "redmine project ai-test already exists"
  fi

  # 既存・新規いずれもトラッカーと課題モジュールを確実に紐付ける（冪等）
  curl -s -o /dev/null "${h[@]}" -X PUT "$base/projects/ai-test.json" -H 'Content-Type: application/json' \
    -d "{\"project\":{\"enabled_module_names\":[\"issue_tracking\"],\"tracker_ids\":${tracker_ids}}}"

  local cnt
  cnt=$(curl -sf "${h[@]}" "$base/issues.json?project_id=ai-test&status_id=*" | jq '.total_count')
  if [ "${cnt:-0}" -lt 2 ]; then
    curl -sf "${h[@]}" -X POST "$base/issues.json" -H 'Content-Type: application/json' \
      -d "{\"issue\":{\"project_id\":\"ai-test\",\"tracker_id\":${tracker_id},\"subject\":\"AI 更新テスト用チケット\",\"description\":\"AI がこのチケットを更新する\"}}" >/dev/null
    curl -sf "${h[@]}" -X POST "$base/issues.json" -H 'Content-Type: application/json' \
      -d "{\"issue\":{\"project_id\":\"ai-test\",\"tracker_id\":${tracker_id},\"subject\":\"PR 連携テスト用チケット\",\"description\":\"PR 番号を追記する\"}}" >/dev/null
    log "redmine sample issues x2 (tracker_id=${tracker_id})"
  else
    log "redmine issues already present ($cnt)"
  fi
}

main() {
  gitea_seed
  svn_seed
  redmine_seed
  log "done"
}
main "$@"
