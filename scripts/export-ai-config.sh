#!/usr/bin/env bash
# 配布用 AI 指示ファイルを対象プロジェクトへコピーする。
# 正リストは docs/ai/DISTRIBUTION.md。
#
# 使い方:
#   scripts/export-ai-config.sh <対象プロジェクトのルート> [--dry-run]
#
# 既存ファイルは上書きする。コピー先でローカル調整している場合は事前に差分を確認すること。

set -euo pipefail

SRC_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
  echo "usage: $0 <target-project-root> [--dry-run]" >&2
  exit 2
}

[ $# -ge 1 ] || usage
DEST_ROOT="$1"
DRY_RUN=""
[ "${2:-}" = "--dry-run" ] && DRY_RUN=1

[ -d "$DEST_ROOT" ] || { echo "not a directory: $DEST_ROOT" >&2; exit 1; }
[ "$(cd "$DEST_ROOT" && pwd)" != "$SRC_ROOT" ] || { echo "source and target are the same" >&2; exit 1; }

# 配布物（DISTRIBUTION.md と一致させる）
ITEMS=(
  "CLAUDE.md"
  ".claude/rules"
  ".claude/skills"
  ".github/copilot-instructions.md"
  ".github/instructions"
  ".github/skills"
  "docs/ai"
)

echo "src : $SRC_ROOT"
echo "dest: $(cd "$DEST_ROOT" && pwd)"
[ -n "$DRY_RUN" ] && echo "(dry-run)"
echo

for item in "${ITEMS[@]}"; do
  src="$SRC_ROOT/$item"
  dest="$DEST_ROOT/$item"
  if [ ! -e "$src" ]; then
    echo "SKIP (missing in source): $item"
    continue
  fi
  if [ -n "$DRY_RUN" ]; then
    echo "COPY $item"
    continue
  fi
  mkdir -p "$(dirname "$dest")"
  if [ -d "$src" ]; then
    rm -rf "$dest"
    cp -R "$src" "$dest"
  else
    cp "$src" "$dest"
  fi
  echo "COPY $item"
done

echo
echo "完了。コピー先で以下を調整する（docs/ai/DISTRIBUTION.md「導入手順」参照）:"
echo "  - CLAUDE.md の「# GiteaSVNTest プロジェクト」節を対象プロジェクト向けに書き換え"
echo "  - docs/ai/env-vars.md の URL / OWNER / REPO を対象環境の実値に"
echo "  - 環境変数の投入（direnv / CI Secrets / systemd）"
echo "  - docs/ai/healthcheck.md で疎通確認"
