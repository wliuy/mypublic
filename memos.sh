#!/usr/bin/env bash

#
# AYANG's Memos Manager (提取自AYANG's Toolbox)
#

# --- 颜色定义 (源于 kejilion.sh) ---
gl_hui='\e[37m'
gl_hong='\033[31m'
gl_lv='\033[32m'
gl_huang='\033[33m'
gl_lan='\033[34m'
gl_bai='\033[0m'
gl_zi='\033[35m'
gl_kjlan='\033[96m'

# --- 辅助函数 (源于 kejilion.sh) ---

# 操作完成后的暂停提示
function press_any_key_to_continue() {
    echo -e "\n${gl_huang}按任意键返回主菜单...${gl_bai}"
    read -n 1 -s -r -p ""
}

# 通用安装函数 (源于 kejilion.sh)
install() {
    if [ $# -eq 0 ]; then
        echo "未提供软件包参数!"
        return 1
    fi

    for package in "$@"; do
        if ! command -v "$package" &>/dev/null; then
            echo -e "${gl_huang}正在安装 $package...${gl_bai}"
            if command -v dnf &>/dev/null; then
                dnf install -y "$package"
            elif command -v yum &>/dev/null; then
                yum install -y "$package"
            elif command -v apt &>/dev/null; then
                apt update -y
                apt install -y "$package"
            elif command -v apk &>/dev/null; then
                apk add "$package"
            elif command -v pacman &>/dev/null; then
                pacman -S --noconfirm "$package"
            else
                echo "未知的包管理器!"
                return 1
            fi
        fi
    done
}

# --- Memos 管理函数 ---
function memos_management() {
    local MEMOS_DATA_DIR="/wliuy/memos"
    local SYNC_SCRIPT_BASE="/wliuy/memos/sync_memos"
    local LOG_FILE="/var/log/sync_memos.log"

    function install_memos() {
        clear
        echo -e "${gl_kjlan}正在安装 Memos...${gl_bai}"
        if ! command -v docker &>/dev/null; then
            echo -e "${gl_hong}错误：Docker 未安装。${gl_bai}"
            return
        fi

        if docker ps -a --format '{{.Names}}' | grep -q "^memos$"; then
            echo -e "\n${gl_huang}Memos 容器已存在，无需重复安装。${gl_bai}"
            local public_ip=$(curl -s https://ipinfo.io/ip)
            echo -e "你可以通过 ${gl_lv}http://${public_ip}:5230${gl_bai} 来访问。"
            echo -e "默认登录信息: ${gl_lv}首次访问页面时自行设置。${gl_bai}"
            echo -e "数据库及配置文件保存在: ${gl_lv}${MEMOS_DATA_DIR}${gl_bai}"
            return
        fi

        echo -e "${gl_lan}正在创建数据目录 ${MEMOS_DATA_DIR}...${gl_bai}"
        mkdir -p "${MEMOS_DATA_DIR}"
        echo -e "${gl_lan}正在拉取 neosmemo/memos 镜像并启动容器...${gl_bai}"
        docker pull neosmemo/memos:latest

        echo -e "${gl_lan}正在运行 Memos 容器...${gl_bai}"
        docker run -d --name memos --restart unless-stopped \
            -p 5230:5230 \
            -v "${MEMOS_DATA_DIR}":/var/opt/memos \
            neosmemo/memos:latest

        sleep 5
        if docker ps -q -f name=^memos$; then
            local public_ip=$(curl -s https://ipinfo.io/ip)
            local access_url="http://${public_ip}:5230"
            echo -e "\n${gl_lv}Memos 安装成功！${gl_bai}"
            echo -e "-----------------------------------"
            echo -e "访问地址: ${gl_lv}${access_url}${gl_bai}"
            echo -e "默认登录信息: ${gl_lv}首次访问页面时自行设置。${gl_bai}"
            echo -e "数据库及配置文件保存在: ${gl_lv}${MEMOS_DATA_DIR}${gl_bai}"
            echo -e "-----------------------------------"
        else
            echo -e "${gl_hong}Memos 容器启动失败，请检查 Docker 日志。${gl_bai}"
        fi
    }

    function uninstall_memos() {
        clear
        echo -e "${gl_kjlan}正在卸载 Memos...${gl_bai}"
        if ! docker ps -a --format '{{.Names}}' | grep -q "^memos$"; then
            echo -e "${gl_huang}未找到 Memos 容器，无需卸载。${gl_bai}"
            return
        fi

        echo -e "${gl_hong}警告：此操作将永久删除 Memos 容器、镜像以及所有相关数据！${gl_bai}"
        echo -e "${gl_hong}数据目录包括: ${MEMOS_DATA_DIR}${gl_bai}"
        echo -e "${gl_hong}同步脚本和日志也将被删除。${gl_bai}"
        read -p "如确认继续，请输入 'y' 或 '1' 确认, 其他任意键取消): " confirm
        if [[ "${confirm,,}" == "y" || "$confirm" == "1" ]]; then
            echo -e "${gl_lan}正在停止并删除 memos 容器...${gl_bai}"
            docker stop memos && docker rm memos

            echo -e "${gl_lan}正在删除 memos 镜像...${gl_bai}"
            docker rmi neosmemo/memos:latest

            echo -e "${gl_lan}正在删除本地数据目录 ${MEMOS_DATA_DIR}...${gl_bai}"
            rm -rf "${MEMOS_DATA_DIR}"

            echo -e "${gl_lan}正在删除同步脚本和定时任务...${gl_bai}"
            if [ -d "${SYNC_SCRIPT_BASE}" ]; then
                for script in "${SYNC_SCRIPT_BASE}"/*.sh; do
                    (crontab -l 2>/dev/null | grep -v "$script") | crontab -
                    rm -f "$script"
                done
                rmdir "${SYNC_SCRIPT_BASE}" >/dev/null 2>&1
            fi

            echo -e "${gl_lan}正在清理日志文件 ${LOG_FILE}...${gl_bai}"
            if [ -f "${LOG_FILE}" ]; then
                rm -f "${LOG_FILE}"
            fi

            echo -e "${gl_lv}✅ Memos 已被彻底卸载。${gl_bai}"
        else
            echo -e "${gl_huang}操作已取消。${gl_bai}"
        fi
    }

    function setup_memos_sync() {
        clear
        echo -e "${gl_kjlan}正在配置 Memos 自动备份...${gl_bai}"

        read -p "请输入远程服务器地址 (REMOTE_HOST): " remote_host
        read -p "请输入远程服务器SSH端口 (REMOTE_PORT): " remote_port
        read -p "请输入远程服务器用户名 (REMOTE_USER): " remote_user
        read -s -p "请输入远程服务器密码 (REMOTE_PASS): " remote_pass
        echo ""
        read -p "请输入本地 Memos 数据目录 (LOCAL_DIR, 默认: /wliuy/memos/): " local_dir
        read -p "请输入远程 Memos 数据目录 (REMOTE_DIR, 默认: /wliuy/memos/): " remote_dir

        local_dir=${local_dir:-"/wliuy/memos/"}
        remote_dir=${remote_dir:-"/wliuy/memos/"}

        echo ""

        if [ -z "$remote_host" ] || [ -z "$remote_port" ] || [ -z "$remote_user" ] || [ -z "$remote_pass" ]; then
            echo -e "${gl_hong}输入信息不完整，备份配置已取消。${gl_bai}"
            return
        fi

        # 检查并安装 sshpass
        if ! command -v sshpass &>/dev/null; then
            echo -e "📦 安装 sshpass..."
            install sshpass
        else
            echo -e "📦 sshpass 已安装，跳过安装"
        fi

        # 生成 SSH 密钥
        echo -e "🔐 检查 SSH 密钥..."
        if [ ! -f ~/.ssh/id_rsa ]; then
            echo -e "🗝️ 生成新的 SSH 密钥..."
            ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa
        fi

        # 配置 SSH 免密登录
        echo -e "🔗 配置 SSH 免密登录（端口 $remote_port）..."
        sshpass -p "$remote_pass" ssh-copy-id -p "$remote_port" -o StrictHostKeyChecking=no "${remote_user}@${remote_host}" >/dev/null 2>&1

        # 测试 SSH 连接
        echo -e "✅ 测试免密登录..."
        if ssh -p "$remote_port" -o BatchMode=yes "${remote_user}@${remote_host}" 'echo 连接成功' &>/dev/null; then
            echo -e "✅ SSH 免密登录配置成功！"
        else
            echo -e "❌ SSH 免密登录失败，请检查端口、防火墙或密码。"
            return 1
        fi

        # 创建同步脚本
        echo -e "📝 创建同步脚本 ${SYNC_SCRIPT_BASE}..."
        mkdir -p "${SYNC_SCRIPT_BASE}"
        local sync_script_path="${SYNC_SCRIPT_BASE}/sync_memos_${remote_host}.sh"

        cat >"${sync_script_path}" <<EOF
#!/bin/bash

# 获取命令行参数
REMOTE_HOST="\$1"
REMOTE_PORT="\$2"
REMOTE_USER="\$3"
LOCAL_DIR="\$4"
REMOTE_DIR="\$5"
CONTAINER_NAME="memos"

# 确保远程目录存在
echo "正在检查并创建远程目录: \$REMOTE_DIR"
if ssh -p "\$REMOTE_PORT" "\$REMOTE_USER@\$REMOTE_HOST" "mkdir -p '\$REMOTE_DIR'"; then
    echo "远程目录检查成功或已创建。"
else
    echo "远程目录创建失败，请检查SSH连接和权限。"
    exit 1
fi

# 检查远程 memos 容器是否存在且正在运行
if ssh -p "\$REMOTE_PORT" "\$REMOTE_USER@\$REMOTE_HOST" "docker inspect --format '{{.State.Running}}' \$CONTAINER_NAME" &>/dev/null; then
    echo "停止远程 memos 容器..."
    ssh -p "\$REMOTE_PORT" "\$REMOTE_USER@\$REMOTE_HOST" "docker stop \$CONTAINER_NAME"
    echo "开始同步数据..."
    rsync -avz --checksum --delete -e "ssh -p \$REMOTE_PORT" "\$LOCAL_DIR" "\$REMOTE_USER@\$REMOTE_HOST:\$REMOTE_DIR"
    echo "启动远程 memos 容器..."
    ssh -p "\$REMOTE_PORT" "\$REMOTE_USER@\$REMOTE_HOST" "docker start \$CONTAINER_NAME"
else
    echo "远程 memos 容器未运行或不存在，只同步数据..."
    rsync -avz --checksum --delete -e "ssh -p \$REMOTE_PORT" "\$LOCAL_DIR" "\$REMOTE_USER@\$REMOTE_HOST:\$REMOTE_DIR"
fi
EOF
        chmod +x "${sync_script_path}"

        # 添加定时任务
        local cron_job="0 0 * * * ${sync_script_path} ${remote_host} ${remote_port} ${remote_user} ${local_dir} ${remote_dir} >> ${LOG_FILE} 2>&1"
        echo -e "📅 添加定时任务（每天 0 点执行）..."
        (crontab -l 2>/dev/null | grep -v "${sync_script_path}"; echo "$cron_job") | crontab -

        echo -e "\n🎉 配置完成！每天 0 点将自动备份 Memos 数据到 ${remote_host}。"
    }

    function delete_memos_sync() {
        clear
        echo -e "${gl_kjlan}删除 Memos 备份配置...${gl_bai}"

        local configured_servers=""
        if [ -d "${SYNC_SCRIPT_BASE}" ]; then
            configured_servers=$(ls "${SYNC_SCRIPT_BASE}" | grep "sync_memos_.*.sh" 2>/dev/null | sed 's/sync_memos_//g;s/.sh//g')
        fi

        if [ -z "$configured_servers" ]; then
            echo -e "----------------------------------------"
            echo -e "${gl_huang}未找到任何已配置的远程备份服务器。${gl_bai}"
            return
        fi

        echo -e "----------------------------------------"
        echo -e "${gl_kjlan}已配置的远程服务器:${gl_bai}"
        echo "$configured_servers" | sed 's/^/  /'
        echo -e "----------------------------------------"

        read -p "请输入要删除备份配置的服务器地址: " server_to_delete

        local sync_script_path="${SYNC_SCRIPT_BASE}/sync_memos_${server_to_delete}.sh"
        if [ -f "$sync_script_path" ]; then
            echo -e "${gl_hong}警告：此操作将永久删除服务器 ${server_to_delete} 的备份配置和定时任务。${gl_bai}"
            read -p "你确定要继续吗？ (输入 'y' 或 '1' 确认, 其他任意键取消): " confirm
            if [[ "${confirm,,}" == "y" || "$confirm" == "1" ]]; then
                (crontab -l 2>/dev/null | grep -v "${sync_script_path}") | crontab -
                rm -f "${sync_script_path}"
                echo -e "${gl_lv}✅ 备份配置已成功删除。${gl_bai}"
            else
                echo -e "${gl_huang}操作已取消。${gl_bai}"
            fi
        else
            echo -e "${gl_hong}错误：未找到服务器 ${server_to_delete} 的备份配置。${gl_bai}"
        fi
    }

    function run_memos_sync() {
        clear
        echo -e "${gl_kjlan}立即执行 Memos 备份...${gl_bai}"
        echo -e "----------------------------------------"
        local configured_scripts=""
        if [ -d "${SYNC_SCRIPT_BASE}" ]; then
            configured_scripts=$(ls "${SYNC_SCRIPT_BASE}" | grep "sync_memos_.*.sh" 2>/dev/null)
        fi

        if [ -z "$configured_scripts" ]; then
            echo -e "${gl_huang}未找到任何已配置的远程备份服务器。请先添加备份配置。${gl_bai}"
            return
        fi

        local total_backups=$(echo "$configured_scripts" | wc -l)
        local backup_count=0

        echo -e "${gl_lan}正在对所有已配置的远程服务器执行备份...${gl_bai}\n"

        for script_name in $configured_scripts; do
            local sync_script_path="${SYNC_SCRIPT_BASE}/${script_name}"
            local server_address=$(echo "$script_name" | sed 's/sync_memos_//g;s/.sh//g')

            local cron_line=$(crontab -l 2>/dev/null | grep "$sync_script_path")
            local remote_host=$(echo "$cron_line" | awk '{print $7}')
            local remote_port=$(echo "$cron_line" | awk '{print $8}')
            local remote_user=$(echo "$cron_line" | awk '{print $9}')
            local local_dir=$(echo "$cron_line" | awk '{print $10}')
            local remote_dir=$(echo "$cron_line" | awk '{print $11}')

            if [ -z "$remote_host" ] || [ -z "$remote_port" ] || [ -z "$remote_user" ] || [ -z "$local_dir" ] || [ -z "$remote_dir" ]; then
                echo -e "${gl_hong}错误：未能从定时任务中解析出完整的备份参数。请重新配置。${gl_bai}"
                continue
            fi

            backup_count=$((backup_count + 1))
            echo -e "▶️  (${backup_count}/${total_backups}) 正在备份到服务器: ${gl_lv}${server_address}${gl_bai}"

            bash "$sync_script_path" "$remote_host" "$remote_port" "$remote_user" "$local_dir" "$remote_dir"

            if [ $? -eq 0 ]; then
                echo -e "✅ 备份任务执行完毕。\n"
            else
                echo -e "${gl_hong}❌ 备份任务执行失败。\n"
            fi
        done
    }

    function view_memos_sync_log() {
        clear
        echo -e "${gl_kjlan}Memos 备份日志${gl_bai}"
        echo -e "----------------------------------------"
        if [ -f "${LOG_FILE}" ]; then
            tail -n 50 "${LOG_FILE}"
        else
            echo -e "${gl_huang}日志文件 ${LOG_FILE} 不存在，请先执行备份任务。${gl_bai}"
        fi
        echo -e "----------------------------------------"
    }

    while true; do
        clear
        echo "Memos 管理"
        echo -e "${gl_hong}----------------------------------------${gl_bai}"
        local memos_installed_flag
        if docker ps -a --filter "name=^memos$" --format "{{.Names}}" | grep -q 'memos' &>/dev/null; then
            memos_installed_flag=true
        else
            memos_installed_flag=false
        fi
        local memos_installed_color
        if [ "$memos_installed_flag" == "true" ]; then
            memos_installed_color="${gl_lv}"
        else
            memos_installed_color="${gl_bai}"
        fi

        echo -e "${memos_installed_color}1.    安装 Memos${gl_bai}"
        echo -e "${gl_kjlan}2.    配置自动备份"
        echo -e "${gl_kjlan}3.    查看备份日志"
        echo -e "${memos_installed_color}4.    卸载 Memos${gl_bai}"
        echo -e "${gl_hong}----------------------------------------${gl_bai}"
        echo -e "${gl_kjlan}0.    退出脚本"
        echo -e "${gl_hong}----------------------------------------${gl_bai}"
        read -p "请输入你的选择: " memos_choice
        case $memos_choice in
        1)
            install_memos
            press_any_key_to_continue
            ;;
        2)
            while true; do
                clear
                echo "Memos 自动备份管理"
                echo -e "${gl_hong}----------------------------------------${gl_bai}"
                echo "已配置的远程服务器:"
                local configured_servers=""
                if [ -d "${SYNC_SCRIPT_BASE}" ]; then
                    configured_servers=$(ls "${SYNC_SCRIPT_BASE}" | grep "sync_memos_.*.sh" 2>/dev/null | sed 's/sync_memos_//g;s/.sh//g')
                fi
                if [ -z "$configured_servers" ]; then
                    echo -e "  ${gl_hui}无${gl_bai}"
                else
                    echo "$configured_servers" | sed 's/^/  /'
                fi
                echo -e "${gl_hong}----------------------------------------${gl_bai}"
                echo "1. 添加备份配置"
                echo "2. 删除备份配置"
                echo "3. 立即备份所有"
                echo "4. 查看备份日志"
                echo -e "${gl_hong}----------------------------------------${gl_bai}"
                echo "0. 返回上一级菜单"
                echo -e "${gl_hong}----------------------------------------${gl_bai}"
                read -p "请输入你的选择: " sync_choice
                case $sync_choice in
                1)
                    setup_memos_sync
                    press_any_key_to_continue
                    ;;
                2)
                    delete_memos_sync
                    press_any_key_to_continue
                    ;;
                3)
                    run_memos_sync
                    press_any_key_to_continue
                    ;;
                4)
                    view_memos_sync_log
                    press_any_key_to_continue
                    ;;
                0) break ;;
                *)
                    echo "无效输入"
                    sleep 1
                    ;;
                esac
            done
            ;;
        3)
            view_memos_sync_log
            press_any_key_to_continue
            ;;
        4)
            uninstall_memos
            press_any_key_to_continue
            ;;
        0)
            clear
            exit 0
            ;;
        *)
            echo "无效输入"
            sleep 1
            ;;
        esac
    done
}

# --- 主入口 ---
memos_management
