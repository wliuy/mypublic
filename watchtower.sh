#!/bin/bash

# 定义一些颜色，让输出更清晰
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo -e "${GREEN}--- Watchtower 交互式启动脚本 ---${NC}"

# 1. 获取要监控的镜像名称
read -p "请输入您要 Watchtower 监控的镜像名称（多个镜像请用空格分隔）：" images

# 检查输入是否为空
if [ -z "$images" ]; then
    echo "您没有输入任何镜像名称，脚本退出。"
    exit 1
fi

# 2. 获取更新频率
echo ""
echo -e "请选择更新频率："
echo "1) 每小时 (每 60 分钟)"
echo "2) 每天 (每天一次)"
echo "3) 每周 (每周一次)"
echo "4) 每月 (每月一次)"
echo "5) 自定义 cron 表达式（例如：'0 0 4 * * *' 代表每天凌晨 4 点）"
read -p "请输入您的选择 (1-5)：" freq_choice

# 根据选择设置 cron 表达式
case $freq_choice in
    1)
        schedule="0 0 * * * *"
        schedule_desc="每小时"
        ;;
    2)
        schedule="0 0 * * *"
        schedule_desc="每天"
        ;;
    3)
        schedule="0 0 0 * * 0"
        schedule_desc="每周"
        ;;
    4)
        schedule="0 0 0 1 * *"
        schedule_desc="每月"
        ;;
    5)
        read -p "请输入自定义 cron 表达式（例如：'0 0 4 * * *'）：" custom_cron
        schedule="$custom_cron"
        schedule_desc="自定义 cron 表达式"
        ;;
    *)
        echo "无效的选择，使用默认频率：每天。"
        schedule="0 0 * * *"
        schedule_desc="每天"
        ;;
esac

# 3. 构建并运行 Watchtower 命令
echo ""
echo "--- 确认您的配置 ---"
echo "将监控以下镜像：$images"
echo "更新频率：$schedule_desc ($schedule)"
echo "-------------------"
echo ""

# 询问是否以非交互式模式运行
read -p "是否以非交互式模式运行 Watchtower（即作为守护进程）？[y/N]: " run_daemon
run_daemon=${run_daemon:-N}

# 构建 Watchtower 命令
watchtower_cmd="docker run --rm -d \
    --name watchtower \
    -v /var/run/docker.sock:/var/run/docker.sock \
    containrrr/watchtower"

# 添加 cron 表达式
watchtower_cmd+=" --schedule \"$schedule\""

# 添加要监控的镜像
for image in $images; do
    watchtower_cmd+=" $image"
done

# 如果不以守护进程运行，则去掉 -d 并添加 --interactive-mode
if [[ ! "$run_daemon" =~ ^[yY]$ ]]; then
    watchtower_cmd=$(echo $watchtower_cmd | sed 's/ -d / /')
    watchtower_cmd+=" --interactive-mode"
    echo -e "${GREEN}即将以交互式模式运行 Watchtower...${NC}"
    echo "你可以通过 Ctrl+C 退出。"
else
    echo -e "${GREEN}即将以守护进程模式运行 Watchtower...${NC}"
fi

echo "运行命令："
echo "$watchtower_cmd"
echo ""

# 运行命令
eval "$watchtower_cmd"

echo -e "${GREEN}脚本执行完毕。${NC}"
