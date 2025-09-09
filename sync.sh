#!/bin/bash

# =======================================================
# 交互式文件同步脚本 (基于 rsync 和 SSH)
# 功能：以交互方式获取配置信息，并执行单向同步
# =======================================================

# --- 颜色定义 ---
gl_hui='\e[37m'
gl_hong='\033[31m'
gl_lv='\033[32m'
gl_huang='\033[33m'
gl_lan='\033[34m'
gl_bai='\033[0m'
gl_zi='\033[35m'
gl_kjlan='\033[96m'

# --- 辅助函数 ---
function check_dependency() {
    local dep="$1"
    if ! command -v "$dep" &>/dev/null; then
        echo -e "${gl_hong}错误：未找到命令 '$dep'。请先安装它。${gl_bai}"
        echo "例如：sudo apt-get install $dep 或 sudo yum install $dep"
        exit 1
    fi
}

function press_any_key_to_continue() {
    echo -e "\n${gl_huang}按任意键继续...${gl_bai}"
    read -n 1 -s -r -p ""
}

# --- 脚本主逻辑 ---

clear
echo -e "${gl_kjlan}====================================================="
echo -e "        欢迎使用交互式文件同步脚本"
echo -e "=====================================================${gl_bai}"
echo ""

# 检查 rsync 是否安装
check_dependency "rsync"
check_dependency "ssh"

echo -e "${gl_huang}提示：此脚本将本地文件夹内容单向同步到远程服务器。${gl_bai}"
echo -e "${gl_huang}警告：同步时将删除远程目录中本地不存在的文件。${gl_bai}"
echo ""

# 1. 获取本地源文件夹路径
read -p "$(echo -e "${gl_lv}请输入要同步的本地文件夹完整路径: ${gl_bai}")" SOURCE_DIR
SOURCE_DIR=$(echo "$SOURCE_DIR" | sed 's/\/$//g') # 移除末尾斜杠

if [ ! -d "$SOURCE_DIR" ]; then
    echo -e "${gl_hong}错误：本地源文件夹 '$SOURCE_DIR' 不存在。${gl_bai}"
    exit 1
fi
echo ""

# 2. 获取远程服务器信息
read -p "$(echo -e "${gl_lv}请输入远程服务器地址 (IP/域名): ${gl_bai}")" REMOTE_HOST
read -p "$(echo -e "${gl_lv}请输入远程服务器SSH端口 (默认 22): ${gl_bai}")" REMOTE_PORT
REMOTE_PORT=${REMOTE_PORT:-22}
read -p "$(echo -e "${gl_lv}请输入远程服务器用户名: ${gl_bai}")" REMOTE_USER
echo ""

# 3. 获取远程目标文件夹路径
read -p "$(echo -e "${gl_lv}请输入远程目标文件夹完整路径: ${gl_bai}")" DEST_DIR
DEST_DIR=$(echo "$DEST_DIR" | sed 's/\/$//g') # 移除末尾斜杠
echo ""

# 4. 确认信息并执行
echo -e "${gl_lan}====================================================="
echo -e "                      确认信息"
echo -e "=====================================================${gl_bai}"
echo -e "${gl_kjlan}本地源目录: ${gl_bai}${SOURCE_DIR}"
echo -e "${gl_kjlan}远程目标:   ${gl_bai}${REMOTE_USER}@${REMOTE_HOST}:${DEST_DIR}"
echo -e "${gl_kjlan}SSH端口:    ${gl_bai}${REMOTE_PORT}"
echo -e "${gl_lan}=====================================================${gl_bai}"

read -p "$(echo -e "${gl_huang}请确认信息无误，是否继续？ (y/N): ${gl_bai}")" confirm
if [[ ! "${confirm,,}" =~ ^(y|yes)$ ]]; then
    echo -e "${gl_hong}操作已取消。${gl_bai}"
    exit 0
fi

echo ""
echo -e "${gl_lv}正在执行同步...${gl_bai}"
echo "--------------------------------------------------------"

# 尝试连接并创建远程目录
echo "正在检查并创建远程目录: $DEST_DIR"
ssh -p "$REMOTE_PORT" "$REMOTE_USER@$REMOTE_HOST" "mkdir -p '$DEST_DIR'"

# 执行 rsync 同步
rsync -avz --delete -e "ssh -p $REMOTE_PORT" "$SOURCE_DIR/" "$REMOTE_USER@$REMOTE_HOST:$DEST_DIR"

if [ $? -eq 0 ]; then
    echo "--------------------------------------------------------"
    echo -e "${gl_lv}🎉 同步成功！${gl_bai}"
else
    echo "--------------------------------------------------------"
    echo -e "${gl_hong}❌ 同步失败。请检查网络连接、SSH配置和文件路径。${gl_bai}"
fi

echo ""
press_any_key_to_continue
clear
