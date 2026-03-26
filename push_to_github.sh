#!/bin/bash
set -e

# -----------------------------
# 用法:
# ./push_to_github.sh <local_folder> <remote_git_url>
# 例如：
# ./push_to_github.sh workspace_tool git@github-personal:allenpark2-coder/workspace_tool.git
# -----------------------------

if [[ $# -ne 2 ]]; then
    echo "Usage: $0 <local_folder> <remote_git_url>"
    exit 1
fi

LOCAL_DIR="$1"
REMOTE_URL="$2"

# 進入本地資料夾
if [[ ! -d "$LOCAL_DIR" ]]; then
    echo "Error: Local folder '$LOCAL_DIR' does not exist"
    exit 1
fi
cd "$LOCAL_DIR"

# 初始化 git
if [[ ! -d ".git" ]]; then
    git init
    echo "Git initialized in $LOCAL_DIR"
else
    echo "Git already initialized"
fi

# 設定 main 分支
git branch -M main

# 加入所有檔案並 commit
git add .
git commit -m "Initial commit for $(basename "$LOCAL_DIR")" || echo "Nothing to commit"

# 新增遠端或更新 URL
if git remote | grep -q "^origin$"; then
    git remote set-url origin "$REMOTE_URL"
    echo "Updated remote origin to $REMOTE_URL"
else
    git remote add origin "$REMOTE_URL"
    echo "Added remote origin $REMOTE_URL"
fi

# 推送到遠端
git push -u origin main

echo "✅ Successfully pushed $LOCAL_DIR to $REMOTE_URL"
