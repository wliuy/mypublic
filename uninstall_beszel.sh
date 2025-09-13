#!/usr/bin/env bash

#
# Beszel All-in-One Uninstaller v1.1
# 彻底卸载 Beszel Hub 和 Agent (包括 Docker 和二进制文件方式)
#

# --- 颜色定义 ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# --- 辅助函数 ---
echo_info() {
    echo -e "${CYAN}▶ $1${NC}"
}

echo_success() {
    echo -e "${GREEN}✔ $1${NC}"
}

echo_warn() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

echo_error() {
    echo -e "${RED}✖ $1${NC}"
}

# --- 卸载逻辑 ---

# 检查是否以 root 权限运行
if [ "$(id -u)" -ne 0 ]; then
   echo_error "此脚本需要以 root 权限运行。"
   echo_info "请尝试使用: sudo $0"
   exit 1
fi

# 用户最终确认
clear
echo_warn "=========================================================="
echo_warn "                Beszel 彻底卸载程序"
echo_warn "=========================================================="
echo ""
echo_warn "此脚本将全面检测并永久删除 Beszel Hub 和 Agent 的所有组件。"
echo_warn "清理范围包括："
echo_warn "  - Docker 容器 (beszel, beszel-agent)"
echo_warn "  - Docker 数据卷 (beszel_data)"
echo_warn "  - systemd 服务 (beszel.service, beszel-agent.service)"
echo_warn "  - 程序文件 (/usr/local/bin/beszel, /usr/local/bin/beszel-agent)"
echo_warn "  - 配置和数据目录 (/etc/beszel, /var/lib/beszel)"
echo_warn "  - 并会提示您清理无用的 Docker 镜像"
echo ""
echo_error "此操作不可逆，所有相关数据将会丢失！"
echo ""
read -p "如果您确定要继续，请输入 'yes' 并按回车: " confirm

if [ "$confirm" != "yes" ]; then
    echo_info "操作已取消。"
    exit 0
fi

echo ""
echo_info "开始全面卸载 Beszel..."
echo "----------------------------------------------------------"

# 1. 清理 Docker 相关组件
if command -v docker &> /dev/null; then
    echo_info "正在检查 Docker 组件..."
    
    # 停止并删除容器
    CONTAINERS_TO_REMOVE=("beszel" "beszel-agent")
    for container in "${CONTAINERS_TO_REMOVE[@]}"; do
        if [ "$(docker ps -a -q -f name=^/${container}$)" ]; then
            echo_info "  发现并停止/删除容器: $container"
            docker stop "$container" >/dev/null 2>&1
            docker rm "$container" >/dev/null 2>&1
            echo_success "    └─ 容器 $container 已删除。"
        else
            echo_info "  未发现容器: $container"
        fi
    done

    # 删除数据卷
    VOLUME_TO_REMOVE="beszel_data"
    if [ "$(docker volume ls -q -f name=${VOLUME_TO_REMOVE})" ]; then
        echo_info "  发现并删除数据卷: $VOLUME_TO_REMOVE"
        docker volume rm "$VOLUME_TO_REMOVE" >/dev/null 2>&1
        echo_success "    └─ 数据卷 $VOLUME_TO_REMOVE 已删除。"
    else
        echo_info "  未发现数据卷: $VOLUME_TO_REMOVE"
    fi
else
    echo_info "未检测到 Docker, 跳过 Docker 组件清理。"
fi

# 2. 清理二进制安装 (Systemd 服务)
echo_info "正在检查二进制安装的 systemd 服务..."
SERVICES_TO_REMOVE=("beszel.service" "beszel-agent.service")
SERVICES_WERE_REMOVED=false
for service in "${SERVICES_TO_REMOVE[@]}"; do
    if [ -f "/etc/systemd/system/${service}" ]; then
        echo_info "  发现并停止/禁用/删除服务: $service"
        systemctl stop "$service" >/dev/null 2>&1
        systemctl disable "$service" >/dev/null 2>&1
        rm -f "/etc/systemd/system/${service}"
        echo_success "    └─ 服务 $service 已删除。"
        SERVICES_WERE_REMOVED=true
    else
        echo_info "  未发现服务: $service"
    fi
done

if [ "$SERVICES_WERE_REMOVED" = true ]; then
    echo_info "  正在重新加载 systemd 管理器配置..."
    systemctl daemon-reload
    echo_success "    └─ systemd 配置已重载。"
fi

# 3. 清理文件系统中的残留文件
echo_info "正在清理文件系统..."
FILES_TO_REMOVE=(
    "/usr/local/bin/beszel"
    "/usr/local/bin/beszel-agent"
    "/tmp/install-hub.sh"
)
for file in "${FILES_TO_REMOVE[@]}"; do
    if [ -f "$file" ]; then
        rm -f "$file"
        echo_success "  文件已删除: $file"
    fi
done

DIRS_TO_REMOVE=(
    "/etc/beszel"
    "/var/lib/beszel"
)
for dir in "${DIRS_TO_REMOVE[@]}"; do
    if [ -d "$dir" ]; then
        rm -rf "$dir"
        echo_success "  目录已删除: $dir"
    fi
done

# 4. 提示清理 Docker 镜像
if command -v docker &> /dev/null; then
    echo ""
    echo_warn "----------------------------------------------------------"
    read -p "是否需要清理不再使用的 Docker 镜像 (例如 henrygd/beszel)？[y/N]: " prune_images
    if [[ "${prune_images,,}" == "y" ]]; then
        echo_info "正在运行 docker image prune -af ..."
        docker image prune -af
        echo_success "无用的 Docker 镜像已清理。"
    else
        echo_info "已跳过清理 Docker 镜像。"
    fi
fi

echo "----------------------------------------------------------"
echo_success "🎉 Beszel 已被彻底卸载！"
echo_info "系统已完成全面清理。"
echo ""
