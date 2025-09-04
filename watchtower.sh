#!/bin/bash

# 定义颜色
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Watchtower 镜像名和容器名
WATCHTOWER_IMAGE="containrrr/watchtower"
WATCHTOWER_CONTAINER_NAME="watchtower"

# --- 核心函数 ---

# 检查 Watchtower 容器是否正在运行
is_watchtower_running() {
    docker ps --format "{{.Names}}" | grep -q "^$WATCHTOWER_CONTAINER_NAME$"
}

# 获取并返回已监控和未监控的镜像列表
get_image_lists() {
    monitored_images=""
    if is_watchtower_running; then
        # 从容器命令中提取已监控的镜像
        monitored_images=$(docker inspect --format '{{.Config.Cmd}}' $WATCHTOWER_CONTAINER_NAME | tr -d '[]' | tr ',' ' ' | xargs)
    fi

    unmonitored_images=$(docker ps --format "{{.Image}}" | grep -v "$WATCHTOWER_IMAGE" | tr '\n' ' ')
    
    # 从未监控列表中移除已监控的镜像
    for m_img in $monitored_images; do
        unmonitored_images=$(echo "$unmonitored_images" | sed "s/\b$m_img\b//g")
    done

    # 返回值
    echo "$monitored_images"
    echo "$unmonitored_images"
}

# --- 功能菜单 ---

# 安装和运行 Watchtower
install_watchtower() {
    read -p "请输入您要 Watchtower 监控的镜像名称（多个用空格分隔）：" images
    read -p "请输入更新频率（秒）：" interval_seconds

    if [[ -z "$images" ]]; then
        echo -e "${RED}镜像名称不能为空。${NC}"
        return 1
    fi
    if [[ -z "$interval_seconds" || ! "$interval_seconds" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}更新频率必须是数字。${NC}"
        return 1
    fi

    docker rm -f $WATCHTOWER_CONTAINER_NAME &>/dev/null
    echo "正在安装和运行 Watchtower..."
    docker run -d --name $WATCHTOWER_CONTAINER_NAME \
        -v /var/run/docker.sock:/var/run/docker.sock \
        $WATCHTOWER_IMAGE \
        --interval "$interval_seconds" \
        $images
    echo -e "${GREEN}Watchtower 已成功安装并运行。${NC}"
}

# 更新 Watchtower 配置（添加/移除/修改）
update_watchtower_config() {
    local new_images=$1
    local new_interval=$2
    local operation_desc=$3

    # 移除旧容器
    docker rm -f $WATCHTOWER_CONTAINER_NAME &>/dev/null

    echo "正在重启 Watchtower 以 ${operation_desc}..."
    docker run -d --name $WATCHTOWER_CONTAINER_NAME \
        -v /var/run/docker.sock:/var/run/docker.sock \
        $WATCHTOWER_IMAGE \
        --interval "$new_interval" \
        $new_images
    
    echo -e "${GREEN}${operation_desc}完成。${NC}"
}

# --- 主菜单和逻辑 ---

main_menu() {
    clear
    echo "--- Watchtower 管理工具 ---"
    echo "Watchtower状态："
    if is_watchtower_running; then
        echo -e "${GREEN}已安装并正在运行${NC}"
        read -a image_lists <<< "$(get_image_lists)"
        MONITORED_IMAGES="${image_lists[0]}"
        UNMONITORED_IMAGES="${image_lists[1]}"
        CURRENT_INTERVAL=$(docker inspect --format '{{index .Config.Cmd 1}}' $WATCHTOWER_CONTAINER_NAME)
    else
        echo -e "${YELLOW}未安装${NC}"
        read -a image_lists <<< "$(get_image_lists)"
        MONITORED_IMAGES="无"
        UNMONITORED_IMAGES="${image_lists[1]}"
        CURRENT_INTERVAL="无"
    fi

    echo "---------------------------"
    echo "监控中：${MONITORED_IMAGES:-无}"
    echo "未监控：${UNMONITORED_IMAGES:-无}"
    echo "当前频率：${CURRENT_INTERVAL} 秒"
    echo "---------------------------"
    
    echo "请选择一个操作："
    echo "1. 安装Watchtower"
    echo "2. 添加监控应用"
    echo "3. 移除监控应用"
    echo "4. 修改监控频率"
    echo "5. 退出"
    read -p "请输入您的选择 (1-5)：" choice
    
    case $choice in
        1)
            install_watchtower
            ;;
        2)
            if ! is_watchtower_running; then
                echo -e "${RED}请先安装Watchtower（选项1）。${NC}"
            else
                read -p "请输入要添加的镜像名称（多个用空格分隔）：" images_to_add
                if [[ -z "$images_to_add" ]]; then
                    echo -e "${YELLOW}未输入任何镜像，操作取消。${NC}"
                else
                    new_images="$MONITORED_IMAGES $images_to_add"
                    update_watchtower_config "$new_images" "$CURRENT_INTERVAL" "添加新镜像"
                fi
            fi
            ;;
        3)
            if ! is_watchtower_running; then
                echo -e "${RED}请先安装Watchtower（选项1）。${NC}"
            else
                read -p "请输入要移除的镜像名称（多个用空格分隔）：" images_to_remove
                if [[ -z "$images_to_remove" ]]; then
                    echo -e "${YELLOW}未输入任何镜像，操作取消。${NC}"
                else
                    new_images_list=""
                    for current_img in $MONITORED_IMAGES; do
                        is_removed=false
                        for remove_img in $images_to_remove; do
                            if [[ "$current_img" == "$remove_img" ]]; then
                                is_removed=true
                                break
                            fi
                        done
                        if [[ "$is_removed" == false ]]; then
                            new_images_list+="$current_img "
                        fi
                    done
                    update_watchtower_config "$new_images_list" "$CURRENT_INTERVAL" "移除镜像"
                fi
            fi
            ;;
        4)
            if ! is_watchtower_running; then
                echo -e "${RED}请先安装Watchtower（选项1）。${NC}"
            else
                read -p "请输入新的更新频率（秒）：" new_interval
                if [[ -z "$new_interval" || ! "$new_interval" =~ ^[0-9]+$ ]]; then
                    echo -e "${RED}更新频率必须是数字。${NC}"
                else
                    update_watchtower_config "$MONITORED_IMAGES" "$new_interval" "修改频率"
                fi
            fi
            ;;
        5)
            echo "退出脚本。"
            exit 0
            ;;
        *)
            echo -e "${RED}无效的选择，请重新输入。${NC}"
            ;;
    esac
    
    echo ""
    read -p "按任意键返回主菜单..."
    main_menu
}

# 启动主菜单
main_menu
