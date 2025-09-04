# AYANG's Toolbox - 服务器管理工具箱

[![版本号](https://img.shields.io/badge/Version-v1.5.0-blue.svg)](https://github.com/wliuy/mypublic/blob/main/ayang.sh)

一个为个人服务器设计的 Shell 脚本工具箱，提供交互式菜单，简化日常 Linux 系统和 Docker 应用的管理任务。

---

## 功能概览

### 1. 系统管理
- **系统信息查询**：一键查看服务器的 CPU、内存、硬盘、IP、地理位置及运行时长。
- **系统更新**：根据不同 Linux 发行版（如 Ubuntu, CentOS, Fedora 等）自动执行系统软件包更新。
- **系统清理**：自动清理无用软件包、缓存和旧的日志文件，释放磁盘空间。
- **系统工具集**：
    - 启用 ROOT 密码登录，并设置密码。
    - 开放所有防火墙端口（基于 `iptables`）。
    - 修改 SSH 登录端口。
    - 优化 DNS 解析地址。
    - 查看端口占用状态。
    - 调整虚拟内存（Swap）大小。
    - 配置系统时区。
    - 管理定时任务。

### 2. 应用管理（基于 Docker）
- **应用安装与管理**：提供一键式安装和管理常用应用，目前支持：
    - **Lucky 反代**：部署一个功能强大的反向代理。
    - **FileBrowser**：搭建一个轻量级的文件管理面板。
    - **Memos**：安装一个开源的轻量级笔记服务。
    - **Watchtower**：自动更新所有或指定 Docker 容器。
- **Memos 备份**：独有的自动备份功能，通过 `rsync` 将 Memos 数据同步到远程服务器，并配置定时任务。

### 3. Docker 管理
- **一站式 Docker 操作**：提供直观的菜单来管理 Docker 环境。
- **安装与卸载**：轻松安装或彻底卸载 Docker 环境。
- **容器与镜像**：对容器和镜像进行批量或单独的启停、删除、重启等操作。
- **网络与数据卷**：对 Docker 网络和数据卷进行创建、删除和清理。
- **系统清理**：一键清理所有未使用的 Docker 镜像、容器、网络和数据卷。

---

## 如何使用

### 1. 快速安装（推荐）

直接在服务器终端运行以下命令：

```bash
bash <(curl -sL [https://raw.githubusercontent.com/wliuy/mypublic/refs/heads/main/ayang.sh](https://raw.githubusercontent.com/wliuy/mypublic/refs/heads/main/ayang.sh))
