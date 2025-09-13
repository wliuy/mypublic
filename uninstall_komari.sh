#!/usr/bin/env bash

#
# Komari Monitor All-in-One Smart Uninstaller v1.0
# 自动检测并彻底卸载 Komari Server 和 Agent (支持 Docker, systemd, init.d/procd)
#

# --- 颜色定义 ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# --- 辅助函数 ---
echo_info() { echo -e "${CYAN}▶ $1${NC}"; }
echo_success() { echo -e "${GREEN}✔ $1${NC}"; }
echo_warn() { echo -e "${YELLOW}⚠ $1${NC}"; }
echo_error() { echo -e "${RED}✖ $1${NC}"; }

# --- 卸载逻辑函数 ---

uninstall_docker_components() {
    echo_info "--- 1/4: 正在检测 Docker 安装 ---"
    if ! command -v docker &> /dev/null; then
        echo_info "未安装 Docker，跳过检测。"
        return
    fi

    local containers_found=0
    # Komari Server 通常叫 komari, Agent 叫 komari-agent
    CONTAINERS=("komari" "komari-agent")
    for container in "${CONTAINERS[@]}"; do
        if [ "$(docker ps -a -q -f name=^/${container}$)" ]; then
            echo_warn "  发现 Docker 容器: $container"
            docker stop "$container" >/dev/null 2>&1
            docker rm "$container" >/dev/null 2>&1
            echo_success "    └─ 容器 '$container' 已停止并删除。"
            containers_found=1
        fi
    done

    if [ "$containers_found" -eq 0 ]; then
        echo_info "  未发现 Komari 相关的 Docker 容器。"
    fi
}

uninstall_systemd_components() {
    echo_info "--- 2/4: 正在检测 systemd 服务 ---"
    if ! command -v systemctl &> /dev/null; then
        echo_info "非 systemd 系统，跳过检测。"
        return
    fi

    local services_found=0
    SERVICES=("komari.service" "komari-agent.service")
    for service in "${SERVICES[@]}"; do
        if systemctl list-units --type=service --all | grep -q "$service"; then
            echo_warn "  发现 systemd 服务: $service"
            systemctl stop "$service" >/dev/null 2>&1
            systemctl disable "$service" >/dev/null 2>&1
            rm -f "/etc/systemd/system/${service}"
            echo_success "    └─ 服务 '$service' 已停止、禁用并删除。"
            services_found=1
        fi
    done

    if [ "$services_found" -eq 1 ]; then
        systemctl daemon-reload
        echo_info "  已重新加载 systemd 配置。"
    else
        echo_info "  未发现 Komari 相关的 systemd 服务。"
    fi
}

uninstall_procd_components() {
    echo_info "--- 3/4: 正在检测 init.d (procd) 服务 ---"
    if [ ! -d "/etc/init.d" ]; then
        echo_info "非 init.d 系统 (如 OpenWrt)，跳过检测。"
        return
    fi
    
    local scripts_found=0
    INIT_SCRIPTS=("komari" "komari-agent")
    for script in "${INIT_SCRIPTS[@]}"; do
        if [ -f "/etc/init.d/${script}" ]; then
            echo_warn "  发现 init.d 脚本: $script"
            "/etc/init.d/${script}" stop >/dev/null 2>&1
            "/etc/init.d/${script}" disable >/dev/null 2>&1
            rm -f "/etc/init.d/${script}"
            echo_success "    └─ 脚本 '$script' 已尝试停止并删除。"
            scripts_found=1
        fi
    done

    if [ "$scripts_found" -eq 0 ]; then
        echo_info "  未发现 Komari 相关的 init.d 脚本。"
    fi
}

cleanup_filesystem_and_processes() {
    echo_info "--- 4/4: 正在清理文件系统和残留进程 ---"
    
    # 强制杀死所有可能残留的进程
    local pids=$(ps | grep 'komari' | grep -v 'grep' | awk '{print $1}')
    if [ -n "$pids" ]; then
        echo_warn "  发现残留的 komari 进程 (PID: $pids)，正在强制终止..."
        kill -9 $pids
        echo_success "    └─ 残留进程已终止。"
    fi

    # 删除主程序目录
    if [ -d "/opt/komari" ]; then
        echo_warn "  发现主程序目录: /opt/komari"
        rm -rf "/opt/komari"
        echo_success "    └─ 目录 '/opt/komari' 已删除。"
    else
        echo_info "  未发现主程序目录 /opt/komari。"
    fi
    
    # 清理安装脚本
    rm -f install.sh
    echo_info "  已清理当前目录下的安装脚本 (install.sh)。"
}


# --- 主逻辑 ---

# 1. 检查 root 权限
if [ "$(id -u)" -ne 0 ]; then
   echo_error "此脚本需要以 root 权限运行。请使用 'sudo ./uninstall_komari.sh'"
   exit 1
fi

# 2. 用户最终确认
clear
echo_warn "========================================================"
echo_warn "        Komari Monitor 通用智能卸载程序 v1.0"
echo_warn "========================================================"
echo ""
echo_info "本脚本将全面检测并永久删除本机所有的 Komari Monitor 组件。"
echo_info "清理范围包括："
echo_info " - Docker 容器 (server/agent)"
echo_info " - Systemd 服务 (主流 Linux 系统)"
echo_info " - init.d 服务 (iStoreOS/OpenWrt 系统)"
echo_info " - /opt/komari 等程序文件和目录"
echo_info " - 残留的进程"
echo ""
echo_error "此操作不可逆，请谨慎操作！"
echo ""
read -p "如果您确定要继续，请输入 'yes' 并按回车: " confirm

if [ "$confirm" != "yes" ]; then
    echo_info "操作已取消。"
    exit 0
fi

echo ""
echo_info "开始全面卸载..."
echo "--------------------------------------------------------"

# 3. 执行所有卸载函数
uninstall_docker_components
uninstall_systemd_components
uninstall_procd_components
cleanup_filesystem_and_processes

echo "--------------------------------------------------------"
echo_success "🎉 所有检测和清理操作已执行完毕！"
echo_info "请检查您的 Komari 面板，确认此服务器是否已离线。"
echo ""
