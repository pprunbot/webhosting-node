#!/bin/bash

# 退出脚本执行错误
set -e

# 颜色定义
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
MAGENTA='\033[35m'
CYAN='\033[36m'
BOLD='\033[1m'
RESET='\033[0m'

# 项目信息
PROJECT_URL="https://github.com/pprunbot/webhosting-node"

# 绘制分隔线
draw_line() {
  printf "%$(tput cols)s\n" | tr ' ' '─'
}

# 显示项目信息
show_header() {
  clear
  echo -e "${GREEN}${BOLD}"
  draw_line
  printf "%*s\n" $(( (${#1} + $(tput cols)) / 2 )) "🌐 $1"
  draw_line
  echo -e "${RESET}"
  echo -e "${CYAN}📦 项目地址: ${YELLOW}${PROJECT_URL}${RESET}\n"
}

# 获取当前用户名
USERNAME=$(whoami)

# 初始界面
show_header "WebHosting Node 管理工具"

# 主菜单
main_menu() {
  echo -e "${BOLD}${MAGENTA}📋 主菜单：${RESET}"
  echo -e "  ${GREEN}1)${RESET} 🚀 新建项目部署"
  echo -e "  ${GREEN}2)${RESET} 🗑️ 卸载现有项目"
  echo -e "  ${GREEN}3)${RESET} ❌ 退出系统"
  draw_line
  read -p "$(echo -e "${BOLD}${CYAN}🔍 请选择操作 [1-3]: ${RESET}")" MAIN_CHOICE

  case $MAIN_CHOICE in
    1) install_menu ;;
    2) uninstall_menu ;;
    3) echo -e "${YELLOW}👋 再见！${RESET}"; exit 0 ;;
    *)
      echo -e "${RED}⚠ 无效选项，请重新选择${RESET}"
      sleep 1
      main_menu
      ;;
  esac
}

# 安装菜单
install_menu() {
  show_header "新建项目部署"

  DOMAINS_DIR="/home/$USERNAME/domains"
  if [ ! -d "$DOMAINS_DIR" ]; then
    echo -e "${RED}❌ 错误：未找到域名目录 ${DOMAINS_DIR}${RESET}"
    exit 1
  fi

  DOMAINS=($(ls -d $DOMAINS_DIR/*/ | xargs -n1 basename))
  if [ ${#DOMAINS[@]} -eq 0 ]; then
    echo -e "${RED}❌ 错误：未找到任何域名配置${RESET}"
    exit 1
  fi

  echo -e "${BOLD}${BLUE}🌍 可用域名列表：${RESET}"
  for i in "${!DOMAINS[@]}"; do
    printf "${GREEN}%2d)${RESET} %s\n" "$((i+1))" "${DOMAINS[$i]}"
  done

  echo ""
  read -p "$(echo -e "${BOLD}${CYAN}📌 请选择域名（输入数字）[默认1]: ${RESET}")" DOMAIN_INDEX
  DOMAIN_INDEX=${DOMAIN_INDEX:-1}
  if [[ ! $DOMAIN_INDEX =~ ^[0-9]+$ ]] || [ $DOMAIN_INDEX -lt 1 ] || [ $DOMAIN_INDEX -gt ${#DOMAINS[@]} ]; then
    echo -e "${RED}❌ 无效的选择${RESET}"
    exit 1
  fi

  DOMAIN=${DOMAINS[$((DOMAIN_INDEX-1))]}
  echo -e "\n✅ 已选择域名: ${YELLOW}${DOMAIN}${RESET}"

  draw_line
  echo ""
  read -p "$(echo -e "${BOLD}${CYAN}📦 请输入端口号 [默认4000]: ${RESET}")" PORT
  PORT=${PORT:-4000}
  if [[ ! $PORT =~ ^[0-9]+$ ]] || [ $PORT -lt 1 ] || [ $PORT -gt 65535 ]; then
    echo -e "${RED}❌ 无效的端口号${RESET}"
    exit 1
  fi

  draw_line
  echo ""
  read -p "$(echo -e "${BOLD}${CYAN}🔑 请输入UUID [默认随机生成]: ${RESET}")" UUID
  if [ -z "$UUID" ]; then
    UUID=$(cat /proc/sys/kernel/random/uuid)
    echo -e "✅ 已生成随机UUID: ${YELLOW}${UUID}${RESET}"
  fi

  start_installation
}

# 卸载菜单
uninstall_menu() {
  show_header "项目卸载中心"

  DOMAINS_DIR="/home/$USERNAME/domains"
  INSTALLED=()
  for domain in $(ls -d $DOMAINS_DIR/*/ 2>/dev/null | xargs -n1 basename); do
    if [ -d "$DOMAINS_DIR/$domain/public_html" ]; then
      INSTALLED+=("$domain")
    fi
  done

  if [ ${#INSTALLED[@]} -eq 0 ]; then
    echo -e "${YELLOW}⚠ 没有找到可卸载的项目${RESET}"
    sleep 2
    main_menu
    return
  fi

  echo -e "${BOLD}${RED}⚠ 警告：这将永久删除项目数据！${RESET}\n"
  echo -e "${BOLD}${BLUE}📂 已部署项目列表：${RESET}"
  for i in "${!INSTALLED[@]}"; do
    printf "${RED}%2d)${RESET} %s\n" "$((i+1))" "${INSTALLED[$i]}"
  done

  echo ""
  read -p "$(echo -e "${BOLD}${CYAN}🗑️ 请选择要卸载的项目 [1-${#INSTALLED[@]}]: ${RESET}")" UNINSTALL_INDEX
  if [[ ! $UNINSTALL_INDEX =~ ^[0-9]+$ ]] || [ $UNINSTALL_INDEX -lt 1 ] || [ $UNINSTALL_INDEX -gt ${#INSTALLED[@]} ]; then
    echo -e "${RED}❌ 无效的选择${RESET}"
    exit 1
  fi

  SELECTED_DOMAIN=${INSTALLED[$((UNINSTALL_INDEX-1))]}

  read -p "$(echo -e "${BOLD}${RED}确认要卸载 ${SELECTED_DOMAIN} 吗？[y/N]: ${RESET}")" CONFIRM
  if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}🟡 已取消卸载操作${RESET}"
    exit 0
  fi

  echo -e "\n🔧 正在停止PM2服务..."
  pm2 stop "my-app-${SELECTED_DOMAIN}" || true
  pm2 delete "my-app-${SELECTED_DOMAIN}" || true
  pm2 save

  echo -e "🧹 正在清理项目文件..."
  rm -rf "${DOMAINS_DIR}/${SELECTED_DOMAIN}/public_html"

  echo -e "\n${GREEN}✅ ${SELECTED_DOMAIN} 已成功卸载${RESET}"
  sleep 2
  main_menu
}

# 检测Node.js安装
check_node() {
  if ! command -v node &> /dev/null || ! command -v npm &> /dev/null; then
    echo -e "\n🔧 检测到未安装 Node.js，正在安装..."

    mkdir -p ~/.local/node
    echo -e "${CYAN}▶ 下载 Node.js 运行环境...${RESET}"
    curl -#fsSL https://nodejs.org/dist/v20.12.2/node-v20.12.2-linux-x64.tar.gz -o node.tar.gz

    echo -e "\n${CYAN}▶ 解压文件...${RESET}"
    tar -xzf node.tar.gz --strip-components=1 -C ~/.local/node

    echo -e "\n${CYAN}▶ 配置环境变量...${RESET}"
    echo 'export PATH=$HOME/.local/node/bin:$PATH' >> ~/.bashrc
    echo 'export PATH=$HOME/.local/node/bin:$PATH' >> ~/.bash_profile
    source ~/.bashrc
    source ~/.bash_profile
    rm node.tar.gz
  fi

  if ! command -v node &> /dev/null || ! command -v npm &> /dev/null; then
    echo -e "${RED}❌ Node.js安装失败，请手动安装后重试${RESET}"
    exit 1
  fi
}

# 安装流程
start_installation() {
  check_node

  echo -e "\n🔧 正在安装PM2进程管理器..."
  npm install -g pm2

  PROJECT_DIR="/home/$USERNAME/domains/$DOMAIN/public_html"
  mkdir -p $PROJECT_DIR
  cd $PROJECT_DIR

  echo -e "\n📥 正在下载项目文件..."
  FILES=("app.js" ".htaccess" "package.json" "ws.php")
  for file in "${FILES[@]}"; do
    echo -e "${CYAN}▶ 下载 $file...${RESET}"
    curl -#fsSL https://raw.githubusercontent.com/pprunbot/webhosting-node/main/$file -O
  done

  echo -e "\n📦 正在安装项目依赖..."
  npm install || { echo -e "${RED}❌ 依赖安装失败${RESET}"; exit 1; }

  echo -e "\n⚙️ 正在配置应用参数..."
  sed -i "s/const DOMAIN = process.env.DOMAIN || '.*';/const DOMAIN = process.env.DOMAIN || '$DOMAIN';/" app.js
  sed -i "s/const UUID = process.env.UUID || '.*';/const UUID = process.env.UUID || '$UUID';/" app.js
  sed -i "s/const port = process.env.PORT || .*;/const port = process.env.PORT || $PORT;/" app.js
  sed -i "s/\$PORT/$PORT/g" .htaccess
  sed -i "s/\$PORT/$PORT/g" ws.php

  echo -e "\n🚀 正在启动 PM2 服务..."
  pm2 start app.js --name "my-app-${DOMAIN}"
  pm2 save

  (crontab -l 2>/dev/null; echo "@reboot sleep 30 && /home/$USERNAME/.local/node/bin/pm2 resurrect --no-daemon") | crontab -

  draw_line
  echo -e "${GREEN}${BOLD}✅ 部署成功！${RESET}"
  echo -e "${CYAN}🔗 访问地址\t: ${YELLOW}https://${DOMAIN}${RESET}"
  echo -e "${CYAN}🆔 UUID\t\t: ${YELLOW}${UUID}${RESET}"
  echo -e "${CYAN}🔢 端口号\t: ${YELLOW}${PORT}${RESET}"
  echo -e "${CYAN}📁 项目目录\t: ${YELLOW}${PROJECT_DIR}${RESET}"
  echo -e "${CYAN}📦 GitHub 仓库\t: ${YELLOW}${PROJECT_URL}${RESET}"
  draw_line
  echo ""
}

# 启动主菜单
main_menu
