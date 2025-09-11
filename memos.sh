#!/usr/bin/env bash

#
# Memos 独立管理脚本
# (提取自 AYANG's Toolbox)
#
# 功能:
# - 安装/卸载 Memos (Docker版)
# - 管理 Memos 数据到远程服务器的自动备份
#

# --- 颜色定义 ---
gl_hui='\e[37m'
gl_hong='\033[31m'
gl_lv='\033[32m'
gl_huang='\033[33m'
gl_lan='\033[34m'
gl_bai='\033[0m'
gl_zi='\033[35m'
gl_kjlan='\033[96m'

# --- 全局配置 ---
# Memos 数据和备份脚本的存放路径
readonly MEMOS_DATA_DIR="/wliuy/memos"
readonly SYNC_SCRIPT_BASE="/wliuy/memos/sync_memos"
readonly LOG_FILE="/var/log/sync_memos.log"


# --- 辅助函数 ---

# 操作完成后的暂停提示
function press_any_key_to_continue() {
    echo -e "\n${gl_huang}按任意键返回主菜单...${gl_bai}"
    read -n 1 -s -r -p ""
}

# 通用安装函数
function install() {
    if [ $# -eq 0 ]; then
        echo "未提供软件包参数!"
        return 1
    fi

    for package in "$@"; do
        if ! command -v "$package" &>/dev/null; then
            echo -e "${gl_huang}正在安装 $package...${gl_bai}"
            if command -v apt &>/dev/null; then
                apt-get update -y
                apt-get install -y "$package"
            elif command -v yum &>/dev/null; then
                yum install -y "$package"
            elif command -v dnf &>/dev/null; then
                dnf install -y "$package"
            else
                echo -e "${gl_hong}错误: 不支持的包管理器，请手动安装 $package。${gl_bai}"
                return 1
            fi
        fi
    done
}


# --- Memos 功能函数 ---

function memos_management() {

    function install_memos() {
        clear; echo -e "${gl_kjlan}正在安装 Memos...${gl_bai}";
        if ! command -v docker &>/dev/null; then echo -e "${gl_hong}错误：Docker 未安装。${gl_bai}"; return; fi

        if docker ps -a --format '{{.Names}}' | grep -q "^memos$"; then
            echo -e "\n${gl_huang}Memos 容器已存在，无需重复安装。${gl_bai}"
            local public_ip=$(curl -s https://ipinfo.io/ip)
            echo -e "你可以通过 ${gl_lv}http://${public_ip}:5230${gl_bai} 来访问。"
            echo -e "默认登录信息: ${gl_lv}首次访问页面时自行设置。${gl_bai}"
            echo -e "数据库及配置文件保存在: ${gl_lv}${MEMOS_DATA_DIR}${gl_bai}"
            return
        fi

        echo -e "${gl_lan}正在创建数据目录 ${MEMOS_DATA_DIR}...${gl_bai}"; mkdir -p ${MEMOS_DATA_DIR}
        echo -e "${gl_lan}正在拉取 neosmemo/memos 镜像并启动容器...${gl_bai}"; docker pull neosmemo/memos:latest

        echo -e "${gl_lan}正在运行 Memos 容器...${gl_bai}";
        docker run -d --name memos --restart unless-stopped \
            -p 5230:5230 \
            -v ${MEMOS_DATA_DIR}:/var/opt/memos \
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
        clear; echo -e "${gl_kjlan}正在卸载 Memos...${gl_bai}"
        if ! docker ps -a --format '{{.Names}}' | grep -q "^memos$"; then
            echo -e "${gl_huang}未找到 Memos 容器，无需卸载。${gl_bai}"; return;
        fi

        echo -e "${gl_hong}警告：此操作将永久删除 Memos 容器、镜像以及所有相关数据！${gl_bai}"
        echo -e "${gl_hong}数据目录包括: ${MEMOS_DATA_DIR}${gl_bai}"
        read -p "如确认继续，请输入 'y' 或 '1' 确认, 其他任意键取消): " confirm
        if [[ "${confirm,,}" == "y" || "$confirm" == "1" ]]; then
            echo -e "${gl_lan}正在停止并删除 memos 容器...${gl_bai}"
            docker stop memos && docker rm memos
            
            echo -e "${gl_lan}正在删除 memos 镜像...${gl_bai}"
            docker rmi neosmemo/memos:latest
            
            echo -e "${gl_lan}正在删除本地数据目录 ${MEMOS_DATA_DIR}...${gl_bai}"
            rm -rf ${MEMOS_DATA_DIR}
            
            echo -e "${gl_lan}正在删除同步脚本和定时任务...${gl_bai}"
            if [ -d "${SYNC_SCRIPT_BASE}" ]; then
                for script in "${SYNC_SCRIPT_BASE}"/*.sh; do
                    ( crontab -l 2>/dev/null | grep -v "$script" ) | crontab -
                    rm -f "$script"
                done
                rmdir "${SYNC_SCRIPT_BASE}" >/dev/null 2>&1
            fi
            
            echo -e "${gl_lan}正在清理日志文件 ${LOG_FILE}...${gl_bai}"
            if [ -f "${LOG_FILE}" ]; then
                rm -f "${LOG_FILE}"
            fi
            
            echo -e "\n${gl_lv}✅ Memos 已被彻底卸载。${gl_bai}"
        else
            echo -e "${gl_huang}操作已取消。${gl_bai}"
        fi
    }

    function setup_memos_sync() {
        clear; echo -e "${gl_kjlan}正在配置 Memos 自动备份...${gl_bai}"

        read -p "请输入远程服务器地址 (IP/域名): " remote_host
        read -p "请输入远程服务器SSH端口 (默认 22): " remote_port
        read -p "请输入远程服务器用户名 (默认 root): " remote_user
        read -s -p "请输入远程服务器密码: " remote_pass
        echo ""
        read -p "请输入远程备份目录 (默认: /wliuy/memos_backup/): " remote_dir
        read -p "请输入同步频率 (每天的几点, 0-23点, 默认 '0'): " cron_hour

        # 设置默认值
        remote_port=${remote_port:-"22"}
        remote_user=${remote_user:-"root"}
        local local_dir="${MEMOS_DATA_DIR}"
        remote_dir=${remote_dir:-"/wliuy/memos_backup/"}
        cron_hour=${cron_hour:-"0"}
        
        # 检查关键信息
        if [[ -z "$remote_host" || -z "$remote_pass" ]]; then
            echo -e "${gl_hong}\n错误：远程主机地址和密码不能为空。操作已取消。${gl_bai}"
            return
        fi

        echo -e "\n${gl_kjlan}--- 确认信息 ---${gl_bai}"
        echo -e "${gl_kjlan}本地源目录: ${gl_bai}${local_dir}"
        echo -e "${gl_kjlan}远程目标:   ${gl_bai}${remote_user}@${remote_host}:${remote_dir}"
        echo -e "${gl_kjlan}SSH端口:    ${gl_bai}${remote_port}"
        echo -e "${gl_kjlan}同步频率:   ${gl_bai}每天 ${cron_hour} 点"
        echo -e "${gl_kjlan}------------------${gl_bai}"

        read -p "$(echo -e "${gl_huang}请确认信息无误，是否继续？ (y/N): ${gl_bai}")" confirm
        if [[ ! "${confirm,,}" =~ ^(y|yes|1)$ ]]; then
            echo -e "${gl_hong}操作已取消。${gl_bai}"
            return
        fi

        # 检查并安装 sshpass 和 rsync
        install sshpass rsync

        # 配置 SSH 免密登录
        mkdir -p ~/.ssh
        chmod 700 ~/.ssh
        if [ ! -f ~/.ssh/id_rsa ]; then
            echo -e "🗝️  生成新的 SSH 密钥..."
            ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa
        fi
        
        echo -e "\n${gl_lv}▶️ 正在配置 SSH 免密登录...${gl_bai}"
        sshpass -p "$remote_pass" ssh-copy-id -p "$remote_port" -o StrictHostKeyChecking=no "${remote_user}@${remote_host}" &>/dev/null

        if [ $? -eq 0 ]; then
            echo -e "  ✅ SSH 免密登录配置成功！"
        else
            echo -e "  ${gl_hong}❌ SSH 免密登录配置失败。请检查密码或SSH配置。${gl_bai}"
            return
        fi

        # 创建同步脚本
        mkdir -p "${SYNC_SCRIPT_BASE}"
        local sync_script_path="${SYNC_SCRIPT_BASE}/sync_memos_to_${remote_host}.sh"
        
        cat > "$sync_script_path" <<EOF
#!/usr/bin/env bash
# =======================================================
# Memos 自动备份脚本
# 同步源: ${local_dir}
# 同步目标: ${remote_user}@${remote_host}:${remote_dir}
# =======================================================
# 确保远程目录存在
ssh -p ${remote_port} ${remote_user}@${remote_host} "mkdir -p '${remote_dir}'"

# 执行 rsync 同步
rsync -avz --delete -e "ssh -p ${remote_port}" "${local_dir}/" "${remote_user}@${remote_host}:${remote_dir}"

if [ \$? -eq 0 ]; then
    echo "Memos 备份成功: \$(date)"
else
    echo "Memos 备份失败: \$(date)"
fi
EOF
        chmod +x "$sync_script_path"
        echo -e "  ✅ 脚本已成功创建在：${gl_lv}${sync_script_path}${gl_bai}"

        # 设置定时任务
        local CRON_JOB="0 ${cron_hour} * * * ${sync_script_path} >> ${LOG_FILE} 2>&1"
        ( crontab -l 2>/dev/null | grep -v "${sync_script_path}" ; echo "$CRON_JOB" ) | crontab -

        if [ $? -eq 0 ]; then
            echo -e "  ✅ Cron 任务已成功设置！"
            echo -e "  任务将在每天 ${cron_hour} 点自动执行。"
        else
            echo -e "  ${gl_hong}❌ 添加 Cron 任务失败。请手动检查并添加。${gl_bai}"
        fi

        echo -e "\n🎉 配置完成！"
    }
    
    function delete_memos_sync() {
        clear; echo -e "${gl_kjlan}删除 Memos 备份配置...${gl_bai}"
        local configured_servers=""
        if [ -d "${SYNC_SCRIPT_BASE}" ]; then
            configured_servers=$(ls "${SYNC_SCRIPT_BASE}" | grep "sync_memos_to_.*.sh" 2>/dev/null | sed 's/sync_memos_to_//g;s/.sh//g')
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

        local sync_script_path="${SYNC_SCRIPT_BASE}/sync_memos_to_${server_to_delete}.sh"
        if [ -f "$sync_script_path" ]; then
            echo -e "${gl_hong}警告：此操作将永久删除服务器 ${server_to_delete} 的备份配置和定时任务。${gl_bai}"
            read -p "你确定要继续吗？ (输入 'y' 或 '1' 确认, 其他任意键取消): " confirm
            if [[ "${confirm,,}" == "y" || "$confirm" == "1" ]]; then
                ( crontab -l 2>/dev/null | grep -v "${sync_script_path}" ) | crontab -
                rm -f "${sync_script_path}"
                echo -e "\n${gl_lv}✅ 备份配置已成功删除。${gl_bai}"
            else
                echo -e "${gl_huang}操作已取消。${gl_bai}"
            fi
        else
            echo -e "${gl_hong}错误：未找到服务器 ${server_to_delete} 的备份配置。${gl_bai}"
        fi
    }

    function run_memos_sync() {
        clear; echo -e "${gl_kjlan}立即执行 Memos 备份...${gl_bai}"
        echo "----------------------------------------"
        if [ ! -d "${SYNC_SCRIPT_BASE}" ] || [ -z "$(ls -A "${SYNC_SCRIPT_BASE}" 2>/dev/null)" ]; then
            echo -e "${gl_huang}未找到任何已配置的远程备份服务器。请先添加备份配置。${gl_bai}"
            return
        fi
        
        local scripts=("$SYNC_SCRIPT_BASE"/*.sh)
        local total_backups=${#scripts[@]}
        local backup_count=0
        
        echo -e "${gl_lan}正在对所有已配置的远程服务器执行备份...${gl_bai}\n"
        
        for script_path in "${scripts[@]}"; do
            local server_address=$(basename "$script_path" | sed 's/sync_memos_to_//g;s/.sh//g')
            backup_count=$((backup_count + 1))
            echo -e "▶️  (${backup_count}/${total_backups}) 正在备份到服务器: ${gl_lv}${server_address}${gl_bai}"
            
            bash "$script_path"
            
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
        echo "----------------------------------------"
        if [ -f "$LOG_FILE" ]; then
            tail -n 50 "$LOG_FILE"
        else
            echo -e "${gl_huang}日志文件 ${LOG_FILE} 不存在。请先运行一次同步任务。${gl_bai}"
        fi
    }

    # Memos 管理主菜单循环
    while true; do
        clear
        echo "Memos 管理"
        echo -e "${gl_hong}----------------------------------------${gl_bai}"
        
        local memos_installed="false"
        if docker ps -a --format '{{.Names}}' | grep -q 'memos'; then memos_installed="true"; fi

        local install_option_color="$gl_bai"
        if [ "$memos_installed" == "true" ]; then install_option_color="$gl_lv"; fi

        echo -e "${install_option_color}1.    ${gl_bai}安装 Memos"
        echo -e "${gl_kjlan}2.    ${gl_bai}配置/管理自动备份"
        echo -e "${install_option_color}3.    ${gl_bai}卸载 Memos"
        echo -e "${gl_hong}----------------------------------------${gl_bai}"
        echo -e "${gl_kjlan}0.    ${gl_bai}退出脚本"
        echo -e "${gl_hong}----------------------------------------${gl_bai}"
        read -p "请输入你的选择: " memos_choice
        case $memos_choice in
            1) install_memos; press_any_key_to_continue ;;
            2)
                while true; do
                    clear
                    echo "Memos 自动备份管理"
                    echo -e "${gl_hong}----------------------------------------${gl_bai}"
                    echo "已配置的远程服务器:"
                    local configured_servers=""
                    if [ -d "${SYNC_SCRIPT_BASE}" ]; then
                        configured_servers=$(ls "${SYNC_SCRIPT_BASE}" | grep "sync_memos_to_.*.sh" 2>/dev/null | sed 's/sync_memos_to_//g;s/.sh//g')
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
                        1) setup_memos_sync; press_any_key_to_continue ;;
                        2) delete_memos_sync; press_any_key_to_continue ;;
                        3) run_memos_sync; press_any_key_to_continue ;;
                        4) view_memos_sync_log; press_any_key_to_continue ;;
                        0) break ;;
                        *) echo "无效输入"; sleep 1 ;;
                    esac
                done
                ;;
            3) uninstall_memos; press_any_key_to_continue ;;
            0) break ;;
            *) echo "无效输入"; sleep 1 ;;
        esac
    done
}

# --- 脚本主入口 ---

# 检查是否为 root 用户
if [[ "$(id -u)" -ne 0 ]]; then
    echo -e "${gl_hong}错误：此脚本需要以 root 权限运行。请使用 'sudo ./memos_manager.sh' 运行。${gl_bai}"
    exit 1
fi

# 检查 Docker 是否已安装
if ! command -v docker &> /dev/null; then
    echo -e "${gl_hong}错误: Docker 未安装。此脚本依赖 Docker，请先安装 Docker。${gl_bai}"
    exit 1
fi

# 调用主函数
memos_management

# 退出脚本
echo -e "${gl_lv}已退出 Memos 管理脚本。${gl_bai}"
exit 0
