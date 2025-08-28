 
# Wiki.js 到 Ghost 遷移工具

這是一個 Bash 腳本工具，用於將 Wiki.js 匯出的 Markdown 檔案批量匯入到 Ghost 部落格系統。腳本支援完整的 Front Matter 解析、路徑路由轉換，並針對中文內容進行了最佳化。

## ✨ 功能特色

- **🔄 批量遷移**：一次性將所有 Wiki.js Markdown 檔案匯入 Ghost
- **📋 Front Matter 支援**：自動解析 `title`、`description`、`tags`、`published`、`slug` 等欄位
- **🗂️ 路徑路由**：將 Wiki.js 的資料夾結構轉換為有意義的 Ghost URL 路徑
- **🌏 中文友好**：完整支援中文檔名和內容，正確處理 UTF-8 編碼
- **🔐 安全認證**：使用 Ghost Admin API 和 JWT Token 認證
- **🔍 詳細診斷**：提供完整的錯誤診斷和修復建議
- **🧪 試運行模式**：可預覽匯入結果而不實際執行

## 📋 系統需求

### 必要工具
- **Bash**：Unix/Linux/macOS 系統
- **curl**：用於 HTTP API 請求
- **Python 3**：用於 JWT token 生成和 JSON 處理
- **realpath**：用於路徑處理（大多數系統預裝）

### Ghost 需求
- **Ghost 版本**：>= 2.0（支援 Admin API v5.0）
- **API 存取權限**：需要 Admin API Key

## 🚀 快速開始

### 1. 準備 Wiki.js 匯出檔案

從 Wiki.js 匯出所有頁面為 Markdown 格式，並將檔案放在指定目錄中：

```
markdown-files/
├── 技術文件/
│   ├── 開發指南/
│   │   └── API-文件.md
│   └── 部署指南.md
├── 專案管理/
│   └── 工作流程.md
└── 筆記.md
```

### 2. 取得 Ghost Admin API Key

1. 登入 Ghost Admin Panel：`http://your-ghost-site.com/ghost`
2. 前往 **Settings** → **Integrations**
3. 點擊 **Add custom integration**
4. 輸入名稱（例如：Wiki.js Import）
5. 儲存後複製 **Admin API Key**

### 3. 設定並執行腳本

```bash
# 下載腳本
chmod +x fixed_ghost_import.sh

# 編輯腳本設定
vim fixed_ghost_import.sh
# 修改以下變數：
# GHOST_URL="http://your-ghost-site.com"
# GHOST_ADMIN_API_KEY="your_api_key_here"

# 測試連線
./fixed_ghost_import.sh --test

# 試運行預覽
./fixed_ghost_import.sh --path-routing --dry-run ./markdown-files

# 正式匯入
./fixed_ghost_import.sh --path-routing ./markdown-files
```

## 📖 使用說明

### 基本語法
```bash
./fixed_ghost_import.sh [選項] [目錄路徑]
```

### 命令列選項

| 選項 | 說明 |
|------|------|
| `-h, --help` | 顯示使用說明 |
| `-u, --url <URL>` | 設定 Ghost 站點 URL |
| `-k, --key <API_KEY>` | 設定 Admin API Key |
| `-t, --test` | 僅測試 API 連線 |
| `-d, --dry-run` | 試運行模式（預覽不匯入） |
| `-p, --path-routing` | 啟用資料夾路徑路由 |

### 使用範例

```bash
# 基本匯入
./fixed_ghost_import.sh ./wiki-export

# 指定 Ghost URL 和 API Key
./fixed_ghost_import.sh -u https://myblog.com -k "your_api_key" ./wiki-export

# 啟用路徑路由的完整匯入
./fixed_ghost_import.sh --path-routing --url https://myblog.com ./wiki-export

# 只測試 API 連線
./fixed_ghost_import.sh --test
```

## 🗂️ 路徑路由功能

### 啟用路徑路由
使用 `--path-routing` 參數可將 Wiki.js 的資料夾結構轉換為 Ghost 文章的 URL 路徑。

### 轉換規則

| Wiki.js 檔案路徑 | Ghost URL Slug |
|------------------|----------------|
| `技術文件/API/REST-API.md` | `/技術文件-api-rest-api/` |
| `專案/開發/部署指南.md` | `/專案-開發-部署指南/` |
| `README.md` | `/readme/` |

### 手動自訂 Slug
在 Markdown 檔案的 Front Matter 中加入 `slug` 欄位可覆寫自動產生的路由：

```yaml
---
title: API 開發指南
slug: api-development-guide
---
```

## 📄 Front Matter 支援

腳本支援以下 Wiki.js 和標準的 Front Matter 欄位：

```yaml
---
title: 文章標題                    # 文章標題
description: 文章描述               # 文章摘要
published: true                    # true=發佈, false=草稿
tags: tag1, tag2, tag3            # 標籤（逗號分隔）
slug: custom-url-slug             # 自訂 URL（可選）
date: 2025-05-06T09:01:09.786Z    # 發佈日期（Ghost 會忽略）
editor: markdown                   # 編輯器類型（Ghost 會忽略）
dateCreated: 2025-05-06T09:01:08Z # 建立日期（Ghost 會忽略）
---

# 你的 Markdown 內容
...
```

## 🔧 設定說明

### 1. Ghost URL 設定
```bash
# 本地開發環境
GHOST_URL="http://localhost:8081"

# 正式環境
GHOST_URL="https://your-blog.com"
```

### 2. Admin API Key 格式
正確的 API Key 格式為：`24位ID:64位Secret`
```
範例：507f1f77bcf86cd799439011:4cc5c681e1d4d3b1e9a64fae7a1f8c6c1234567890abcdef
```

### 3. 目錄結構
確保你的 Markdown 檔案放在指定目錄中：
```
your-wiki-export/
├── folder1/
│   ├── subfolder/
│   │   └── article.md
│   └── another-article.md
└── root-article.md
```

## 🚨 故障排除

### 常見錯誤及解決方案

#### 1. **JWT Token 生成失敗**
```
錯誤: JWT token 生成失敗
```
**解決方案：**
- 檢查 API Key 格式是否正確（24+64 位十六進制）
- 確認 Python 3 已安裝
- 檢查系統時間是否正確

#### 2. **API 連線失敗 (401)**
```
✗ 認證失敗 (401)
```
**解決方案：**
- 重新產生 Ghost Admin API Key
- 確認 API Key 完整複製（沒有多餘空格）
- 檢查 Ghost URL 是否正確

#### 3. **API 連線失敗 (404)**
```
✗ API 端點不存在 (404)
```
**解決方案：**
- 確認 Ghost 版本 >= 2.0
- 檢查 Ghost URL 路徑（不要多加 `/ghost`）
- 確認 Ghost 服務正常運行

#### 4. **Unicode 處理錯誤**
```
SyntaxError: (unicode error) 'unicodeescape' codec can't decode bytes
```
**解決方案：**
- 使用最新版腳本（已修復此問題）
- 確認檔案編碼為 UTF-8

#### 5. **Ghost 服務無法連接**
```
✗ 無法連接到 Ghost 服務
```
**解決方案：**
```bash
# 檢查 Ghost 狀態
curl -I http://localhost:8081

# 如使用 Docker
docker ps | grep ghost
docker logs ghost-container-name
```

### 診斷指令

```bash
# 完整診斷
./fixed_ghost_import.sh --test

# 檢查 API Key 格式
echo "your_api_key" | grep -E "^[a-f0-9]{24}:[a-f0-9]{64}$"

# 測試基本連線
curl "http://localhost:8081/ghost/api/content/posts/?limit=1"
```

## 📚 進階用法

### 批次處理多個目錄
```bash
# 處理多個 Wiki.js 匯出目錄
for dir in wiki-export-*; do
    echo "處理 $dir..."
    ./fixed_ghost_import.sh --path-routing "$dir"
done
```

### 自訂標籤映射
在 Front Matter 中使用不同的標籤策略：
```yaml
# Wiki.js 原始標籤
tags: development, api, documentation

# 轉換為 Ghost 標籤
# 腳本會自動建立這些標籤
```

### 大量檔案處理
對於大量檔案，建議分批處理：
```bash
# 先處理特定子目錄
./fixed_ghost_import.sh --path-routing ./wiki-export/技術文件

# 再處理其他目錄
./fixed_ghost_import.sh --path-routing ./wiki-export/專案文件
```

## ⚠️ 重要注意事項

### 遷移前準備
1. **備份 Ghost 資料庫**：執行匯入前務必備份
2. **測試環境驗證**：建議先在測試環境執行
3. **內容檢查**：確認 Markdown 格式正確

### 內容限制
- **圖片處理**：需要手動處理圖片上傳和路徑更新
- **內部連結**：Wiki.js 的內部連結需要手動調整為 Ghost 格式
- **自訂元素**：Wiki.js 的特殊元素可能需要轉換為 Ghost 支援的格式

### 效能考量
- **大檔案**：超大的 Markdown 檔案可能需要分割
- **API 限制**：Ghost API 有速率限制，大量檔案建議分批處理
- **記憶體使用**：處理大量檔案時注意系統記憶體

## 🔗 相關資源

- [Ghost Admin API 文件](https://ghost.org/docs/admin-api/)
- [Ghost Content Structure](https://ghost.org/docs/content-structure/)
- [Wiki.js 匯出指南](https://docs.requarks.io/)

## 📋 授權與貢獻

這個工具是開源專案，歡迎提出問題和改進建議。

### 回報問題
如果遇到問題，請提供以下資訊：
- Ghost 版本
- 錯誤訊息
- 範例 Markdown 檔案
- 系統環境（OS、Shell 版本）

---

**⚡ 快速開始指令：**
```bash
# 1. 測試連線
./fixed_ghost_import.sh --test

# 2. 預覽效果
./fixed_ghost_import.sh --path-routing --dry-run ./your-wiki-export

# 3. 正式匯入
./fixed_ghost_import.sh --path-routing ./your-wiki-export
```
