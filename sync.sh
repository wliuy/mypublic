#!/usr/bin/env bash

# =======================================================
# 交互式通用文件同步管理工具
# 版本：1.0.0
# 功能：增删改查自动化 rsync 同步任务
# =======================================================

# --- 全局配置与颜色定义 ---
SYNC_SCRIPT_DIR="$HOME/sync_scripts"
LOG_FILE="/var/log/auto_sync.log"

gl_hong='\033[31m'
gl_lv='\033[32m'
gl_huang='\033[33m'
gl_bai='\033[0m'
gl_zi='\033[35m'
gl_kjlan='\033[96m'

# --- 辅助函数 ---

function check_dependency() {
    local dep="$1"
    if ! command -v "$dep" &>/dev/null; then
        echo -e "${gl_hong}错误：未找到命令 '$dep'。正在尝试安装...${gl_bai}"
        if command -v apt &>/dev/null; then
            sudo apt update && sudo apt install -y "$dep"
        elif command -v yum &>/dev/null; then
            sudo yum install -y "$dep"
        elif command -v dnf &>/dev/null; then
            sudo dnf install -y "$dep"
        else
            echo -e "${gl_hong}错误：无法自动安装 '$dep'。请手动安装后再试。${gl_bai}"
            exit 1
        fi
    fi
}

function press_any_key_to_continue() {
    echo -e "\n${gl_huang}按任意键继续...${gl_bai}"
    read -n 1 -s -r -p ""
}

# --- 核心功能函数 ---

# 1. 添加新的同步任务
function add_sync_task() {
    clear
    echo -e "${gl_kjlan}▶️ 添加新的同步任务${gl_bai}"
    echo "----------------------------------------"
    check_dependency "rsync"
    check_dependency "ssh"
    check_dependency "sshpass"

    echo -e "${gl_huang}提示：此脚本将引导您配置一个每日自动同步任务。${gl_bai}"
    echo -e "${gl_huang}警告：同步将使用 rsync 的 --delete 参数，远程目录中多余的文件将被删除。${gl_bai}"
    echo ""

    read -p "$(echo -e "${gl_lv}1. 请输入要同步的本地文件夹完整路径: ${gl_bai}")" SOURCE_DIR
    if [ ! -d "$SOURCE_DIR" ]; then
        echo -e "${gl_hong}错误：本地源文件夹 '$SOURCE_DIR' 不存在。${gl_bai}"
        press_any_key_to_continue
        return
    fi
    echo ""

    read -p "$(echo -e "${gl_lv}2. 请输入远程服务器地址 (IP/域名): ${gl_bai}")" REMOTE_HOST
    read -p "$(echo -e "${gl_lv}3. 请输入远程服务器SSH端口 (默认 22): ${gl_bai}")" REMOTE_PORT
    REMOTE_PORT=${REMOTE_PORT:-22}
    read -p "$(echo -e "${gl_lv}4. 请输入远程服务器用户名: ${gl_bai}")" REMOTE_USER
    read -s -p "$(echo -e "${gl_lv}5. 请输入远程服务器密码: ${gl_bai}")" REMOTE_PASS
    echo ""
    echo ""

    read -p "$(echo -e "${gl_lv}6. 请输入远程目标文件夹完整路径: ${gl_bai}")" DEST_DIR
    echo ""

    read -p "$(echo -e "${gl_lv}7. 请输入同步频率 (每天的几点，0-23点，如 '0' 表示凌晨0点): ${gl_bai}")" CRON_HOUR
    CRON_HOUR=${CRON_HOUR:-0}

    echo -e "${gl_kjlan}----------------------------------------"
    echo -e "            确认信息"
    echo -e "----------------------------------------${gl_bai}"
    echo -e "${gl_kjlan}本地源目录: ${gl_bai}${SOURCE_DIR}"
    echo -e "${gl_kjlan}远程目标:   ${gl_bai}${REMOTE_USER}@${REMOTE_HOST}:${DEST_DIR}"
    echo -e "${gl_kjlan}SSH端口:    ${gl_bai}${REMOTE_PORT}"
    echo -e "${gl_kjlan}同步频率:   ${gl_bai}每天 ${CRON_HOUR} 点"
    echo -e "${gl_kjlan}----------------------------------------${gl_bai}"

    read -p "$(echo -e "${gl_huang}请确认信息无误，是否继续？ (y/N): ${gl_bai}")" confirm
    if [[ ! "${confirm,,}" =~ ^(y|yes)$ ]]; then
        echo -e "${gl_hong}操作已取消。${gl_bai}"
        press_any_key_to_continue
        return
    fi

    echo -e "\n${gl_lv}▶️ 正在配置 SSH 免密登录...${gl_bai}"
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh
    if [ ! -f ~/.ssh/id_rsa ]; then
        echo -e "  🗝️ 生成新的 SSH 密钥..."
        ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa
    fi
    sshpass -p "$REMOTE_PASS" ssh-copy-id -p "$REMOTE_PORT" -o StrictHostKeyChecking=no "${REMOTE_USER}@${REMOTE_HOST}" &>/dev/null

    if [ $? -eq 0 ]; then
        echo -e "  ✅ SSH 免密登录配置成功！"
    else
        echo -e "  ${gl_hong}❌ SSH 免密登录配置失败。请检查密码或SSH配置。${gl_bai}"
        press_any_key_to_continue
        return
    fi

    # 创建同步脚本
    mkdir -p "$SYNC_SCRIPT_DIR"
    local SCRIPT_FILE="${SYNC_SCRIPT_DIR}/sync_${REMOTE_HOST}_${REMOTE_USER}.sh"
    
    cat > "$SCRIPT_FILE" <<EOF
#!/usr/bin/env bash
# =======================================================
# 自动同步脚本 (由 sync_manager.sh 生成)
# 同步源: ${SOURCE_DIR}
# 同步目标: ${REMOTE_USER}@${REMOTE_HOST}:${DEST_DIR}
# =======================================================
# 确保远程目录存在
ssh -p ${REMOTE_PORT} ${REMOTE_USER}@${REMOTE_HOST} "mkdir -p '${DEST_DIR}'"

# 执行 rsync 同步
rsync -avz --delete -e "ssh -p ${REMOTE_PORT}" "${SOURCE_DIR}/" "${REMOTE_USER}@${REMOTE_HOST}:${DEST_DIR}"

if [ \$? -eq 0 ]; then
    echo "同步成功: \$(date)"
else
    echo "同步失败: \$(date)"
fi
EOF

    chmod +x "$SCRIPT_FILE"
    echo -e "  ✅ 脚本已成功创建在：${gl_lv}${SCRIPT_FILE}${gl_bai}"

    # 设置定时任务
    local CRON_JOB="0 ${CRON_HOUR} * * * ${SCRIPT_FILE} >> ${LOG_FILE} 2>&1"
    ( sudo crontab -l 2>/dev/null | grep -v "${SCRIPT_FILE}" ; echo "$CRON_JOB" ) | sudo crontab -

    if [ $? -eq 0 ]; then
        echo -e "  ✅ Cron 任务已成功设置！"
        echo -e "  任务将在每天 ${CRON_HOUR} 点自动执行。"
    else
        echo -e "  ${gl_hong}❌ 添加 Cron 任务失败。请手动检查并添加。${gl_bai}"
    fi

    echo -e "\n${gl_lv}🎉 配置完成！${gl_bai}"
    press_any_key_to_continue
}

# 2. 查看已添加的同步任务
function list_sync_tasks() {
    clear
    echo -e "${gl_kjlan}▶️ 已配置的同步任务${gl_bai}"
    echo "----------------------------------------"
    
    if [ ! -d "$SYNC_SCRIPT_DIR" ] || [ -z "$(ls -A "$SYNC_SCRIPT_DIR" 2>/dev/null)" ]; then
        echo -e "${gl_huang}没有找到已配置的同步任务。${gl_bai}"
        press_any_key_to_continue
        return
    fi

    local i=1
    for script in "$SYNC_SCRIPT_DIR"/*.sh; do
        local cron_line=$(sudo crontab -l 2>/dev/null | grep "$script" | head -n 1)
        local source_dir=$(grep '^# 同步源:' "$script" | cut -d':' -f2 | xargs)
        local remote_info=$(grep '^# 同步目标:' "$script" | cut -d':' -f2- | xargs)
        local cron_time="未找到"
        if [[ -n "$cron_line" ]]; then
            cron_time=$(echo "$cron_line" | awk '{print $2 "点"}')
        fi
        
        echo -e "${gl_lv}--- 任务 ${i} ---${gl_bai}"
        echo -e "${gl_kjlan}文件:   ${gl_bai}${script}"
        echo -e "${gl_kjlan}来源:   ${gl_bai}${source_dir}"
        echo -e "${gl_kjlan}目标:   ${gl_bai}${remote_info}"
        echo -e "${gl_kjlan}频率:   ${gl_bai}每天 ${cron_time}"
        echo -e "----------------------------------------"
        i=$((i+1))
    done
    
    press_any_key_to_continue
}

# 3. 立即执行同步任务
function run_sync_task() {
    clear
    echo -e "${gl_kjlan}▶️ 立即执行同步任务${gl_bai}"
    echo "----------------------------------------"

    if [ ! -d "$SYNC_SCRIPT_DIR" ] || [ -z "$(ls -A "$SYNC_SCRIPT_DIR" 2>/dev/null)" ]; then
        echo -e "${gl_huang}没有找到已配置的同步任务。${gl_bai}"
        press_any_key_to_continue
        return
    fi

    local scripts=("$SYNC_SCRIPT_DIR"/*.sh)
    for i in "${!scripts[@]}"; do
        echo -e "${gl_lv}$((i+1)). ${gl_bai}$(basename "${scripts[$i]}")"
    done
    echo -e "\n${gl_huang}0. 返回${gl_bai}"
    echo "----------------------------------------"

    read -p "$(echo -e "${gl_lv}请选择要立即执行的任务编号: ${gl_bai}")" choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#scripts[@]} ]; then
        local script_to_run="${scripts[$((choice-1))]}"
        echo -e "\n${gl_lv}正在执行 ${script_to_run} ...${gl_bai}"
        bash "$script_to_run"
        echo -e "\n${gl_lv}执行完成。${gl_bai}"
    elif [ "$choice" -eq 0 ]; then
        echo -e "${gl_huang}操作已取消。${gl_bai}"
    else
        echo -e "${gl_hong}无效输入。${gl_bai}"
    fi

    press_any_key_to_continue
}

# 4. 删除同步任务
function delete_sync_task() {
    clear
    echo -e "${gl_kjlan}▶️ 删除同步任务${gl_bai}"
    echo "----------------------------------------"

    if [ ! -d "$SYNC_SCRIPT_DIR" ] || [ -z "$(ls -A "$SYNC_SCRIPT_DIR" 2>/dev/null)" ]; then
        echo -e "${gl_huang}没有找到已配置的同步任务。${gl_bai}"
        press_any_key_to_continue
        return
    fi

    local scripts=("$SYNC_SCRIPT_DIR"/*.sh)
    for i in "${!scripts[@]}"; do
        echo -e "${gl_lv}$((i+1)). ${gl_bai}$(basename "${scripts[$i]}")"
    done
    echo -e "\n${gl_hong}0. 返回${gl_bai}"
    echo "----------------------------------------"
    
    read -p "$(echo -e "${gl_lv}请选择要删除的任务编号: ${gl_bai}")" choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#scripts[@]} ]; then
        local script_to_delete="${scripts[$((choice-1))]}"
        echo -e "${gl_hong}警告：此操作将永久删除脚本和定时任务。${gl_bai}"
        read -p "$(echo -e "确定要删除任务 ${gl_hong}${script_to_delete}${gl_bai} 吗？ (y/N): ")" confirm
        
        if [[ "${confirm,,}" =~ ^(y|yes)$ ]]; then
            sudo rm -f "$script_to_delete"
            ( sudo crontab -l 2>/dev/null | grep -v "$script_to_delete" ) | sudo crontab -
            echo -e "\n${gl_lv}✅ 任务已成功删除。${gl_bai}"
        else
            echo -e "${gl_huang}操作已取消。${gl_bai}"
        fi
    elif [ "$choice" -eq 0 ]; then
        echo -e "${gl_huang}操作已取消。${gl_bai}"
    else
        echo -e "${gl_hong}无效输入。${gl_bai}"
    fi

    press_any_key_to_continue
}

# 5. 查看同步日志
function view_sync_log() {
    clear
    echo -e "${gl_kjlan}▶️ 查看同步日志${gl_bai}"
    echo "----------------------------------------"
    if [ -f "$LOG_FILE" ]; then
        tail -n 50 "$LOG_FILE"
    else
        echo -e "${gl_huang}日志文件 ${LOG_FILE} 不存在。请先运行一次同步任务。${gl_bai}"
    fi
    press_any_key_to_continue
}

# --- 主菜单 ---

function main_menu() {
    clear
    echo -e "${gl_kjlan}========================================="
    echo -e "        通用文件同步管理工具"
    echo -e "=========================================${gl_bai}"
    echo -e "${gl_lv}1.    查看已添加的同步任务${gl_bai}"
    echo -e "${gl_lv}2.    添加新的同步任务${gl_bai}"
    echo -e "${gl_lv}3.    立即执行同步任务${gl_bai}"
    echo -e "${gl_lv}4.    删除同步任务${gl_bai}"
    echo -e "${gl_lv}5.    查看同步日志${gl_bai}"
    echo -e "-----------------------------------------"
    echo -e "${gl_hong}0.    退出脚本${gl_bai}"
    echo -e "-----------------------------------------"

    read -p "$(echo -e "${gl_kjlan}请输入你的选择: ${gl_bai}")" choice

    case $choice in
        1) list_sync_tasks ;;
        2) add_sync_task ;;
        3) run_sync_task ;;
        4) delete_sync_task ;;
        5) view_sync_log ;;
        0) clear; exit 0 ;;
        *) echo -e "${gl_hong}无效输入！${gl_bai}"; press_any_key_to_continue ;;
    esac
}

# --- 脚本主入口 ---

# 检查权限并运行主循环
if [[ "$(id -u)" -ne 0 ]]; then
    echo -e "${gl_hong}警告: 此脚本需要 root 权限才能执行。${gl_bai}"
    echo -e "请使用 ${gl_lv}sudo bash $0${gl_bai} 来运行。"
    exit 1
fi

while true; do
    main_menu
done
