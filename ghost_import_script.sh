#!/bin/bash

# Ghost Markdown 批量匯入腳本（完全修復版）
# 使用方法: ./fixed_ghost_import.sh /path/to/markdown-files

# 設定變數
GHOST_URL="http://localhost:8081"
GHOST_API_URL="${GHOST_URL}/ghost/api/admin"
MARKDOWN_DIR="${1:-./markdown-files}"
GHOST_ADMIN_API_KEY="68afcb482f1363000177e4be:f51cebce9cfad3d07e4a744932bcd18b6e4f6bcb87009fcd960017c144024ff0"
USE_PATH_ROUTING="false"  # 是否啟用資料夾路徑路由

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 使用 Python 生成 JWT Token（完全重寫，避免 bash 處理十六進制問題）
generate_jwt_token() {
    local api_key="$1"

    # 分割 API Key
    IFS=':' read -r KEY_ID SECRET <<< "$api_key"

    if [ -z "$KEY_ID" ] || [ -z "$SECRET" ]; then
        echo -e "${RED}錯誤: API Key 格式不正確${NC}" >&2
        return 1
    fi

    # 使用 Python 生成 JWT token
    python3 << EOF
import hmac
import hashlib
import base64
import json
import time
import sys

def base64_url_encode(data):
    """Base64URL 編碼"""
    if isinstance(data, str):
        data = data.encode('utf-8')
    elif isinstance(data, dict):
        data = json.dumps(data, separators=(',', ':')).encode('utf-8')

    return base64.urlsafe_b64encode(data).decode('utf-8').rstrip('=')

# JWT header
header = {
    "alg": "HS256",
    "typ": "JWT",
    "kid": "$KEY_ID"
}

# JWT payload
now = int(time.time())
payload = {
    "iat": now,
    "exp": now + 300,  # 5 分鐘後過期
    "aud": "/admin/"
}

try:
    # 編碼 header 和 payload
    header_encoded = base64_url_encode(header)
    payload_encoded = base64_url_encode(payload)
    message = f"{header_encoded}.{payload_encoded}"

    # 將十六進制 secret 轉換為 bytes
    secret_bytes = bytes.fromhex("$SECRET")

    # 生成簽名
    signature = hmac.new(
        secret_bytes,
        message.encode('utf-8'),
        hashlib.sha256
    ).digest()

    signature_encoded = base64_url_encode(signature)

    # 生成完整的 JWT token
    jwt_token = f"{message}.{signature_encoded}"
    print(jwt_token)

except ValueError as e:
    print(f"錯誤: Secret 不是有效的十六進制字串: {e}", file=sys.stderr)
    sys.exit(1)
except Exception as e:
    print(f"JWT 生成失敗: {e}", file=sys.stderr)
    sys.exit(1)
EOF
}

# 改進的 API 連線測試
test_api_connection() {
    echo -e "${BLUE}測試 Ghost API 連線...${NC}"

    # 生成 JWT token
    jwt_token=$(generate_jwt_token "$GHOST_ADMIN_API_KEY")

    if [ $? -ne 0 ] || [ -z "$jwt_token" ]; then
        echo -e "${RED}✗ JWT token 生成失敗${NC}"
        return 1
    fi

    echo -e "${CYAN}JWT Token 長度: ${#jwt_token}${NC}"

    # 首先測試 Ghost 基本連接
    echo -e "${BLUE}檢查 Ghost 服務...${NC}"
    basic_response=$(curl -s -m 10 -w "HTTP_CODE:%{http_code}" "$GHOST_URL")
    basic_http_code=$(echo "$basic_response" | tail -c 4)

    if [ "$basic_http_code" != "200" ]; then
        echo -e "${RED}✗ 無法連接到 Ghost 服務 (HTTP: $basic_http_code)${NC}"
        echo -e "${YELLOW}請確認 Ghost 是否在 $GHOST_URL 運行${NC}"
        return 1
    fi

    echo -e "${GREEN}✓ Ghost 服務運行正常${NC}"

    # 測試 Admin API
    echo -e "${BLUE}測試 Admin API 認證...${NC}"
    response=$(curl -s -m 10 -w "\nHTTP_CODE:%{http_code}" -X GET "${GHOST_API_URL}/site/" \
        -H "Authorization: Ghost $jwt_token" \
        -H "Accept-Version: v5.0" \
        -H "Content-Type: application/json")

    http_code=$(echo "$response" | tail -n1 | cut -d':' -f2)
    response_body=$(echo "$response" | head -n -1)

    echo -e "${CYAN}HTTP 狀態碼: $http_code${NC}"

    case "$http_code" in
        "200")
            if echo "$response_body" | grep -q '"site"'; then
                echo -e "${GREEN}✓ API 認證成功${NC}"
                return 0
            else
                echo -e "${RED}✗ 回應格式異常${NC}"
                echo -e "${YELLOW}回應內容: $response_body${NC}"
                return 1
            fi
            ;;
        "401")
            echo -e "${RED}✗ 認證失敗 (401)${NC}"
            echo -e "${YELLOW}可能的原因:${NC}"
            echo "  • API Key 不正確"
            echo "  • JWT token 簽名錯誤"
            echo "  • 系統時間不正確"
            echo -e "${YELLOW}回應: $response_body${NC}"
            return 1
            ;;
        "404")
            echo -e "${RED}✗ API 端點不存在 (404)${NC}"
            echo -e "${YELLOW}請檢查 Ghost 版本是否 >= 2.0${NC}"
            return 1
            ;;
        "000")
            echo -e "${RED}✗ 連線超時或拒絕${NC}"
            echo -e "${YELLOW}請確認 Ghost 正在運行且可訪問${NC}"
            return 1
            ;;
        *)
            echo -e "${RED}✗ 未預期的回應 ($http_code)${NC}"
            echo -e "${YELLOW}回應: $response_body${NC}"
            return 1
            ;;
    esac
}

# 檢查必要工具
check_requirements() {
    echo -e "${BLUE}檢查必要工具...${NC}"

    # 檢查工具
    for tool in curl python3; do
        if ! command -v $tool &> /dev/null; then
            echo -e "${RED}錯誤: $tool 未安裝${NC}"
            exit 1
        fi
    done

    # 檢查 Python 模組
    python3 -c "import hmac, hashlib, base64, json, time" 2>/dev/null || {
        echo -e "${RED}錯誤: Python 缺少必要模組${NC}"
        exit 1
    }

    echo -e "${GREEN}✓ 所有工具檢查通過${NC}"

    # 檢查目錄
    if [ ! -d "$MARKDOWN_DIR" ]; then
        echo -e "${RED}錯誤: 目錄 $MARKDOWN_DIR 不存在${NC}"
        exit 1
    fi

    # 驗證 API Key 格式
    if [[ ! "$GHOST_ADMIN_API_KEY" =~ ^[a-f0-9]{24}:[a-f0-9]{64}$ ]]; then
        echo -e "${RED}錯誤: API Key 格式不正確${NC}"
        echo -e "${YELLOW}正確格式: 24位十六進制ID:64位十六進制Secret${NC}"
        echo -e "${YELLOW}當前格式: ${GHOST_ADMIN_API_KEY}${NC}"
        echo -e "${YELLOW}ID 長度: $(echo "$GHOST_ADMIN_API_KEY" | cut -d':' -f1 | wc -c)${NC}"
        echo -e "${YELLOW}Secret 長度: $(echo "$GHOST_ADMIN_API_KEY" | cut -d':' -f2 | wc -c)${NC}"
        show_api_key_help
        exit 1
    fi

    echo -e "${GREEN}✓ API Key 格式正確${NC}"
}

# 產生基於路徑的 slug
generate_path_based_slug() {
    local file="$1"
    local base_dir="$2"

    # 取得相對路徑
    relative_path=$(realpath --relative-to="$base_dir" "$file" 2>/dev/null || echo "$file")

    # 移除副檔名
    relative_path=$(echo "$relative_path" | sed 's/\.md$//')

    # 使用 Python 處理 URL 友好的 slug 轉換（支援中文）
    python3 << EOF
import re
import sys

path = """$relative_path"""

# 將 / 轉換為 -
slug = path.replace('/', '-')

# 移除或替換特殊字符，保留中文字符
slug = re.sub(r'[^\w\u4e00-\u9fff-]', '-', slug)

# 清理多餘的連字號
slug = re.sub(r'-+', '-', slug)
slug = slug.strip('-')

# 轉換為小寫（只轉換英文字符）
slug = ''.join(c.lower() if c.isascii() else c for c in slug)

print(slug)
EOF
}

# Front Matter 解析函數（增加 slug 支援）
parse_frontmatter() {
    local file="$1"

    # 預設值
    title=$(basename "$file" .md)
    description=""
    tags=""
    status="draft"
    content=""
    slug=""

    # 讀取檔案
    if [ ! -f "$file" ]; then
        echo -e "${RED}錯誤: 檔案 $file 不存在${NC}"
        return 1
    fi

    full_content=$(cat "$file")

    # 檢查是否有 Front Matter
    if echo "$full_content" | head -1 | grep -q "^---$"; then
        # 提取 Front Matter
        front_matter=$(echo "$full_content" | sed -n '2,/^---$/p' | sed '$d')

        # 提取內容（跳過 Front Matter）
        content=$(echo "$full_content" | sed -n '/^---$/{ :a; n; /^---$/!ba; :b; n; p; bb; }')

        # 解析 Front Matter 欄位
        while IFS= read -r line; do
            if echo "$line" | grep -q "^title:"; then
                title=$(echo "$line" | cut -d':' -f2- | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' | sed 's/^["'\'']//' | sed 's/["'\'']$//')
            elif echo "$line" | grep -q "^description:"; then
                description=$(echo "$line" | cut -d':' -f2- | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' | sed 's/^["'\'']//' | sed 's/["'\'']$//')
            elif echo "$line" | grep -q "^published:"; then
                published=$(echo "$line" | cut -d':' -f2- | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
                if [ "$published" = "true" ]; then
                    status="published"
                fi
            elif echo "$line" | grep -q "^tags:"; then
                tags=$(echo "$line" | cut -d':' -f2- | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
            elif echo "$line" | grep -q "^slug:"; then
                slug=$(echo "$line" | cut -d':' -f2- | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' | sed 's/^["'\'']//' | sed 's/["'\'']$//')
            fi
        done <<< "$front_matter"
    else
        content="$full_content"
    fi

    # 如果沒有自訂 slug，則根據檔案路徑產生
    if [ -z "$slug" ] && [ "$USE_PATH_ROUTING" = "true" ]; then
        slug=$(generate_path_based_slug "$file" "$MARKDOWN_DIR")
    fi

    # 清理內容（移除多餘的空行）
    content=$(echo "$content" | sed '/^$/N;/^\n$/d')
}

# 使用 Python 生成 JSON payload（修復 Unicode 轉義問題）
generate_json_payload() {
    local title="$1"
    local content="$2"
    local status="$3"
    local description="$4"
    local tags="$5"
    local slug="$6"

    # 將參數寫入臨時檔案以避免 shell 轉義問題
    local temp_dir="/tmp/ghost_import_$"
    mkdir -p "$temp_dir"

    echo "$title" > "$temp_dir/title.txt"
    echo "$content" > "$temp_dir/content.txt"
    echo "$status" > "$temp_dir/status.txt"
    echo "$description" > "$temp_dir/description.txt"
    echo "$tags" > "$temp_dir/tags.txt"
    echo "$6" > "$temp_dir/slug.txt"  # slug 參數

    # 使用 Python 正確處理 JSON
    python3 << EOF
import json
import sys
import os

temp_dir = "$temp_dir"

# 從檔案讀取參數（避免 shell 轉義問題）
def read_file_safe(filename):
    try:
        with open(filename, 'r', encoding='utf-8') as f:
            return f.read().strip()
    except:
        return ""

title = read_file_safe(os.path.join(temp_dir, "title.txt"))
content = read_file_safe(os.path.join(temp_dir, "content.txt"))
status = read_file_safe(os.path.join(temp_dir, "status.txt"))
description = read_file_safe(os.path.join(temp_dir, "description.txt"))
tags_str = read_file_safe(os.path.join(temp_dir, "tags.txt"))
slug = read_file_safe(os.path.join(temp_dir, "slug.txt"))

# 建立 mobiledoc 格式
mobiledoc = {
    "version": "0.3.1",
    "atoms": [],
    "cards": [["markdown", {"cardName": "markdown", "markdown": content}]],
    "markups": [],
    "sections": [[10, 0]]
}

# 建立 post 物件
post = {
    "title": title,
    "mobiledoc": json.dumps(mobiledoc),
    "status": status
}

# 加入 slug（如果有）
if slug and slug.strip():
    post["slug"] = slug

# 加入描述（如果有）
if description and description.strip():
    post["custom_excerpt"] = description

# 處理標籤（如果有）
if tags_str and tags_str.strip():
    # 簡單處理逗號分隔的標籤
    tag_list = [tag.strip() for tag in tags_str.split(',') if tag.strip()]
    if tag_list:
        post["tags"] = [{"name": tag} for tag in tag_list]

# 建立最終 payload
payload = {"posts": [post]}

# 輸出 JSON（確保正確的 UTF-8 編碼）
try:
    print(json.dumps(payload, ensure_ascii=False, separators=(',', ':')))
except Exception as e:
    print(f"JSON 生成錯誤: {e}", file=sys.stderr)
    sys.exit(1)
finally:
    # 清理臨時檔案
    import shutil
    try:
        shutil.rmtree(temp_dir)
    except:
        pass
EOF

    # 清理臨時檔案（雙重保險）
    rm -rf "$temp_dir" 2>/dev/null
}

# 匯入單個檔案（改進版）
import_file() {
    local file="$1"
    echo -e "${BLUE}處理檔案: $(basename "$file")${NC}"

    # 解析檔案
    if ! parse_frontmatter "$file"; then
        echo -e "${RED}✗ 檔案解析失敗${NC}"
        return 1
    fi

    # 顯示解析結果
    echo -e "${CYAN}  標題: $title${NC}"
    echo -e "${CYAN}  狀態: $status${NC}"
    echo -e "${CYAN}  內容長度: ${#content} 字元${NC}"

    if [ -n "$description" ]; then
        echo -e "${CYAN}  描述: ${description:0:50}...${NC}"
    fi

    if [ -n "$slug" ]; then
        echo -e "${CYAN}  路由 Slug: $slug${NC}"
    fi

    # 生成 JWT Token
    echo -e "${BLUE}  生成 JWT Token...${NC}"
    jwt_token=$(generate_jwt_token "$GHOST_ADMIN_API_KEY")

    if [ $? -ne 0 ] || [ -z "$jwt_token" ]; then
        echo -e "${RED}✗ JWT token 生成失敗${NC}"
        return 1
    fi

    # 生成 JSON payload
    echo -e "${BLUE}  生成 JSON payload...${NC}"
    json_payload=$(generate_json_payload "$title" "$content" "$status" "$description" "$tags" "$slug")

    if [ $? -ne 0 ] || [ -z "$json_payload" ]; then
        echo -e "${RED}✗ JSON payload 生成失敗${NC}"
        return 1
    fi

    # 顯示 payload 大小
    echo -e "${CYAN}  Payload 大小: ${#json_payload} 字元${NC}"

    # 發送 API 請求
    echo -e "${BLUE}  發送 API 請求...${NC}"
    response=$(curl -s -m 30 -w "\nHTTP_CODE:%{http_code}" -X POST "${GHOST_API_URL}/posts/" \
        -H "Authorization: Ghost $jwt_token" \
        -H "Content-Type: application/json; charset=utf-8" \
        -H "Accept-Version: v5.0" \
        -d "$json_payload")

    # 解析回應
    http_code=$(echo "$response" | tail -n1 | cut -d':' -f2)
    response_body=$(echo "$response" | head -n -1)

    # 檢查結果
    case "$http_code" in
        "201")
            echo -e "${GREEN}✓ 成功匯入: $title${NC}"

            # 嘗試提取文章 ID 和 URL
            if command -v python3 &> /dev/null; then
                post_info=$(echo "$response_body" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    if 'posts' in data and len(data['posts']) > 0:
        post = data['posts'][0]
        print(f\"  ID: {post.get('id', 'N/A')}\"  )
        print(f\"  URL: {post.get('url', 'N/A')}\")
except:
    pass
")
                if [ -n "$post_info" ]; then
                    echo -e "${GREEN}$post_info${NC}"
                fi
            fi

            return 0
            ;;
        "200")
            echo -e "${GREEN}✓ 文章已存在，可能已更新: $title${NC}"
            return 0
            ;;
        "422")
            echo -e "${RED}✗ 資料驗證失敗: $title${NC}"
            echo -e "${YELLOW}錯誤: $response_body${NC}"

            # 檢查是否是重複標題
            if echo "$response_body" | grep -q "already exists"; then
                echo -e "${YELLOW}  → 可能是重複的標題${NC}"
            fi
            return 1
            ;;
        "401")
            echo -e "${RED}✗ 認證失敗: $title${NC}"
            echo -e "${YELLOW}  → 請檢查 API Key 是否正確${NC}"
            return 1
            ;;
        *)
            echo -e "${RED}✗ 匯入失敗: $title (HTTP: $http_code)${NC}"
            echo -e "${YELLOW}回應: ${response_body:0:200}...${NC}"
            return 1
            ;;
    esac
}

# API Key 設定說明
show_api_key_help() {
    echo -e "${YELLOW}=== Ghost Admin API Key 設定指南 ===${NC}"
    echo "1. 前往 Ghost Admin: $GHOST_URL/ghost"
    echo "2. 登入後進入 Settings → Integrations"
    echo "3. 點擊 'Add custom integration'"
    echo "4. 輸入名稱（例如：Markdown Import）並儲存"
    echo "5. 複製 Admin API Key"
    echo ""
    echo -e "${BLUE}API Key 格式檢查:${NC}"
    echo "• 正確格式: 24個字元的ID:64個字元的Secret"
    echo "• 範例: 507f1f77bcf86cd799439011:4cc5c681e1d4d3b1e9a64fae7a1f8c6c1234567890abcdef1234567890abcdef"
    echo ""
    echo -e "${BLUE}常見問題:${NC}"
    echo "• 確認複製的是 Admin API Key（不是 Content API Key）"
    echo "• 檢查是否完整複製（沒有遺漏字元）"
    echo "• 確認沒有多餘的空格或換行符"
}

# 顯示使用說明
show_help() {
    echo -e "${BLUE}=== Ghost Markdown 批量匯入工具 ===${NC}"
    echo "使用方法: $0 [選項] [目錄路徑]"
    echo ""
    echo -e "${YELLOW}選項:${NC}"
    echo "  -h, --help              顯示此說明"
    echo "  -u, --url <URL>         設定 Ghost URL (預設: http://localhost:8081)"
    echo "  -k, --key <API_KEY>     設定 Admin API Key"
    echo "  -t, --test              只測試 API 連線"
    echo "  -d, --dry-run           試運行（不實際匯入）"
    echo "  -p, --path-routing      啟用資料夾路徑路由（將資料夾結構轉為文章 URL）"
    echo ""
    echo -e "${YELLOW}範例:${NC}"
    echo "  $0 ./my-posts                    # 匯入 ./my-posts 目錄下的文章"
    echo "  $0 -u http://myblog.com ./posts  # 指定 Ghost URL"
    echo "  $0 -p ./my-posts                 # 啟用路徑路由"
    echo "  $0 -t                            # 只測試連線"
    echo ""
    echo -e "${BLUE}路徑路由範例:${NC}"
    echo "  檔案: ./posts/技術/SSL/自簽憑證.md"
    echo "  產生的 URL: /技術-ssl-自簽憑證/"
    echo ""
    echo "  檔案: ./posts/blog/tutorials/docker-setup.md"
    echo "  產生的 URL: /blog-tutorials-docker-setup/"
}

# 主要函數
main() {
    echo -e "${BLUE}=== Ghost Markdown 批量匯入工具（修復版）===${NC}"
    echo "目標目錄: $MARKDOWN_DIR"
    echo "Ghost URL: $GHOST_URL"
    echo "路徑路由: $(if [ "$USE_PATH_ROUTING" = "true" ]; then echo "啟用"; else echo "停用"; fi)"
    echo ""

    # 檢查必要條件
    check_requirements

    # 測試 API 連線
    if ! test_api_connection; then
        echo -e "${RED}API 連線測試失敗${NC}"
        echo ""
        show_api_key_help
        exit 1
    fi

    echo ""

    # 如果只是測試連線，到此結束
    if [ "$TEST_ONLY" = "true" ]; then
        echo -e "${GREEN}API 測試完成，連線正常！${NC}"
        exit 0
    fi

    # 統計檔案
    total_files=$(find "$MARKDOWN_DIR" -name "*.md" -type f | wc -l)

    if [ "$total_files" -eq 0 ]; then
        echo -e "${YELLOW}在 $MARKDOWN_DIR 中沒有找到 .md 檔案${NC}"
        exit 0
    fi

    echo -e "${BLUE}找到 $total_files 個 Markdown 檔案${NC}"

    if [ "$USE_PATH_ROUTING" = "true" ]; then
        echo -e "${YELLOW}🔗 路徑路由已啟用 - 資料夾結構將轉換為文章 URL${NC}"
    fi

    if [ "$DRY_RUN" = "true" ]; then
        echo -e "${YELLOW}=== 試運行模式 - 不會實際匯入 ===${NC}"
    fi

    echo ""

    # 初始化計數器
    imported_count=0
    failed_count=0

    # 處理所有檔案
    while IFS= read -r -d '' file; do
        if [ "$DRY_RUN" = "true" ]; then
            echo -e "${YELLOW}[試運行] 處理檔案: $(basename "$file")${NC}"
            parse_frontmatter "$file"
            echo -e "${CYAN}  標題: $title${NC}"
            echo -e "${CYAN}  狀態: $status${NC}"
            if [ -n "$slug" ]; then
                echo -e "${CYAN}  路由 Slug: $slug${NC}"
            fi
            imported_count=$((imported_count + 1))
        else
            if import_file "$file"; then
                imported_count=$((imported_count + 1))
            else
                failed_count=$((failed_count + 1))
            fi
        fi
        echo ""
    done < <(find "$MARKDOWN_DIR" -name "*.md" -type f -print0)

    # 顯示最終結果
    echo -e "${BLUE}=== 匯入完成 ===${NC}"
    echo "總檔案數: $total_files"
    echo -e "${GREEN}成功匯入: $imported_count${NC}"
    if [ "$failed_count" -gt 0 ]; then
        echo -e "${RED}匯入失敗: $failed_count${NC}"
    fi

    if [ "$DRY_RUN" = "true" ]; then
        echo -e "${YELLOW}這是試運行結果，沒有實際匯入任何檔案${NC}"
        echo -e "${BLUE}如要實際匯入，請移除 --dry-run 參數${NC}"
    fi
}

# 處理命令列參數
DRY_RUN="false"
TEST_ONLY="false"

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -u|--url)
            GHOST_URL="$2"
            GHOST_API_URL="${GHOST_URL}/ghost/api/admin"
            shift 2
            ;;
        -k|--key)
            GHOST_ADMIN_API_KEY="$2"
            shift 2
            ;;
        -t|--test)
            TEST_ONLY="true"
            shift
            ;;
        -d|--dry-run)
            DRY_RUN="true"
            shift
            ;;
        -p|--path-routing)
            USE_PATH_ROUTING="true"
            shift
            ;;
        *)
            MARKDOWN_DIR="$1"
            shift
            ;;
    esac
done

# 執行主程式
main
