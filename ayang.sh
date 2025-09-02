#!/usr/bin/env bash

#
# AYANG's Toolbox v1.1.1 (最终版)
#

# --- 全局配置 ---
readonly SCRIPT_VERSION="1.1.1"
readonly SCRIPT_URL="https://raw.githubusercontent.com/wliuy/mypublic/refs/heads/main/ayang.sh"

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

# --- 功能函数定义 ---

# 1. 系统信息查询
function system_info() {
	clear
	ipv4_address=$(curl -s https://ipinfo.io/ip)
	ipv6_address=$(curl -s --max-time 1 https://v6.ipinfo.io/ip)
	local cpu_info=$(lscpu | awk -F': +' '/Model name:/ {print $2; exit}')
	local cpu_usage_percent=$(awk '{u=$2+$4; t=$2+$4+$5; if (NR==1){u1=u; t1=t;} else printf "%.0f\n", (($2+$4-u1) * 100 / (t-t1))}' <(grep 'cpu ' /proc/stat) <(sleep 1; grep 'cpu ' /proc/stat))
	local cpu_cores=$(nproc)
	local mem_info=$(free -b | awk 'NR==2{printf "%.2f/%.2fG (%.2f%%)", $3/1024/1024/1024, $2/1024/1024/1024, $3*100/$2}')
	local disk_info=$(df -h | awk '$NF=="/"{printf "%s/%s (%s)", $3, $2, $5}')
	local country=$(curl -s ipinfo.io/country)
	local city=$(curl -s ipinfo.io/city)
	local isp_info=$(curl -s ipinfo.io/org)
	local load=$(uptime | awk '{print $(NF-2), $(NF-1), $NF}')
	local cpu_arch=$(uname -m)
	local hostname=$(uname -n)
	local kernel_version=$(uname -r)
	local os_info=$(grep PRETTY_NAME /etc/os-release | cut -d '=' -f2 | tr -d '"')
	local runtime=$(cat /proc/uptime | awk -F. '{run_days=int($1 / 86400);run_hours=int(($1 % 86400) / 3600);run_minutes=int(($1 % 3600) / 60); if (run_days > 0) printf("%d天 ", run_days); if (run_hours > 0) printf("%d时 ", run_hours); printf("%d分\n", run_minutes)}')

	echo ""
	echo -e "系统信息查询"
	echo -e "${gl_kjlan}-------------"
	echo -e "${gl_kjlan}主机名:       ${gl_bai}$hostname"
	echo -e "${gl_kjlan}系统版本:     ${gl_bai}$os_info"
	echo -e "${gl_kjlan}Linux版本:    ${gl_bai}$kernel_version"
	echo -e "${gl_kjlan}-------------"
	echo -e "${gl_kjlan}CPU架构:      ${gl_bai}$cpu_arch"
	echo -e "${gl_kjlan}CPU型号:      ${gl_bai}$cpu_info"
	echo -e "${gl_kjlan}CPU核心数:    ${gl_bai}$cpu_cores"
	echo -e "${gl_kjlan}-------------"
	echo -e "${gl_kjlan}CPU占用:      ${gl_bai}$cpu_usage_percent%"
	echo -e "${gl_kjlan}系统负载:     ${gl_bai}$load"
	echo -e "${gl_kjlan}物理内存:     ${gl_bai}$mem_info"
	echo -e "${gl_kjlan}硬盘占用:     ${gl_bai}$disk_info"
	echo -e "${gl_kjlan}-------------"
	if [ -n "$ipv4_address" ]; then echo -e "${gl_kjlan}IPv4地址:     ${gl_bai}$ipv4_address"; fi
	if [ -n "$ipv6_address" ]; then echo -e "${gl_kjlan}IPv6地址:     ${gl_bai}$ipv6_address"; fi
	echo -e "${gl_kjlan}运营商:       ${gl_bai}$isp_info"
	echo -e "${gl_kjlan}地理位置:     ${gl_bai}$country $city"
	echo -e "${gl_kjlan}-------------"
	echo -e "${gl_kjlan}运行时长:     ${gl_bai}$runtime"
	echo
}

# 2. 系统更新
function system_update() {
	echo -e "${gl_huang}正在系统更新...${gl_bai}"
	if command -v dnf &>/dev/null; then dnf -y update
	elif command -v yum &>/dev/null; then yum -y update
	elif command -v apt &>/dev/null; then apt update -y && apt full-upgrade -y
	elif command -v apk &>/dev/null; then apk update && apk upgrade
	elif command -v pacman &>/dev/null; then pacman -Syu --noconfirm
	else echo "未知的包管理器!"; return; fi
}

# 3. 系统清理
function system_clean() {
	echo -e "${gl_huang}正在系统清理...${gl_bai}"
	if command -v dnf &>/dev/null; then dnf autoremove -y && dnf clean all && journalctl --rotate && journalctl --vacuum-time=1s
	elif command -v yum &>/dev/null; then yum autoremove -y && yum clean all && journalctl --rotate && journalctl --vacuum-time=1s
	elif command -v apt &>/dev/null; then apt autoremove --purge -y && apt clean -y && apt autoclean -y && journalctl --rotate && journalctl --vacuum-time=1s
	elif command -v apk &>/dev/null; then rm -rf /var/cache/apk/*
	elif command -v pacman &>/dev/null; then pacman -Rns $(pacman -Qdtq) --noconfirm && pacman -Scc --noconfirm && journalctl --rotate && journalctl --vacuum-time=1s
	else echo "未知的包管理器!"; return; fi
}

# 6. Docker管理
function docker_management() {
    echo -e "${gl_huang}Docker管理功能正在开发中...${gl_bai}"
    sleep 1
}

# (核心功能) 安装快捷指令
function install_shortcut() {
  local shortcut_name="y" # <--- 改回快捷键 y
  local install_name="ayang" # 主程序名保持为ayang
  local install_path_bin="/usr/local/bin/${shortcut_name}"
  local install_path_root="/root/${install_name}.sh"

  if [[ "${auto_install}" != "true" ]]; then
    clear
  fi
  echo -e "${gl_kjlan}开始安装/更新快捷方式 '${shortcut_name}'...${gl_bai}"

  if [[ "$(id -u)" -ne 0 ]]; then
    echo -e "${gl_hong}错误：此操作需要 root 权限。${gl_bai}";
    if [[ "${auto_install}" != "true" ]]; then press_any_key_to_continue; fi
    return 1
  fi

  echo -e "${gl_lan}正在从 GitHub 下载最新版脚本到 ${install_path_root}...${gl_bai}"
  if curl -L "${SCRIPT_URL}" -o "${install_path_root}"; then
    echo -e "${gl_lv}下载成功！${gl_bai}"
  else
    echo -e "${gl_hong}错误：下载脚本失败。${gl_bai}"; return 1;
  fi

  echo -e "${gl_lan}正在设置执行权限...${gl_bai}"; chmod +x "${install_path_root}"
  echo -e "${gl_lan}正在创建快捷命令 '${shortcut_name}' -> '${install_path_root}'...${gl_bai}"; ln -sf "${install_path_root}" "${install_path_bin}"
  
  echo -e "\n${gl_lv}🎉 恭喜！操作成功！${gl_bai}"
  
  if [[ "${auto_install}" == "true" ]]; then
      echo -e "下次登录后, 你就可以在任何地方直接输入 '${gl_huang}${shortcut_name}${gl_bai}' 来运行此工具箱了。"
  else
      echo -e "现在你可以在任何地方直接输入 '${gl_huang}${shortcut_name}${gl_bai}' 来运行此工具箱了。"
  fi
  return 0
}

# 00. 脚本更新
function update_script() {
  clear
  echo -e "${gl_kjlan}正在检查更新...${gl_bai}"
  
  local remote_script_content=$(curl -sL "${SCRIPT_URL}")
  local remote_version=$(echo "${remote_script_content}" | grep 'readonly SCRIPT_VERSION=' | head -n 1 | cut -d'"' -f2)

  if [ -z "$remote_version" ]; then
    echo -e "${gl_hong}获取远程版本失败，请检查网络或链接。${gl_bai}"
    press_any_key_to_continue; return
  fi

  echo -e "当前版本: ${gl_huang}v${SCRIPT_VERSION}${gl_bai}    最新版本: ${gl_lv}v${remote_version}${gl_bai}"

  if [[ "$SCRIPT_VERSION" == "$remote_version" ]]; then
    echo -e "\n${gl_lv}已是最新版，无需更新！${gl_bai}"
    sleep 1
  else
    echo -e "\n${gl_huang}发现新版本，是否立即更新？${gl_bai}"
    read -p "(y/N): " confirm
    if [[ "${confirm,,}" == "y" ]]; then
      local auto_install="true"
      if install_shortcut; then
        echo -e "${gl_lv}更新完成，正在重新加载脚本...${gl_bai}"
        sleep 2
        exec "/usr/local/bin/y" # <--- 改回 y
      fi
    else
      echo -e "${gl_huang}操作已取消。${gl_bai}"; press_any_key_to_continue
    fi
  fi
}

# 000. 卸载脚本
function uninstall_script() {
  clear
  echo -e "${gl_kjlan}开始卸载脚本和快捷方式...${gl_bai}"
  
  local shortcut_path="/usr/local/bin/y" # <--- 改回 y
  local root_copy_path="/root/ayang.sh"

  if [[ "$(id -u)" -ne 0 ]]; then echo -e "${gl_hong}错误：卸载过程需要 root 权限。${gl_bai}"; press_any_key_to_continue; return; fi
  if [ ! -f "${shortcut_path}" ] && [ ! -f "${root_copy_path}" ]; then echo -e "${gl_huang}脚本未安装或文件不存在，无需卸载。${gl_bai}"; press_any_key_to_continue; return; fi

  echo -e "${gl_hong}警告：这将从系统中永久删除脚本 '${shortcut_path}' 和 '${root_copy_path}'。${gl_bai}"
  read -p "你确定要继续吗？ (输入 'y' 确认, 其他任意键取消): " confirm
  if [[ "${confirm,,}" != "y" ]]; then echo -e "\n${gl_huang}操作已取消。${gl_bai}"; press_any_key_to_continue; return; fi
  
  echo -e "\n${gl_lan}正在移除快捷命令: ${shortcut_path}...${gl_bai}"; rm -f "${shortcut_path}"
  echo -e "${gl_lan}正在移除源文件副本: ${root_copy_path}...${gl_bai}"; rm -f "${root_copy_path}"
  
  echo -e "\n${gl_lv}✅ 卸载完成！${gl_bai}"
  echo -e "所有相关文件已被移除。"; echo -e "脚本即将退出。"; sleep 3; exit 0
}

# --- 主菜单显示 ---
function main_menu() {
  clear
  echo -e "${gl_kjlan}"
  echo -e "    █████╗ ██╗   ██╗ █████╗ ███╗   ██╗ ██████╗"
  echo -e "   ██╔══██╗╚██╗ ██╔╝██╔══██╗████╗  ██║██╔════╝"
  echo -e "   ███████║ ╚████╔╝ ███████║██╔██╗ ██║██║  ███╗"
  echo -e "   ██╔══██║  ╚██╔╝  ██╔══██║██║╚██╗██║██║   ██║"
  echo -e "   ██║  ██║   ██║   ██║  ██║██║ ╚████║╚██████╔╝"
  echo -e "   ╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═══╝ ╚═════╝"
  echo -e "${gl_bai}"
  echo -e "${gl_lan}               AYANG's Toolbox v${SCRIPT_VERSION}               ${gl_bai}"
  echo -e "${gl_kjlan}----------------------------------------------------${gl_bai}"
  echo -e "${gl_kjlan}1.  ${gl_bai}系统信息查询"
  echo -e "${gl_kjlan}2.  ${gl_bai}系统更新"
  echo -e "${gl_kjlan}3.  ${gl_bai}系统清理"
  echo -e "${gl_kjlan}6.  ${gl_bai}Docker管理"
  echo -e "${gl_kjlan}----------------------------------------------------${gl_bai}"
  echo -e "${gl_kjlan}00. ${gl_bai}更新脚本"
  echo -e "${gl_kjlan}000.${gl_bai}卸载脚本"
  echo -e "${gl_kjlan}0.  ${gl_bai}退出脚本"
  echo -e "${gl_kjlan}----------------------------------------------------${gl_bai}"
  read -p "请输入你的选择: " choice
}

# --- 主循环 ---
function main_loop() {
    while true; do
      main_menu
      case $choice in
        1) system_info; press_any_key_to_continue ;;
        2) clear; system_update; press_any_key_to_continue ;;
        3) clear; system_clean; press_any_key_to_continue ;;
        6) docker_management; press_any_key_to_continue ;;
        00) update_script ;;
        000) uninstall_script ;;
        0) clear; exit 0 ;;
        *) echo -e "${gl_hong}无效的输入!${gl_bai}"; sleep 1 ;;
      esac
    done
}


# ===================================================================================
# --- 脚本主入口逻辑 ---
# ===================================================================================

readonly INSTALL_PATH="/usr/local/bin/y" # <--- 改回 y

# 判断脚本是否已安装
if [ ! -f "${INSTALL_PATH}" ]; then
  clear
  echo -e "${gl_kjlan}欢迎使用 AYANG's Toolbox, 检测到是首次运行。${gl_bai}"
  echo -e "${gl_huang}为了方便您未来使用, 脚本将自动为您安装 'y' 快捷指令。${gl_bai}"
  echo -e "---------------------------------------------------------------------"
  
  auto_install="true"
  
  if ! install_shortcut; then
    echo -e "\n${gl_hong}自动安装失败, 脚本将进入临时会话模式。${gl_bai}"
    press_any_key_to_continue
    main_loop 
    exit 1
  fi
  
  echo -e "\n${gl_lv}安装流程执行完毕！正在进入主菜单...${gl_bai}"
fi

# 无论是首次运行安装后, 还是之后直接运行, 最终都会执行主循环
main_loop
