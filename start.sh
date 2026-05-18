#!/usr/bin/env bash
# ============================================================================
# mimo2api Docker 一键启动脚本
# 首次运行会自动准备 .env 和必要目录，然后 docker compose up -d
# ============================================================================

set -euo pipefail

# 切换到脚本所在目录（保证相对路径正确）
cd "$(dirname "$0")"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_ok()   { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_err()  { echo -e "${RED}[ERR]${NC}   $*"; }

# ------ 1. 检查 Docker ------
if ! command -v docker >/dev/null 2>&1; then
    log_err "未检测到 docker。请先安装 Docker Desktop 或 docker-ce。"
    echo "       macOS: https://www.docker.com/products/docker-desktop/"
    echo "       Linux: curl -fsSL https://get.docker.com | sh"
    exit 1
fi
log_ok "已检测到 Docker: $(docker --version)"

# 判断 compose 命令（兼容老版本 docker-compose 和新版 docker compose）
if docker compose version >/dev/null 2>&1; then
    COMPOSE="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
    COMPOSE="docker-compose"
else
    log_err "未检测到 docker compose 插件。请升级 Docker 或单独安装 docker-compose。"
    exit 1
fi
log_ok "已检测到 Compose: $COMPOSE"

# ------ 2. 准备 .env ------
if [ ! -f ".env" ]; then
    log_warn ".env 不存在，正在从 env.example 创建..."
    cp env.example .env
    log_ok ".env 已创建。请稍后编辑此文件，至少设置 MIMO_RELAY_OPENAI_KEY 和 MIMO_WEBUI_PASSWORD。"
else
    log_ok ".env 已存在"
fi

# ------ 3. 准备必要目录和文件 ------
mkdir -p users logs data
log_ok "目录就绪: users/ logs/ data/"

# 没有 model_mapping.json 就建一个空映射
if [ ! -f "model_mapping.json" ]; then
    echo '{}' > model_mapping.json
    log_ok "model_mapping.json 已初始化"
fi

# ------ 4. 启动 ------
log_ok "开始构建并启动容器（首次构建可能需要几分钟）..."
$COMPOSE up -d --build

# ------ 5. 状态展示 ------
echo ""
log_ok "服务已启动。常用命令："
echo "  查看状态:    $COMPOSE ps"
echo "  实时日志:    $COMPOSE logs -f"
echo "  停止服务:    $COMPOSE down"
echo "  重启服务:    $COMPOSE restart"
echo "  重新构建:    $COMPOSE up -d --build"
echo ""
echo "  WebUI 地址:  http://127.0.0.1:8000/"
echo "  API 端点:    http://127.0.0.1:8000/v1"
echo ""
