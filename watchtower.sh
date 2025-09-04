#!/bin/bash

#
# AYANG's Watchtower Management Toolbox (v2.4)
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

# 检查 Watchtower 容器是否存在（包括已停止的）
function does_watchtower_exist() {
    docker ps -a --format "{{.Names}}" | grep -q "^$WATCHTOWER_CONTAINER_NAME$"
}

# 【新增】将秒数格式化为易读的单位
function format_interval() {
    local seconds=$1
    if [[ ! "$seconds" =~ ^[0-9]+$ || "$seconds" -lt 1 ]]; then
        echo "无"
        return
    fi

    if (( seconds % 2592000 == 0 )); then
        echo "$((seconds / 2592000)) 月"
    elif (( seconds % 604800 == 0 )); then
        echo "$((seconds / 604800)) 周"
    elif (( seconds % 86400 == 0 )); then
        echo "$((seconds / 86400)) 天"
    elif (( seconds % 3600 == 0 )); then
        echo "$((seconds / 3600)) 小时"
    else
        echo "$seconds 秒"
    fi
}

# 核心函数：获取 Watchtower 的详细信息
function get_watchtower_info() {
    local monitored_containers=""
    local unmonitored_containers=""
    local current_interval_seconds="-"
    local formatted_interval="无"
    local is_monitoring_all=false

    if ! does_watchtower_exist; then
        echo "$monitored_containers;$unmonitored_containers;$current_interval_seconds;$formatted_interval;$is_monitoring_all"
        return
    fi

    local cmd_json
    cmd_json=$(docker inspect --format '{{json .Config.Cmd}}' "$WATCHTOWER_CONTAINER_NAME")
    
    local cmd_array=()
    if [[ "$cmd_json" != "null" && "$cmd_json" != "[]" ]]; then
        local formatted_cmd
        formatted_cmd=$(echo "$cmd_json" | sed 's/^\[//; s/\]$//; s/,/\n/g' | sed 's/"//g')
        while IFS= read -r line; do
            cmd_array+=("$line")
        done <<< "$formatted_cmd"
    fi

    local next_is_interval=false
    for arg in "${cmd_array[@]}"; do
        if [[ "$next_is_interval" == "true" ]]; then
            current_interval_seconds="$arg"
            next_is_interval=false
            continue
        fi
        case "$arg" in
            --interval) next_is_interval=true ;;
            *)
                if [[ -n "$arg" ]]; then
                    monitored_containers+="$arg "
                fi
                ;;
        esac
    done
    monitored_containers=$(echo "$monitored_containers" | xargs)

    # 【修改点】调用新函数格式化时间
    formatted_interval=$(format_interval "$current_interval_seconds")

    local all_running_containers
    all_running_containers=$(docker ps --format "{{.Names}}" | grep -v "^$WATCHTOWER_CONTAINER_NAME$" | tr '\n' ' ' | xargs)

    if [[ -z "$monitored_containers" ]]; then
        is_monitoring_all=true
        monitored_containers="所有正在运行的应用"
        unmonitored_containers="无"
    else
        local sorted_all
        local sorted_monitored
        sorted_all=$(echo "$all_running_containers" | tr ' ' '\n' | sort)
        sorted_monitored=$(echo "$monitored_containers" | tr ' ' '\n' | sort)
        unmonitored_containers=$(comm -23 <(echo "$sorted_all") <(echo "$sorted_monitored") | tr '\n' ' ' | xargs)
    fi
    
    # 【修改点】返回原始秒数和格式化后的字符串
    echo "$monitored_containers;$unmonitored_containers;$current_interval_seconds;$formatted_interval;$is_monitoring_all"
}

# --- 功能函数 ---

# 应用 Watchtower 配置（安装或更新）
function apply_watchtower_config() {
    local containers_to_monitor="$1"
    local interval="$2"
    local operation_desc="$3"

    echo -e "\n${YELLOW}正在 ${operation_desc}...${NC}"

    if does_watchtower_exist; then
        echo " -> 正在停止并移除旧的 Watchtower 容器..."
        docker rm -f "$WATCHTOWER_CONTAINER_NAME" &>/dev/null
    fi

    echo " -> 正在启动新的 Watchtower 容器..."
    local docker_run_cmd="docker run -d --name $WATCHTOWER_CONTAINER_NAME --restart unless-stopped -v /var/run/docker.sock:/var/run/docker.sock $WATCHTOWER_IMAGE"
    
    if [[ -n "$interval" && "$interval" != "-" ]]; then
        docker_run_cmd+=" --interval $interval"
    fi

    if [[ "$containers_to_monitor" != "所有正在运行的应用" ]]; then
         docker_run_cmd+=" $containers_to_monitor"
    fi
    
    eval "$docker_run_cmd"
    sleep 2
    
    if docker ps --format '{{.Names}}' | grep -q "^$WATCHTOWER_CONTAINER_NAME$"; then
        echo -e "${GREEN}操作成功！Watchtower 已按新配置运行。${NC}"
    else
        echo -e "${RED}错误：Watchtower 容器启动失败，请检查 Docker 日志。${NC}"
    fi
}

# 卸载 Watchtower 函数
function uninstall_watchtower() {
    clear
    echo "--- 卸载 Watchtower ---"
    if ! does_watchtower_exist; then
        echo -e "\n${YELLOW}未找到 Watchtower 容器，无需卸载。${NC}"
        return
    fi

    echo -e "\n${RED}警告：此操作将永久停止并删除 Watchtower 容器及其 Docker 镜像。${NC}"
    read -p "您确定要继续吗？ (输入 'y' 或 '1' 确认, 其他任意键取消): " confirm

    if [[ "${confirm,,}" == "y" || "$confirm" == "1" ]]; then
        echo -e "\n${YELLOW} -> 正在停止 Watchtower 容器...${NC}"
        docker stop "$WATCHTOWER_CONTAINER_NAME" &>/dev/null
        echo -e "${YELLOW} -> 正在删除 Watchtower 容器...${NC}"
        docker rm "$WATCHTOWER_CONTAINER_NAME" &>/dev/null
        echo -e "${YELLOW} -> 正在删除 Watchtower 镜像 ($WATCHTOWER_IMAGE)...${NC}"
        docker rmi "$WATCHTOWER_IMAGE" &>/dev/null
        echo -e "\n${GREEN}Watchtower 已被彻底卸载。${NC}"
    else
        echo -e "\n${YELLOW}操作已取消。${NC}"
    fi
}


# --- 主菜单和逻辑 ---
function main_menu() {
    while true; do
        clear
        echo "--- Watchtower 管理工具 (v2.4) ---"

        # 【修改点】读取5个返回值
        IFS=';' read -r MONITORED_IMAGES UNMONITORED_IMAGES CURRENT_INTERVAL_SECONDS FORMATTED_INTERVAL IS_MONITORING_ALL < <(get_watchtower_info)

        echo -e "\n${CYAN}Watchtower 状态：${NC}"
        if docker ps --format "{{.Names}}" | grep -q "^$WATCHTOWER_CONTAINER_NAME$"; then
            echo -e "  ${GREEN}已安装并正在运行${NC}"
        elif does_watchtower_exist; then
             echo -e "  ${YELLOW}已安装但已停止${NC}"
        else
            echo -e "  ${YELLOW}未安装${NC}"
        fi

        echo -e "\n${CYAN}监控详情：${NC}"
        echo -e "  监控中   : ${CYAN}${MONITORED_IMAGES:-无}${NC}"
        echo -e "  未监控   : ${UNMONITORED_IMAGES:-无}"
        # 【修改点】显示格式化后的时间
        echo -e "  更新频率 : ${FORMATTED_INTERVAL:-无}"
        echo "------------------------------------"
        
        echo "请选择一个操作："
        if does_watchtower_exist; then
            echo -e "  ${GREEN}1. 重新安装/更新配置${NC}"
        else
            echo "  1. 安装 Watchtower"
        fi
        echo "  2. 添加监控应用"
        echo "  3. 移除监控应用"
        echo "  4. 修改监控频率"
        echo "  5. 卸载 Watchtower"
        echo -e "${RED}------------------------------------${NC}"
        echo "  0. 退出脚本"
        echo "------------------------------------"
        read -p "请输入您的选择 (0-5): " choice
        
        case $choice in
            1)
                local running_containers
                running_containers=$(docker ps --format "{{.Names}}" | grep -v "^$WATCHTOWER_CONTAINER_NAME$" | tr '\n' ' ')
                echo -e "\n当前正在运行的应用有:\n  ${CYAN}${running_containers:-无}${NC}"
                echo -e "${YELLOW}提示: 若要监控所有应用，请在此处直接按回车。${NC}"
                read -p "请输入您要监控的应用名称 (多个用空格分隔): " images_to_install
                read -p "请输入更新频率（秒，默认 86400）: " interval_seconds
                interval_seconds=${interval_seconds:-86400}
                
                apply_watchtower_config "$images_to_install" "$interval_seconds" "安装/更新 Watchtower"
                press_any_key
                ;;

            2)
                if ! does_watchtower_exist; then
                    echo -e "\n${RED}错误：请先安装 Watchtower (选项 1)。${NC}"
                elif [[ "$IS_MONITORING_ALL" == "true" ]]; then
                    echo -e "\n${YELLOW}提示：Watchtower 当前已在监控所有应用，无需单独添加。${NC}"
                elif [[ -z "$UNMONITORED_IMAGES" || "$UNMONITORED_IMAGES" == "无" ]]; then
                     echo -e "\n${YELLOW}提示：没有可供添加的未监控应用了。${NC}"
                else
                    echo -e "\n当前未监控的应用有:\n  ${CYAN}$UNMONITORED_IMAGES${NC}"
                    read -p "请输入要添加的应用名称 (多个用空格分隔): " images_to_add
                    if [[ -n "$images_to_add" ]]; then
                        local new_images
                        new_images=$(echo "$MONITORED_IMAGES $images_to_add" | tr ' ' '\n' | sort -u | tr '\n' ' ' | xargs)
                        apply_watchtower_config "$new_images" "$CURRENT_INTERVAL_SECONDS" "添加监控应用"
                    else
                        echo -e "\n${YELLOW}未输入任何应用，操作取消。${NC}"
                    fi
                fi
                press_any_key
                ;;

            3)
                if ! does_watchtower_exist; then
                    echo -e "\n${RED}错误：请先安装 Watchtower (选项 1)。${NC}"
                elif [[ "$IS_MONITORING_ALL" == "true" ]]; then
                    echo -e "\n${RED}错误：Watchtower 当前在监控所有应用，无法单独移除。${NC}\n如需指定监控，请使用选项 [1] 重新安装。"
                else
                    echo -e "\n当前正在监控的应用有:\n  ${CYAN}$MONITORED_IMAGES${NC}"
                    read -p "请输入要移除的应用名称 (多个用空格分隔): " images_to_remove
                    if [[ -n "$images_to_remove" ]]; then
                        local final_images="$MONITORED_IMAGES"
                        for img in $images_to_remove; do
                            if ! echo " $MONITORED_IMAGES " | grep -q " $img "; then
                                echo -e "${YELLOW}警告：应用 '$img' 不在监控列表中，已忽略。${NC}"
                                continue
                            fi
                            final_images=$(echo " $final_images " | sed "s/ $img / /g" | xargs)
                        done

                        if [[ "$final_images" == "$MONITORED_IMAGES" ]]; then
                             echo -e "\n${YELLOW}没有有效的应用被移除，配置未更改。${NC}"
                        else
                             apply_watchtower_config "$final_images" "$CURRENT_INTERVAL_SECONDS" "移除监控应用"
                        fi
                    else
                        echo -e "\n${YELLOW}未输入任何应用，操作取消。${NC}"
                    fi
                fi
                press_any_key
                ;;

            4) # 【修改点】修改频率的交互方式
                if ! does_watchtower_exist; then
                    echo -e "\n${RED}错误：请先安装 Watchtower (选项 1)。${NC}"
                else
                    echo ""
                    echo "--- 修改监控频率 (当前: $FORMATTED_INTERVAL) ---"
                    echo "请选择新的时间单位："
                    echo "  1. 小时"
                    echo "  2. 天"
                    echo "  3. 周"
                    echo "  4. 月 (按30天计算)"
                    read -p "请输入您的选择 (1-4, 其他键取消): " unit_choice

                    local multiplier=0
                    local unit_name=""

                    case $unit_choice in
                        1) multiplier=3600; unit_name="小时" ;;
                        2) multiplier=86400; unit_name="天" ;;
                        3) multiplier=604800; unit_name="周" ;;
                        4) multiplier=2592000; unit_name="月" ;;
                        *) echo -e "\n${YELLOW}操作已取消。${NC}"; press_any_key; continue ;;
                    esac

                    read -p "请输入具体的 ${unit_name} 数 (必须是大于0的整数): " number
                    if [[ ! "$number" =~ ^[1-9][0-9]*$ ]]; then
                        echo -e "\n${RED}输入无效，操作取消。${NC}"
                    else
                        local new_interval=$((number * multiplier))
                        local monitored_list_for_update="$MONITORED_IMAGES"
                        if [[ "$IS_MONITORING_ALL" == "true" ]]; then
                            monitored_list_for_update=""
                        fi
                        apply_watchtower_config "$monitored_list_for_update" "$new_interval" "修改更新频率"
                    fi
                fi
                press_any_key
                ;;

            5) 
                uninstall_watchtower
                press_any_key
                ;;

            0) 
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
