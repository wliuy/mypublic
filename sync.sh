#!/usr/bin/env bash

# =======================================================
# 交互式通用文件同步配置脚本
# 功能：引导用户配置一个基于 SSH 免密登录的自动化同步任务
# =======================================================

# --- 颜色定义 ---
gl_hong='\033[31m'
gl_lv='\033[32m'
gl_huang='\033[33m'
gl_bai='\033[0m'
gl_kjlan='\033[96m'

# --- 辅助函数 ---

function check_dependency() {
    local dep="$1"
    if ! command -v "$dep" &>/dev/null; then
        echo -e "${gl_hong}错误：未找到命令 '$dep'。正在尝试安装...${gl_bai}"
        if command -v apt &>/dev/null; then
            apt update && apt install -y "$dep"
        elif command -v yum &>/dev/null; then
            yum install -y "$dep"
        elif command -v dnf &>/dev/null; then
            dnf install -y "$dep"
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

# --- 主逻辑开始 ---
clear
echo -e "${gl_kjlan}====================================================="
echo -e "        欢迎使用通用自动化同步配置工具"
echo -e "=====================================================${gl_bai}"
echo ""

# 检查依赖
check_dependency "rsync"
check_dependency "ssh"
check_dependency "sshpass"

echo -e "${gl_huang}提示：此脚本将引导您配置一个每日自动同步任务。${gl_bai}"
echo -e "${gl_huang}警告：同步将使用 rsync 的 --delete 参数，远程目录中多余的文件将被删除。${gl_bai}"
echo ""

# 1. 获取本地源文件夹路径
read -p "$(echo -e "${gl_lv}1. 请输入要同步的本地文件夹完整路径: ${gl_bai}")" SOURCE_DIR
if [ ! -d "$SOURCE_DIR" ]; then
    echo -e "${gl_hong}错误：本地源文件夹 '$SOURCE_DIR' 不存在。${gl_bai}"
    exit 1
fi
echo ""

# 2. 获取远程服务器信息
read -p "$(echo -e "${gl_lv}2. 请输入远程服务器地址 (IP/域名): ${gl_bai}")" REMOTE_HOST
read -p "$(echo -e "${gl_lv}3. 请输入远程服务器SSH端口 (默认 22): ${gl_bai}")" REMOTE_PORT
REMOTE_PORT=${REMOTE_PORT:-22}
read -p "$(echo -e "${gl_lv}4. 请输入远程服务器用户名: ${gl_bai}")" REMOTE_USER
read -s -p "$(echo -e "${gl_lv}5. 请输入远程服务器密码: ${gl_bai}")" REMOTE_PASS
echo ""
echo ""

# 3. 获取远程目标文件夹路径
read -p "$(echo -e "${gl_lv}6. 请输入远程目标文件夹完整路径: ${gl_bai}")" DEST_DIR
echo ""

# 4. 获取同步频率
read -p "$(echo -e "${gl_lv}7. 请输入同步频率 (每天的几点，0-23点，如 '0' 表示凌晨0点): ${gl_bai}")" CRON_HOUR
CRON_HOUR=${CRON_HOUR:-0}

# 5. 确认信息
echo -e "${gl_kjlan}====================================================="
echo -e "                      确认信息"
echo -e "=====================================================${gl_bai}"
echo -e "${gl_kjlan}本地源目录: ${gl_bai}${SOURCE_DIR}"
echo -e "${gl_kjlan}远程目标:   ${gl_bai}${REMOTE_USER}@${REMOTE_HOST}:${DEST_DIR}"
echo -e "${gl_kjlan}SSH端口:    ${gl_bai}${REMOTE_PORT}"
echo -e "${gl_kjlan}同步频率:   ${gl_bai}每天 ${CRON_HOUR} 点"
echo -e "${gl_kjlan}-----------------------------------------------------${gl_bai}"

read -p "$(echo -e "${gl_huang}请确认信息无误，是否继续？ (y/N): ${gl_bai}")" confirm
if [[ ! "${confirm,,}" =~ ^(y|yes)$ ]]; then
    echo -e "${gl_hong}操作已取消。${gl_bai}"
    exit 0
fi

# 6. 配置 SSH 免密登录
echo -e "\n${gl_lv}▶️ 正在配置 SSH 免密登录...${gl_bai}"
# 确保 ~/.ssh 目录存在
mkdir -p ~/.ssh
chmod 700 ~/.ssh
# 生成 SSH 密钥 (如果不存在)
if [ ! -f ~/.ssh/id_rsa ]; then
    echo -e "  🗝️ 生成新的 SSH 密钥..."
    ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa
fi
# 使用 sshpass 自动复制公钥到远程服务器
sshpass -p "$REMOTE_PASS" ssh-copy-id -p "$REMOTE_PORT" -o StrictHostKeyChecking=no "${REMOTE_USER}@${REMOTE_HOST}" &>/dev/null

if [ $? -eq 0 ]; then
    echo -e "  ✅ SSH 免密登录配置成功！"
else
    echo -e "  ${gl_hong}❌ SSH 免密登录配置失败。请检查密码或SSH配置。${gl_bai}"
    exit 1
fi

# 7. 创建同步脚本
SYNC_SCRIPT_DIR="$HOME/sync_scripts"
SYNC_SCRIPT_NAME="sync_${REMOTE_HOST}.sh"
SYNC_SCRIPT_PATH="${SYNC_SCRIPT_DIR}/${SYNC_SCRIPT_NAME}"

echo -e "\n${gl_lv}▶️ 正在创建同步脚本文件...${gl_bai}"
mkdir -p "$SYNC_SCRIPT_DIR"

cat > "$SYNC_SCRIPT_PATH" <<EOF
#!/bin/bash
# =======================================================
# 每日自动同步脚本 (由 setup_auto_sync.sh 生成)
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

chmod +x "$SYNC_SCRIPT_PATH"
echo -e "  ✅ 脚本已成功创建在：${gl_lv}${SYNC_SCRIPT_PATH}${gl_bai}"


# 8. 设置定时任务
CRON_JOB="0 ${CRON_HOUR} * * * ${SYNC_SCRIPT_PATH} >> /var/log/auto_sync.log 2>&1"
echo -e "\n${gl_lv}▶️ 正在将任务添加到 Cron...${gl_bai}"

# 检查 cron 是否已安装
if ! command -v crontab &>/dev/null; then
    echo -e "${gl_hong}警告：未找到 'crontab' 命令。请手动安装 cronie/cron。${gl_bai}"
    echo "例如: apt install cron 或 yum install cronie"
    exit 1
fi

# 移除旧的同名任务（如果存在），然后添加新任务
( crontab -l 2>/dev/null | grep -v "${SYNC_SCRIPT_PATH}" ; echo "$CRON_JOB" ) | crontab -

if [ $? -eq 0 ]; then
    echo -e "  ✅ Cron 任务已成功设置！"
    echo -e "  任务将在每天 ${CRON_HOUR} 点自动执行。"
else
    echo -e "  ${gl_hong}❌ 添加 Cron 任务失败。请手动检查并添加。${gl_bai}"
    exit 1
fi

echo -e "\n${gl_lv}🎉 配置完成！${gl_bai}"
echo "--------------------------------------------------------"
echo "您已成功配置每日自动同步任务。"
echo "备份日志将写入 ${gl_lv}/var/log/auto_sync.log${gl_bai}，您可以随时查看。"
echo "--------------------------------------------------------"

press_any_key_to_continue
clear
