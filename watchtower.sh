#!/bin/bash

#
# AYANG's Watchtower Management Toolbox (v2.1 - Patched)
#

# --- 颜色定义 ---
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# --- 全局配置 ---
readonly WATCHTOWER_IMAGE="containrrr/watchtower"
readonly WATCHTOWER_CONTAINER_NAME="watchtower"

# --- 辅助函数 ---

# 操作完成后的暂停提示
function press_any_key() {
    echo ""
    read -n 1 -s -r -p "按任意键返回主菜单..."
}

# 检查 Watchtower 容器是否正在运行
function is_watchtower_running() {
    docker ps --format "{{.Names}}" | grep -q "^$WATCHTOWER_CONTAINER_NAME$"
}

# 核心函数：获取 Watchtower 的详细信息 (已修复解析逻辑)
function get_watchtower_info() {
    local monitored_containers=""
    local unmonitored_containers=""
    local current_interval="-"
    local is_monitoring_all=false

    if ! is_watchtower_running; then
        # 如果 Watchtower 未运行，直接返回空值
        echo "$monitored_containers;$unmonitored_containers;$current_interval;$is_monitoring_all"
        return
    fi

    # 1. 解析 Watchtower 的运行命令，提取监控列表和频率
    local cmd_json
    cmd_json=$(docker inspect --format '{{json .Config.Cmd}}' "$WATCHTOWER_CONTAINER_NAME")
    
    # 将 JSON 数组字符串转换为 Bash 数组，这种方法更健壮
    local cmd_array=()
    local temp_str=${cmd_json//[\"\[\]]/} # 移除引号和括号
    IFS=',' read -r -a cmd_array <<< "$temp_str" # 按逗号分割

    local i=0
    while [[ $i -lt ${#cmd_array[@]} ]]; do
        local arg="${cmd_array[$i]}"
        case "$arg" in
            --interval)
                # 跳过 --interval，取下一个元素作为其值
                ((i++))
                current_interval="${cmd_array[$i]}"
                ;;
            # 在此可以添加对其他参数的处理，如 --schedule, --cleanup 等
            *)
                # 不属于任何已知参数的，视为被监控的容器名
                if [[ -n "$arg" ]]; then
                    monitored_containers+="$arg "
                fi
                ;;
        esac
        ((i++))
    done
    # 去除末尾空格
    monitored_containers=$(echo "$monitored_containers" | xargs)

    # 2. 获取本机所有正在运行的容器（排除 Watchtower 自身）
    local all_running_containers
    all_running_containers=$(docker ps --format "{{.Names}}" | grep -v "^$WATCHTOWER_CONTAINER_NAME$" | tr '\n' ' ' | xargs)

    # 3. 判断是否在监控所有容器
    if [[ -z "$monitored_containers" ]]; then
        is_monitoring_all=true
        monitored_containers="所有正在运行的应用"
        unmonitored_containers="无"
    else
        # 4. 计算未被监控的容器列表
        # 使用 comm 命令高效比对两个列表
        local sorted_all
        local sorted_monitored
        sorted_all=$(echo "$all_running_containers" | tr ' ' '\n' | sort)
        sorted_monitored=$(echo "$monitored_containers" | tr ' ' '\n' | sort)
        
        unmonitored_containers=$(comm -23 <(echo "$sorted_all") <(echo "$sorted_monitored") | tr '\n' ' ' | xargs)
    fi

    # 使用分号作为分隔符返回多个值
    echo "$monitored_containers;$unmonitored_containers;$current_interval;$is_monitoring_all"
}

# --- 功能函数 ---

# 应用 Watchtower 配置（安装或更新）
function apply_watchtower_config() {
    local containers_to_monitor="$1"
    local interval="$2"
    local operation_desc="$3"

    echo -e "\n${YELLOW}正在 ${operation_desc}...${NC}"

    # 停止并移除旧的 Watchtower 容器
    if is_watchtower_running; then
        echo " -> 正在停止并移除旧的 Watchtower 容器..."
        docker rm -f "$WATCHTOWER_CONTAINER_NAME" &>/dev/null
    fi

    echo " -> 正在启动新的 Watchtower 容器..."
    # 构建 docker run 命令
    local docker_run_cmd="docker run -d --name $WATCHTOWER_CONTAINER_NAME --restart unless-stopped -v /var/run/docker.sock:/var/run/docker.sock $WATCHTOWER_IMAGE"
    
    if [[ -n "$interval" && "$interval" != "-" ]]; then
        docker_run_cmd+=" --interval $interval"
    fi

    # 只有在明确指定了容器列表时才将其添加到命令中
    if [[ "$containers_to_monitor" != "所有正在运行的应用" && -n "$containers_to_monitor" ]]; then
         docker_run_cmd+=" $containers_to_monitor"
    fi
    
    # 执行命令
    eval "$docker_run_cmd"

    sleep 2 # 等待容器启动
    if is_watchtower_running; then
        echo -e "${GREEN}操作成功！Watchtower 已按新配置运行。${NC}"
    else
        echo -e "${RED}错误：Watchtower 容器启动失败，请检查 Docker 日志。${NC}"
    fi
}

# --- 主菜单和逻辑 ---
function main_menu() {
    while true; do
        clear
        echo "--- Watchtower 管理工具 (v2.1) ---"

        # 获取所有信息
        IFS=';' read -r MONITORED_IMAGES UNMONITORED_IMAGES CURRENT_INTERVAL IS_MONITORING_ALL < <(get_watchtower_info)

        echo -e "\n${CYAN}Watchtower 状态：${NC}"
        if is_watchtower_running; then
            echo -e "  ${GREEN}已安装并正在运行${NC}"
        else
            echo -e "  ${YELLOW}未安装${NC}"
        fi

        echo -e "\n${CYAN}监控详情：${NC}"
        echo -e "  监控中   : ${MONITORED_IMAGES:-无}"
        echo -e "  未监控   : ${UNMONITORED_IMAGES:-无}"
        echo -e "  更新频率 : ${CURRENT_INTERVAL:-无} 秒"
        echo "------------------------------------"
        
        echo "请选择一个操作："
        if is_watchtower_running; then
            echo -e "  ${GREEN}1. 重新安装 Watchtower${NC}"
        else
            echo "  1. 安装 Watchtower"
        fi
        echo "  2. 添加监控应用"
        echo "  3. 移除监控应用"
        echo "  4. 修改监控频率"
        echo "  5. 退出"
        echo "------------------------------------"
        read -p "请输入您的选择 (1-5): " choice
        
        case $choice in
            1) # 安装/重装
                local running_containers
                running_containers=$(docker ps --format "{{.Names}}" | grep -v "^$WATCHTOWER_CONTAINER_NAME$" | tr '\n' ' ')
                echo -e "\n当前正在运行的应用有:\n  ${CYAN}${running_containers:-无}${NC}"
                echo -e "${YELLOW}提示: 若要监控所有应用，请在此处直接按回车。${NC}"
                read -p "请输入您要监控的应用名称 (多个用空格分隔): " images_to_install
                read -p "请输入更新频率（秒，默认 86400）: " interval_seconds
                interval_seconds=${interval_seconds:-86400} # 默认值
                
                apply_watchtower_config "$images_to_install" "$interval_seconds" "安装 Watchtower"
                press_any_key
                ;;

            2) # 添加
                if ! is_watchtower_running; then
                    echo -e "\n${RED}错误：请先安装 Watchtower (选项 1)。${NC}"
                elif [[ "$IS_MONITORING_ALL" == "true" ]]; then
                    echo -e "\n${YELLOW}提示：Watchtower 当前已在监控所有应用，无需单独添加。${NC}"
                elif [[ -z "$UNMONITORED_IMAGES" || "$UNMONITORED_IMAGES" == "无" ]]; then
                     echo -e "\n${YELLOW}提示：没有可供添加的未监控应用了。${NC}"
                else
                    echo -e "\n当前未监控的应用有:\n  ${CYAN}$UNMONITORED_IMAGES${NC}"
                    read -p "请输入要添加的应用名称 (多个用空格分隔): " images_to_add
                    if [[ -n "$images_to_add" ]]; then
                        # 合并新旧列表并去重
                        local new_images
                        new_images=$(echo "$MONITORED_IMAGES $images_to_add" | tr ' ' '\n' | sort -u | tr '\n' ' ' | xargs)
                        apply_watchtower_config "$new_images" "$CURRENT_INTERVAL" "添加监控应用"
                    else
                        echo -e "\n${YELLOW}未输入任何应用，操作取消。${NC}"
                    fi
                fi
                press_any_key
                ;;

            3) # 移除
                if ! is_watchtower_running; then
                    echo -e "\n${RED}错误：请先安装 Watchtower (选项 1)。${NC}"
                elif [[ "$IS_MONITORING_ALL" == "true" ]]; then
                    echo -e "\n${RED}错误：Watchtower 当前在监控所有应用，无法单独移除。${NC}\n如需指定监控，请使用选项 [1] 重新安装。"
                else
                    echo -e "\n当前正在监控的应用有:\n  ${CYAN}$MONITORED_IMAGES${NC}"
                    read -p "请输入要移除的应用名称 (多个用空格分隔): " images_to_remove
                    if [[ -n "$images_to_remove" ]]; then
                        local final_images="$MONITORED_IMAGES"
                        for img in $images_to_remove; do
                            # 检查要移除的镜像是否在监控列表中
                            if ! echo " $MONITORED_IMAGES " | grep -q " $img "; then
                                echo -e "${YELLOW}警告：应用 '$img' 不在监控列表中，已忽略。${NC}"
                                continue
                            fi
                            # 从列表中移除
                            final_images=$(echo " $final_images " | sed "s/ $img / /g" | xargs)
                        done

                        if [[ "$final_images" == "$MONITORED_IMAGES" ]]; then
                             echo -e "\n${YELLOW}没有有效的应用被移除，配置未更改。${NC}"
                        else
                             apply_watchtower_config "$final_images" "$CURRENT_INTERVAL" "移除监控应用"
                        fi
                    else
                        echo -e "\n${YELLOW}未输入任何应用，操作取消。${NC}"
                    fi
                fi
                press_any_key
                ;;

            4) # 修改频率
                if ! is_watchtower_running; then
                    echo -e "\n${RED}错误：请先安装 Watchtower (选项 1)。${NC}"
                else
                    read -p "当前频率为 ${CURRENT_INTERVAL} 秒，请输入新的更新频率 (秒): " new_interval
                    if [[ "$new_interval" =~ ^[0-9]+$ ]]; then
                        local monitored_list_for_update="$MONITORED_IMAGES"
                        # 如果是监控所有，则传递一个空列表给更新函数
                        if [[ "$IS_MONITORING_ALL" == "true" ]]; then
                            monitored_list_for_update=""
                        fi
                        apply_watchtower_config "$monitored_list_for_update" "$new_interval" "修改更新频率"
                    else
                        echo -e "\n${RED}输入无效，频率必须是纯数字。${NC}"
                    fi
                fi
                press_any_key
                ;;

            5) # 退出
                echo "退出脚本。"
                break
                ;;
            *)
                echo -e "\n${RED}无效的选择，请重新输入。${NC}"
                press_any_key
                ;;
        esac
    done
}

# --- 脚本入口 ---
if ! command -v docker &> /dev/null; then
    echo -e "${RED}错误：检测到 Docker 未安装或未在 PATH 中。请先安装 Docker。${NC}"
    exit 1
fi

main_menu
