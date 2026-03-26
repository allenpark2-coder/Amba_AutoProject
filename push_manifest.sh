#!/bin/bash
# push_manifest.sh — 將 manifest XML 推送到 GitLab manifest repo
# 用法: ./push_manifest.sh <xml-file-path> <branch-name>
# 例如: ./push_manifest.sh amba_cv5_cooper_2.5.2.xml COOPER_SDK-2.5.2-20250912-CV2X_CV5X_CV7X

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_JSON="$SCRIPT_DIR/project.json"

XML_FILE="$1"
BRANCH="$2"

# 前置檢查
[ -f "$PROJECT_JSON" ] || { echo "ERROR: project.json not found"; exit 1; }
[ -n "$XML_FILE" ] || { echo "Usage: $0 <xml-file-path> <branch-name>"; exit 1; }
[ -n "$BRANCH" ]   || { echo "Usage: $0 <xml-file-path> <branch-name>"; exit 1; }
[ -f "$XML_FILE" ] || { echo "ERROR: XML file not found: $XML_FILE"; exit 1; }

XML_BASENAME=$(basename "$XML_FILE")
MANIFEST_REPO=$(python3 -c "import json; d=json.load(open('$PROJECT_JSON')); print(d['manifest_repo'])")

TMPDIR="$SCRIPT_DIR/_manifest_tmp_$$"

echo "=== [manifest] Clone $MANIFEST_REPO ==="
git clone "$MANIFEST_REPO" "$TMPDIR"

echo "=== [manifest] Copy $XML_BASENAME ==="
cp "$XML_FILE" "$TMPDIR/$XML_BASENAME"

cd "$TMPDIR"
git add "$XML_BASENAME"
git commit -m "Add manifest $XML_BASENAME for $BRANCH"
git push
cd "$SCRIPT_DIR"

rm -rf "$TMPDIR"
echo "=== [manifest] Done: $XML_BASENAME pushed to manifest repo ==="
