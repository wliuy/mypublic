#!/usr/bin/env bash

#
# AYANG's Toolbox v1.3.21 (修复Memos远程备份容器和目录不存在的问题)
#

# --- 全局配置 ---
readonly SCRIPT_VERSION="1.3.21"
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

# 通用卸载函数 (源于 kejilion.sh)
remove() {
	if [ $# -eq 0 ]; then
		echo "未提供软件包参数!"
	fi

	for package in "$@"; do
		echo -e "${gl_huang}正在卸载 $package...${gl_bai}"
		if command -v dnf &>/dev/null; then
			dnf remove -y "$package"
		elif command -v yum &>/dev/null; then
			yum remove -y "$package"
		elif command -v apt &>/dev/null; then
			apt purge -y "$package"
		elif command -v apk &>/dev/null; then
			apk del "$package"
		elif command -v pacman &>/dev/null; then
			pacman -Rns --noconfirm "$package"
		else
			echo "未知的包管理器!"
			return 1
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
	if [ -n "$ipv4_address" ]; then echo -e "${gl_kjlan}IPv4地址:      ${gl_bai}$ipv4_address"; fi
	if [ -n "$ipv6_address" ]; then echo -e "${gl_kjlan}IPv6地址:      ${gl_bai}$ipv6_address"; fi
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

# 4. 系统工具
function system_tools() {
    function restart_ssh() {
        systemctl restart sshd >/dev/null 2>&1 || systemctl restart ssh >/dev/null 2>&1
    }
    function add_sshpasswd() {
        echo "设置你的ROOT密码"
        passwd
        sed -i 's/^\s*#\?\s*PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config;
        sed -i 's/^\s*#\?\s*PasswordAuthentication.*/PasswordAuthentication yes/g' /etc/ssh/sshd_config;
        rm -rf /etc/ssh/sshd_config.d/* /etc/ssh/ssh_config.d/* >/dev/null 2>&1
        restart_ssh
        echo -e "${gl_lv}ROOT密码登录已启用！${gl_bai}"
    }
    function open_all_ports() {
        install iptables
        iptables -P INPUT ACCEPT; iptables -P FORWARD ACCEPT; iptables -P OUTPUT ACCEPT; iptables -F
        echo "所有端口已开放 (iptables policy ACCEPT)"
    }
    function change_ssh_port() {
        sed -i 's/#Port/Port/' /etc/ssh/sshd_config
        local current_port=$(grep -E '^ *Port [0-9]+' /etc/ssh/sshd_config | awk '{print $2}')
        read -p "当前 SSH 端口是: ${current_port}。请输入新的端口号 (1-65535): " new_port
        if [[ $new_port =~ ^[0-9]+$ ]] && [ "$new_port" -ge 1 ] && [ "$new_port" -le 65535 ]; then
            sed -i "s/Port [0-9]\+/Port $new_port/g" /etc/ssh/sshd_config
            restart_ssh; echo "SSH 端口已修改为: $new_port"
        else
            echo "无效的端口号。"
        fi
    }
    function set_dns_ui() {
        while true; do
            clear; echo "优化DNS地址"; echo "------------------------"; echo "当前DNS地址"; cat /etc/resolv.conf; echo "------------------------"; echo ""; echo "1. 国外DNS (Google/Cloudflare)"; echo "2. 国内DNS (阿里/腾讯)"; echo "3. 手动编辑"; echo "------------------------"; echo "0. 返回"; echo "------------------------"
            read -p "请输入你的选择: " dns_choice
            local dns_config=""
            case "$dns_choice" in
                1) dns_config="nameserver 8.8.8.8\nnameserver 1.1.1.1\nnameserver 2001:4860:4860::8888\nnameserver 2606:4700:4700::1111";;
                2) dns_config="nameserver 223.5.5.5\nnameserver 119.29.29.29";;
                3) install nano; nano /etc/resolv.conf; continue;;
                0) break;;
                *) echo "无效输入"; sleep 1; continue;;
            esac
            echo -e "$dns_config" > /etc/resolv.conf; echo "DNS 已更新！"; sleep 1
        done
    }
    function add_swap_menu() {
        function _do_add_swap() {
            local swap_size=$1
            swapoff /swapfile >/dev/null 2>&1
            rm -f /swapfile >/dev/null 2>&1
            echo "正在创建新的swap文件 (使用 fallocate 命令)..."
            fallocate -l ${swap_size}M /swapfile
            chmod 600 /swapfile
            mkswap /swapfile
            swapon /swapfile
            sed -i '/swapfile/d' /etc/fstab
            echo "/swapfile swap swap defaults 0 0" >> /etc/fstab
            echo -e "${gl_lv}虚拟内存大小已成功调整为 ${swap_size}M${gl_bai}"
        }
        while true; do
            clear; echo "设置虚拟内存"
            local swap_info=$(free -m | awk 'NR==3{used=$3; total=$2; if (total == 0) {percentage=0} else {percentage=used*100/total}; printf "%dM/%dM (%d%%)", used, total, percentage}')
            echo -e "当前虚拟内存: ${gl_huang}$swap_info${gl_bai}"; echo -e "${gl_hong}------------------------${gl_bai}"; echo "1. 分配1024M          2. 分配2048M"; echo "3. 分配4096M          4. 自定义大小"; echo -e "${gl_hong}------------------------${gl_bai}"; echo "0. 返回上一级选单"; echo -e "${gl_hong}------------------------${gl_bai}"
            read -p "请输入你的选择: " swap_choice
            case "$swap_choice" in
              1) _do_add_swap 1024; break ;;
              2) _do_add_swap 2048; break ;;
              3) _do_add_swap 4096; break ;;
              4) read -p "请输入虚拟内存大小（单位M）: " new_swap; _do_add_swap "$new_swap"; break ;;
              0) break ;;
              *) echo "无效输入"; sleep 1 ;;
            esac
        done
    }
    function timezone_menu() {
        function _current_timezone() {
            if grep -q 'Alpine' /etc/issue 2>/dev/null; then date +"%Z %z"; else timedatectl | grep "Time zone" | awk '{print $3}'; fi
        }
        function _set_timedate() {
            if grep -q 'Alpine' /etc/issue 2>/dev/null; then install tzdata; cp /usr/share/zoneinfo/${1} /etc/localtime; else timedatectl set-timezone ${1}; fi
        }
        while true; do
            clear; echo "系统时间信息"; echo "当前系统时区：$(_current_timezone)"; echo "当前系统时间：$(date +"%Y-%m-%d %H:%M:%S")"; echo ""; echo "时区切换"; echo -e "${gl_hong}------------------------${gl_bai}"; echo "亚洲"; echo "1.  中国上海时间           2.  中国香港时间"; echo "3.  日本东京时间           4.  韩国首尔时间"; echo "5.  新加坡时间"; echo -e "${gl_hong}------------------------${gl_bai}"; echo "欧洲"; echo "11. 英国伦敦时间           12. 法国巴黎时间"; echo "13. 德国柏林时间"; echo -e "${gl_hong}------------------------${gl_bai}"; echo "美洲"; echo "21. 美国西部时间           22. 美国东部时间"; echo "23. 加拿大时间"; echo -e "${gl_hong}------------------------${gl_bai}"; echo "31. UTC全球标准时间"; echo -e "${gl_hong}------------------------${gl_bai}"; echo "0. 返回上一级选单"; echo -e "${gl_hong}------------------------${gl_bai}";
            read -p "请输入你的选择: " sub_choice
            case $sub_choice in
                1) _set_timedate Asia/Shanghai ;;
                2) _set_timedate Asia/Hong_Kong ;;
                3) _set_timedate Asia/Tokyo ;;
                4) _set_timedate Asia/Seoul ;;
                5) _set_timedate Asia/Singapore ;;
                11) _set_timedate Europe/London ;;
                12) _set_timedate Europe/Paris ;;
                13) _set_timedate Europe/Berlin ;;
                21) _set_timedate America/Los_Angeles ;;
                22) _set_timedate America/New_York ;;
                23) _set_timedate America/Vancouver ;;
                31) _set_timedate UTC ;;
                0) break ;;
                *) echo "无效输入"; sleep 1 ;;
            esac
        done
    }
    while true; do
        clear; echo "系统工具"; echo -e "${gl_hong}----------------------------------------${gl_bai}"; echo "1. ROOT密码登录模式"; echo "2. 修改登录密码"; echo "3. 开放所有端口"; echo "4. 修改SSH连接端口"; echo "5. 优化DNS地址"; echo "6. 查看端口占用状态"; echo "7. 修改虚拟内存大小"; echo "8. 系统时区调整"; echo "9. 定时任务管理"; echo -e "${gl_hong}----------------------------------------${gl_bai}"; echo "0. 返回主菜单"; echo -e "${gl_hong}----------------------------------------${gl_bai}"
        read -p "请输入你的选择: " tool_choice
        case $tool_choice in
            1) clear; add_sshpasswd; press_any_key_to_continue ;;
            2) clear; echo "设置当前用户密码"; passwd; press_any_key_to_continue ;;
            3) clear; open_all_ports; press_any_key_to_continue ;;
            4) clear; change_ssh_port; press_any_key_to_continue ;;
            5) set_dns_ui ;;
            6) clear; install ss; ss -tulnpe; press_any_key_to_continue ;;
            7) add_swap_menu; press_any_key_to_continue ;;
            8) timezone_menu ;;
            9) install cron || install cronie; clear; crontab -e ;;
            0) break ;;
            *) echo "无效输入"; sleep 1 ;;
        esac
    done
}

# 5. 应用管理
function app_management() {
    local lucky_color=$(docker ps -a --format '{{.Names}}' | grep -q "^lucky$" && echo -e "${gl_kjlan}" || echo -e "${gl_bai}")
    local fb_color=$(docker ps -a --format '{{.Names}}' | grep -q "^filebrowser$" && echo -e "${gl_kjlan}" || echo -e "${gl_bai}")
    local memos_color=$(docker ps -a --format '{{.Names}}' | grep -q "^memos$" && echo -e "${gl_kjlan}" || echo -e "${gl_bai}")

    function install_lucky() {
        clear; echo -e "${gl_kjlan}正在安装 Lucky 反代...${gl_bai}";
        if ! command -v docker &>/dev/null; then echo -e "${gl_hong}错误：Docker 未安装。${gl_bai}"; return; fi
        
        local public_ip=$(curl -s https://ipinfo.io/ip)
        local data_dir="/docker/goodluck"

        if docker ps -a --format '{{.Names}}' | grep -q "^lucky$"; then
            echo -e "\n${gl_huang}Lucky 容器已存在，无需重复安装。${gl_bai}"
            echo -e "访问地址通常为 ${gl_lv}http://${public_ip}:16601${gl_bai}"
            echo -e "\n${gl_huang}温馨提示：${gl_bai}由于 Lucky 配置文件是加密的，无法直接读取其端口和安全入口。"
            echo -e "如需重置，请删除 ${gl_hong}${data_dir}/lucky_base.lkcf${gl_bai} 文件，"
            echo -e "然后重启 lucky 容器，例如：${gl_lv}docker restart lucky${gl_bai}"
            echo -e "重置后，你可以在首次登录时重新设置密码和端口。"
            return
        fi

        echo -e "${gl_lan}正在创建数据目录 ${data_dir}...${gl_bai}"; mkdir -p ${data_dir}
        echo -e "${gl_lan}正在拉取 gdy666/lucky 镜像...${gl_bai}"; docker pull gdy666/lucky
        echo -e "${gl_lan}正在启动 Lucky 容器...${gl_bai}"; docker run -d --name lucky --restart always --net=host -v ${data_dir}:/goodluck gdy666/lucky
        
        sleep 3
        if docker ps -q -f name=^lucky$; then
            echo -e "${gl_lv}Lucky 安装成功！${gl_bai}"
            echo -e "Lucky 容器使用 ${gl_huang}--net=host${gl_bai} 模式，端口由配置文件 lucky.conf 决定。"
            echo -e "默认访问地址为 ${gl_lv}http://${public_ip}:16601${gl_bai}"
        else
            echo -e "${gl_hong}Lucky 容器启动失败，请检查 Docker 日志。${gl_bai}"
        fi
    }
    
    function install_filebrowser() {
        clear; echo -e "${gl_kjlan}正在安装 FileBrowser...${gl_bai}";
        if ! command -v docker &>/dev/null; then echo -e "${gl_hong}错误：Docker 未安装。${gl_bai}"; return; fi

        if docker ps -a --format '{{.Names}}' | grep -q "^filebrowser$"; then
            echo -e "\n${gl_huang}FileBrowser 容器已存在，无需重复安装。${gl_bai}"
            local public_ip=$(curl -s https://ipinfo.io/ip)
            echo -e "你可以通过 ${gl_lv}http://${public_ip}:5566${gl_bai} 来访问。"
            return
        fi

        echo -e "${gl_lan}正在创建本地目录...${gl_bai}"
        mkdir -p /wliuy/filebrowser/database
        mkdir -p /wliuy/filebrowser/config
        chown -R root:root /wliuy/filebrowser

        echo -e "${gl_lan}正在拉取 FileBrowser 镜像并启动容器...${gl_bai}"
        docker run -d --name filebrowser --restart always \
          -u 0:0 \
          -v /wliuy/filebrowser/files:/srv \
          -v /wliuy/filebrowser/database:/database \
          -v /wliuy/filebrowser/config:/config \
          -p 5566:80 \
          filebrowser/filebrowser

        echo -e "${gl_lan}等待容器启动并生成日志...${gl_bai}"
        local timeout=20
        local start_time=$(date +%s)
        local password=""
        while [ $(($(date +%s) - start_time)) -lt $timeout ]; do
            local log_line=$(docker logs filebrowser 2>&1 | grep "password: " | tail -n 1)
            if [ -n "$log_line" ]; then
                password=$(echo "$log_line" | awk '{print $NF}' | tr -d '\r')
                break
            fi
            sleep 1
        done

        if docker ps -q -f name=^filebrowser$; then
            local public_ip=$(curl -s https://ipinfo.io/ip)
            local access_url="http://${public_ip}:5566"
            local username="admin"

            echo -e "\n${gl_lv}FileBrowser 安装成功！${gl_bai}"
            echo -e "-----------------------------------"
            echo -e "访问地址: ${gl_lv}${access_url}${gl_bai}"
            echo -e "默认用户名: ${gl_lv}${username}${gl_bai}"
            
            if [ -n "$password" ]; then
                echo -e "默认密码: ${gl_lv}${password}${gl_bai}"
            else
                echo -e "${gl_hong}注意：${gl_bai}未能从日志中自动获取密码。默认密码可能为 ${gl_lv}admin${gl_bai} 或其他随机值，请检查日志。"
                echo -e "你可以运行 ${gl_lv}docker logs filebrowser${gl_bai} 手动查看。"
            fi
            echo -e "-----------------------------------"
        else
            echo -e "${gl_hong}FileBrowser 容器启动失败，请检查 Docker 日志。${gl_bai}"
        fi
    }
    
    function memos_management() {
        local MEMOS_DATA_DIR="/wliuy/memos"
        local SYNC_SCRIPT_BASE="/wliuy/memos/sync_memos"
        local LOG_FILE="/var/log/sync_memos.log"

        function install_memos() {
            clear; echo -e "${gl_kjlan}正在安装 Memos...${gl_bai}"
            if ! command -v docker &>/dev/null; then echo -e "${gl_hong}错误：Docker 未安装。${gl_bai}"; return; fi

            if docker ps -a --format '{{.Names}}' | grep -q "^memos$"; then
                echo -e "\n${gl_huang}Memos 容器已存在，无需重复安装。${gl_bai}"
                local public_ip=$(curl -s https://ipinfo.io/ip)
                echo -e "你可以通过 ${gl_lv}http://${public_ip}:5230${gl_bai} 来访问。"
                echo -e "默认用户名: ${gl_lv}admin${gl_bai}"
                echo -e "默认密码: ${gl_lv}admin${gl_bai}"
                echo -e "数据库及配置文件保存在: ${gl_lv}${MEMOS_DATA_DIR}${gl_bai}"
                return
            fi

            echo -e "${gl_lan}正在创建数据目录 ${MEMOS_DATA_DIR}...${gl_bai}"; mkdir -p ${MEMOS_DATA_DIR}
            echo -e "${gl_lan}正在拉取 neosmemo/memos 镜像并启动容器...${gl_bai}"
            docker run -d --name memos --restart unless-stopped \
              -p 5230:5230 \
              -v ${MEMOS_DATA_DIR}:/var/opt/memos \
              neosmemo/memos:latest

            sleep 5
            if docker ps -q -f name=^memos$; then
                local public_ip=$(curl -s https://ipinfo.io/ip)
                echo -e "\n${gl_lv}Memos 安装成功！${gl_bai}"
                echo -e "-----------------------------------"
                echo -e "访问地址: ${gl_lv}http://${public_ip}:5230${gl_bai}"
                echo -e "默认用户名: ${gl_lv}admin${gl_bai}"
                echo -e "默认密码: ${gl_lv}admin${gl_bai}"
                echo -e "数据库及配置文件保存在: ${gl_lv}${MEMOS_DATA_DIR}${gl_bai}"
                echo -e "-----------------------------------"
            else
                echo -e "${gl_hong}Memos 容器启动失败，请检查 Docker 日志。${gl_bai}"
            fi
        }

        function setup_memos_sync() {
            clear; echo -e "${gl_kjlan}正在配置 Memos 自动备份...${gl_bai}"

            read -p "请输入远程服务器地址 (REMOTE_HOST): " remote_host
            read -p "请输入远程服务器SSH端口 (REMOTE_PORT): " remote_port
            read -p "请输入远程服务器用户名 (REMOTE_USER): " remote_user
            read -p "请输入远程服务器密码 (REMOTE_PASS): " remote_pass
            read -p "请输入本地 Memos 数据目录 (LOCAL_DIR, 默认: /wliuy/memos): " local_dir
            read -p "请输入远程 Memos 数据目录 (REMOTE_DIR, 默认: /wliuy/memos): " remote_dir
            
            local_dir=${local_dir:-"/wliuy/memos"}
            remote_dir=${remote_dir:-"/wliuy/memos"}
            
            echo ""

            if [ -z "$remote_host" ] || [ -z "$remote_port" ] || [ -z "$remote_user" ] || [ -z "$remote_pass" ]; then
                echo -e "${gl_hong}输入信息不完整，备份配置已取消。${gl_bai}"
                return
            fi
            
            # 检查并安装 sshpass
            if ! command -v sshpass &> /dev/null; then
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
            
            # 确保远程目录存在
            echo -e "📁 正在远程创建备份目录 ${remote_dir}..."
            ssh -p "$remote_port" "${remote_user}@${remote_host}" "mkdir -p '${remote_dir}'"

            # 创建同步脚本
            echo -e "📝 创建同步脚本 ${SYNC_SCRIPT_BASE}..."
            mkdir -p "${SYNC_SCRIPT_BASE}"
            local sync_script_path="${SYNC_SCRIPT_BASE}/sync_memos_${remote_host}.sh"
            
            cat > "${sync_script_path}" <<EOF
#!/bin/bash
# 停止远程 memos 容器 (如果存在)
ssh -p ${remote_port} ${remote_user}@${remote_host} "docker inspect --format '{{.State.Running}}' memos" | grep -q "true" && ssh -p ${remote_port} ${remote_user}@${remote_host} "docker stop memos"

# 同步本地目录到远程
rsync -avz --checksum -e "ssh -p ${remote_port}" --delete "${local_dir}" ${remote_user}@${remote_host}:"${remote_dir}"

# 启动远程 memos 容器 (如果存在)
ssh -p ${remote_port} ${remote_user}@${remote_host} "docker inspect --format '{{.State.Running}}' memos" | grep -q "false" && ssh -p ${remote_port} ${remote_user}@${remote_host} "docker start memos"
EOF
            chmod +x "${sync_script_path}"

            # 添加定时任务
            local cron_job="0 0 * * * ${sync_script_path} >> ${LOG_FILE} 2>&1"
            echo -e "📅 添加定时任务（每天 0 点执行）..."
            ( crontab -l 2>/dev/null | grep -v "${sync_script_path}" ; echo "$cron_job" ) | crontab -

            echo -e "\n🎉 配置完成！每天 0 点将自动备份 Memos 数据到 ${remote_host}。"
        }
        
        function delete_memos_sync() {
            clear; echo -e "${gl_kjlan}删除 Memos 备份配置...${gl_bai}"
            echo -e "----------------------------------------"
            local configured_servers=""
            if [ -d "${SYNC_SCRIPT_BASE}" ]; then
                configured_servers=$(ls "${SYNC_SCRIPT_BASE}" | grep "sync_memos_.*.sh" 2>/dev/null | sed 's/sync_memos_//g;s/.sh//g')
            fi

            if [ -z "$configured_servers" ]; then
                echo -e "${gl_huang}未找到任何已配置的远程备份服务器。${gl_bai}"
                return
            fi

            echo -e "${gl_kjlan}已配置的远程服务器:${gl_bai}"
            echo "${configured_servers}"
            echo -e "----------------------------------------"

            read -p "请输入要删除备份配置的服务器地址: " server_to_delete

            local sync_script_path="${SYNC_SCRIPT_BASE}/sync_memos_${server_to_delete}.sh"
            if [ -f "$sync_script_path" ]; then
                echo -e "${gl_hong}警告：此操作将永久删除服务器 ${server_to_delete} 的备份配置和定时任务。${gl_bai}"
                read -p "你确定要继续吗？ (输入 'y' 确认, 其他任意键取消): " confirm
                if [[ "${confirm,,}" == "y" ]]; then
                    rm -f "${sync_script_path}"
                    ( crontab -l 2>/dev/null | grep -v "$sync_script_path" ) | crontab -
                    echo -e "${gl_lv}✅ 备份配置已成功删除。${gl_bai}"
                else
                    echo -e "${gl_huang}操作已取消。${gl_bai}"
                fi
            else
                echo -e "${gl_hong}错误：未找到服务器 ${server_to_delete} 的备份配置。${gl_bai}"
            fi
        }

        function run_memos_sync() {
            clear; echo -e "${gl_kjlan}立即执行 Memos 备份...${gl_bai}"
            echo -e "----------------------------------------"
            local configured_servers=""
            if [ -d "${SYNC_SCRIPT_BASE}" ]; then
                configured_servers=$(ls "${SYNC_SCRIPT_BASE}" | grep "sync_memos_.*.sh" 2>/dev/null | sed 's/sync_memos_//g;s/.sh//g')
            fi

            if [ -z "$configured_servers" ]; then
                echo -e "${gl_huang}未找到任何已配置的远程备份服务器。请先添加备份配置。${gl_bai}"
                return
            fi

            echo -e "${gl_kjlan}已配置的远程服务器:${gl_bai}"
            echo "${configured_servers}"
            echo -e "----------------------------------------"

            read -p "请输入要立即备份的服务器地址: " server_to_sync

            local sync_script_path="${SYNC_SCRIPT_BASE}/sync_memos_${server_to_sync}.sh"
            if [ -f "$sync_script_path" ]; then
                echo -e "${gl_lan}正在执行备份脚本...${gl_bai}"
                bash "$sync_script_path"
                echo -e "\n${gl_lv}✅ 备份任务执行完毕。${gl_bai}"
            else
                echo -e "${gl_hong}错误：未找到服务器 ${server_to_sync} 的备份脚本。${gl_bai}"
            fi
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
            clear; echo "Memos 管理"; echo -e "${gl_hong}----------------------------------------${gl_bai}"; echo "1. 安装 Memos"; echo "2. 配置自动备份"; echo "3. 查看备份日志"; echo -e "${gl_hong}----------------------------------------${gl_bai}"; echo "0. 返回上一级菜单"; echo -e "${gl_hong}----------------------------------------${gl_bai}"
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
                            configured_servers=$(ls "${SYNC_SCRIPT_BASE}" | grep "sync_memos_.*.sh" 2>/dev/null | sed 's/sync_memos_//g;s/.sh//g')
                        fi
                        if [ -z "$configured_servers" ]; then
                            echo -e "  ${gl_hui}无${gl_bai}"
                        else
                            echo -e "${gl_lv}  $configured_servers${gl_bai}"
                        fi
                        echo -e "${gl_hong}----------------------------------------${gl_bai}"
                        echo "1. 添加备份配置"
                        echo "2. 删除备份配置"
                        echo "3. 立即备份"
                        echo -e "${gl_hong}----------------------------------------${gl_bai}"
                        echo "0. 返回上一级菜单"
                        echo -e "${gl_hong}----------------------------------------${gl_bai}"
                        read -p "请输入你的选择: " sync_choice
                        case $sync_choice in
                            1) setup_memos_sync; press_any_key_to_continue ;;
                            2) delete_memos_sync; press_any_key_to_continue ;;
                            3) run_memos_sync; press_any_key_to_continue ;;
                            0) break ;;
                            *) echo "无效输入"; sleep 1 ;;
                        esac
                    done
                    ;;
                3) view_memos_sync_log; press_any_key_to_continue ;;
                0) break ;;
                *) echo "无效输入"; sleep 1 ;;
            esac
        done
    }

    function uninstall_filebrowser() {
        clear; echo -e "${gl_kjlan}正在卸载 FileBrowser...${gl_bai}"
        if ! docker ps -a --format '{{.Names}}' | grep -q "^filebrowser$"; then
            echo -e "${gl_huang}未找到 FileBrowser 容器，无需卸载。${gl_bai}"; return;
        fi
        
        echo -e "${gl_hong}警告：此操作将永久删除 FileBrowser 容器、镜像以及所有相关数据！${gl_bai}"
        echo -e "${gl_hong}数据目录包括: /wliuy/filebrowser${gl_bai}"
        read -p "如确认继续，请输入 'y' : " confirm
        if [[ "${confirm,,}" != "y" ]]; then echo -e "${gl_huang}操作已取消。${gl_bai}"; return; fi

        echo -e "${gl_lan}正在停止并删除 filebrowser 容器...${gl_bai}"
        docker stop filebrowser && docker rm filebrowser

        echo -e "${gl_lan}正在删除 filebrowser/filebrowser 镜像...${gl_bai}"
        docker rmi filebrowser/filebrowser

        echo -e "${gl_lan}正在删除本地数据目录 /wliuy/filebrowser...${gl_bai}"
        rm -rf /wliuy/filebrowser

        echo -e "${gl_lv}✅ FileBrowser 已被彻底卸载。${gl_bai}"
    }

    function uninstall_lucky() {
        clear; echo -e "${gl_kjlan}正在卸载 Lucky 反代...${gl_bai}"
        if ! docker ps -a --format '{{.Names}}' | grep -q "^lucky$"; then echo -e "${gl_huang}未找到 Lucky 容器，无需卸载。${gl_bai}"; return; fi
        echo -e "${gl_hong}警告：此操作将永久删除 Lucky 容器、镜像以及所有数据 (${gl_huang}/docker/goodluck${gl_hong})。${gl_bai}"
        read -p "如确认继续，请输入 'y' : " confirm
        if [[ "${confirm,,}" != "y" ]]; then echo -e "${gl_huang}操作已取消。${gl_bai}"; return; fi
        echo -e "${gl_lan}正在停止并删除 lucky 容器...${gl_bai}"; docker stop lucky && docker rm lucky
        echo -e "${gl_lan}正在删除 gdy666/lucky 镜像...${gl_bai}"; docker rmi gdy666/lucky
        echo -e "${gl_lan}正在删除数据目录 /docker/goodluck...${gl_bai}"; rm -rf /docker/goodluck
        echo -e "${gl_lv}✅ Lucky 已被彻底卸载。${gl_bai}"
    }
    
    function uninstall_memos() {
        local MEMOS_DATA_DIR="/wliuy/memos"
        local SYNC_SCRIPT_BASE="/wliuy/memos/sync_memos"
        local LOG_FILE="/var/log/sync_memos.log"
        
        clear; echo -e "${gl_kjlan}正在卸载 Memos...${gl_bai}"
        if ! docker ps -a --format '{{.Names}}' | grep -q "^memos$"; then
            echo -e "${gl_huang}未找到 Memos 容器，无需卸载。${gl_bai}"; return;
        fi

        echo -e "${gl_hong}警告：此操作将永久删除 Memos 容器、镜像以及所有相关数据！${gl_bai}"
        echo -e "${gl_hong}数据目录包括: ${MEMOS_DATA_DIR}${gl_bai}"
        echo -e "${gl_hong}同步脚本和日志也将被删除。${gl_bai}"
        read -p "如确认继续，请输入 'y' : " confirm
        if [[ "${confirm,,}" != "y" ]]; then echo -e "${gl_huang}操作已取消。${gl_bai}"; return; fi
        
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
        
        echo -e "${gl_lv}✅ Memos 已被彻底卸载。${gl_bai}"
    }

    while true; do
        clear
        echo -e "应用管理"
        echo -e "${gl_hong}----------------------------------------${gl_bai}"
        echo "安装:"
        echo -e "  ${lucky_color}1. Lucky 反代"
        echo -e "  ${fb_color}2. FileBrowser (文件管理)"
        echo -e "  ${memos_color}3. Memos (轻量笔记)"
        echo
        echo "卸载:"
        echo -e "  ${lucky_color}-1. 卸载 Lucky 反代"
        echo -e "  ${fb_color}-2. 卸载 FileBrowser"
        echo -e "  ${memos_color}-3. 卸载 Memos"
        echo -e "${gl_hong}----------------------------------------${gl_bai}"
        echo -e "0. 返回主菜单"
        echo -e "${gl_hong}----------------------------------------${gl_bai}"
        read -p "请输入你的选择: " app_choice
        case $app_choice in
            1) install_lucky; press_any_key_to_continue ;;
            2) install_filebrowser; press_any_key_to_continue ;;
            3) memos_management ;;
            -1) uninstall_lucky; app_management ;;
            -2) uninstall_filebrowser; app_management ;;
            -3) uninstall_memos; app_management ;;
            0) break ;;
            *) echo "无效输入"; sleep 1 ;;
        esac
    done
}


# 6. Docker管理
function docker_management() {
    function docker_tato() {
        local container_count=$(docker ps -a -q 2>/dev/null | wc -l)
        local image_count=$(docker images -q 2>/dev/null | wc -l)
        local network_count=$(docker network ls -q 2>/dev/null | wc -l)
        local volume_count=$(docker volume ls -q 2>/dev/null | wc -l)
        if command -v docker &> /dev/null; then
            echo -e "${gl_kjlan}------------------------"
            echo -e "${gl_lv}环境已经安装${gl_bai}  容器: ${gl_lv}$container_count${gl_bai}  镜像: ${gl_lv}$image_count${gl_bai}  网络: ${gl_lv}$network_count${gl_bai}  卷: ${gl_lv}$volume_count${gl_bai}"
        fi
    }
    function install_add_docker() {
        echo -e "${gl_huang}正在安装docker环境...${gl_bai}"
        if [ -f /etc/os-release ] && grep -q "Fedora" /etc/os-release; then
            install_add_docker_guanfang
        elif command -v dnf &>/dev/null; then
            dnf update -y; dnf install -y yum-utils; rm -f /etc/yum.repos.d/docker*.repo > /dev/null
            if [[ "$(curl -s ipinfo.io/country)" == "CN" ]]; then curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo | tee /etc/yum.repos.d/docker-ce.repo > /dev/null
            else yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo > /dev/null; fi
            dnf install -y docker-ce docker-ce-cli containerd.io; install_add_docker_cn
        elif command -v apt &>/dev/null || command -v yum &>/dev/null; then
            install_add_docker_guanfang
        else
            install docker docker-compose; install_add_docker_cn
        fi
        sleep 2
    }
    function install_add_docker_cn() {
        if [[ "$(curl -s ipinfo.io/country)" == "CN" ]]; then
        cat > /etc/docker/daemon.json << EOF
{ "registry-mirrors": ["https://docker.m.daocloud.io", "https://docker.1panel.live", "https://registry.dockermirror.com"] }
EOF
        fi
        systemctl enable docker >/dev/null 2>&1; systemctl start docker >/dev/null 2>&1; systemctl restart docker >/dev/null 2>&1
    }
    function install_add_docker_guanfang() {
        if [[ "$(curl -s ipinfo.io/country)" == "CN" ]]; then sh <(curl -sSL https://linuxmirrors.cn/docker.sh) --mirror Aliyun
        else curl -fsSL https://get.docker.com | sh; fi
        install_add_docker_cn
    }
    function docker_ps() {
        while true; do
            clear; echo "Docker容器列表"; docker ps -a --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}"; echo ""
            echo "容器操作"; echo -e "${gl_hong}------------------------${gl_bai}"; echo "1. 创建新的容器"; echo "2. 启动指定容器            6. 启动所有容器"; echo "3. 停止指定容器            7. 停止所有容器"; echo "4. 删除指定容器            8. 删除所有容器"; echo "5. 重启指定容器            9. 重启所有容器"; echo "11. 进入指定容器           12. 查看容器日志"; echo "0. 返回上一级选单"; echo -e "${gl_hong}------------------------${gl_bai}"
            read -p "请输入你的选择: " sub_choice
            case $sub_choice in
                1) read -p "请输入创建命令: " dockername; $dockername ;;
                2) read -p "请输入容器名: " dockername; docker start $dockername ;;
                3) read -p "请输入容器名: " dockername; docker stop $dockername ;;
                4) read -p "请输入容器名: " dockername; docker rm -f $dockername ;;
                5) read -p "请输入容器名: " dockername; docker restart $dockername ;;
                6) docker start $(docker ps -a -q) ;;
                7) docker stop $(docker ps -q) ;;
                8) read -p "$(echo -e "${gl_hong}注意: ${gl_bai}确定删除所有容器吗？(Y/N): ")" choice; if [[ "${choice,,}" == "y" ]]; then docker rm -f $(docker ps -a -q); fi ;;
                9) docker restart $(docker ps -q) ;;
                11) read -p "请输入容器名: " dockername; docker exec -it $dockername /bin/sh; press_any_key_to_continue ;;
                12) read -p "请输入容器名: " dockername; docker logs $dockername; press_any_key_to_continue ;;
                0) break ;;
                *) echo "无效输入"; sleep 1 ;;
            esac
        done
    }
    function docker_image() {
        while true; do
            clear; echo "Docker镜像列表"; docker image ls; echo ""; echo "镜像操作"; echo -e "${gl_hong}------------------------${gl_bai}"; echo "1. 获取指定镜像            3. 删除指定镜像"; echo "2. 更新指定镜像            4. 删除所有镜像"; echo "0. 返回上一级选单"; echo -e "${gl_hong}------------------------${gl_bai}"
            read -p "请输入你的选择: " sub_choice
            case $sub_choice in
                1) read -p "请输入镜像名: " name; docker pull $name ;;
                2) read -p "请输入镜像名: " name; docker pull $name ;;
                3) read -p "请输入镜像名: " name; docker rmi -f $name ;;
                4) read -p "$(echo -e "${gl_hong}注意: ${gl_bai}确定删除所有镜像吗？(Y/N): ")" choice; if [[ "${choice,,}" == "y" ]]; then docker rmi -f $(docker images -q); fi ;;
                0) break ;;
                *) echo "无效输入"; sleep 1 ;;
            esac
        done
    }
    function docker_network() {
        while true; do
            clear; echo "Docker网络列表"; echo -e "${gl_hong}------------------------------------------------------------${gl_bai}"; docker network ls; echo ""
            echo "网络操作"; echo -e "${gl_hong}------------------------${gl_bai}"; echo "1. 创建网络"; echo "2. 加入网络"; echo "3. 退出网络"; echo "4. 删除网络"; echo "0. 返回上一级选单"; echo -e "${gl_hong}------------------------${gl_bai}"
            read -p "请输入你的选择: " sub_choice
            case $sub_choice in
                1) read -p "设置新网络名: " network; docker network create $network ;;
                2) read -p "加入网络名: " network; read -p "哪些容器加入该网络: " names; for name in $names; do docker network connect $network $name; done ;;
                3) read -p "退出网络名: " network; read -p "哪些容器退出该网络: " names; for name in $names; do docker network disconnect $network $name; done ;;
                4) read -p "请输入要删除的网络名: " network; docker network rm $network ;;
                0) break ;;
                *) echo "无效输入"; sleep 1 ;;
            esac
        done
    }
    function docker_volume() {
        while true; do
            clear; echo "Docker卷列表"; docker volume ls; echo ""; echo "卷操作"; echo -e "${gl_hong}------------------------${gl_bai}"; echo "1. 创建新卷"; echo "2. 删除指定卷"; echo "3. 删除所有未使用的卷"; echo "0. 返回上一级选单"; echo -e "${gl_hong}------------------------${gl_bai}"
            read -p "请输入你的选择: " sub_choice
            case $sub_choice in
                1) read -p "设置新卷名: " volume; docker volume create $volume ;;
                2) read -p "输入删除卷名: " volume; docker volume rm $volume ;;
                3) read -p "$(echo -e "${gl_hong}注意: ${gl_bai}确定删除所有未使用的卷吗？(Y/N): ")" choice; if [[ "${choice,,}" == "y" ]]; then docker volume prune -f; fi ;;
                0) break ;;
                *) echo "无效输入"; sleep 1 ;;
            esac
        done
    }
    
    while true; do
      clear; echo -e "Docker管理"; docker_tato; echo -e "${gl_hong}------------------------${gl_bai}"
      echo -e "${gl_kjlan}1.    ${gl_bai}安装/更新Docker环境 ${gl_huang}★${gl_bai}"; echo -e "${gl_kjlan}2.    ${gl_bai}查看Docker全局状态 ${gl_huang}★${gl_bai}"; echo -e "${gl_kjlan}3.    ${gl_bai}Docker容器管理 ${gl_huang}★${gl_bai}"; echo -e "${gl_kjlan}4.    ${gl_bai}Docker镜像管理"; echo -e "${gl_kjlan}5.    ${gl_bai}Docker网络管理"; echo -e "${gl_kjlan}6.    ${gl_bai}Docker卷管理"; echo -e "${gl_kjlan}7.    ${gl_bai}清理无用的Docker数据"; echo -e "${gl_kjlan}8.    ${gl_bai}更换Docker源"; echo -e "${gl_kjlan}20.   ${gl_bai}卸载Docker环境"
      echo -e "${gl_hong}------------------------${gl_bai}"; echo -e "${gl_kjlan}0.    ${gl_bai}返回主菜单"; echo -e "${gl_hong}----------------------------------------${gl_bai}"
      read -p "请输入你的选择: " sub_choice
      case $sub_choice in
        1) clear; install_add_docker; press_any_key_to_continue ;;
        2) clear; docker system df -v; press_any_key_to_continue ;;
        3) docker_ps ;;
        4) docker_image ;;
        5) docker_network ;;
        6) docker_volume ;;
        7) 
          clear; read -p "$(echo -e "${gl_huang}提示: ${gl_bai}将清理无用的镜像容器网络，包括停止的容器，确定清理吗？(Y/N): ")" choice
          if [[ "${choice,,}" == "y" ]]; then docker system prune -af --volumes; else echo "已取消"; fi
          press_any_key_to_continue
          ;;
        8) clear; bash <(curl -sSL https://linuxmirrors.cn/docker.sh); press_any_key_to_continue ;;
        20) 
          clear
          read -p "$(echo -e "${gl_hong}注意: ${gl_bai}确定卸载docker环境吗？(Y/N): ")" choice
          case "$choice" in
            [Yy])
              docker ps -a -q | xargs -r docker rm -f && docker images -q | xargs -r docker rmi -f
              remove docker docker-compose docker-ce docker-ce-cli containerd.io
              rm -f /etc/docker/daemon.json; hash -r
              ;;
            *) echo "已取消" ;;
          esac
          press_any_key_to_continue
          ;;
        0) break ;;
        *) echo "无效输入"; sleep 1 ;;
      esac
    done
}


# (核心功能) 安装快捷指令
function install_shortcut() {
  local shortcut_name="y"
  local install_name="ayang"
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
        exec "/usr/local/bin/y"
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
  
  local shortcut_path="/usr/local/bin/y"
  local root_copy_path="/root/ayang.sh"

  if [[ "$(id -u)" -ne 0 ]]; then echo -e "${gl_hong}错误：卸载过程需要 root 权限。${gl_bai}"; press_any_key_to_continue; return; fi
  if [ ! -f "${shortcut_path}" ] && [ ! -f "${root_copy_path}" ]; then echo -e "${gl_huang}脚本未安装或文件不存在，无需卸载。${gl_bai}"; press_any_key_to_continue; return; fi

  echo -e "${gl_hong}警告：这将从系统中永久删除脚本 '${shortcut_path}' 和 '${root_copy_path}'。${gl_bai}"
  read -p "你确定要继续吗？ (输入 'y' 确认, 其他任意键取消): " confirm
  if [[ "${confirm,,}" != "y" ]]; then echo -e "\n${gl_huang}操作已取消。${gl_bai}"; press_any_key_to_continue; return; fi
  
  echo -e "\n${gl_lan}正在移除快捷命令: ${shortcut_path}...${gl_bai}"; rm -f "${shortcut_path}"
  echo -e "\n${gl_lan}正在移除源文件副本: ${root_copy_path}...${gl_bai}"; rm -f "${root_copy_path}"
  
  echo -e "\n${gl_lv}✅ 卸载完成！${gl_bai}"
  echo -e "所有相关文件已被移除。"; echo -e "脚本即将退出。"; sleep 1; exit 0
}

# --- 主菜单显示 ---
function main_menu() {
  clear
  echo -e "${gl_kjlan}"
  echo -e "    █████╗ ██╗    ██╗ █████╗ ███╗    ██╗ ██████╗"
  echo -e "   ██╔══██╗╚██╗ ██╔╝██╔══██╗████╗   ██║██╔════╝"
  echo -e "   ███████║ ╚████╔╝ ███████║██╔██╗  ██║██║  ███╗"
  echo -e "   ██╔══██║  ╚██╔╝  ██╔══██║██║╚██╗██║██║    ██║"
  echo -e "   ██║  ██║   ██║   ██║  ██║██║ ╚████║╚██████╔╝"
  echo -e "   ╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═══╝ ╚═════╝"
  echo -e "${gl_bai}"
  echo -e "${gl_lan}          AYANG's Toolbox v${SCRIPT_VERSION}              ${gl_bai}"
  echo -e "${gl_hong}----------------------------------------------------${gl_bai}"
  echo -e "${gl_kjlan}1.  ${gl_bai}系统信息查询"
  echo -e "${gl_kjlan}2.  ${gl_bai}系统更新"
  echo -e "${gl_kjlan}3.  ${gl_bai}系统清理"
  echo -e "${gl_kjlan}4.  ${gl_bai}系统工具"
	echo -e "${gl_kjlan}5.  ${gl_bai}应用管理"
	echo -e "${gl_kjlan}6.  ${gl_bai}Docker管理"
	echo -e "${gl_hong}----------------------------------------------------${gl_bai}"
	echo -e "${gl_kjlan}00. ${gl_bai}更新脚本"
	echo -e "${gl_kjlan}000.${gl_bai}卸载脚本"
	echo -e "${gl_kjlan}0.  ${gl_bai}退出脚本"
	echo -e "${gl_hong}----------------------------------------------------${gl_bai}"
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
        4) system_tools ;;
        5) app_management ;;
        6) docker_management ;;
        00) update_script ;;
        000) uninstall_script ;;
        0) clear; exit 0 ;;
        *) echo "无效输入"; sleep 1 ;;
      esac
    done
}


# ===================================================================================
# --- 脚本主入口逻辑 ---
# ===================================================================================

readonly INSTALL_PATH="/usr/local/bin/y"

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
