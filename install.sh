#!/bin/bash

# 退出脚本执行错误
set -e

# 颜色定义
BLACK='\033[30m'
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
MAGENTA='\033[35m'
CYAN='\033[36m'
WHITE='\033[37m'
BOLD='\033[1m'
RESET='\033[0m'

# 图形符号
CHECK="${GREEN}✓${RESET}"
CROSS="${RED}✗${RESET}"
ARROW="${CYAN}➜${RESET}"
PROGRESS="${BLUE}↻${RESET}"

# 项目信息
PROJECT_URL="https://github.com/pprunbot/webhosting-node"
USERNAME=$(whoami)
DOMAINS_DIR="/home/$USERNAME/domains"

# 界面尺寸
WIDTH=70
HEIGHT=20

# --------------------------
# 图形绘制函数
# --------------------------
draw_box() {
  local width=$1
  local height=$2
  echo -ne "${WHITE}"
  
  # 上边框
  echo -n "╭"
  printf "%0.s─" $(seq 1 $((width-2)))
  echo -n "╮"
  
  # 侧边框
  for i in $(seq 1 $((height-2))); do
    echo -ne "\n│"
    printf "%$((width-2))s" " "
    echo -n "│"
  done
  
  # 下边框
  echo -ne "\n╰"
  printf "%0.s─" $(seq 1 $((width-2)))
  echo -ne "╯${RESET}"
}

draw_header() {
  clear
  echo -e "${BLUE}${BOLD}"
  echo "╔══════════════════════════════════════════════════╗"
  printf "║%*s║\n" $(( (34 + ${#1}) / 2 )) " 🚀  $1  🚀 "
  echo "╚══════════════════════════════════════════════════╝"
  echo -e "${RESET}"
  echo -e "${WHITE}  项目地址: ${YELLOW}${PROJECT_URL}${RESET}\n"
}

spinner() {
  local pid=$!
  local delay=0.1
  local spinstr='|/-\'
  while [ -d /proc/$pid ]; do
    printf " [%c]  " "$spinstr"
    spinstr=${spinstr#?}${spinstr%???}
    sleep $delay
    printf "\b\b\b\b\b\b"
  done
  printf "    \b\b\b\b"
}

# --------------------------
# 核心功能函数
# --------------------------
check_node() {
  if ! command -v node &> /dev/null || ! command -v npm &> /dev/null; then
    echo -e "\n${PROGRESS} 安装Node.js..."
    
    mkdir -p ~/.local/node
    curl -#fsSL https://nodejs.org/dist/v20.12.2/node-v20.12.2-linux-x64.tar.gz -o node.tar.gz &
    spinner
    tar -xzf node.tar.gz --strip-components=1 -C ~/.local/node
    
    echo 'export PATH=$HOME/.local/node/bin:$PATH' >> ~/.bashrc
    echo 'export PATH=$HOME/.local/node/bin:$PATH' >> ~/.bash_profile
    source ~/.bashrc
    source ~/.bash_profile
    rm node.tar.gz
  fi

  if ! command -v node &> /dev/null; then
    echo -e "\n${CROSS} Node.js安装失败"
    exit 1
  fi
}

download_files() {
  PROJECT_DIR="/home/$USERNAME/domains/$DOMAIN/public_html"
  mkdir -p $PROJECT_DIR
  cd $PROJECT_DIR

  FILES=("app.js" ".htaccess" "package.json" "ws.php")
  for file in "${FILES[@]}"; do
    curl -#fsSL https://raw.githubusercontent.com/pprunbot/webhosting-node/main/$file -O &
    spinner
  done
}

configure_system() {
  sed -i "s/const DOMAIN = process.env.DOMAIN || '.*';/const DOMAIN = process.env.DOMAIN || '$DOMAIN';/" app.js
  sed -i "s/const UUID = process.env.UUID || '.*';/const UUID = process.env.UUID || '$UUID';/" app.js
  sed -i "s/const port = process.env.PORT || .*;/const port = process.env.PORT || $PORT;/" app.js
  sed -i "s/\$PORT/$PORT/g" .htaccess
  sed -i "s/\$PORT/$PORT/g" ws.php

  npm install > /dev/null 2>&1 &
  spinner

  pm2 start app.js --name "my-app-${DOMAIN}" > /dev/null 2>&1
  pm2 save > /dev/null 2>&1
  (crontab -l 2>/dev/null; echo "@reboot sleep 30 && /home/$USERNAME/.local/node/bin/pm2 resurrect --no-daemon") | crontab -
}

# --------------------------
# 交互功能模块
# --------------------------
main_menu() {
  draw_header "WebHosting 管理平台"
  echo -e "${BOLD}${WHITE}"
  draw_box 50 8
  echo -e "\n${BOLD}${MAGENTA} 主功能菜单：${RESET}"
  echo -e "  ${GREEN}1)${RESET} 新建项目部署       ${ARROW} 创建全新Web服务"
  echo -e "  ${GREEN}2)${RESET} 卸载现有项目       ${ARROW} 清理已部署服务"
  echo -e "  ${GREEN}3)${RESET} 退出系统           ${ARROW} 关闭管理程序"
  
  read -p "$(echo -e "\n${BOLD}${CYAN} 请输入选项 [1-3]: ${RESET}")" choice

  case $choice in
    1) install_flow ;;
    2) uninstall_flow ;;
    3) exit_flow ;;
    *) error_prompt "无效选项" ;;
  esac
}

install_flow() {
  draw_header "新建项目部署"
  
  # 域名选择
  DOMAINS=($(ls -d $DOMAINS_DIR/*/ 2>/dev/null | xargs -n1 basename))
  [ ${#DOMAINS[@]} -eq 0 ] && error_prompt "未找到可用域名"
  
  echo -e "${BOLD}${CYAN} 选择域名：${RESET}"
  for i in "${!DOMAINS[@]}"; do
    printf "  ${GREEN}%2d)${RESET} %s\n" "$((i+1))" "${DOMAINS[$i]}"
  done
  
  read -p "$(echo -e "\n${CYAN} 请选择 [1-${#DOMAINS[@]}]: ${RESET}")" idx
  DOMAIN=${DOMAINS[$((idx-1))]}
  
  # 端口设置
  read -p "$(echo -e "\n${CYAN} 输入端口 [4000]: ${RESET}")" PORT
  PORT=${PORT:-4000}
  [[ ! $PORT =~ ^[0-9]+$ ]] && error_prompt "无效端口"
  
  # UUID设置
  read -p "$(echo -e "\n${CYAN} 输入UUID [随机生成]: ${RESET}")" UUID
  UUID=${UUID:-$(cat /proc/sys/kernel/random/uuid)}
  
  # 确认界面
  draw_header "安装确认"
  echo -e "${WHITE}"
  draw_box 60 6
  echo -e "\n  ${CYAN}域名\t: ${YELLOW}$DOMAIN"
  echo -e "  ${CYAN}端口\t: ${YELLOW}$PORT"
  echo -e "  ${CYAN}UUID\t: ${YELLOW}$UUID"
  read -p "$(echo -e "\n${GREEN} 确认安装？ [y/N]: ${RESET}")" confirm
  [[ ! $confirm =~ ^[Yy]$ ]] && main_menu
  
  # 执行安装
  draw_header "安装进行中"
  echo -e "${PROGRESS} 环境准备..."
  check_node &
  spinner
  
  echo -e "\n${PROGRESS} 下载文件..."
  download_files &
  spinner
  
  echo -e "\n${PROGRESS} 系统配置..."
  configure_system &
  spinner
  
  # 完成界面
  draw_header "安装完成"
  echo -e "${GREEN}"
  draw_box 60 8
  echo -e "\n  ${CHECK} 部署成功！"
  echo -e "  ${CYAN}访问地址\t: ${YELLOW}https://$DOMAIN"
  echo -e "  ${CYAN}服务端口\t: ${YELLOW}$PORT"
  echo -e "  ${CYAN}安全密钥\t: ${YELLOW}$UUID"
  read -p "$(echo -e "\n${WHITE} 按回车返回主菜单...${RESET}")"
  main_menu
}

uninstall_flow() {
  draw_header "项目卸载"
  INSTALLED=()
  for domain in $(ls -d $DOMAINS_DIR/*/ 2>/dev/null | xargs -n1 basename); do
    [ -d "$DOMAINS_DIR/$domain/public_html" ] && INSTALLED+=("$domain")
  done
  
  [ ${#INSTALLED[@]} -eq 0 ] && {
    echo -e "${YELLOW} 没有可卸载的项目"
    sleep 2
    main_menu
  }
  
  echo -e "${RED}⚠ 警告：此操作不可逆！${RESET}"
  echo -e "${CYAN} 已部署项目："
  for i in "${!INSTALLED[@]}"; do
    printf "  ${RED}%2d)${RESET} %s\n" "$((i+1))" "${INSTALLED[$i]}"
  done
  
  read -p "$(echo -e "\n${CYAN} 选择要卸载的项目 [1-${#INSTALLED[@]}]: ${RESET}")" idx
  DOMAIN=${INSTALLED[$((idx-1))]}
  
  read -p "$(echo -e "${RED}⚠ 确认卸载 $DOMAIN? [y/N]: ${RESET}")" confirm
  [[ ! $confirm =~ ^[Yy]$ ]] && main_menu
  
  # 执行卸载
  pm2 stop "my-app-$DOMAIN" >/dev/null 2>&1
  pm2 delete "my-app-$DOMAIN" >/dev/null 2>&1
  rm -rf "$DOMAINS_DIR/$DOMAIN/public_html"
  
  draw_header "卸载完成"
  echo -e "${GREEN}"
  draw_box 50 5
  echo -e "\n  ${CHECK} $DOMAIN 已卸载"
  sleep 2
  main_menu
}

exit_flow() {
  draw_header "感谢使用"
  echo -e "${GREEN}"
  draw_box 50 5
  echo -e "\n  ${CHECK} 已安全退出系统\n"
  exit 0
}

error_prompt() {
  echo -e "\n${RED}"
  draw_box 50 3
  echo -e "  ${CROSS} $1"
  sleep 2
  main_menu
}

# --------------------------
# 启动程序
# --------------------------
[ "$USER" != "root" ] && main_menu || {
  echo -e "${RED}请勿使用root用户运行！${RESET}"
  exit 1
}
