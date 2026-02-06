#!/bin/bash

# ==========================================
# Ralph Loop V7.2: 项目初始化版
# ==========================================
# 新功能:
# 1. 自动下载 ralph-claude-code 模板
# 2. 检测并安装 Superpowers
# 3. 支持新项目/已有项目 clone
# 4. 项目类型选择和配置
# ==========================================

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# 当前脚本所在目录 (模板根目录)
TEMPLATE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}══════════════════════════════════════════${NC}"
echo -e "${BLUE}🔧 Ralph Loop V7.2: 项目初始化版${NC}"
echo -e "${BLUE}══════════════════════════════════════════${NC}"

# ==========================================
# 系统检查: 仅支持 Linux
# ==========================================
if [[ "$(uname)" != "Linux" ]]; then
    echo -e "${RED}❌ 此脚本仅支持 Linux 系统${NC}"
    echo -e "${YELLOW}   检测到: $(uname)${NC}"
    exit 1
fi

# ==========================================
# Step 0: 依赖检查
# ==========================================
echo -e "\n${YELLOW}[Step 0] 检查依赖...${NC}"

detect_os() {
    if command -v brew &> /dev/null; then
        echo "brew"
    elif command -v apt-get &> /dev/null; then
        echo "apt"
    else
        echo "unknown"
    fi
}

install_with_apt() {
    local pkg="$1"
    if command -v sudo &> /dev/null; then
        sudo apt-get update -y
        sudo apt-get install -y "$pkg"
    else
        apt-get update -y
        apt-get install -y "$pkg"
    fi
}

install_with_brew() {
    local pkg="$1"
    brew install "$pkg"
}

check_dependency() {
    if ! command -v "$1" &> /dev/null; then
        echo -e "${YELLOW}⚠️ 缺少依赖: $1，尝试自动安装...${NC}"
        local os_manager
        os_manager=$(detect_os)
        case "$1" in
            jq)
                if [ "$os_manager" = "brew" ]; then
                    install_with_brew jq
                elif [ "$os_manager" = "apt" ]; then
                    install_with_apt jq
                else
                    echo -e "${RED}❌ 无法自动安装 jq，请手动安装${NC}"
                    exit 1
                fi
                ;;
            git)
                if [ "$os_manager" = "brew" ]; then
                    install_with_brew git
                elif [ "$os_manager" = "apt" ]; then
                    install_with_apt git
                else
                    echo -e "${RED}❌ 无法自动安装 git，请手动安装${NC}"
                    exit 1
                fi
                ;;
            python3)
                if [ "$os_manager" = "brew" ]; then
                    install_with_brew python
                elif [ "$os_manager" = "apt" ]; then
                    install_with_apt python3
                    install_with_apt python3-pip
                else
                    echo -e "${RED}❌ 无法自动安装 python3，请手动安装${NC}"
                    exit 1
                fi
                ;;
            npx)
                if [ "$os_manager" = "brew" ]; then
                    install_with_brew node
                elif [ "$os_manager" = "apt" ]; then
                    install_with_apt nodejs
                    install_with_apt npm
                else
                    echo -e "${RED}❌ 无法自动安装 npx，请手动安装${NC}"
                    exit 1
                fi
                if ! command -v npx &> /dev/null; then
                    npm install -g npx
                fi
                ;;
            npm)
                if [ "$os_manager" = "brew" ]; then
                    install_with_brew node
                elif [ "$os_manager" = "apt" ]; then
                    install_with_apt nodejs
                    install_with_apt npm
                else
                    echo -e "${RED}❌ 无法自动安装 npm，请手动安装${NC}"
                    exit 1
                fi
                ;;
            claude)
                if ! command -v npm &> /dev/null; then
                    echo -e "${YELLOW}⚠️ 未检测到 npm，尝试安装 Node.js...${NC}"
                    if [ "$os_manager" = "brew" ]; then
                        install_with_brew node
                    elif [ "$os_manager" = "apt" ]; then
                        install_with_apt nodejs
                        install_with_apt npm
                    else
                        echo -e "${RED}❌ 无法自动安装 npm，请手动安装${NC}"
                        exit 1
                    fi
                fi
                # 检查 Node 版本 (需要 >= 18)
                if command -v node &> /dev/null; then
                    NODE_MAJOR=$(node -v | sed 's/^v//' | cut -d. -f1)
                    if [ -z "$NODE_MAJOR" ] || [ "$NODE_MAJOR" -lt 18 ]; then
                        echo -e "${YELLOW}⚠️ Node.js 版本过低 (当前: $(node -v)). 需要 >= 18${NC}"
                        exit 1
                    fi
                fi
                npm install -g @anthropic-ai/claude-code@2.076
                ;;
            uvx)
                if command -v pipx &> /dev/null; then
                    pipx install uv
                elif command -v apt-get &> /dev/null; then
                    if command -v sudo &> /dev/null; then
                        sudo apt-get update -y
                        sudo apt-get install -y pipx
                    else
                        apt-get update -y
                        apt-get install -y pipx
                    fi
                    pipx ensurepath 2>/dev/null || true
                    export PATH="$HOME/.local/bin:$PATH"
                    pipx install uv
                else
                    if command -v pip3 &> /dev/null; then
                        pip3 install --break-system-packages uv
                    else
                        echo -e "${RED}❌ 无法安装 uv，请手动安装: pipx install uv${NC}"
                        exit 1
                    fi
                fi
                export PATH="$HOME/.local/bin:$PATH"
                ;;
            *)
                echo -e "${RED}❌ 未知依赖: $1${NC}"
                exit 1
                ;;
        esac
        if ! command -v "$1" &> /dev/null; then
            echo -e "${RED}❌ 自动安装失败: $1${NC}"
            exit 1
        fi
    fi
    echo -e "${GREEN}✓ $1${NC}"
}

check_dependency "git" "apt install git"
check_dependency "jq" "apt install jq"
check_dependency "python3" "apt install python3"
check_dependency "npm" "apt install npm"
check_dependency "npx" "npm install -g npx"
check_dependency "claude" "npm install -g @anthropic-ai/claude-code"
check_dependency "uvx" "pip install uv"

prompt_yes_no() {
    local prompt="$1"
    local default="${2:-n}"
    local response
    if [ "$default" = "y" ]; then
        read -p "$prompt [Y/n]: " response
        response="${response:-y}"
    else
        read -p "$prompt [y/N]: " response
        response="${response:-n}"
    fi
    [[ "$response" =~ ^[Yy]$ ]]
}

should_overwrite_file() {
    local file="$1"
    if [ -f "$file" ]; then
        if ! prompt_yes_no "检测到 $file 已存在，是否覆盖?" "n"; then
            echo -e "${YELLOW}⏭️ 已跳过 $file${NC}"
            return 1
        fi
    fi
    return 0
}

detect_package_manager() {
    if [ -f "pnpm-lock.yaml" ]; then
        echo "pnpm"
    elif [ -f "yarn.lock" ]; then
        echo "yarn"
    elif [ -f "package-lock.json" ]; then
        echo "npm"
    else
        echo "npm"
    fi
}

ensure_command() {
    local cmd="$1"
    local apt_pkg="$2"
    local brew_pkg="$3"
    if command -v "$cmd" &> /dev/null; then
        return 0
    fi
    echo -e "${YELLOW}⚠️ 未检测到 $cmd${NC}"
    if ! prompt_yes_no "是否尝试安装 $cmd?" "y"; then
        return 1
    fi
    local os_manager
    os_manager=$(detect_os)
    # pnpm 在 apt 上没有包，需要通过 npm 安装
    if [ "$cmd" = "pnpm" ] && [ "$os_manager" = "apt" ]; then
        if ! command -v npm &> /dev/null; then
            echo -e "${YELLOW}⚠️ 需要先安装 npm...${NC}"
            install_with_apt nodejs
            install_with_apt npm
        fi
        npm install -g pnpm
    elif [ "$os_manager" = "apt" ] && [ -n "$apt_pkg" ]; then
        install_with_apt "$apt_pkg"
    elif [ "$os_manager" = "brew" ] && [ -n "$brew_pkg" ]; then
        install_with_brew "$brew_pkg"
    else
        echo -e "${RED}❌ 无法自动安装 $cmd，请手动安装${NC}"
        return 1
    fi
    command -v "$cmd" &> /dev/null
}

append_line_if_missing() {
    local file="$1"
    local line="$2"
    touch "$file"
    grep -Fqx "$line" "$file" 2>/dev/null || echo "$line" >> "$file"
}

ensure_dir() {
    local dir="$1"
    [ -z "$dir" ] && return 0
    mkdir -p "$dir"
}

init_package_json() {
    if [ -f "package.json" ]; then
        return 0
    fi

    local project_name
    project_name=$(basename "$PWD" | tr ' ' '-' )

    if [ -f "README.md" ]; then
        if prompt_yes_no "检测到 README.md 已存在，是否运行 npm init -y（可能覆盖 README.md）?" "n"; then
            npm init -y
        else
            cat << EOF > package.json
{
  "name": "${project_name}",
  "version": "0.1.0",
  "private": true
}
EOF
            echo -e "${GREEN}✓ 已创建 package.json（未覆盖 README.md）${NC}"
        fi
    else
        npm init -y
    fi
}

add_pkg_script_if_missing() {
    local key="$1"
    local value="$2"
    if [ ! -f "package.json" ]; then
        return 0
    fi
    jq --arg k "$key" --arg v "$value" \
        '.scripts = (.scripts // {}) | if .scripts[$k] then . else .scripts[$k] = $v end' \
        package.json > package.json.tmp && mv package.json.tmp package.json
}

has_pkg_dep() {
    local name="$1"
    if [ ! -f "package.json" ]; then
        return 1
    fi
    jq -e --arg n "$name" '.dependencies[$n] or .devDependencies[$n]' package.json >/dev/null 2>&1
}

has_python_req() {
    local name="$1"
    if [ -f "requirements.txt" ] && grep -Eq "^${name}([=<>!]|$)" requirements.txt 2>/dev/null; then
        return 0
    fi
    if [ -f "pyproject.toml" ] && grep -Eq "${name}" pyproject.toml 2>/dev/null; then
        return 0
    fi
    return 1
}

set_pkg_field_if_missing() {
    local key="$1"
    local value="$2"
    if [ ! -f "package.json" ]; then
        return 0
    fi
    jq --arg k "$key" --arg v "$value" \
        'if .[$k] then . else .[$k] = $v end' \
        package.json > package.json.tmp && mv package.json.tmp package.json
}

install_node_dependencies() {
    local manager
    manager=$(detect_package_manager)
    case "$manager" in
        pnpm)
            if ensure_command "pnpm" "pnpm" "pnpm"; then
                pnpm install
            fi
            ;;
        yarn)
            if ensure_command "yarn" "yarn" "yarn"; then
                yarn install
            fi
            ;;
        *)
            npm install
            ;;
    esac
}

install_playwright() {
    local manager
    manager=$(detect_package_manager)
    case "$manager" in
        pnpm)
            if ensure_command "pnpm" "pnpm" "pnpm"; then
                pnpm add -D @playwright/test
            fi
            ;;
        yarn)
            if ensure_command "yarn" "yarn" "yarn"; then
                yarn add -D @playwright/test
            fi
            ;;
        *)
            npm install -D @playwright/test
            ;;
    esac
    npx playwright install --with-deps 2>/dev/null || npx playwright install
}

# Configure E2E framework with database and OSS verification helpers
configure_e2e_framework() {
    local frontend_path="${1:-.}"
    local has_mysql="$2"
    local has_oss="$3"
    
    echo -e "${BLUE}配置 E2E 测试框架...${NC}"
    
    local test_dir="$frontend_path/tests/e2e"
    local helpers_dir="$test_dir/helpers"
    mkdir -p "$helpers_dir"
    
    # Install additional dependencies based on project needs
    local manager
    manager=$(detect_package_manager)
    local deps_to_install="dotenv"
    
    if [ "$has_mysql" = "yes" ]; then
        deps_to_install="$deps_to_install mysql2"
    fi
    if [ "$has_oss" = "yes" ]; then
        # Check if ali-oss is already installed
        if ! has_pkg_dep "ali-oss"; then
            deps_to_install="$deps_to_install ali-oss"
        fi
    fi
    
    if [ -n "$deps_to_install" ]; then
        echo -e "${BLUE}安装 E2E 辅助依赖: $deps_to_install${NC}"
        case "$manager" in
            pnpm) pnpm add -D $deps_to_install ;;
            yarn) yarn add -D $deps_to_install ;;
            *) npm install -D $deps_to_install ;;
        esac
    fi
    
    # Create database helper if MySQL is used
    if [ "$has_mysql" = "yes" ]; then
        create_db_helper "$helpers_dir"
    fi
    
    # Create OSS helper if OSS is used
    if [ "$has_oss" = "yes" ]; then
        create_oss_helper "$helpers_dir"
    fi
    
    # Create auth helper for test user management
    create_auth_helper "$helpers_dir"
    
    # Create .env.test.example
    create_env_test_example "$frontend_path" "$has_mysql" "$has_oss"
    
    # Update playwright.config.ts with global setup/teardown
    update_playwright_config "$frontend_path" "$has_mysql" "$has_oss"
    
    echo -e "${GREEN}✓ E2E 测试框架配置完成${NC}"
    echo -e "${YELLOW}提示: 请复制 .env.test.example 为 .env.test 并填写实际值${NC}"
}

create_db_helper() {
    local helpers_dir="$1"
    local target_file="$helpers_dir/db.ts"
    if ! should_overwrite_file "$target_file"; then
        return 0
    fi
    cat << 'EOF' > "$target_file"
/**
 * Database helper for E2E tests
 * Provides direct MySQL connection for data verification and cleanup
 */
import mysql, { Pool, RowDataPacket, ResultSetHeader } from 'mysql2/promise';
import * as dotenv from 'dotenv';
import * as path from 'path';

// Load test environment
dotenv.config({ path: path.resolve(__dirname, '../../.env.test') });

let pool: Pool | null = null;

export interface DatabaseConfig {
  host: string;
  port: number;
  user: string;
  password: string;
  database: string;
}

export function getDbConfig(): DatabaseConfig {
  return {
    host: process.env.TEST_DB_HOST || 'localhost',
    port: parseInt(process.env.TEST_DB_PORT || '3306'),
    user: process.env.TEST_DB_USER || 'root',
    password: process.env.TEST_DB_PASSWORD || '',
    database: process.env.TEST_DB_NAME || 'test_db',
  };
}

export async function getConnection(): Promise<Pool> {
  if (!pool) {
    pool = mysql.createPool({
      ...getDbConfig(),
      waitForConnections: true,
      connectionLimit: 5,
      queueLimit: 0,
    });
  }
  return pool;
}

export async function closeConnection(): Promise<void> {
  if (pool) {
    await pool.end();
    pool = null;
  }
}

/**
 * Query the database and return typed results
 */
export async function query<T extends RowDataPacket[]>(
  sql: string,
  params?: (string | number | boolean | null)[]
): Promise<T> {
  const conn = await getConnection();
  const [rows] = await conn.query<T>(sql, params);
  return rows;
}

/**
 * Execute a statement (INSERT, UPDATE, DELETE) and return result
 */
export async function execute(
  sql: string,
  params?: (string | number | boolean | null)[]
): Promise<ResultSetHeader> {
  const conn = await getConnection();
  const [result] = await conn.execute<ResultSetHeader>(sql, params);
  return result;
}

/**
 * Verify a record exists in the database
 */
export async function verifyRecordExists(
  table: string,
  conditions: Record<string, string | number | boolean | null>
): Promise<boolean> {
  const keys = Object.keys(conditions);
  const where = keys.map((k) => `\`${k}\` = ?`).join(' AND ');
  const values = Object.values(conditions);
  
  const rows = await query(
    `SELECT 1 FROM \`${table}\` WHERE ${where} LIMIT 1`,
    values
  );
  return rows.length > 0;
}

/**
 * Get a record from the database
 */
export async function getRecord<T extends RowDataPacket>(
  table: string,
  conditions: Record<string, string | number | boolean | null>
): Promise<T | null> {
  const keys = Object.keys(conditions);
  const where = keys.map((k) => `\`${k}\` = ?`).join(' AND ');
  const values = Object.values(conditions);
  
  const rows = await query<T[]>(
    `SELECT * FROM \`${table}\` WHERE ${where} LIMIT 1`,
    values
  );
  return rows[0] || null;
}

/**
 * Delete test records (for cleanup)
 * Use with caution - only for test data cleanup
 */
export async function deleteTestRecords(
  table: string,
  conditions: Record<string, string | number | boolean | null>
): Promise<number> {
  const keys = Object.keys(conditions);
  const where = keys.map((k) => `\`${k}\` = ?`).join(' AND ');
  const values = Object.values(conditions);
  
  const result = await execute(
    `DELETE FROM \`${table}\` WHERE ${where}`,
    values
  );
  return result.affectedRows;
}

/**
 * Cleanup test data by prefix (for test isolation)
 */
export async function cleanupByPrefix(
  table: string,
  column: string,
  prefix: string
): Promise<number> {
  const result = await execute(
    `DELETE FROM \`${table}\` WHERE \`${column}\` LIKE ?`,
    [`${prefix}%`]
  );
  return result.affectedRows;
}
EOF
    echo -e "${GREEN}✓ 创建 $helpers_dir/db.ts${NC}"
}

create_oss_helper() {
    local helpers_dir="$1"
    local target_file="$helpers_dir/oss.ts"
    if ! should_overwrite_file "$target_file"; then
        return 0
    fi
    cat << 'EOF' > "$target_file"
/**
 * OSS helper for E2E tests
 * Provides Alibaba OSS operations for file upload verification and cleanup
 */
import OSS from 'ali-oss';
import * as dotenv from 'dotenv';
import * as path from 'path';

// Load test environment
dotenv.config({ path: path.resolve(__dirname, '../../.env.test') });

let client: OSS | null = null;

export interface OSSConfig {
  region: string;
  accessKeyId: string;
  accessKeySecret: string;
  bucket: string;
  endpoint?: string;
}

export function getOSSConfig(): OSSConfig {
  return {
    region: process.env.TEST_OSS_REGION || 'oss-cn-hangzhou',
    accessKeyId: process.env.TEST_OSS_ACCESS_KEY_ID || '',
    accessKeySecret: process.env.TEST_OSS_ACCESS_KEY_SECRET || '',
    bucket: process.env.TEST_OSS_BUCKET || '',
    endpoint: process.env.TEST_OSS_ENDPOINT,
  };
}

export function getOSSClient(): OSS {
  if (!client) {
    const config = getOSSConfig();
    client = new OSS({
      region: config.region,
      accessKeyId: config.accessKeyId,
      accessKeySecret: config.accessKeySecret,
      bucket: config.bucket,
      endpoint: config.endpoint,
    });
  }
  return client;
}

/**
 * Verify a file exists in OSS
 */
export async function verifyFileExists(objectKey: string): Promise<boolean> {
  try {
    const ossClient = getOSSClient();
    await ossClient.head(objectKey);
    return true;
  } catch (error: unknown) {
    const e = error as { code?: string };
    if (e.code === 'NoSuchKey') {
      return false;
    }
    throw error;
  }
}

/**
 * Get file metadata from OSS
 */
export async function getFileMeta(objectKey: string): Promise<{
  size: number;
  contentType: string;
  lastModified: Date;
  etag: string;
} | null> {
  try {
    const ossClient = getOSSClient();
    const result = await ossClient.head(objectKey);
    return {
      size: parseInt(result.res.headers['content-length'] as string || '0'),
      contentType: result.res.headers['content-type'] as string || '',
      lastModified: new Date(result.res.headers['last-modified'] as string || ''),
      etag: result.res.headers['etag'] as string || '',
    };
  } catch (error: unknown) {
    const e = error as { code?: string };
    if (e.code === 'NoSuchKey') {
      return null;
    }
    throw error;
  }
}

/**
 * Delete a file from OSS (for cleanup)
 */
export async function deleteFile(objectKey: string): Promise<boolean> {
  try {
    const ossClient = getOSSClient();
    await ossClient.delete(objectKey);
    return true;
  } catch (error: unknown) {
    const e = error as { code?: string };
    if (e.code === 'NoSuchKey') {
      return false;
    }
    throw error;
  }
}

/**
 * Delete multiple files by prefix (for test cleanup)
 */
export async function deleteByPrefix(prefix: string): Promise<number> {
  const ossClient = getOSSClient();
  let deleted = 0;
  let continuationToken: string | undefined;
  
  do {
    const listResult = await ossClient.listV2({
      prefix,
      'max-keys': 1000,
      'continuation-token': continuationToken,
    });
    
    const objects = listResult.objects || [];
    if (objects.length > 0) {
      const keys = objects.map((obj) => obj.name);
      await ossClient.deleteMulti(keys, { quiet: true });
      deleted += keys.length;
    }
    
    continuationToken = listResult.nextContinuationToken;
  } while (continuationToken);
  
  return deleted;
}

/**
 * List files with a prefix
 */
export async function listFiles(prefix: string, maxKeys = 100): Promise<string[]> {
  const ossClient = getOSSClient();
  const result = await ossClient.listV2({
    prefix,
    'max-keys': maxKeys,
  });
  
  return (result.objects || []).map((obj) => obj.name);
}
EOF
    echo -e "${GREEN}✓ 创建 $helpers_dir/oss.ts${NC}"
}

create_auth_helper() {
    local helpers_dir="$1"
    local target_file="$helpers_dir/auth.ts"
    if ! should_overwrite_file "$target_file"; then
        return 0
    fi
    cat << 'EOF' > "$target_file"
/**
 * Auth helper for E2E tests
 * Provides test user authentication utilities
 */
import { Page } from '@playwright/test';
import * as dotenv from 'dotenv';
import * as path from 'path';

// Load test environment
dotenv.config({ path: path.resolve(__dirname, '../../.env.test') });

export interface TestUser {
  username: string;
  password: string;
  email?: string;
}

export function getTestUser(): TestUser {
  return {
    username: process.env.TEST_USER_USERNAME || 'test_e2e_user',
    password: process.env.TEST_USER_PASSWORD || 'test_password',
    email: process.env.TEST_USER_EMAIL,
  };
}

export function getTestApiBaseUrl(): string {
  return process.env.TEST_API_BASE_URL || 'http://localhost:8000';
}

/**
 * Login via UI
 * Customize this function based on your login page structure
 */
export async function loginViaUI(page: Page, user?: TestUser): Promise<void> {
  const { username, password } = user || getTestUser();
  
  // Navigate to login page
  await page.goto('/login');
  
  // Fill login form - adjust selectors based on your UI
  await page.fill('input[name="username"], input[type="text"]', username);
  await page.fill('input[name="password"], input[type="password"]', password);
  
  // Submit login
  await page.click('button[type="submit"]');
  
  // Wait for navigation after login
  await page.waitForURL('**/*', { timeout: 10000 });
}

/**
 * Login via API and set cookies/tokens
 */
export async function loginViaAPI(page: Page, user?: TestUser): Promise<string> {
  const { username, password } = user || getTestUser();
  const apiBaseUrl = getTestApiBaseUrl();
  
  // Make API login request
  const response = await page.request.post(`${apiBaseUrl}/api/v1/auth/login`, {
    form: {
      username,
      password,
    },
  });
  
  if (!response.ok()) {
    throw new Error(`Login failed: ${response.status()}`);
  }
  
  const data = await response.json();
  const token = data.access_token;
  
  // Store token in localStorage or as cookie based on your auth mechanism
  await page.evaluate((t) => {
    localStorage.setItem('access_token', t);
  }, token);
  
  return token;
}

/**
 * Logout the current user
 */
export async function logout(page: Page): Promise<void> {
  await page.evaluate(() => {
    localStorage.removeItem('access_token');
  });
  await page.context().clearCookies();
}

/**
 * Generate a unique test identifier
 * Use this for test data isolation
 */
export function generateTestId(prefix = 'e2e'): string {
  const timestamp = Date.now();
  const random = Math.random().toString(36).substring(2, 8);
  return `${prefix}_${timestamp}_${random}`;
}
EOF
    echo -e "${GREEN}✓ 创建 $helpers_dir/auth.ts${NC}"
}

create_env_test_example() {
    local frontend_path="$1"
    local has_mysql="$2"
    local has_oss="$3"
    local target_file="$frontend_path/.env.test.example"
    if ! should_overwrite_file "$target_file"; then
        return 0
    fi
    
    cat << 'EOF' > "$target_file"
# E2E Test Environment Configuration
# Copy this file to .env.test and fill in actual values

# Test API Base URL
TEST_API_BASE_URL=http://localhost:8000

# Test User Credentials (create a dedicated test user)
TEST_USER_USERNAME=test_e2e_user
TEST_USER_PASSWORD=test_password
TEST_USER_EMAIL=test@example.com

EOF

    if [ "$has_mysql" = "yes" ]; then
        cat << 'EOF' >> "$target_file"
# MySQL Database Configuration (for direct verification)
TEST_DB_HOST=localhost
TEST_DB_PORT=3306
TEST_DB_USER=root
TEST_DB_PASSWORD=
TEST_DB_NAME=factory_explorer_test

EOF
    fi
    
    if [ "$has_oss" = "yes" ]; then
        cat << 'EOF' >> "$target_file"
# Alibaba OSS Configuration (for upload verification)
TEST_OSS_REGION=oss-cn-hangzhou
TEST_OSS_ACCESS_KEY_ID=
TEST_OSS_ACCESS_KEY_SECRET=
TEST_OSS_BUCKET=
TEST_OSS_ENDPOINT=

EOF
    fi
    
    echo -e "${GREEN}✓ 创建 $target_file${NC}"
}

update_playwright_config() {
    local frontend_path="$1"
    local has_mysql="$2"
    local has_oss="$3"
    local config_file="$frontend_path/playwright.config.ts"
    local manager
    local web_command
    manager=$(detect_package_manager)
    case "$manager" in
        pnpm) web_command="pnpm dev" ;;
        yarn) web_command="yarn dev" ;;
        *) web_command="npm run dev" ;;
    esac
    
    local allow_config_update=true
    if [ -f "$config_file" ]; then
        if ! prompt_yes_no "检测到 $config_file 已存在，是否覆盖?" "n"; then
            echo -e "${YELLOW}⏭️ 已跳过 $config_file${NC}"
            allow_config_update=false
        fi
    fi

    # If playwright config doesn't exist, create a basic one
    if [ "$allow_config_update" = true ] && [ ! -f "$config_file" ]; then
        cat << 'EOF' > "$config_file"
import { defineConfig, devices } from '@playwright/test';
import * as dotenv from 'dotenv';
import * as path from 'path';

// Load test environment
dotenv.config({ path: path.resolve(__dirname, '.env.test') });

export default defineConfig({
  testDir: './tests/e2e',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: 'html',
  
  globalSetup: './tests/e2e/global-setup.ts',
  globalTeardown: './tests/e2e/global-teardown.ts',
  
  use: {
    baseURL: process.env.TEST_BASE_URL || 'http://localhost:3000',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
  },

  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],

  webServer: {
        command: '__WEB_COMMAND__',
    url: 'http://localhost:3000',
    reuseExistingServer: !process.env.CI,
    timeout: 120 * 1000,
  },
});
EOF
                sed -i "s|__WEB_COMMAND__|${web_command}|" "$config_file"
        echo -e "${GREEN}✓ 创建 $config_file${NC}"
        else
            if [ "$allow_config_update" = true ]; then
                if grep -q "command: 'pnpm dev'" "$config_file" || grep -q 'command: "pnpm dev"' "$config_file"; then
                    if [ "$manager" != "pnpm" ]; then
                        sed -i "s/command: 'pnpm dev'/command: '${web_command//\//\\/}'/" "$config_file"
                        sed -i "s/command: \"pnpm dev\"/command: \"${web_command//\//\\/}\"/" "$config_file"
                    fi
                fi
                if ! grep -q "globalSetup:" "$config_file" || ! grep -q "globalTeardown:" "$config_file"; then
                    awk -v add_setup="$(grep -q "globalSetup:" "$config_file" && echo 0 || echo 1)" \
                        -v add_teardown="$(grep -q "globalTeardown:" "$config_file" && echo 0 || echo 1)" \
                        'BEGIN{inserted=0}
                        /^[ \t]*reporter:/ && !inserted {print; if (add_setup==1) print "  globalSetup: '\''./tests/e2e/global-setup.ts'\'',"; if (add_teardown==1) print "  globalTeardown: '\''./tests/e2e/global-teardown.ts'\'',"; inserted=1; next}
                        /^[ \t]*workers:/ && !inserted {print; if (add_setup==1) print "  globalSetup: '\''./tests/e2e/global-setup.ts'\'',"; if (add_teardown==1) print "  globalTeardown: '\''./tests/e2e/global-teardown.ts'\'',"; inserted=1; next}
                        /^[ \t]*retries:/ && !inserted {print; if (add_setup==1) print "  globalSetup: '\''./tests/e2e/global-setup.ts'\'',"; if (add_teardown==1) print "  globalTeardown: '\''./tests/e2e/global-teardown.ts'\'',"; inserted=1; next}
                        /^[ \t]*fullyParallel:/ && !inserted {print; if (add_setup==1) print "  globalSetup: '\''./tests/e2e/global-setup.ts'\'',"; if (add_teardown==1) print "  globalTeardown: '\''./tests/e2e/global-teardown.ts'\'',"; inserted=1; next}
                        {print}' "$config_file" > "$config_file.tmp" && mv "$config_file.tmp" "$config_file"
                fi
            fi
        fi
    
    # Create global setup file
    local setup_file="$frontend_path/tests/e2e/global-setup.ts"
    if should_overwrite_file "$setup_file"; then
        cat << 'EOF' > "$setup_file"
/**
 * Global setup for E2E tests
 * Runs once before all tests
 */
import * as dotenv from 'dotenv';
import * as path from 'path';

// Load test environment
dotenv.config({ path: path.resolve(__dirname, '../../.env.test') });

async function globalSetup() {
  console.log('\\n🚀 E2E Test Suite Starting...');
  console.log(`   API Base URL: ${process.env.TEST_API_BASE_URL || 'http://localhost:8000'}`);
  console.log(`   Frontend URL: ${process.env.TEST_BASE_URL || 'http://localhost:3000'}`);
  
  // Add any global setup logic here:
  // - Seed test database
  // - Create test user
  // - Setup test fixtures
}

export default globalSetup;
EOF
    fi
    
        # Create global teardown file
        if [ "$has_mysql" = "yes" ]; then
            local teardown_file="$frontend_path/tests/e2e/global-teardown.ts"
            if should_overwrite_file "$teardown_file"; then
                cat << 'EOF' > "$teardown_file"
/**
 * Global teardown for E2E tests
 * Runs once after all tests complete
 */
import { closeConnection, cleanupByPrefix } from './helpers/db';

async function globalTeardown() {
    console.log('\\n🧹 E2E Test Suite Cleanup...');
  
    try {
        // Cleanup test data created during tests
        // Uncomment and customize based on your tables
        // await cleanupByPrefix('users', 'username', 'e2e_');
        // await cleanupByPrefix('products', 'name', 'e2e_');
    
        console.log('   ✓ Test data cleaned up');
    } catch (error) {
        console.error('   ⚠ Cleanup error:', error);
    } finally {
        await closeConnection();
        console.log('   ✓ Database connection closed');
    }
  
    console.log('✅ E2E Test Suite Complete\\n');
}

export default globalTeardown;
EOF
        fi
        else
        local teardown_file="$frontend_path/tests/e2e/global-teardown.ts"
        if should_overwrite_file "$teardown_file"; then
            cat << 'EOF' > "$teardown_file"
/**
 * Global teardown for E2E tests
 * Runs once after all tests complete
 */
async function globalTeardown() {
    console.log('\\n🧹 E2E Test Suite Cleanup...');
    console.log('✅ E2E Test Suite Complete\\n');
}

export default globalTeardown;
EOF
        fi
        fi
    
    # Create example test file
    if [ "$has_mysql" = "yes" ]; then
        local example_file="$frontend_path/tests/e2e/example-with-verification.spec.ts"
        if should_overwrite_file "$example_file"; then
            cat << 'EOF' > "$example_file"
/**
 * Example E2E test with database and OSS verification
 * Demonstrates the testing pattern: UI action -> DB verify -> OSS verify -> Cleanup
 */
import { test, expect } from '@playwright/test';
import { loginViaUI, generateTestId, getTestUser } from './helpers/auth';
import { verifyRecordExists, getRecord, deleteTestRecords } from './helpers/db';
// import { verifyFileExists, deleteFile } from './helpers/oss';

// Test data for this test suite
const TEST_PREFIX = 'e2e_example';

test.describe('Example with Verification', () => {
  // Unique ID for test isolation
  let testId: string;
  
  test.beforeEach(async ({ page }) => {
    // Generate unique test ID for this test run
    testId = generateTestId(TEST_PREFIX);
    
    // Login before each test
    // await loginViaUI(page);
  });
  
  test.afterEach(async () => {
    // Cleanup test data after each test
    // Uncomment and customize based on your data model
    // await deleteTestRecords('your_table', { name: testId });
  });

  test('homepage loads correctly', async ({ page }) => {
    await page.goto('/');
    await expect(page).toHaveTitle(/.*/, { timeout: 10000 });
  });

  test.skip('submit form and verify in database', async ({ page }) => {
    // 1. Navigate to form page
    await page.goto('/your-form-page');
    
    // 2. Fill and submit form
    await page.fill('input[name="name"]', testId);
    await page.fill('input[name="description"]', 'Test description');
    await page.click('button[type="submit"]');
    
    // 3. Wait for success indicator
    await expect(page.locator('.success-message')).toBeVisible();
    
    // 4. Verify data was written to database
    const exists = await verifyRecordExists('your_table', { name: testId });
    expect(exists).toBe(true);
    
    // 5. Optionally get and verify record details
    const record = await getRecord('your_table', { name: testId });
    expect(record).not.toBeNull();
    expect(record?.description).toBe('Test description');
  });

  test.skip('upload file and verify in OSS', async ({ page }) => {
    // 1. Navigate to upload page
    await page.goto('/upload');
    
    // 2. Upload file
    const fileInput = page.locator('input[type="file"]');
    await fileInput.setInputFiles({
      name: `${testId}.txt`,
      mimeType: 'text/plain',
      buffer: Buffer.from('Test file content'),
    });
    
    // 3. Submit upload
    await page.click('button[type="submit"]');
    
    // 4. Wait for upload completion
    await expect(page.locator('.upload-success')).toBeVisible();
    
    // 5. Verify file exists in OSS
    // const ossPath = `uploads/${testId}.txt`;
    // const exists = await verifyFileExists(ossPath);
    // expect(exists).toBe(true);
    
    // 6. Cleanup: delete uploaded file
    // await deleteFile(ossPath);
  });
});
EOF
    fi
        else
        local example_file="$frontend_path/tests/e2e/example-with-verification.spec.ts"
        if should_overwrite_file "$example_file"; then
            cat << 'EOF' > "$example_file"
/**
 * Example E2E test with verification template
 * Demonstrates the testing pattern: UI action -> Verify -> Cleanup
 */
import { test, expect } from '@playwright/test';
import { loginViaUI, generateTestId, getTestUser } from './helpers/auth';
// import { verifyRecordExists, getRecord, deleteTestRecords } from './helpers/db';
// import { verifyFileExists, deleteFile } from './helpers/oss';

// Test data for this test suite
const TEST_PREFIX = 'e2e_example';

test.describe('Example with Verification', () => {
    // Unique ID for test isolation
    let testId: string;
  
    test.beforeEach(async ({ page }) => {
        // Generate unique test ID for this test run
        testId = generateTestId(TEST_PREFIX);
    
        // Login before each test
        // await loginViaUI(page);
    });
  
    test('homepage loads correctly', async ({ page }) => {
        await page.goto('/');
        await expect(page).toHaveTitle(/.*/, { timeout: 10000 });
    });
});
EOF
        fi
        fi
    echo -e "${GREEN}✓ 创建 E2E 测试示例和全局配置文件${NC}"
}

install_eslint_prettier() {
    local manager
    manager=$(detect_package_manager)
    case "$manager" in
        pnpm)
            ensure_command "pnpm" "pnpm" "pnpm" && pnpm add -D eslint prettier eslint-config-prettier eslint-plugin-prettier
            ;;
        yarn)
            ensure_command "yarn" "yarn" "yarn" && yarn add -D eslint prettier eslint-config-prettier eslint-plugin-prettier
            ;;
        *)
            npm install -D eslint prettier eslint-config-prettier eslint-plugin-prettier
            ;;
    esac
    if [ ! -f ".eslintrc.json" ] && [ ! -f "eslint.config.js" ]; then
                if has_pkg_dep "next"; then
                        cat << 'EOF' > .eslintrc.json
{
    "extends": ["next/core-web-vitals", "plugin:prettier/recommended"]
}
EOF
                elif has_typescript_dep || [ -f "tsconfig.json" ]; then
                        case "$manager" in
                                pnpm)
                                        pnpm add -D @typescript-eslint/parser @typescript-eslint/eslint-plugin
                                        ;;
                                yarn)
                                        yarn add -D @typescript-eslint/parser @typescript-eslint/eslint-plugin
                                        ;;
                                *)
                                        npm install -D @typescript-eslint/parser @typescript-eslint/eslint-plugin
                                        ;;
                        esac
                        cat << 'EOF' > .eslintrc.json
{
    "env": { "browser": true, "node": true, "es2021": true },
    "extends": ["eslint:recommended", "plugin:@typescript-eslint/recommended", "plugin:prettier/recommended"],
    "parser": "@typescript-eslint/parser",
    "parserOptions": { "ecmaVersion": "latest", "sourceType": "module" }
}
EOF
                else
                        cat << 'EOF' > .eslintrc.json
{
    "env": { "browser": true, "node": true, "es2021": true },
    "extends": ["eslint:recommended", "plugin:prettier/recommended"],
    "parserOptions": { "ecmaVersion": "latest", "sourceType": "module" }
}
EOF
                fi
    fi
    if [ ! -f ".prettierrc" ]; then
        cat << 'EOF' > .prettierrc
{
  "singleQuote": true,
  "trailingComma": "all"
}
EOF
    fi
}

install_vitest() {
    local manager
    manager=$(detect_package_manager)
    case "$manager" in
        pnpm)
            ensure_command "pnpm" "pnpm" "pnpm" && pnpm add -D vitest
            ;;
        yarn)
            ensure_command "yarn" "yarn" "yarn" && yarn add -D vitest
            ;;
        *)
            npm install -D vitest
            ;;
    esac
    if [ ! -f "vitest.config.ts" ] && [ ! -f "vitest.config.js" ]; then
        cat << 'EOF' > vitest.config.ts
import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    environment: 'node',
        include: ['src/**/*.{test,spec}.{ts,tsx}'],
        exclude: ['**/tests/e2e/**', '**/node_modules/**'],
  },
});
EOF
    fi
}

install_jest() {
    local manager
    manager=$(detect_package_manager)
    case "$manager" in
        pnpm)
            ensure_command "pnpm" "pnpm" "pnpm" && pnpm add -D jest
            ;;
        yarn)
            ensure_command "yarn" "yarn" "yarn" && yarn add -D jest
            ;;
        *)
            npm install -D jest
            ;;
    esac
    if [ ! -f "jest.config.cjs" ]; then
        cat << 'EOF' > jest.config.cjs
module.exports = {
  testEnvironment: 'node',
};
EOF
    fi
}

setup_node_scripts() {
    local unit_runner="$1"
    add_pkg_script_if_missing "lint" "eslint . --fix"
    add_pkg_script_if_missing "format" "prettier --write ."
    if [ -f "tsconfig.json" ] || has_typescript_dep; then
        add_pkg_script_if_missing "type-check" "tsc --noEmit"
    fi
    if [ "$unit_runner" = "vitest" ]; then
        add_pkg_script_if_missing "test:unit" "vitest run"
    elif [ "$unit_runner" = "jest" ]; then
        add_pkg_script_if_missing "test:unit" "jest"
    fi
    add_pkg_script_if_missing "test:e2e" "npx playwright test"
    if [ -n "$unit_runner" ]; then
        add_pkg_script_if_missing "test" "npm run test:unit && npm run test:e2e"
        add_pkg_script_if_missing "check" "npm run type-check && npm run lint && npm run test:unit"
    fi
}

init_frontend_stack() {
    local frontend_path="$1"
    local choice="$2"

    if [ -n "$frontend_path" ]; then
        mkdir -p "$frontend_path"
    fi

    case "$choice" in
        node)
            (cd "$frontend_path" && {
                init_node_stack
                if ! has_pkg_dep "eslint" || ! has_pkg_dep "prettier"; then
                    if prompt_yes_no "是否安装 ESLint + Prettier?" "y"; then
                        install_eslint_prettier
                    fi
                fi
                echo -e "${BLUE}选择前端单测框架:${NC}"
                echo -e "  1) Vitest"
                echo -e "  2) Jest"
                echo -e "  3) 跳过"
                UNIT_RUNNER=""
                while true; do
                    read -p "请输入选项 [1-3]: " UNIT_CHOICE
                    case "$UNIT_CHOICE" in
                        1)
                            if ! has_pkg_dep "vitest"; then
                                install_vitest
                            fi
                            UNIT_RUNNER="vitest"; break ;;
                        2)
                            if ! has_pkg_dep "jest"; then
                                install_jest
                            fi
                            UNIT_RUNNER="jest"; break ;;
                        3) break ;;
                        *) echo -e "${YELLOW}请输入 1-3 的有效选项${NC}" ;;
                    esac
                done
                if ! has_playwright_dep; then
                    if prompt_yes_no "是否安装 Playwright (E2E)?" "y"; then
                        install_playwright
                        # Offer E2E framework configuration
                        if prompt_yes_no "是否配置 E2E 测试框架（DB/OSS 验证）?" "n"; then
                            local has_mysql="no"
                            local has_oss="no"
                            if prompt_yes_no "  项目是否使用 MySQL 数据库?" "y"; then
                                has_mysql="yes"
                            fi
                            if prompt_yes_no "  项目是否使用 OSS 文件存储?" "n"; then
                                has_oss="yes"
                            fi
                            configure_e2e_framework "." "$has_mysql" "$has_oss"
                        fi
                    fi
                fi
                if prompt_yes_no "是否补齐 package.json scripts?" "y"; then
                    setup_node_scripts "$UNIT_RUNNER"
                fi
            })
            ;;
        ts)
            (cd "$frontend_path" && {
                init_typescript_stack
                if ! has_pkg_dep "eslint" || ! has_pkg_dep "prettier"; then
                    if prompt_yes_no "是否安装 ESLint + Prettier?" "y"; then
                        install_eslint_prettier
                    fi
                fi
                echo -e "${BLUE}选择前端单测框架:${NC}"
                echo -e "  1) Vitest"
                echo -e "  2) Jest"
                echo -e "  3) 跳过"
                UNIT_RUNNER=""
                while true; do
                    read -p "请输入选项 [1-3]: " UNIT_CHOICE
                    case "$UNIT_CHOICE" in
                        1)
                            if ! has_pkg_dep "vitest"; then
                                install_vitest
                            fi
                            UNIT_RUNNER="vitest"; break ;;
                        2)
                            if ! has_pkg_dep "jest"; then
                                install_jest
                            fi
                            UNIT_RUNNER="jest"; break ;;
                        3) break ;;
                        *) echo -e "${YELLOW}请输入 1-3 的有效选项${NC}" ;;
                    esac
                done
                if ! has_playwright_dep; then
                    if prompt_yes_no "是否安装 Playwright (E2E)?" "y"; then
                        install_playwright
                        # Offer E2E framework configuration for TypeScript projects
                        if prompt_yes_no "是否配置 E2E 测试框架（DB/OSS 验证）?" "n"; then
                            local has_mysql="no"
                            local has_oss="no"
                            if prompt_yes_no "  项目是否使用 MySQL 数据库?" "y"; then
                                has_mysql="yes"
                            fi
                            if prompt_yes_no "  项目是否使用 OSS 文件存储?" "n"; then
                                has_oss="yes"
                            fi
                            configure_e2e_framework "." "$has_mysql" "$has_oss"
                        fi
                    fi
                fi
                if prompt_yes_no "是否补齐 package.json scripts?" "y"; then
                    setup_node_scripts "$UNIT_RUNNER"
                fi
            })
            ;;
        custom)
            (cd "$frontend_path" && init_custom_stack)
            ;;
        skip)
            echo -e "${YELLOW}已跳过前端初始化${NC}"
            ;;
    esac
}

init_backend_fastapi() {
    local backend_path="$1"
    mkdir -p "$backend_path"
    (cd "$backend_path" && {
        init_python_stack "yes"
        setup_python_tooling
        if [ ! -f "main.py" ]; then
            cat << 'PY_EOF' > main.py
from fastapi import FastAPI

app = FastAPI()

@app.get("/")
def read_root():
    return {"status": "ok"}
PY_EOF
        fi
        if prompt_yes_no "是否安装 FastAPI 依赖?" "y"; then
            if [ ! -f "requirements.txt" ]; then
                : > requirements.txt
            fi
            grep -q '^fastapi' requirements.txt 2>/dev/null || echo "fastapi" >> requirements.txt
            grep -q '^uvicorn' requirements.txt 2>/dev/null || echo "uvicorn" >> requirements.txt
            if [ -d ".venv" ]; then
                ./.venv/bin/pip install -r requirements.txt
            else
                pip3 install -r requirements.txt
            fi
        fi
    })
}

init_backend_flask() {
    local backend_path="$1"
    mkdir -p "$backend_path"
    (cd "$backend_path" && {
        init_python_stack "yes"
        setup_python_tooling
        if [ ! -f "app.py" ]; then
            cat << 'PY_EOF' > app.py
from flask import Flask

app = Flask(__name__)

@app.get("/")
def index():
    return {"status": "ok"}

if __name__ == "__main__":
    app.run(debug=True)
PY_EOF
        fi
        if prompt_yes_no "是否安装 Flask 依赖?" "y"; then
            if [ ! -f "requirements.txt" ]; then
                : > requirements.txt
            fi
            grep -q '^flask' requirements.txt 2>/dev/null || echo "flask" >> requirements.txt
            if [ -d ".venv" ]; then
                ./.venv/bin/pip install -r requirements.txt
            else
                pip3 install -r requirements.txt
            fi
        fi
    })
}

init_backend_django() {
    local backend_path="$1"
    mkdir -p "$backend_path"
    (cd "$backend_path" && {
        init_python_stack "yes"
        setup_python_tooling
        if prompt_yes_no "是否安装 Django 并创建项目?" "y"; then
            if [ ! -f "requirements.txt" ]; then
                : > requirements.txt
            fi
            grep -q '^django' requirements.txt 2>/dev/null || echo "django" >> requirements.txt
            if [ -d ".venv" ]; then
                ./.venv/bin/pip install -r requirements.txt
                read -p "请输入 Django 项目名: " DJANGO_PROJECT
                if [ -n "$DJANGO_PROJECT" ]; then
                    ./.venv/bin/django-admin startproject "$DJANGO_PROJECT" .
                fi
            else
                pip3 install -r requirements.txt
                read -p "请输入 Django 项目名: " DJANGO_PROJECT
                if [ -n "$DJANGO_PROJECT" ]; then
                    django-admin startproject "$DJANGO_PROJECT" .
                fi
            fi
        fi
    })
}

init_backend_express() {
    local backend_path="$1"
    mkdir -p "$backend_path"
    (cd "$backend_path" && {
        if [ ! -f "package.json" ]; then
            init_package_json
        fi
        npm install express
        if ! has_pkg_dep "eslint" || ! has_pkg_dep "prettier"; then
            if prompt_yes_no "是否安装 ESLint + Prettier?" "y"; then
                install_eslint_prettier
            fi
        fi
        echo -e "${BLUE}选择后端单测框架:${NC}"
        echo -e "  1) Vitest"
        echo -e "  2) Jest"
        echo -e "  3) 跳过"
        UNIT_RUNNER=""
        while true; do
            read -p "请输入选项 [1-3]: " UNIT_CHOICE
            case "$UNIT_CHOICE" in
                1)
                    if ! has_pkg_dep "vitest"; then
                        install_vitest
                    fi
                    UNIT_RUNNER="vitest"; break ;;
                2)
                    if ! has_pkg_dep "jest"; then
                        install_jest
                    fi
                    UNIT_RUNNER="jest"; break ;;
                3) break ;;
                *) echo -e "${YELLOW}请输入 1-3 的有效选项${NC}" ;;
            esac
        done
        if prompt_yes_no "是否补齐 package.json scripts?" "y"; then
            setup_node_scripts "$UNIT_RUNNER"
        fi
        if [ ! -f "server.js" ]; then
            cat << 'JS_EOF' > server.js
const express = require('express');
const app = express();

app.get('/', (req, res) => {
  res.json({ status: 'ok' });
});

const port = process.env.PORT || 3000;
app.listen(port, () => {
  console.log(`Server running on ${port}`);
});
JS_EOF
        fi
    })
}

init_backend_nest() {
    local backend_path="$1"
    if ! ensure_command "npx" "npm" "node"; then
        return 1
    fi
    if [ -d "$backend_path" ] && [ -n "$(ls -A "$backend_path" 2>/dev/null)" ]; then
        echo -e "${YELLOW}⚠️ 后端目录非空，跳过 Nest 初始化${NC}"
        return 0
    fi
    npx @nestjs/cli new "$backend_path"
    (cd "$backend_path" && {
        if ! has_pkg_dep "eslint" || ! has_pkg_dep "prettier"; then
            if prompt_yes_no "是否安装 ESLint + Prettier?" "y"; then
                install_eslint_prettier
            fi
        fi
        echo -e "${BLUE}选择后端单测框架:${NC}"
        echo -e "  1) Vitest"
        echo -e "  2) Jest"
        echo -e "  3) 跳过"
        UNIT_RUNNER=""
        while true; do
            read -p "请输入选项 [1-3]: " UNIT_CHOICE
            case "$UNIT_CHOICE" in
                1)
                    if ! has_pkg_dep "vitest"; then
                        install_vitest
                    fi
                    UNIT_RUNNER="vitest"; break ;;
                2)
                    if ! has_pkg_dep "jest"; then
                        install_jest
                    fi
                    UNIT_RUNNER="jest"; break ;;
                3) break ;;
                *) echo -e "${YELLOW}请输入 1-3 的有效选项${NC}" ;;
            esac
        done
        if prompt_yes_no "是否补齐 package.json scripts?" "y"; then
            setup_node_scripts "$UNIT_RUNNER"
        fi
    })
}

init_backend_gin() {
    local backend_path="$1"
    mkdir -p "$backend_path"
    (cd "$backend_path" && {
        init_go_stack
        if prompt_yes_no "是否生成 Go 测试/覆盖率入口 (Makefile)?" "n"; then
            if [ ! -f "Makefile" ]; then
                cat << 'EOF' > Makefile
test:
	go test ./...

coverage:
	go test ./... -coverprofile=coverage.out
EOF
            fi
        fi
        if prompt_yes_no "是否安装 Gin 并生成示例?" "y"; then
            go get github.com/gin-gonic/gin
            if [ ! -f "main.go" ]; then
                cat << 'GO_EOF' > main.go
package main

import "github.com/gin-gonic/gin"

func main() {
  r := gin.Default()
  r.GET("/", func(c *gin.Context) {
    c.JSON(200, gin.H{"status": "ok"})
  })
  r.Run()
}
GO_EOF
            fi
        fi
    })
}

init_backend_rust_axum() {
    local backend_path="$1"
    mkdir -p "$backend_path"
    (cd "$backend_path" && {
        init_rust_stack
        if prompt_yes_no "是否生成 Rust 测试/覆盖率入口 (Makefile)?" "n"; then
            if [ ! -f "Makefile" ]; then
                cat << 'EOF' > Makefile
test:
	cargo test

coverage:
	@echo "如需覆盖率，建议安装 cargo-tarpaulin"
EOF
            fi
        fi
        if prompt_yes_no "是否安装 Axum 并生成示例?" "y"; then
            cargo add axum tokio --features tokio/full
            if [ ! -f "src/main.rs" ]; then
                cat << 'RS_EOF' > src/main.rs
use axum::{routing::get, Json, Router};
use serde_json::json;

#[tokio::main]
async fn main() {
    let app = Router::new().route("/", get(|| async { Json(json!({"status": "ok"})) }));
    let listener = tokio::net::TcpListener::bind("0.0.0.0:3000").await.unwrap();
    axum::serve(listener, app).await.unwrap();
}
RS_EOF
            fi
        fi
    })
}

init_backend_stack() {
    local backend_path="$1"
    local choice="$2"

    BACKEND_INITIALIZED=true
    BACKEND_STACK="$choice"

    case "$choice" in
        fastapi) init_backend_fastapi "$backend_path" ;;
        flask) init_backend_flask "$backend_path" ;;
        django) init_backend_django "$backend_path" ;;
        express) init_backend_express "$backend_path" ;;
        nest) init_backend_nest "$backend_path" ;;
        gin) init_backend_gin "$backend_path" ;;
        axum) init_backend_rust_axum "$backend_path" ;;
        custom) (cd "$backend_path" && init_custom_stack) ;;
        skip) echo -e "${YELLOW}已跳过后端初始化${NC}" ;;
    esac
}

install_typescript_deps() {
    local manager
    manager=$(detect_package_manager)
    case "$manager" in
        pnpm)
            if ensure_command "pnpm" "pnpm" "pnpm"; then
                pnpm add -D typescript ts-node @types/node
            fi
            ;;
        yarn)
            if ensure_command "yarn" "yarn" "yarn"; then
                yarn add -D typescript ts-node @types/node
            fi
            ;;
        *)
            npm install -D typescript ts-node @types/node
            ;;
    esac
    if [ ! -f "tsconfig.json" ]; then
        npx tsc --init
    fi
}

has_playwright_dep() {
    if [ ! -f "package.json" ]; then
        return 1
    fi
    jq -e '.dependencies["@playwright/test"] or .devDependencies["@playwright/test"]' package.json >/dev/null 2>&1
}

has_typescript_dep() {
    if [ ! -f "package.json" ]; then
        return 1
    fi
    jq -e '.dependencies["typescript"] or .devDependencies["typescript"]' package.json >/dev/null 2>&1
}

init_node_stack() {
    if [ ! -f "package.json" ]; then
        echo -e "${YELLOW}初始化 Node.js 项目...${NC}"
        init_package_json
    fi
    if prompt_yes_no "是否设置 package.json 为 ES Module (type: module)?" "n"; then
        set_pkg_field_if_missing "type" "module"
    fi
}

init_typescript_stack() {
    if [ ! -f "package.json" ]; then
        echo -e "${YELLOW}初始化 TypeScript 项目...${NC}"
        init_package_json
    fi
    install_typescript_deps
    if [ ! -f "tsconfig.json" ]; then
        cat << 'EOF' > tsconfig.json
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "strict": true,
    "noEmit": true
  },
  "include": ["src", "tests"]
}
EOF
    fi
    if prompt_yes_no "是否设置 package.json 为 ES Module (type: module)?" "n"; then
        set_pkg_field_if_missing "type" "module"
    fi
}

init_python_stack() {
    local create_requirements="${1:-yes}"
    if [ ! -f "pyproject.toml" ] && [ ! -f "requirements.txt" ]; then
        echo -e "${YELLOW}初始化 Python 项目...${NC}"
        if [ "$create_requirements" = "yes" ]; then
            : > requirements.txt
        fi
    fi
    if prompt_yes_no "是否创建 Python 虚拟环境 (.venv)?" "y"; then
        python3 -m venv .venv
    fi
    if [ -f "requirements.txt" ] && prompt_yes_no "是否安装 Python 依赖 (pip install -r requirements.txt)?" "y"; then
        if [ -d ".venv" ]; then
            ./.venv/bin/pip install -r requirements.txt
        else
            if prompt_yes_no "检测到系统 Python 受管理(PEP 668)。是否使用 --break-system-packages 安装?" "n"; then
                pip3 install --break-system-packages -r requirements.txt
            else
                echo -e "${YELLOW}⚠️ 已跳过系统级安装，请先创建 .venv 再安装依赖${NC}"
            fi
        fi
    fi
}

pip_install_list() {
    local pkgs=("$@")
    if [ ${#pkgs[@]} -eq 0 ]; then
        return 0
    fi
    if [ -d ".venv" ]; then
        ./.venv/bin/pip install "${pkgs[@]}"
    else
        if prompt_yes_no "检测到系统 Python 受管理(PEP 668)。是否使用 --break-system-packages 安装?" "n"; then
            pip3 install --break-system-packages "${pkgs[@]}"
        else
            echo -e "${YELLOW}⚠️ 已跳过系统级安装，请先创建 .venv 再安装依赖${NC}"
        fi
    fi
}

setup_python_tooling() {
    if ! has_python_req "pytest" || ! has_python_req "pytest-cov"; then
        if prompt_yes_no "是否安装 pytest + pytest-cov?" "y"; then
            pip_install_list pytest pytest-cov
        fi
        if [ ! -f "pytest.ini" ]; then
            cat << 'EOF' > pytest.ini
[pytest]
testpaths = tests
EOF
        fi
    fi
    if ! has_python_req "ruff"; then
        if prompt_yes_no "是否安装 ruff 进行代码检查?" "y"; then
            pip_install_list ruff
        fi
        if [ ! -f "ruff.toml" ]; then
            cat << 'EOF' > ruff.toml
[lint]
select = ["E", "F", "I"]
EOF
        fi
    fi
    if ! has_python_req "mypy"; then
        if prompt_yes_no "是否安装 mypy 进行类型检查?" "y"; then
            pip_install_list mypy
        fi
        if [ ! -f "mypy.ini" ]; then
            cat << 'EOF' > mypy.ini
[mypy]
python_version = 3.11
ignore_missing_imports = true
explicit_package_bases = true
namespace_packages = true
EOF
        fi
    fi
    if ! has_python_req "playwright"; then
        if prompt_yes_no "是否安装 Python Playwright (E2E)?" "n"; then
            pip_install_list playwright
        fi
    fi
    if has_python_req "playwright"; then
        if [ -d ".venv" ]; then
            ./.venv/bin/python -m playwright install --with-deps 2>/dev/null || ./.venv/bin/python -m playwright install
        else
            python3 -m playwright install --with-deps 2>/dev/null || python3 -m playwright install
        fi
    fi
}

init_go_stack() {
    if ! ensure_command "go" "golang" "go"; then
        return 1
    fi
    if [ ! -f "go.mod" ]; then
        read -p "请输入 Go module 名称 (如 github.com/you/project): " GO_MODULE
        if [ -n "$GO_MODULE" ]; then
            go mod init "$GO_MODULE"
        fi
    fi
    if prompt_yes_no "是否运行 go mod tidy?" "y"; then
        go mod tidy
    fi
    if prompt_yes_no "是否需要 golangci-lint (手动安装提示)?" "n"; then
        echo -e "${YELLOW}请参考: https://golangci-lint.run/usage/install/${NC}"
    fi
}

init_rust_stack() {
    if ! ensure_command "cargo" "cargo" "rust"; then
        return 1
    fi
    if [ ! -f "Cargo.toml" ]; then
        cargo init
    fi
    if prompt_yes_no "是否需要 rustfmt/clippy 检查?" "n"; then
        rustup component add rustfmt clippy 2>/dev/null || true
    fi
}

init_custom_stack() {
    read -p "请输入初始化命令 (将在项目目录执行): " CUSTOM_CMD
    if [ -n "$CUSTOM_CMD" ]; then
        eval "$CUSTOM_CMD"
    fi
}

# ==========================================
# Step 0.5: 根目录 Claude 初始化检查
# ==========================================
echo -e "\n${YELLOW}[Step 0.5] 检测根目录 Claude 初始化...${NC}"

ROOT_CLAUDE_DIR="$TEMPLATE_DIR/.claude"
ROOT_SETTINGS_FILE="$ROOT_CLAUDE_DIR/settings.json"
ROOT_SETTINGS_LOCAL_FILE="$ROOT_CLAUDE_DIR/settings.local.json"
ROOT_MCP_FILE="$TEMPLATE_DIR/.mcp.json"

root_claude_initialized() {
    if [ -f "$ROOT_MCP_FILE" ] && { [ -f "$ROOT_SETTINGS_FILE" ] || [ -f "$ROOT_SETTINGS_LOCAL_FILE" ]; }; then
        return 0
    fi
    return 1
}

if root_claude_initialized; then
        echo -e "${GREEN}✓ 根目录 Claude 已初始化${NC}"
else
        echo -e "${YELLOW}⚠️ 根目录未检测到完整 Claude 初始化，开始初始化...${NC}"

        if command -v claude &> /dev/null; then
            INIT_OUTPUT=$(cd "$TEMPLATE_DIR" && claude init 2>&1) || {
                echo -e "${RED}❌ claude init 失败:${NC}"
                echo "$INIT_OUTPUT"
                exit 1
            }
        fi

        # 若 claude init 未生成配置，则创建最小可用配置以支持 planning.sh
        if [ ! -f "$ROOT_SETTINGS_FILE" ]; then
                mkdir -p "$ROOT_CLAUDE_DIR"
                cat << 'EOF' > "$ROOT_SETTINGS_FILE"
{
    "permissions": {
        "allow": [
            "Read",
            "Edit",
            "Bash(ls:*)",
            "Bash(cat:*)",
            "Bash(grep:*)",
            "Bash(find:*)",
            "Bash(head:*)",
            "Bash(tail:*)",
            "Bash(wc:*)",
            "Bash(echo:*)",
            "Bash(pwd:*)",
            "Bash(cd:*)",
            "Bash(mkdir:*)",
            "Bash(touch:*)",
            "Bash(cp:*)",
            "Bash(mv:*)",
            "Bash(npm:*)",
            "Bash(npx:*)",
            "Bash(node:*)",
            "Bash(python3:*)",
            "Bash(python:*)",
            "Bash(pip:*)",
            "Bash(lsof:*)",
            "Bash(ps:*)",
            "Bash(kill:*)",
            "Bash(which:*)",
            "Bash(env:*)",
            "Bash(export:*)",
            "Bash(uvx:*)"
        ],
        "deny": [
            "Bash(rm -rf:*)",
            "Bash(rm -r:*)",
            "Bash(sudo:*)",
            "Bash(shutdown:*)",
            "Bash(reboot:*)",
            "Bash(mkfs:*)",
            "Bash(dd:*)",
            "Bash(chmod 777:*)",
            "Bash(curl:*)|sh",
            "Bash(wget:*)|sh",
            "Read(/etc/passwd)",
            "Read(/etc/shadow)",
            "Read(./.env)",
            "Read(./.env.*)"
        ],
        "ask": [
            "Bash(git push:*)",
            "Bash(git commit:*)",
            "Bash(npm publish:*)",
            "Bash(rm:*)"
        ]
    }
}
EOF
        fi

        if [ ! -f "$ROOT_MCP_FILE" ]; then
                cat << 'EOF' > "$ROOT_MCP_FILE"
{
    "mcpServers": {
        "superpowers": {
            "command": "npx",
            "args": ["-y", "@anthropic-ai/superpower"]
        }
    }
}
EOF
        fi

        if [ -f "$ROOT_SETTINGS_FILE" ] && [ -f "$ROOT_MCP_FILE" ]; then
            echo -e "${GREEN}✓ 根目录 Claude 初始化完成${NC}"
        else
            echo -e "${RED}❌ 根目录 Claude 初始化失败，请手动执行: claude init${NC}"
            exit 1
        fi
fi

# ==========================================
# Step 1: 检测并下载 ralph-claude-code
# ==========================================
echo -e "\n${YELLOW}[Step 1] 检测 ralph-claude-code 模板...${NC}"

RALPH_REPO_DIR="$TEMPLATE_DIR/ralph-claude-code"

if [ -d "$RALPH_REPO_DIR" ]; then
    echo -e "${GREEN}✓ ralph-claude-code 已存在${NC}"
    echo -e "  路径: $RALPH_REPO_DIR"
    
    # 询问是否更新
    echo ""
    read -p "是否更新到最新版本? [y/N]: " UPDATE_RALPH
    if [[ "$UPDATE_RALPH" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}更新 ralph-claude-code...${NC}"
        cd "$RALPH_REPO_DIR"
        if prompt_yes_no "是否执行 ralph-claude-code/uninstall.sh?" "y"; then
            echo -e "${YELLOW}运行 ralph-claude-code/uninstall.sh...${NC}"
            ( [ -x ./uninstall.sh ] && ./uninstall.sh || bash ./uninstall.sh )
        else
            echo -e "${YELLOW}⏭️ 已跳过 uninstall.sh${NC}"
        fi
        cd "$TEMPLATE_DIR"
        
        if prompt_yes_no "是否删除旧的 ralph-claude-code 目录并重新下载?" "y"; then
            echo -e "${YELLOW}删除旧的 ralph-claude-code 目录...${NC}"
            rm -rf "$RALPH_REPO_DIR"
            echo -e "${YELLOW}重新下载 ralph-claude-code...${NC}"
            git clone https://github.com/dawenrenhub/ralph-claude-code.git "$RALPH_REPO_DIR"
            echo -e "${GREEN}✓ 更新完成${NC}"
        else
            echo -e "${YELLOW}⏭️ 已跳过删除和重新下载${NC}"
            if prompt_yes_no "是否执行 git pull 更新?" "y"; then
                cd "$RALPH_REPO_DIR"
                echo -e "${YELLOW}执行 git pull...${NC}"
                git pull
                cd "$TEMPLATE_DIR"
                echo -e "${GREEN}✓ git pull 完成${NC}"
            else
                echo -e "${YELLOW}⏭️ 已跳过 git pull${NC}"
            fi
        fi
        
        echo -e "${YELLOW}运行 ralph-claude-code/install.sh...${NC}"
        (cd "$RALPH_REPO_DIR" && ( [ -x ./install.sh ] && ./install.sh || bash ./install.sh ))
        echo -e "${GREEN}✓ ralph-claude-code 安装完成${NC}"
    fi
else
    echo -e "${YELLOW}下载 ralph-claude-code...${NC}"
    git clone https://github.com/dawenrenhub/ralph-claude-code.git "$RALPH_REPO_DIR"
    echo -e "${GREEN}✓ 下载完成${NC}"
    echo -e "${YELLOW}运行 ralph-claude-code/install.sh...${NC}"
    (cd "$RALPH_REPO_DIR" && ( [ -x ./install.sh ] && ./install.sh || bash ./install.sh ))
    echo -e "${GREEN}✓ ralph-claude-code 安装完成${NC}"
fi

# ==========================================
# Step 2: 配置项目级 Superpowers（MCP）
# ==========================================
echo -e "\n${YELLOW}[Step 2] 配置项目级 Superpowers...${NC}"

ROOT_MCP_FILE="$TEMPLATE_DIR/.mcp.json"

ensure_superpowers_mcp() {
    if [ -f "$ROOT_MCP_FILE" ]; then
        if jq -e '.mcpServers.superpowers' "$ROOT_MCP_FILE" >/dev/null 2>&1; then
            return 0
        fi
        tmp_file=$(mktemp)
        jq '.mcpServers = (.mcpServers // {}) | .mcpServers.superpowers = {"command":"npx","args":["-y","@anthropic-ai/superpower"]}' \
            "$ROOT_MCP_FILE" > "$tmp_file" && mv "$tmp_file" "$ROOT_MCP_FILE"
    else
        cat << 'EOF' > "$ROOT_MCP_FILE"
{
    "mcpServers": {
        "superpowers": {
            "command": "npx",
            "args": ["-y", "@anthropic-ai/superpower"]
        }
    }
}
EOF
    fi
}

ensure_superpowers_mcp
echo -e "${GREEN}✓ Superpowers 已配置为项目级 MCP${NC}"

# ==========================================
# Step 3: 询问项目类型 (新项目 / 已有项目)
# ==========================================
echo -e "\n${YELLOW}[Step 3] 项目配置...${NC}"

if prompt_yes_no "是否需要进行项目配置?" "n"; then

echo ""
echo -e "${BLUE}请选择项目类型:${NC}"
echo -e "  1) 新项目 - 创建一个全新的项目"
echo -e "  2) 已有项目 - 从 Git 仓库 clone"
echo -e "  3) 本地项目 - 选择已有本地目录"
echo ""
read -p "请输入选项 [1-3] (默认: 1): " PROJECT_TYPE

case "$PROJECT_TYPE" in
    2)
        # 已有项目 - clone
        echo ""
        echo -e "${CYAN}请输入 Git 仓库地址:${NC}"
        read -p "Git URL: " GIT_URL
        
        if [ -z "$GIT_URL" ]; then
            echo -e "${RED}❌ Git URL 不能为空${NC}"
            exit 1
        fi
        
        echo ""
        read -p "请输入分支名 (默认: main): " GIT_BRANCH
        GIT_BRANCH="${GIT_BRANCH:-main}"
        
        # 从 URL 提取项目名
        PROJECT_NAME=$(basename "$GIT_URL" .git)
        echo ""
        read -p "项目文件夹名 (默认: $PROJECT_NAME): " CUSTOM_NAME
        PROJECT_NAME="${CUSTOM_NAME:-$PROJECT_NAME}"
        
        PROJECT_DIR="$TEMPLATE_DIR/$PROJECT_NAME"
        
        if [ -d "$PROJECT_DIR" ]; then
            echo -e "${YELLOW}⚠️ 目录已存在: $PROJECT_DIR${NC}"
            read -p "是否覆盖? [y/N]: " OVERWRITE
            if [[ "$OVERWRITE" =~ ^[Yy]$ ]]; then
                rm -rf "$PROJECT_DIR"
            else
                echo -e "${RED}❌ 操作取消${NC}"
                exit 1
            fi
        fi
        
        echo -e "${YELLOW}克隆项目...${NC}"
        git clone -b "$GIT_BRANCH" "$GIT_URL" "$PROJECT_DIR"
        echo -e "${GREEN}✓ 项目克隆成功${NC}"
        ;;
    3)
        echo -e "${YELLOW}🔎 正在检索可用项目目录...${NC}"
        mapfile -t PROJECT_DIRS < <(find . -maxdepth 1 -mindepth 1 -type d -printf '%f\n' | grep -vE '^(ralph-claude-code|\.claude|\.git|\.idea|\.vscode|node_modules)$' | sort)

        if [ ${#PROJECT_DIRS[@]} -eq 0 ]; then
            echo -e "${RED}❌ 当前目录下未找到可用项目目录${NC}"
            echo -e "${CYAN}请输入本地项目路径:${NC}"
            read -p "项目路径: " LOCAL_PROJECT_PATH
            if [ ! -d "$LOCAL_PROJECT_PATH" ]; then
                echo -e "${RED}❌ 目录不存在: $LOCAL_PROJECT_PATH${NC}"
                exit 1
            fi
            PROJECT_DIR="$(cd "$LOCAL_PROJECT_PATH" && pwd)"
        else
            echo -e "${CYAN}请选择项目目录:${NC}"
            for i in "${!PROJECT_DIRS[@]}"; do
                echo "  $((i+1))) ${PROJECT_DIRS[$i]}"
            done
            echo "  0) 输入自定义路径"

            read -p "请输入序号: " SELECT_IDX
            
            if [ "$SELECT_IDX" -eq 0 ]; then
                 read -p "请输入项目完整路径: " LOCAL_PROJECT_PATH
                 if [ ! -d "$LOCAL_PROJECT_PATH" ]; then
                    echo -e "${RED}❌ 目录不存在: $LOCAL_PROJECT_PATH${NC}"
                    exit 1
                 fi
                 PROJECT_DIR="$(cd "$LOCAL_PROJECT_PATH" && pwd)"
            elif [[ "$SELECT_IDX" =~ ^[0-9]+$ ]] && [ "$SELECT_IDX" -ge 1 ] && [ "$SELECT_IDX" -le ${#PROJECT_DIRS[@]} ]; then
                 PROJECT_DIR="$(pwd)/${PROJECT_DIRS[$((SELECT_IDX-1))]}"
            else
                 echo -e "${RED}❌ 无效选择${NC}"
                 exit 1
            fi
        fi

        PROJECT_NAME="$(basename "$PROJECT_DIR")"
        echo -e "${GREEN}✓ 使用本地项目目录: $PROJECT_DIR${NC}"
        ;;
    *)
        # 新项目
        echo ""
        echo -e "${CYAN}请输入项目名称:${NC}"
        read -p "项目名: " PROJECT_NAME
        
        if [ -z "$PROJECT_NAME" ]; then
            echo -e "${RED}❌ 项目名不能为空${NC}"
            exit 1
        fi
        
        # 替换空格为下划线
        PROJECT_NAME=$(echo "$PROJECT_NAME" | tr ' ' '_')
        PROJECT_DIR="$TEMPLATE_DIR/$PROJECT_NAME"
        
        if [ -d "$PROJECT_DIR" ]; then
            echo -e "${YELLOW}⚠️ 目录已存在: $PROJECT_DIR${NC}"
            read -p "是否覆盖? [y/N]: " OVERWRITE
            if [[ "$OVERWRITE" =~ ^[Yy]$ ]]; then
                rm -rf "$PROJECT_DIR"
            else
                echo -e "${RED}❌ 操作取消${NC}"
                exit 1
            fi
        fi
        
        mkdir -p "$PROJECT_DIR"
        echo -e "${GREEN}✓ 创建项目目录: $PROJECT_DIR${NC}"
        ;;
esac

# ==========================================
# Step 4: 进入项目目录，配置项目结构
# ==========================================
echo -e "\n${YELLOW}[Step 4] 项目结构配置...${NC}"

FRONTEND_DIR=""
PLAYWRIGHT_CONFIG_DIR="."
TESTS_DIR="tests/e2e"
DEFAULT_PORT="3000"

if prompt_yes_no "是否执行 Step 4（项目结构配置）?" "y"; then
    cd "$PROJECT_DIR"
    echo -e "  工作目录: ${BLUE}$PROJECT_DIR${NC}"

    echo ""
    echo -e "${BLUE}请选择你的项目结构:${NC}"
    echo -e "  1) 单体项目 (所有代码在根目录)"
    echo -e "  2) Monorepo - 前端在 frontend/"
    echo -e "  3) Monorepo - 前端在 client/"
    echo -e "  4) Monorepo - 前端在 web/"
    echo -e "  5) 自定义前端目录"
    echo ""
    read -p "请输入选项 [1-5] (默认: 1): " PROJECT_STRUCTURE

    case "$PROJECT_STRUCTURE" in
        2)
            FRONTEND_DIR="frontend"
            ;;
        3)
            FRONTEND_DIR="client"
            ;;
        4)
            FRONTEND_DIR="web"
            ;;
        5)
            read -p "请输入前端目录名称: " CUSTOM_DIR
            FRONTEND_DIR="${CUSTOM_DIR:-frontend}"
            ;;
        *)
            FRONTEND_DIR=""
            ;;
    esac

    # 设置文件路径
    if [ -n "$FRONTEND_DIR" ]; then
        PLAYWRIGHT_CONFIG_DIR="$FRONTEND_DIR"
        TESTS_DIR="$FRONTEND_DIR/tests/e2e"
        echo -e "${GREEN}✓ Monorepo 模式: 前端目录 = $FRONTEND_DIR${NC}"
    else
        PLAYWRIGHT_CONFIG_DIR="."
        TESTS_DIR="tests/e2e"
        echo -e "${GREEN}✓ 单体项目模式${NC}"
    fi

    echo ""
    echo -e "${BLUE}请选择默认端口:${NC}"
    echo -e "  1) 3000 (Next.js / Express / 通用)"
    echo -e "  2) 5173 (Vite)"
    echo -e "  3) 8080 (Vue CLI / 通用)"
    echo -e "  4) 4200 (Angular)"
    echo -e "  5) 自定义端口"
    echo ""
    read -p "请输入选项 [1-5] (默认: 1): " PORT_CHOICE

    case "$PORT_CHOICE" in
        2)
            DEFAULT_PORT="5173"
            ;;
        3)
            DEFAULT_PORT="8080"
            ;;
        4)
            DEFAULT_PORT="4200"
            ;;
        5)
            read -p "请输入端口号: " CUSTOM_PORT
            DEFAULT_PORT="${CUSTOM_PORT:-3000}"
            ;;
        *)
            DEFAULT_PORT="3000"
            ;;
    esac

    echo -e "${GREEN}✓ 默认端口: $DEFAULT_PORT${NC}"
else
    cd "$PROJECT_DIR"
    echo -e "${YELLOW}⏭️ 已跳过 Step 4，使用默认项目结构与端口${NC}"
fi

# ==========================================
# Step 5: 技术栈初始化
# ==========================================
echo -e "\n${YELLOW}[Step 5] 技术栈初始化...${NC}"

if prompt_yes_no "是否执行 Step 5（技术栈初始化）?" "y"; then
    FRONTEND_PATH="$PROJECT_DIR"
    if [ -n "$FRONTEND_DIR" ]; then
        FRONTEND_PATH="$PROJECT_DIR/$FRONTEND_DIR"
        mkdir -p "$FRONTEND_PATH"
    fi

    BACKEND_DIR=""
    BACKEND_REQUESTED=false
    BACKEND_INITIALIZED=false
    BACKEND_STACK=""
    BACKEND_HANDLED=false

    if prompt_yes_no "是否有后端?" "n"; then
        BACKEND_REQUESTED=true
        read -p "后端目录名 (默认: backend): " BACKEND_DIR_INPUT
        BACKEND_DIR="${BACKEND_DIR_INPUT:-backend}"
    else
        if [[ "$PROJECT_TYPE" =~ ^2$ ]]; then
            for candidate in backend server api; do
                if [ -d "$PROJECT_DIR/$candidate" ]; then
                    if prompt_yes_no "检测到后端目录: $candidate，是否使用?" "y"; then
                        BACKEND_DIR="$candidate"
                        BACKEND_REQUESTED=true
                        break
                    fi
                fi
            done
            if [ "$BACKEND_REQUESTED" = false ]; then
                if prompt_yes_no "未检测到后端目录，是否初始化后端?" "n"; then
                    BACKEND_REQUESTED=true
                    read -p "后端目录名 (默认: backend): " BACKEND_DIR_INPUT
                    BACKEND_DIR="${BACKEND_DIR_INPUT:-backend}"
                fi
            fi
        fi
    fi

    HAS_BACKEND=false
    BACKEND_PATH=""
    if [ -n "$BACKEND_DIR" ]; then
        BACKEND_PATH="$PROJECT_DIR/$BACKEND_DIR"
        if [ -d "$BACKEND_PATH" ]; then
            HAS_BACKEND=true
        fi
    fi

    if [[ "$PROJECT_TYPE" =~ ^2$ ]]; then
        HAS_STACK=false

        if [ -f "$FRONTEND_PATH/package.json" ]; then
            HAS_STACK=true
            echo -e "${GREEN}✓ 检测到 Node.js 项目${NC}"
            (cd "$FRONTEND_PATH" && {
                if prompt_yes_no "是否安装前端依赖?" "y"; then
                    install_node_dependencies
                fi

                if prompt_yes_no "是否安装 ESLint + Prettier?" "n"; then
                    install_eslint_prettier
                fi

                if [ -f "tsconfig.json" ] || has_typescript_dep; then
                    echo -e "${GREEN}✓ 检测到 TypeScript 配置${NC}"
                    if ! has_typescript_dep; then
                        if prompt_yes_no "未检测到 typescript 依赖，是否安装?" "y"; then
                            install_typescript_deps
                        fi
                    fi
                else
                    if prompt_yes_no "是否为 TypeScript 项目?" "n"; then
                        install_typescript_deps
                    fi
                fi

                echo -e "${BLUE}选择单测框架:${NC}"
                echo -e "  1) Vitest"
                echo -e "  2) Jest"
                echo -e "  3) 跳过"
                UNIT_RUNNER=""
                while true; do
                    read -p "请输入选项 [1-3]: " UNIT_CHOICE
                    case "$UNIT_CHOICE" in
                        1) install_vitest; UNIT_RUNNER="vitest"; break ;;
                        2) install_jest; UNIT_RUNNER="jest"; break ;;
                        3) break ;;
                        *) echo -e "${YELLOW}请输入 1-3 的有效选项${NC}" ;;
                    esac
                done

                if has_playwright_dep; then
                    if prompt_yes_no "是否安装 Playwright 浏览器?" "y"; then
                        npx playwright install
                    fi
                else
                    if prompt_yes_no "未检测到 @playwright/test，是否安装?" "y"; then
                        install_playwright
                    fi
                fi

                if prompt_yes_no "是否补齐 package.json scripts?" "y"; then
                    setup_node_scripts "$UNIT_RUNNER"
                fi
            })
        fi

        if [ -n "$BACKEND_PATH" ] && [ -d "$BACKEND_PATH" ]; then
            if [ -f "$BACKEND_PATH/pyproject.toml" ] || [ -f "$BACKEND_PATH/requirements.txt" ]; then
                HAS_STACK=true
                echo -e "${GREEN}✓ 检测到 Python 后端${NC}"
                (cd "$BACKEND_PATH" && {
                    init_python_stack "no"
                    setup_python_tooling
                })
                BACKEND_HANDLED=true
            fi

            if [ -f "$BACKEND_PATH/go.mod" ]; then
                HAS_STACK=true
                echo -e "${GREEN}✓ 检测到 Go 后端${NC}"
                (cd "$BACKEND_PATH" && init_go_stack)
                BACKEND_HANDLED=true
            fi

            if [ -f "$BACKEND_PATH/Cargo.toml" ]; then
                HAS_STACK=true
                echo -e "${GREEN}✓ 检测到 Rust 后端${NC}"
                (cd "$BACKEND_PATH" && init_rust_stack)
                BACKEND_HANDLED=true
            fi
        else
            if [ -f "pyproject.toml" ] || [ -f "requirements.txt" ]; then
                HAS_STACK=true
                echo -e "${GREEN}✓ 检测到 Python 项目${NC}"
                init_python_stack "no"
                setup_python_tooling
            fi

            if [ -f "go.mod" ]; then
                HAS_STACK=true
                echo -e "${GREEN}✓ 检测到 Go 项目${NC}"
                init_go_stack
            fi

            if [ -f "Cargo.toml" ]; then
                HAS_STACK=true
                echo -e "${GREEN}✓ 检测到 Rust 项目${NC}"
                init_rust_stack
            fi
        fi

        if [ "$HAS_STACK" = false ]; then
            echo -e "${YELLOW}⚠️ 未检测到已知技术栈${NC}"
            echo -e "${BLUE}请选择要初始化的技术栈:${NC}"
            echo -e "  1) Node.js (JavaScript)"
            echo -e "  2) TypeScript"
            echo -e "  3) Python"
            echo -e "  4) Go"
            echo -e "  5) Rust"
            echo -e "  6) 自定义命令"
            echo -e "  7) 跳过"
            while true; do
                read -p "请输入选项 [1-7]: " STACK_CHOICE
                case "$STACK_CHOICE" in
                    1) init_node_stack; break ;;
                    2) init_typescript_stack; break ;;
                    3) init_python_stack; break ;;
                    4) init_go_stack; break ;;
                    5) init_rust_stack; break ;;
                    6) init_custom_stack; break ;;
                    7) echo -e "${YELLOW}已跳过技术栈初始化${NC}"; break ;;
                    *) echo -e "${YELLOW}请输入 1-7 的有效选项${NC}" ;;
                esac
            done
        fi

        if [ "$HAS_BACKEND" = true ] && [ "$BACKEND_HANDLED" = false ]; then
            if [ -f "$BACKEND_PATH/pyproject.toml" ] || [ -f "$BACKEND_PATH/requirements.txt" ]; then
                echo -e "${GREEN}✓ 检测到 Python 后端${NC}"
                (cd "$BACKEND_PATH" && init_python_stack "no")
            elif [ -f "$BACKEND_PATH/package.json" ]; then
                echo -e "${GREEN}✓ 检测到 Node.js 后端${NC}"
                if prompt_yes_no "是否安装后端依赖?" "y"; then
                    (cd "$BACKEND_PATH" && install_node_dependencies)
                fi
                if prompt_yes_no "是否安装 ESLint + Prettier?" "n"; then
                    (cd "$BACKEND_PATH" && install_eslint_prettier)
                fi
                echo -e "${BLUE}选择后端单测框架:${NC}"
                echo -e "  1) Vitest"
                echo -e "  2) Jest"
                echo -e "  3) 跳过"
                UNIT_RUNNER=""
                while true; do
                    read -p "请输入选项 [1-3]: " UNIT_CHOICE
                    case "$UNIT_CHOICE" in
                        1) (cd "$BACKEND_PATH" && install_vitest); UNIT_RUNNER="vitest"; break ;;
                        2) (cd "$BACKEND_PATH" && install_jest); UNIT_RUNNER="jest"; break ;;
                        3) break ;;
                        *) echo -e "${YELLOW}请输入 1-3 的有效选项${NC}" ;;
                    esac
                done
                if prompt_yes_no "是否补齐 package.json scripts?" "y"; then
                    (cd "$BACKEND_PATH" && setup_node_scripts "$UNIT_RUNNER")
                fi
            elif [ -f "$BACKEND_PATH/go.mod" ]; then
                echo -e "${GREEN}✓ 检测到 Go 后端${NC}"
                (cd "$BACKEND_PATH" && init_go_stack)
            elif [ -f "$BACKEND_PATH/Cargo.toml" ]; then
                echo -e "${GREEN}✓ 检测到 Rust 后端${NC}"
                (cd "$BACKEND_PATH" && init_rust_stack)
            else
                if prompt_yes_no "未检测到后端配置，是否初始化后端?" "n"; then
                    echo -e "${BLUE}请选择后端技术栈:${NC}"
                    echo -e "  1) FastAPI"
                    echo -e "  2) Flask"
                    echo -e "  3) Django"
                    echo -e "  4) Express"
                    echo -e "  5) NestJS"
                    echo -e "  6) Go (Gin)"
                    echo -e "  7) Rust (Axum)"
                    echo -e "  8) 自定义命令"
                    echo -e "  9) 跳过"
                    while true; do
                        read -p "请输入选项 [1-9]: " BACKEND_CHOICE
                        case "$BACKEND_CHOICE" in
                            1) init_backend_stack "$BACKEND_PATH" fastapi; break ;;
                            2) init_backend_stack "$BACKEND_PATH" flask; break ;;
                            3) init_backend_stack "$BACKEND_PATH" django; break ;;
                            4) init_backend_stack "$BACKEND_PATH" express; break ;;
                            5) init_backend_stack "$BACKEND_PATH" nest; break ;;
                            6) init_backend_stack "$BACKEND_PATH" gin; break ;;
                            7) init_backend_stack "$BACKEND_PATH" axum; break ;;
                            8) init_backend_stack "$BACKEND_PATH" custom; break ;;
                            9) echo -e "${YELLOW}已跳过后端初始化${NC}"; break ;;
                            *) echo -e "${YELLOW}请输入 1-9 的有效选项${NC}" ;;
                        esac
                    done
                fi
            fi
        elif [ "$BACKEND_REQUESTED" = true ]; then
            if prompt_yes_no "是否需要初始化后端?" "n"; then
                echo -e "${BLUE}请选择后端技术栈:${NC}"
                echo -e "  1) FastAPI"
                echo -e "  2) Flask"
                echo -e "  3) Django"
                echo -e "  4) Express"
                echo -e "  5) NestJS"
                echo -e "  6) Go (Gin)"
                echo -e "  7) Rust (Axum)"
                echo -e "  8) 自定义命令"
                echo -e "  9) 跳过"
                while true; do
                    read -p "请输入选项 [1-9]: " BACKEND_CHOICE
                    case "$BACKEND_CHOICE" in
                        1) init_backend_stack "$BACKEND_PATH" fastapi; break ;;
                        2) init_backend_stack "$BACKEND_PATH" flask; break ;;
                        3) init_backend_stack "$BACKEND_PATH" django; break ;;
                        4) init_backend_stack "$BACKEND_PATH" express; break ;;
                        5) init_backend_stack "$BACKEND_PATH" nest; break ;;
                        6) init_backend_stack "$BACKEND_PATH" gin; break ;;
                        7) init_backend_stack "$BACKEND_PATH" axum; break ;;
                        8) init_backend_stack "$BACKEND_PATH" custom; break ;;
                        9) echo -e "${YELLOW}已跳过后端初始化${NC}"; break ;;
                        *) echo -e "${YELLOW}请输入 1-9 的有效选项${NC}" ;;
                    esac
                done
            fi
        fi
    else
        echo -e "${BLUE}请选择前端技术栈:${NC}"
        echo -e "  1) Node.js (JavaScript)"
        echo -e "  2) TypeScript"
        echo -e "  3) 自定义命令"
        echo -e "  4) 跳过前端"
        while true; do
            read -p "请输入选项 [1-4]: " FRONT_CHOICE
            case "$FRONT_CHOICE" in
                1) init_frontend_stack "$FRONTEND_PATH" node; break ;;
                2) init_frontend_stack "$FRONTEND_PATH" ts; break ;;
                3) init_frontend_stack "$FRONTEND_PATH" custom; break ;;
                4) init_frontend_stack "$FRONTEND_PATH" skip; break ;;
                *) echo -e "${YELLOW}请输入 1-4 的有效选项${NC}" ;;
            esac
        done

        if prompt_yes_no "是否需要初始化后端?" "n"; then
            echo -e "${BLUE}请选择后端技术栈:${NC}"
            echo -e "  1) FastAPI"
            echo -e "  2) Flask"
            echo -e "  3) Django"
            echo -e "  4) Express"
            echo -e "  5) NestJS"
            echo -e "  6) Go (Gin)"
            echo -e "  7) Rust (Axum)"
            echo -e "  8) 自定义命令"
            echo -e "  9) 跳过"
            while true; do
                read -p "请输入选项 [1-9]: " BACKEND_CHOICE
                case "$BACKEND_CHOICE" in
                    1) init_backend_stack "$PROJECT_DIR/$BACKEND_DIR" fastapi; break ;;
                    2) init_backend_stack "$PROJECT_DIR/$BACKEND_DIR" flask; break ;;
                    3) init_backend_stack "$PROJECT_DIR/$BACKEND_DIR" django; break ;;
                    4) init_backend_stack "$PROJECT_DIR/$BACKEND_DIR" express; break ;;
                    5) init_backend_stack "$PROJECT_DIR/$BACKEND_DIR" nest; break ;;
                    6) init_backend_stack "$PROJECT_DIR/$BACKEND_DIR" gin; break ;;
                    7) init_backend_stack "$PROJECT_DIR/$BACKEND_DIR" axum; break ;;
                    8) init_backend_stack "$PROJECT_DIR/$BACKEND_DIR" custom; break ;;
                    9) echo -e "${YELLOW}已跳过后端初始化${NC}"; break ;;
                    *) echo -e "${YELLOW}请输入 1-9 的有效选项${NC}" ;;
                esac
            done
        fi

    fi
else
    echo -e "${YELLOW}⏭️ 已跳过 Step 5${NC}"
fi

# ==========================================
# Step 6: 创建目录结构
# ==========================================
echo -e "\n${YELLOW}[Step 6] 创建目录结构...${NC}"

if prompt_yes_no "是否执行 Step 6（创建目录结构）?" "y"; then
    if prompt_yes_no "是否创建标准目录结构 (src, tests/unit, tests/e2e, docs, logs)?" "y"; then
        ensure_dir "src"
        ensure_dir "tests/unit"
        ensure_dir "$TESTS_DIR"
        ensure_dir "docs"
        ensure_dir "logs"
    else
        ensure_dir "$TESTS_DIR"
        ensure_dir "docs"
        ensure_dir "logs"
    fi

    if [ -n "$FRONTEND_DIR" ]; then
        ensure_dir "$FRONTEND_DIR"
    fi

        ensure_dir "$PLAYWRIGHT_CONFIG_DIR/playwright"

        # Playwright 配置
        if [ -n "$FRONTEND_DIR" ]; then
                PLAYWRIGHT_CONFIG_PATH="$FRONTEND_DIR/playwright.config.ts"
                mkdir -p "$FRONTEND_DIR/playwright"
        else
                PLAYWRIGHT_CONFIG_PATH="playwright.config.ts"
                mkdir -p "playwright"
        fi

        SKIP_STEP6=false
        if [ -f "$PLAYWRIGHT_CONFIG_PATH" ]; then
            if ! prompt_yes_no "检测到 $PLAYWRIGHT_CONFIG_PATH 已存在，是否覆盖?" "n"; then
                echo -e "${YELLOW}⏭️ 已跳过 Step 6${NC}"
                SKIP_STEP6=true
            fi
        fi

        if [ "$SKIP_STEP6" = false ]; then
        cat << TS_EOF > "$PLAYWRIGHT_CONFIG_PATH"
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
    testDir: './tests/e2e',
    fullyParallel: true,
    retries: process.env.CI ? 2 : 0,
  
    use: {
        baseURL: process.env.PLAYWRIGHT_BASE_URL || 'http://localhost:$DEFAULT_PORT',
        headless: true,
        trace: 'on-first-retry',
        screenshot: 'only-on-failure',
    },
  
    reporter: [['list']],
  
    projects: [
        { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
    ],
});
TS_EOF

        echo -e "${GREEN}✓ $PLAYWRIGHT_CONFIG_PATH${NC}"

        echo -e "${GREEN}✓ 目录结构已创建${NC}"
        fi
else
    echo -e "${YELLOW}⏭️ 已跳过 Step 6${NC}"
fi

# ==========================================
# Step 7: 创建 .mcp.json
# ==========================================
echo -e "\n${YELLOW}[Step 7] 创建 .mcp.json...${NC}"

if prompt_yes_no "是否执行 Step 7（创建 .mcp.json）?" "y"; then
    if [ -f ".mcp.json" ]; then
        if ! prompt_yes_no "检测到 .mcp.json 已存在，是否覆盖?" "n"; then
            echo -e "${YELLOW}⏭️ 已跳过 Step 7${NC}"
        else
            cp .mcp.json .mcp.json.backup.$(date +%Y%m%d_%H%M%S)
            echo -e "${YELLOW}  已备份现有 .mcp.json${NC}"
            cat << 'EOF' > .mcp.json
{
    "mcpServers": {
        "playwright": {
            "command": "npx",
            "args": ["-y", "@modelcontextprotocol/server-playwright"]
        },
        "browser-use": {
            "command": "uvx",
            "args": ["browser-use-mcp"]
        }
    }
}
EOF
            echo -e "${GREEN}✓ .mcp.json${NC}"
        fi
    else
        cat << 'EOF' > .mcp.json
{
    "mcpServers": {
        "playwright": {
            "command": "npx",
            "args": ["-y", "@modelcontextprotocol/server-playwright"]
        },
        "browser-use": {
            "command": "uvx",
            "args": ["browser-use-mcp"]
        }
    }
}
EOF
        echo -e "${GREEN}✓ .mcp.json${NC}"
    fi
else
    echo -e "${YELLOW}⏭️ 已跳过 Step 7${NC}"
fi

# ==========================================
# Step 8: 创建示例测试和配置
# ==========================================
echo -e "\n${YELLOW}[Step 8] 创建辅助文件...${NC}"

if prompt_yes_no "是否执行 Step 8（创建辅助文件）?" "y"; then
        SKIP_STEP8=false
        if [ -f "$TESTS_DIR/example.spec.ts" ]; then
            if ! prompt_yes_no "检测到 $TESTS_DIR/example.spec.ts 已存在，是否覆盖?" "n"; then
                echo -e "${YELLOW}⏭️ 已跳过 Step 8${NC}"
                SKIP_STEP8=true
            fi
        fi
        if [ "$SKIP_STEP8" = false ]; then
        # 示例测试
        cat << 'TS_EOF' > "$TESTS_DIR/example.spec.ts"
import { test, expect } from '@playwright/test';

test.describe('示例测试', () => {
    test('首页加载', async ({ page }) => {
        await page.goto('/');
        await expect(page).toHaveTitle(/.*/);
    });
});
TS_EOF

        echo -e "${GREEN}✓ $TESTS_DIR/example.spec.ts${NC}"

        # .gitignore (追加缺失项)
        append_line_if_missing .gitignore "# Ralph"
        append_line_if_missing .gitignore "logs/"
        append_line_if_missing .gitignore "test-results/"
        append_line_if_missing .gitignore "playwright-report/"
        append_line_if_missing .gitignore "!docs/"
        append_line_if_missing .gitignore "!docs/plans/"
        append_line_if_missing .gitignore "!$TESTS_DIR/"
        append_line_if_missing .gitignore "# Node / System"
        append_line_if_missing .gitignore "node_modules/"
        append_line_if_missing .gitignore ".env"
        append_line_if_missing .gitignore ".env.*"
        append_line_if_missing .gitignore ".DS_Store"
        append_line_if_missing .gitignore "dist/"
        append_line_if_missing .gitignore "build/"
        append_line_if_missing .gitignore "coverage/"
        append_line_if_missing .gitignore "__pycache__/"
        append_line_if_missing .gitignore "*.pyc"
        append_line_if_missing .gitignore ".venv/"
        append_line_if_missing .gitignore ".pytest_cache/"

        echo -e "${GREEN}✓ 辅助文件已创建${NC}"
        fi
else
        echo -e "${YELLOW}⏭️ 已跳过 Step 8${NC}"
fi

# ==========================================
# 完成
# ==========================================
echo ""
echo -e "${BLUE}══════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ Ralph Loop V7.2 安装完成！${NC}"
echo -e "${BLUE}══════════════════════════════════════════${NC}"
echo ""
echo -e "📁 项目目录: ${CYAN}$PROJECT_DIR${NC}"
echo ""
echo -e "创建的文件:"
echo -e "  ✓ .mcp.json"
echo -e "  ✓ $PLAYWRIGHT_CONFIG_PATH"
echo -e "  ✓ $TESTS_DIR/example.spec.ts"
echo -e "  ✓ .gitignore"
if [ "$BACKEND_INITIALIZED" = true ] && [ -n "$BACKEND_DIR" ]; then
    echo -e "  ✓ (后端) $BACKEND_DIR"
fi
echo -e "创建的目录:"
echo -e "  ✓ logs"
echo -e "  ✓ docs"
echo -e "  ✓ tests/e2e"
echo -e "  ✓ playwright"
echo ""
echo -e "🚀 快速开始:"
echo ""
echo -e "  ${CYAN}# 1. 进入项目目录${NC}"
echo -e "  cd $PROJECT_NAME"
echo ""
echo -e "  ${CYAN}# 2. 启动 Claude${NC}"
echo -e "  claude"
echo ""

# ==========================================
# Step 9: 生成 Manifest 文件
# ==========================================
echo -e "\n${YELLOW}[Step 9] 生成安装清单...${NC}"

if [ -z "$PLAYWRIGHT_CONFIG_PATH" ]; then
    if [ -n "$FRONTEND_DIR" ]; then
        PLAYWRIGHT_CONFIG_PATH="$FRONTEND_DIR/playwright.config.ts"
    else
        PLAYWRIGHT_CONFIG_PATH="playwright.config.ts"
    fi
fi

generate_manifest() {
    local manifest_file="$PROJECT_DIR/.template-manifest.json"
    local timestamp=$(date -Iseconds)
    
    # 根据项目结构确定实际路径
    local tests_dir_path="$TESTS_DIR"
    local playwright_config_path="$PLAYWRIGHT_CONFIG_PATH"
    local playwright_dir_path="playwright"
    if [ -n "$FRONTEND_DIR" ]; then
        playwright_dir_path="$FRONTEND_DIR/playwright"
    fi

    local backend_files_json="[]"
    local backend_dirs_json="[]"
    local backend_category=""
    if [ "$BACKEND_INITIALIZED" = true ] && [ -n "$BACKEND_DIR" ]; then
        local backend_files=()
        local backend_path="$PROJECT_DIR/$BACKEND_DIR"
        for f in "main.py" "app.py" "server.js" "package.json" "package-lock.json" "yarn.lock" "pnpm-lock.yaml" "requirements.txt" "pyproject.toml" "go.mod" "Cargo.toml" "src/main.rs"; do
            if [ -f "$backend_path/$f" ]; then
                backend_files+=("$BACKEND_DIR/$f")
            fi
        done
        backend_files_json=$(printf '%s\n' "${backend_files[@]}" | jq -R . | jq -s .)
        backend_dirs_json=$(printf '%s\n' "$BACKEND_DIR" | jq -R . | jq -s .)
        backend_category=$(cat << EOF
    "backend-init": {
      "name": "后端初始化",
      "description": "由 install.sh 初始化的后端骨架",
      "files": $backend_files_json,
      "directories": $backend_dirs_json
    },
EOF
)
    fi

# CI/CD
if prompt_yes_no "是否生成 GitHub Actions CI?" "n"; then
                if [ -f ".github/workflows/ci.yml" ]; then
                    if ! prompt_yes_no "检测到 .github/workflows/ci.yml 已存在，是否覆盖?" "n"; then
                        echo -e "${YELLOW}⏭️ 已跳过 CI 生成${NC}"
                    else
                        ensure_dir ".github/workflows"
                        cat << 'EOF' > .github/workflows/ci.yml
name: CI

on:
    push:
        branches: ["main"]
    pull_request:

jobs:
    build:
        runs-on: ubuntu-latest
        steps:
            - uses: actions/checkout@v4

            - name: Set up Node
                if: hashFiles('package.json') != ''
                uses: actions/setup-node@v4
                with:
                    node-version: 18
                    cache: npm

            - name: Install Node deps
                if: hashFiles('package.json') != ''
                run: npm ci

            - name: Node lint/typecheck/unit
                if: hashFiles('package.json') != ''
                run: |
                    npm run lint --if-present
                    npm run type-check --if-present
                    npm run test:unit --if-present

            - name: Set up Python
                if: hashFiles('requirements.txt') != '' || hashFiles('pyproject.toml') != ''
                uses: actions/setup-python@v5
                with:
                    python-version: '3.11'

            - name: Install Python deps
                if: hashFiles('requirements.txt') != ''
                run: pip install -r requirements.txt

            - name: Python lint/typecheck/unit
                if: hashFiles('requirements.txt') != '' || hashFiles('pyproject.toml') != ''
                run: |
                    ruff check . || true
                    mypy . || true
                    pytest -q || true

            - name: Go test
                if: hashFiles('go.mod') != ''
                run: go test ./...

            - name: Rust test
                if: hashFiles('Cargo.toml') != ''
                run: cargo test
EOF
                    fi
                else
                    ensure_dir ".github/workflows"
                    cat << 'EOF' > .github/workflows/ci.yml
name: CI

on:
    push:
        branches: ["main"]
    pull_request:

jobs:
    build:
        runs-on: ubuntu-latest
        steps:
            - uses: actions/checkout@v4

            - name: Set up Node
                if: hashFiles('package.json') != ''
                uses: actions/setup-node@v4
                with:
                    node-version: 18
                    cache: npm

            - name: Install Node deps
                if: hashFiles('package.json') != ''
                run: npm ci

            - name: Node lint/typecheck/unit
                if: hashFiles('package.json') != ''
                run: |
                    npm run lint --if-present
                    npm run type-check --if-present
                    npm run test:unit --if-present

            - name: Set up Python
                if: hashFiles('requirements.txt') != '' || hashFiles('pyproject.toml') != ''
                uses: actions/setup-python@v5
                with:
                    python-version: '3.11'

            - name: Install Python deps
                if: hashFiles('requirements.txt') != ''
                run: pip install -r requirements.txt

            - name: Python lint/typecheck/unit
                if: hashFiles('requirements.txt') != '' || hashFiles('pyproject.toml') != ''
                run: |
                    ruff check . || true
                    mypy . || true
                    pytest -q || true

            - name: Go test
                if: hashFiles('go.mod') != ''
                run: go test ./...

            - name: Rust test
                if: hashFiles('Cargo.toml') != ''
                run: cargo test
EOF
                fi
fi
    
    cat << MANIFEST_EOF > "$manifest_file"
{
  "version": "7.2",
  "installed_at": "$timestamp",
  "project_name": "$PROJECT_NAME",
  "frontend_dir": "$FRONTEND_DIR",
  "default_port": "$DEFAULT_PORT",
  "categories": {
        "mcp-config": {
      "name": "MCP 配置",
      "description": "Model Context Protocol 服务器配置",
      "files": [".mcp.json"],
      "directories": []
    },
$backend_category
        "tooling-config": {
            "name": "工具链与测试配置",
            "description": "Lint/Test/CI 配置文件",
            "files": [
                ".eslintrc.json",
                ".prettierrc",
                "vitest.config.ts",
                "jest.config.cjs",
                "pytest.ini",
                "ruff.toml",
                "mypy.ini",
                ".github/workflows/ci.yml",
                "Makefile"
            ],
            "directories": [".github/workflows"]
        },
        "test-examples": {
            "name": "测试示例",
            "description": "Playwright 测试模板和配置",
            "files": ["$tests_dir_path/example.spec.ts", "$playwright_config_path"],
            "directories": ["$tests_dir_path", "$playwright_dir_path"]
        },
    "meta-files": {
      "name": "项目元文件",
      "description": "日志、文档目录",
      "files": [],
            "directories": ["logs", "docs"]
    }
  }
}
MANIFEST_EOF

    echo -e "${GREEN}✓ .template-manifest.json${NC}"
}

if prompt_yes_no "是否执行 Step 9（生成安装清单）?" "y"; then
    if [ -f "$PROJECT_DIR/.template-manifest.json" ]; then
        if ! prompt_yes_no "检测到 $PROJECT_DIR/.template-manifest.json 已存在，是否覆盖?" "n"; then
            echo -e "${YELLOW}⏭️ 已跳过 Step 9${NC}"
        else
            generate_manifest
            echo -e "${GREEN}✓ .template-manifest.json${NC}"
        fi
    else
        generate_manifest
        echo -e "${GREEN}✓ .template-manifest.json${NC}"
    fi
else
    echo -e "${YELLOW}⏭️ 已跳过 Step 9${NC}"
fi

else
    echo -e "${YELLOW}⏭️ 已跳过项目配置${NC}"
fi

echo ""
echo -e "${CYAN}💡 提示: 如需卸载模板文件，运行 ./uninstall.sh${NC}"
echo ""
