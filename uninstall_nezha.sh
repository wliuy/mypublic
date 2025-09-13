#!/usr/bin/env bash

#
# Nezha All-in-One Uninstaller v1.0
# 彻底卸载 Nezha Dashboard 和 Agent
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

# --- 主逻辑 ---

# 1. 检查是否以 root 权限运行
if [ "$(id -u)" -ne 0 ]; then
   echo_error "此脚本需要以 root 权限运行。"
   echo_info "请尝试使用: sudo $0"
   exit 1
fi

# 2. 用户确认
clear
echo_warn "====================================================="
echo_warn "                 Nezha 彻底卸载程序"
echo_warn "====================================================="
echo ""
echo_warn "此脚本将从您的系统中永久删除 Nezha Dashboard 和 Agent。"
echo_warn "这包括："
echo_warn "  - Nezha 的所有程序文件 (默认在 /opt/nezha)"
echo_warn "  - 相关的 systemd 服务和配置文件"
echo_warn "  - 当前目录下的安装脚本 (nezha.sh, agent.sh)"
echo ""
echo_error "此操作不可逆，所有数据将会丢失！"
echo ""
read -p "如果您确定要继续，请输入 'yes' 并按回车: " confirm

if [ "$confirm" != "yes" ]; then
    echo_info "操作已取消。"
    exit 0
fi

echo ""
echo_info "开始卸载 Nezha..."
echo "-----------------------------------------------------"

# 3. 停止并禁用服务
echo_info "正在停止并禁用 systemd 服务..."
systemctl stop nezha-dashboard >/dev/null 2>&1
systemctl disable nezha-dashboard >/dev/null 2>&1
systemctl stop nezha-agent >/dev/null 2>&1
systemctl disable nezha-agent >/dev/null 2>&1
echo_success "服务已停止并禁用。"

# 4. 删除 systemd 服务文件
echo_info "正在删除 systemd 服务文件..."
rm -f /etc/systemd/system/nezha-dashboard.service
rm -f /etc/systemd/system/nezha-agent.service
echo_success "服务文件已删除。"

# 5. 重新加载 systemd 配置
echo_info "正在重新加载 systemd 管理器配置..."
systemctl daemon-reload
echo_success "systemd 配置已重载。"

# 6. 删除程序和数据目录
NEZHA_DIR="/opt/nezha"
if [ -d "$NEZHA_DIR" ]; then
    echo_info "正在删除 Nezha 主程序目录: $NEZHA_DIR ..."
    rm -rf "$NEZHA_DIR"
    echo_success "主程序目录已删除。"
else
    echo_info "未找到 Nezha 主程序目录 ($NEZHA_DIR)，跳过。"
fi

# 7. 删除安装脚本
echo_info "正在清理当前目录下的安装脚本..."
rm -f ./nezha.sh
rm -f ./agent.sh
echo_success "安装脚本已清理。"

echo "-----------------------------------------------------"
echo_success "🎉 Nezha 已被彻底卸载！"
echo_info "系统已清理完毕。"
echo ""
