#!/bin/bash

# 定义颜色
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # 无色

# Watchtower 镜像名
WATCHTOWER_IMAGE="containrrr/watchtower"
# Watchtower 容器名
WATCHTOWER_CONTAINER_NAME="watchtower"

# --- 函数定义 ---

# 检查 Watchtower 容器是否正在运行
check_watchtower_status() {
    if docker ps --format "{{.Names}}" | grep -q "^$WATCHTOWER_CONTAINER_NAME$"; then
        echo -e "${GREEN}Watchtower 已安装并正在运行。${NC}"
        return 0
    else
        echo -e "${YELLOW}Watchtower 未运行。${NC}"
        return 1
    fi
}

# 列出所有镜像（已监控和未监控）
list_images() {
    echo ""
    echo "--- 正在被 Watchtower 监控的镜像 ---"
    monitored_images=""
    if docker ps --format "{{.Names}}" | grep -q "^$WATCHTOWER_CONTAINER_NAME$"; then
        monitored_images=$(docker inspect --format '{{.Config.Cmd}}' $WATCHTOWER_CONTAINER_NAME | tr -d '[]' | tr ',' ' ' | xargs)
        echo "$monitored_images"
    else
        echo "Watchtower 未运行，无法获取监控镜像列表。"
    fi
    echo "------------------------------------"
    echo "--- 当前系统中的其他镜像（未监控）---"
    unmonitored_images=$(docker ps --format "{{.Image}}" | grep -v "$WATCHTOWER_IMAGE" | tr '\n' ' ')
    
    # 从未监控列表中移除已监控的镜像，确保不重复
    for m_img in $monitored_images; do
        unmonitored_images=$(echo "$unmonitored_images" | sed "s/\b$m_img\b//g")
    done
    
    echo "$unmonitored_images" | tr -s ' '
    echo "--------------------------------------"
}

# 安装和运行 Watchtower
install_watchtower() {
    read -p "请输入您要 Watchtower 监控的镜像名称（多个用空格分隔）：" images
    read -p "请输入更新频率（秒）：" interval_seconds

    if [[ -z "$images" ]]; then
        echo -e "${RED}镜像名称不能为空。${NC}"
        return
    fi
    if [[ -z "$interval_seconds" || ! "$interval_seconds" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}更新频率必须是数字。${NC}"
        return
    fi

    # 停止旧的 Watchtower 容器（如果有）
    docker rm -f $WATCHTOWER_CONTAINER_NAME &>/dev/null

    echo "正在安装和运行 Watchtower..."
    docker run -d --name $WATCHTOWER_CONTAINER_NAME \
        -v /var/run/docker.sock:/var/run/docker.sock \
        $WATCHTOWER_IMAGE \
        --interval $interval_seconds \
        $images
    echo -e "${GREEN}Watchtower 已成功安装并运行。${NC}"
}

# 添加新镜像到监控列表
add_image() {
    list_images
    read -p "请输入要添加的镜像名称（多个用空格分隔）：" images_to_add
    if [[ -z "$images_to_add" ]]; then
        echo -e "${YELLOW}未输入任何镜像，操作取消。${NC}"
        return
    fi
    
    current_images=$(docker inspect --format '{{.Config.Cmd}}' $WATCHTOWER_CONTAINER_NAME | tr -d '[]' | tr ',' ' ' | xargs)
    new_images="$current_images $images_to_add"
    
    # 移除旧容器
    docker rm -f $WATCHTOWER_CONTAINER_NAME &>/dev/null
    
    echo "正在重启 Watchtower 以添加新镜像..."
    docker run -d --name $WATCHTOWER_CONTAINER_NAME \
        -v /var/run/docker.sock:/var/run/docker.sock \
        $WATCHTOWER_IMAGE \
        --interval $(docker inspect --format '{{index .Config.Cmd 1}}' $WATCHTOWER_CONTAINER_NAME) \
        $new_images
    
    echo -e "${GREEN}镜像已成功添加。${NC}"
}

# 移除监控镜像
remove_image() {
    list_images
    read -p "请输入要移除的镜像名称（多个用空格分隔）：" images_to_remove
    if [[ -z "$images_to_remove" ]]; then
        echo -e "${YELLOW}未输入任何镜像，操作取消。${NC}"
        return
    fi
    
    current_images=$(docker inspect --format '{{.Config.Cmd}}' $WATCHTOWER_CONTAINER_NAME | tr -d '[]' | tr ',' ' ' | xargs)
    
    new_images_list=""
    for current_img in $current_images; do
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
    
    # 移除旧容器
    docker rm -f $WATCHTOWER_CONTAINER_NAME &>/dev/null
    
    echo "正在重启 Watchtower 以移除镜像..."
    docker run -d --name $WATCHTOWER_CONTAINER_NAME \
        -v /var/run/docker.sock:/var/run/docker.sock \
        $WATCHTOWER_IMAGE \
        --interval $(docker inspect --format '{{index .Config.Cmd 1}}' $WATCHTOWER_CONTAINER_NAME) \
        $new_images_list
    
    echo -e "${GREEN}镜像已成功移除。${NC}"
}

# 修改监控频率
modify_frequency() {
    read -p "请输入新的更新频率（秒）：" new_interval
    if [[ -z "$new_interval" || ! "$new_interval" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}更新频率必须是数字。${NC}"
        return
    fi
    
    current_images=$(docker inspect --format '{{.Config.Cmd}}' $WATCHTOWER_CONTAINER_NAME | tr -d '[]' | tr ',' ' ' | xargs)
    
    # 移除旧容器
    docker rm -f $WATCHTOWER_CONTAINER_NAME &>/dev/null
    
    echo "正在重启 Watchtower 以修改更新频率..."
    docker run -d --name $WATCHTOWER_CONTAINER_NAME \
        -v /var/run/docker.sock:/var/run/docker.sock \
        $WATCHTOWER_IMAGE \
        --interval $new_interval \
        $current_images
        
    echo -e "${GREEN}更新频率已成功修改。${NC}"
}

# --- 主菜单 ---

main_menu() {
    clear
    echo "--- Watchtower 管理工具 ---"
    check_watchtower_status
    echo "---------------------------"
    echo "请选择一个操作："
    echo "1. 安装/配置 Watchtower"
    echo "2. 添加监控镜像"
    echo "3. 移除监控镜像"
    echo "4. 修改监控频率"
    echo "5. 退出"
    read -p "请输入您的选择 (1-5)：" choice
    
    case $choice in
        1)
            install_watchtower
            ;;
        2)
            add_image
            ;;
        3)
            remove_image
            ;;
        4)
            modify_frequency
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
