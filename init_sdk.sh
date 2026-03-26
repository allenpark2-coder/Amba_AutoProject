#!/bin/bash
# init_sdk.sh — 首次初始化 Cooper SDK 基礎版本
# 解壓 tarball → git init 20 個 repo → push 到 GitLab
# 前置條件: GitLab 上的 repo 已手動建立

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_JSON="$SCRIPT_DIR/project.json"

# 前置檢查
[ -f "$PROJECT_JSON" ] || { echo "ERROR: project.json not found"; exit 1; }

# ── 讀取設定 ──────────────────────────────────────────────────────────────────
echo "=== [1] Reading config from project.json ==="
read -r VERSION TARBALL CONTAINER MANIFEST_XML BRANCH <<EOF
$(python3 -c "
import json, sys
d = json.load(open('$PROJECT_JSON'))
for v in d['versions']:
    if v['type'] == 'base' and v['status'] == 'pending':
        print(v['version'])
        print(v['tarball'])
        print(v.get('tarball_container', ''))
        print(v['manifest_xml'])
        print(v['branch'])
        sys.exit(0)
print('ERROR: No pending base version found in project.json', file=sys.stderr)
sys.exit(1)
")
EOF

GITLAB_SERVER=$(python3 -c "import json; d=json.load(open('$PROJECT_JSON')); print(d['gitlab_server'])")
WORK_DIR="$SCRIPT_DIR/workspace"
XML="$SCRIPT_DIR/$MANIFEST_XML"

echo "  版本: $VERSION  分支: $BRANCH"

# 前置檢查
[ -f "$SCRIPT_DIR/$TARBALL" ] || { echo "ERROR: Tarball not found: $TARBALL"; exit 1; }
[ -f "$XML" ]                  || { echo "ERROR: Manifest XML not found: $MANIFEST_XML"; exit 1; }

# ── XML 解析工具函式 ───────────────────────────────────────────────────────────
get_all_paths() {
    grep '<project ' "$1" | grep -o 'path="[^"]*"' | cut -d'"' -f2
}

get_name_for_path() {
    local xml="$1" path="$2"
    grep "path=\"$path\"" "$xml" | grep -o 'name="[^"]*"' | cut -d'"' -f2
}

ALL_PATHS=$(get_all_paths "$XML")

# ── 解壓 tarball ──────────────────────────────────────────────────────────────
echo "=== [2] Extracting $TARBALL (this may take a while) ==="
mkdir -p "$WORK_DIR"

case "$TARBALL" in
    *.tar.xz)  tar xJf "$SCRIPT_DIR/$TARBALL" -C "$WORK_DIR" ;;
    *.tar.gz)  tar xzf "$SCRIPT_DIR/$TARBALL" -C "$WORK_DIR" ;;
    *.tar.bz2) tar xjf "$SCRIPT_DIR/$TARBALL" -C "$WORK_DIR" ;;
    *.tar)     tar xf  "$SCRIPT_DIR/$TARBALL" -C "$WORK_DIR" ;;
    *)         echo "ERROR: Unknown tarball format: $TARBALL"; exit 1 ;;
esac

# 把容器目錄內容移到 workspace/ 根層
if [ -n "$CONTAINER" ] && [ -d "$WORK_DIR/$CONTAINER" ]; then
    echo "  Moving contents from container dir: $CONTAINER"
    for item in "$WORK_DIR/$CONTAINER"/.[!.]* "$WORK_DIR/$CONTAINER"/*; do
        [ -e "$item" ] && mv "$item" "$WORK_DIR/"
    done
    rmdir "$WORK_DIR/$CONTAINER"
fi

# ── Pass 1: 建立 .gitignore（父 repo 排除子 repo 目錄）────────────────────────
echo "=== [3] Building .gitignore for parent repos ==="

echo "$ALL_PATHS" | while IFS= read -r repo_path; do
    # 收集此 path 下的直接子 repo 目錄名稱
    children=$(echo "$ALL_PATHS" | while IFS= read -r other; do
        case "$other" in
            "$repo_path"/*)
                rel="${other#$repo_path/}"
                echo "${rel%%/*}"
                ;;
        esac
    done | sort -u)

    if [ -n "$children" ]; then
        mkdir -p "$WORK_DIR/$repo_path"
        echo "$children" > "$WORK_DIR/$repo_path/.gitignore"
        echo "  .gitignore: $repo_path/ ($(echo "$children" | wc -l | tr -d ' ') entries)"
    fi
done

# ── Pass 2: git init + commit + push ─────────────────────────────────────────
echo "=== [4] Initializing git repos and pushing to GitLab ==="

echo "$ALL_PATHS" | while IFS= read -r repo_path; do
    repo_name=$(get_name_for_path "$XML" "$repo_path")
    repo_dir="$WORK_DIR/$repo_path"

    echo "--- $repo_path -> $repo_name"

    # 建立目錄（如 doc/ 可能不在 tarball 中）
    mkdir -p "$repo_dir"

    # 已初始化則跳過（冪等性保護）
    if [ -d "$repo_dir/.git" ]; then
        echo "  已初始化，跳過"
        continue
    fi

    git init "$repo_dir"
    git -C "$repo_dir" add .
    git -C "$repo_dir" commit -m "Cooper SDK $VERSION" 2>/dev/null \
        || git -C "$repo_dir" commit --allow-empty -m "Cooper SDK $VERSION"
    git -C "$repo_dir" checkout -b "$BRANCH"
    git -C "$repo_dir" remote add origin "${GITLAB_SERVER}:${repo_name}.git"
    git -C "$repo_dir" push -u origin "$BRANCH"
done

# ── 更新 project.json ─────────────────────────────────────────────────────────
echo "=== [5] Updating project.json ==="
python3 -c "
import json
with open('$PROJECT_JSON') as f:
    d = json.load(f)
for v in d['versions']:
    if v['version'] == '$VERSION' and v['type'] == 'base':
        v['status'] = 'pushed'
d['current_version'] = '$VERSION'
with open('$PROJECT_JSON', 'w') as f:
    json.dump(d, f, indent=2)
print('  project.json updated')
"

# ── 推送 manifest ─────────────────────────────────────────────────────────────
echo "=== [6] Pushing manifest XML ==="
"$SCRIPT_DIR/push_manifest.sh" "$XML" "$BRANCH"

echo ""
echo "✅ Done! Cooper SDK $VERSION pushed. Branch: $BRANCH"
