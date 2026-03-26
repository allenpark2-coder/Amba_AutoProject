#!/bin/bash
# apply_patch.sh — 套用 Cooper SDK 累進 patch，建立新 git branch 並推送到 GitLab
# 前置條件: init_sdk.sh 已執行完成（workspace/ 已存在）

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_JSON="$SCRIPT_DIR/project.json"

# 前置檢查
[ -f "$PROJECT_JSON" ] || { echo "ERROR: project.json not found"; exit 1; }

# ── 讀取設定 ──────────────────────────────────────────────────────────────────
echo "=== [1] Reading config from project.json ==="
read -r NEW_VERSION OUTER_TAR INNER_TARBALL MANIFEST_XML NEW_BRANCH <<EOF
$(python3 -c "
import json, sys
d = json.load(open('$PROJECT_JSON'))
for v in d['versions']:
    if v['type'] == 'patch' and v['status'] == 'pending':
        print(v['version'])
        print(v['tarball'])
        print(v.get('inner_tarball', ''))
        print(v['manifest_xml'])
        print(v['branch'])
        sys.exit(0)
print('ERROR: No pending patch version found in project.json', file=sys.stderr)
sys.exit(1)
")
EOF

WORK_DIR="$SCRIPT_DIR/workspace"
XML="$SCRIPT_DIR/$MANIFEST_XML"

echo "  版本: $NEW_VERSION  分支: $NEW_BRANCH"

# 前置檢查
[ -d "$WORK_DIR/ambarella" ] || { echo "ERROR: workspace/ambarella not found. Run init_sdk.sh first."; exit 1; }
[ -f "$SCRIPT_DIR/$OUTER_TAR" ] || { echo "ERROR: Patch tarball not found: $OUTER_TAR"; exit 1; }
[ -f "$XML" ] || { echo "ERROR: Manifest XML not found: $MANIFEST_XML"; exit 1; }

# ── XML 解析工具函式 ───────────────────────────────────────────────────────────
get_all_paths() {
    grep '<project ' "$1" | grep -o 'path="[^"]*"' | cut -d'"' -f2
}

get_name_for_path() {
    local xml="$1" path="$2"
    grep "path=\"$path\"" "$xml" | grep -o 'name="[^"]*"' | cut -d'"' -f2
}

ALL_PATHS=$(get_all_paths "$XML")

# ── 解壓外層 tar，取出 inner .tar.bz2 ─────────────────────────────────────────
echo "=== [2] Extracting outer tarball ==="
OUTER_TMP="$WORK_DIR/_outer_$$"
mkdir -p "$OUTER_TMP"
tar xf "$SCRIPT_DIR/$OUTER_TAR" -C "$OUTER_TMP"

INNER_PATH=$(find "$OUTER_TMP" -name "$INNER_TARBALL" | head -1)
[ -n "$INNER_PATH" ] || { echo "ERROR: Cannot find $INNER_TARBALL inside $OUTER_TAR"; rm -rf "$OUTER_TMP"; exit 1; }

# ── 解壓 inner .tar.bz2 到 workspace/（與 ambarella/ 同層）─────────────────────
echo "=== [3] Extracting patch (inner tarball) to workspace/ ==="
tar xjf "$INNER_PATH" -C "$WORK_DIR"
rm -rf "$OUTER_TMP"

# ── 執行 apply.sh ──────────────────────────────────────────────────────────────
echo "=== [4] Running apply.sh ==="
PATCH_DIR=$(find "$WORK_DIR" -maxdepth 1 -type d -name 'cooper_patch_*' | head -1)
[ -n "$PATCH_DIR" ] || { echo "ERROR: Cannot find cooper_patch_* directory in workspace/"; exit 1; }

echo "  Patch dir: $PATCH_DIR"
cd "$PATCH_DIR"
chmod +x apply.sh
./apply.sh
cd "$SCRIPT_DIR"

# 清除 patch 暫存目錄
rm -rf "$PATCH_DIR"

# ── git: 建新 branch、commit、push ────────────────────────────────────────────
echo "=== [5] Creating new branch $NEW_BRANCH and pushing ==="

echo "$ALL_PATHS" | while IFS= read -r repo_path; do
    repo_dir="$WORK_DIR/$repo_path"
    echo "--- $repo_path"

    if [ ! -d "$repo_dir/.git" ]; then
        echo "  WARNING: No git repo in $repo_path, skipping"
        continue
    fi

    git -C "$repo_dir" checkout -b "$NEW_BRANCH"
    git -C "$repo_dir" add .

    # 若有變更才 commit；否則建立空 commit 保持 branch 存在
    if git -C "$repo_dir" diff --cached --quiet; then
        git -C "$repo_dir" commit --allow-empty -m "Cooper SDK $NEW_VERSION (no changes)"
    else
        git -C "$repo_dir" commit -m "Cooper SDK $NEW_VERSION"
    fi

    git -C "$repo_dir" push origin "$NEW_BRANCH"
done

# ── 更新 project.json ─────────────────────────────────────────────────────────
echo "=== [6] Updating project.json ==="
python3 -c "
import json
with open('$PROJECT_JSON') as f:
    d = json.load(f)
for v in d['versions']:
    if v['version'] == '$NEW_VERSION' and v['type'] == 'patch':
        v['status'] = 'pushed'
d['current_version'] = '$NEW_VERSION'
with open('$PROJECT_JSON', 'w') as f:
    json.dump(d, f, indent=2)
print('  project.json updated')
"

# ── 推送 manifest ─────────────────────────────────────────────────────────────
echo "=== [7] Pushing manifest XML ==="
"$SCRIPT_DIR/push_manifest.sh" "$XML" "$NEW_BRANCH"

echo ""
echo "✅ Done! Patch $NEW_VERSION applied. Branch: $NEW_BRANCH"
