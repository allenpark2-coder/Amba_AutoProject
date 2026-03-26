# Amba Project — 專案規則

## Development Rules

這個專案的開發規則，所有 Agent 都必須遵守：

1. **Script 風格**：多用 Linux shell script，語法要簡單易讀。避免複雜的正則式或特殊語法，儘量用一般人熟悉的寫法（`grep`、`cut`、`sed` 簡單用法即可）。
2. **文件語言**：流程說明一律用**繁體中文**，除了 folder 名稱、指令、專業名詞可以用英文。
3. **Markdown 檔案格式**：`.md` 檔（包含 `CLAUDE.md`、`skill.md`、`subagent.md` 等）採中英混合：標題與技術名詞用英文，說明文字用繁體中文。
4. **功能文件拆分**：每個功能或模組的詳細說明獨立成一個 `.md` 檔，存放在這個目錄，並在下方 `## Features` 區塊用 `@filename.md` 引用。CLAUDE.md 只保留規則與索引，不放實作細節。

## Features

各功能的詳細文件：

- @sdk-version-management.md — Cooper SDK 解壓、git init、push 到 GitLab 的自動化流程
