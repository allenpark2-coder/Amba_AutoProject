# SDK Version Management — Cooper SDK 自動化工作流程

自動將 Ambarella Cooper SDK tarball 建立 git repo 並推送到 GitLab，支援逐版本的 branch 追蹤與累進 patch。

## Prerequisites

- `git@venus.vivotek.tw` 的 SSH 金鑰已設定（`~/.ssh/config`）
- `python3`、`git`、`tar` 已安裝
- GitLab 上的 repo 需手動先建好（script 只負責 push，不自動建立 repo）

## Repository Layout

```
Amba_Project/
├── project.json        ← 版本設定與狀態追蹤（新版本時手動編輯）
├── init_sdk.sh         ← 首次基礎 SDK 初始化
├── apply_patch.sh      ← 套用累進 patch
├── push_manifest.sh    ← 更新 GitLab manifest repo
└── workspace/          ← 解壓後的 SDK 工作目錄（由 init_sdk.sh 建立）
```

## project.json Schema

| 欄位 | 說明 |
|------|------|
| `gitlab_server` | GitLab SSH base URL |
| `namespace` | SDK repo 的 GitLab group 路徑 |
| `manifest_repo` | manifest repo 的 SSH URL |
| `work_dir` | 本機 SDK 解壓目錄（預設 `./workspace`）|
| `current_version` | 成功 push 後自動更新 |
| `versions[]` | 版本設定陣列（見下表）|

### Version Entry 欄位

| 欄位 | 必填 | 說明 |
|------|------|------|
| `version` | 必填 | 例如 `"2.5"` 或 `"2.5.2"` |
| `tarball` | 必填 | tarball 檔名（放在此目錄） |
| `tarball_container` | base 版才需要 | tarball 解壓後的容器目錄名稱 |
| `inner_tarball` | patch 版才需要 | 外層 tar 裡面的 `.tar.bz2` 檔名 |
| `manifest_xml` | 必填 | manifest XML 檔名（放在此目錄） |
| `branch` | 必填 | GitLab branch 名稱（`COOPER_SDK-{VERSION}-{DATE}-{CHIPS}`）|
| `type` | 必填 | `"base"` 或 `"patch"` |
| `status` | 必填 | `"pending"` → `"pushed"`（自動更新）|
| `based_on` | patch 才需要 | 此 patch 所套用的基礎版本號 |

## First-Time Setup（基礎 SDK）

1. 下載 base SDK tarball 到 `Amba_Project/`
2. 將 manifest XML（例如 `amba_cv5_cooper_2.5.xml`）放到 `Amba_Project/`
3. 在 GitLab 手動建立 20 個 SDK repo + 1 個 manifest repo
4. 在 `project.json` 的 `versions` 加入 base 版本，`"status": "pending"`
5. 執行：
   ```bash
   ./init_sdk.sh
   ```

## Applying a Patch

1. 下載 patch tarball 到 `Amba_Project/`
2. 將新 manifest XML（例如 `amba_cv5_cooper_2.5.2.xml`）放到 `Amba_Project/`
3. 在 `project.json` 的 `versions` 加入 patch 版本，`"status": "pending"`
4. 執行：
   ```bash
   ./apply_patch.sh
   ```

## 各腳本說明

**`init_sdk.sh`**：從 `project.json` 讀取待處理的 base 版本。解壓 tarball 到
`workspace/`，為父 repo（`ambarella/`）建立 `.gitignore` 排除子 repo 目錄，
然後對 manifest XML 定義的所有 20 個 repo 執行 `git init` + `git add` +
`git commit` + `git push`。最後呼叫 `push_manifest.sh` 更新 manifest repo。
加上 `--step` 參數可進入逐步模式，每個步驟前暫停確認（按 Enter 繼續，輸入 `q` 離開）。

**`apply_patch.sh`**：從 `project.json` 讀取待處理的 patch 版本。若 `workspace/`
已被清除，會自動從對應的 base tarball 重新解壓，並從 GitLab fetch 回 git 歷史後
繼續。解壓雙層 tarball 到 `workspace/`，執行 Ambarella 的 `apply.sh` 更新 SDK 檔案，
再對每個 repo 建立新 branch、commit 變更並 push。最後呼叫 `push_manifest.sh`。

**`push_manifest.sh`**：Clone GitLab manifest repo，將新的 manifest XML 複製進去，
commit 並 push。可由其他腳本自動呼叫，也可手動執行：
`./push_manifest.sh <xml-file> <branch-name>`

## Manifest Repo 使用方式

Scripts 執行完成後，下游工程師可用以下指令取得完整 SDK：
```bash
repo init -u git@venus.vivotek.tw:odm-rd3/manifest/amba-cv5x.git \
          -m amba_cv5_cooper_2.5.2.xml \
          -b COOPER_SDK-2.5.2-20250912-CV2X_CV5X_CV7X
repo sync
```

## Known Caveats

1. **雙層 patch tarball**：Ambarella patch 是 `outer.tar → container/ → inner.tar.bz2 → apply.sh` 結構。`apply.sh` 需在 `cooper_patch_*/` 目錄內執行，`../ambarella/` 為目標 SDK 目錄。

2. **`doc/` repo 可能為空**：manifest XML 中有 `doc/` 路徑，但 base tarball 裡可能不存在。Script 會自動建立空目錄並推送空 commit。

3. **`ambarella/` 父 repo**：`ambarella/` 底下有 18 個子 repo 目錄，script 會自動建立 `.gitignore` 排除它們，避免被父 repo 追蹤。

4. **大型 tarball**：base SDK 約 1.7 GB，patch 約 1.4 GB，解壓需要數分鐘。

5. **套 patch 前 workspace 被清除**：`apply_patch.sh` 會自動偵測並從 base tarball 重新解壓、從 GitLab fetch git 歷史。因此 **base tarball 需保留在此目錄**，不可刪除（patch tarball 同理）。

## GitLab Repo List

全部 20 個 repo 都在 `ad-odm-rdd3/codebase/sdk/amab_cooper_sdk/` 底下：

```
ambarella           ambarella/app       ambarella/boards    ambarella/boot
ambarella/build     ambarella/document  ambarella/drv_modules ambarella/kernel
ambarella/license   ambarella/metadata  ambarella/oryx_v2   ambarella/oss
ambarella/oss_yocto ambarella/packages  ambarella/prebuild  ambarella/rootfs
ambarella/security  ambarella/unit_test external            doc
```
