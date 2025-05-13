#!/bin/bash

# 退出脚本执行错误
set -e

# 颜色定义
RED='\033[38;5;196m'
GREEN='\033[38;5;46m'
YELLOW='\033[38;5;226m'
BLUE='\033[38;5;45m'
MAGENTA='\033[38;5;201m'
CYAN='\033[38;5;51m'
ORANGE='\033[38;5;208m'
BOLD='\033[1m'
RESET='\033[0m'

# 图形元素
PROJECT_NAME=$(cat <<-'EOF'
 ██████╗ ██████╗ ███████╗██╗  ██╗     ██████╗ ██████╗ ███╗   ██╗
██╔═══██╗██╔══██╗██╔════╝██║  ██║    ██╔════╝██╔═══██╗████╗  ██║
██║   ██║██████╔╝█████╗  ███████║    ██║     ██║   ██║██╔██╗ ██║
██║   ██║██╔═══╝ ██╔══╝  ██╔══██║    ██║     ██║   ██║██║╚██╗██║
╚██████╔╝██║     ███████╗██║  ██║    ╚██████╗╚██████╔╝██║ ╚████║
 ╚═════╝ ╚═╝     ╚══════╝╚═╝  ╚═╝     ╚═════╝ ╚═════╝ ╚═╝  ╚═══╝
EOF
)

# 项目信息
PROJECT_URL="https://github.com/pprunbot/webhosting-node"
VERSION="2.1.0"

# 绘制分隔线
draw_line() {
  echo -e "${BLUE}┌──────────────────────────────────────────────────────────────┐${RESET}"
}

# 显示标题
show_header() {
  clear
  echo -e "${MAGENTA}${PROJECT_NAME}${RESET}"
  echo -e "${CYAN}${BOLD}Version ${VERSION}${RESET}"
  draw_line
  echo -e "${YELLOW}📦 项目地址: ${BLUE}${PROJECT_URL}${RESET}"
  draw_line
  echo
}

# 进度动画
show_spinner() {
  local pid=$!
  local delay=0.1
  local spinstr='|/-\'
  while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
    local temp=${spinstr#?}
    printf " [%c]  " "$spinstr"
    local spinstr=$temp${spinstr%"$temp"}
    sleep $delay
    printf "\b\b\b\b\b\b"
  done
  printf "    \b\b\b\b"
}

# 卸载功能
uninstall() {
  show_header
  echo -e "${RED}${BOLD}⚠️ 警告：这将删除所有安装内容！${RESET}"
  read -p "$(echo -e "${BOLD}确定要卸载吗？(y/N): ${RESET}")" confirm
  
  if [[ $confirm =~ [Yy] ]]; then
    echo -e "\n${CYAN}▶ 正在停止PM2进程...${RESET}"
    pm2 delete my-app 2>/dev/null || true
    pm2 save 2>/dev/null || true
    
    echo -e "${CYAN}▶ 删除定时任务...${RESET}"
    crontab -l | grep -v 'pm2 resurrect' | crontab -
    
    echo -e "${CYAN}▶ 清理项目文件...${RESET}"
    [ -d "$PROJECT_DIR" ] && rm -rf "$PROJECT_DIR"
    
    echo -e "${CYAN}▶ 移除Node.js环境...${RESET}"
    [ -d ~/.local/node ] && rm -rf ~/.local/node
    
    echo -e "\n${GREEN}✓ 卸载完成！${RESET}"
  else
    echo -e "\n${BLUE}操作已取消${RESET}"
  fi
  exit 0
}

# 主菜单
main_menu() {
  show_header
  echo -e "${BOLD}${GREEN}请选择操作：${RESET}"
  echo -e "  ${CYAN}1) 安装WebHosting节点${RESET}"
  echo -e "  ${ORANGE}2) 卸载WebHosting节点${RESET}"
  echo -e "  ${RED}3) 退出脚本${RESET}"
  echo
  draw_line
  
  read -p "$(echo -e "${BOLD}请输入选项 (1-3): ${RESET}")" choice
  
  case $choice in
    1) install_process ;;
    2) uninstall ;;
    3) exit 0 ;;
    *) echo -e "${RED}无效选项，请重新输入${RESET}"; sleep 1; main_menu ;;
  esac
}

# 安装流程
install_process() {
  # 获取当前用户名
  USERNAME=$(whoami)
  
  # 检测域名目录
  DOMAINS_DIR="/home/$USERNAME/domains"
  if [ ! -d "$DOMAINS_DIR" ]; then
    echo -e "${RED}错误：未找到域名目录 ${DOMAINS_DIR}${RESET}"
    exit 1
  fi

  # 获取可用域名列表
  DOMAINS=($(ls -d $DOMAINS_DIR/*/ | xargs -n1 basename))
  if [ ${#DOMAINS[@]} -eq 0 ]; then
    echo -e "${RED}错误：未找到任何域名配置${RESET}"
    exit 1
  fi

  # 域名选择
  show_header
  echo -e "${BOLD}${CYAN}🌐 可用域名列表：${RESET}"
  for i in "${!DOMAINS[@]}"; do
    printf "${GREEN}%2d)${RESET} %s\n" "$((i+1))" "${DOMAINS[$i]}"
  done

  read -p "$(echo -e "${BOLD}${CYAN}请选择域名（输入数字）[默认1]: ${RESET}")" DOMAIN_INDEX
  DOMAIN_INDEX=${DOMAIN_INDEX:-1}
  if [[ ! $DOMAIN_INDEX =~ ^[0-9]+$ ]] || [ $DOMAIN_INDEX -lt 1 ] || [ $DOMAIN_INDEX -gt ${#DOMAINS[@]} ]; then
    echo -e "${RED}无效的选择${RESET}"
    exit 1
  fi

  DOMAIN=${DOMAINS[$((DOMAIN_INDEX-1))]}
  PROJECT_DIR="/home/$USERNAME/domains/$DOMAIN/public_html"
  
  # 获取端口
  show_header
  read -p "$(echo -e "${BOLD}${CYAN}🚪 请输入端口号 [默认4000]: ${RESET}")" PORT
  PORT=${PORT:-4000}
  if [[ ! $PORT =~ ^[0-9]+$ ]] || [ $PORT -lt 1 ] || [ $PORT -gt 65535 ]; then
    echo -e "${RED}无效的端口号${RESET}"
    exit 1
  fi

  # 获取UUID
  show_header
  read -p "$(echo -e "${BOLD}${CYAN}🔑 请输入UUID [默认随机生成]: ${RESET}")" UUID
  if [ -z "$UUID" ]; then
    UUID=$(cat /proc/sys/kernel/random/uuid)
    echo -e "${GREEN}✓ 已生成随机UUID: ${YELLOW}${UUID}${RESET}"
    sleep 1
  fi

  # Node.js安装检测
  check_node() {
    if ! command -v node &> /dev/null; then
      show_header
      echo -e "${CYAN}▶ 安装Node.js运行环境...${RESET}"
      mkdir -p ~/.local/node
      curl -#fSL https://nodejs.org/dist/v20.12.2/node-v20.12.2-linux-x64.tar.gz -o node.tar.gz &
      show_spinner
      tar -xzf node.tar.gz --strip-components=1 -C ~/.local/node
      echo 'export PATH=$HOME/.local/node/bin:$PATH' >> ~/.bashrc
      echo 'export PATH=$HOME/.local/node/bin:$PATH' >> ~/.bash_profile
      source ~/.bashrc
      source ~/.bash_profile
      rm node.tar.gz
    fi
  }

  # 安装流程
  show_header
  echo -e "${CYAN}▶ 开始安装流程...${RESET}"
  
  check_node
  echo -e "${GREEN}✓ Node.js环境就绪${RESET}"
  
  echo -e "${CYAN}▶ 安装PM2进程管理器...${RESET}"
  npm install -g pm2 &> /dev/null &
  show_spinner
  echo -e "${GREEN}✓ PM2安装完成${RESET}"
  
  mkdir -p $PROJECT_DIR
  cd $PROJECT_DIR
  
  # 下载文件
  FILES=("app.js" ".htaccess" "package.json" "ws.php")
  for file in "${FILES[@]}"; do
    echo -e "${CYAN}▶ 下载 $file...${RESET}"
    curl -#fSL https://raw.githubusercontent.com/pprunbot/webhosting-node/main/$file -O
  done
  
  # 安装依赖
  echo -e "${CYAN}▶ 安装项目依赖...${RESET}"
  npm install &> /dev/null &
  show_spinner
  
  # 配置修改
  sed -i "s/const DOMAIN = process.env.DOMAIN || '.*';/const DOMAIN = process.env.DOMAIN || '$DOMAIN';/" app.js
  sed -i "s/const UUID = process.env.UUID || '.*';/const UUID = process.env.UUID || '$UUID';/" app.js
  sed -i "s/const port = process.env.PORT || .*;/const port = process.env.PORT || $PORT;/" app.js
  sed -i "s/\$PORT/$PORT/g" .htaccess
  sed -i "s/\$PORT/$PORT/g" ws.php
  
  # 启动服务
  pm2 start app.js --name my-app
  pm2 save
  
  # 定时任务
  (crontab -l 2>/dev/null; echo "@reboot sleep 30 && $HOME/.local/node/bin/pm2 resurrect --no-daemon") | crontab -
  
  # 完成界面
  show_header
  draw_line
  echo -e "${GREEN}${BOLD}🎉 部署成功！${RESET}"
  echo -e "${CYAN}┌──────────────────────────┬─────────────────────────────┐${RESET}"
  echo -e "${CYAN}│ ${BOLD}🔗 访问地址${RESET}${CYAN}          │ ${YELLOW}https://${DOMAIN}${RESET}"
  echo -e "${CYAN}│ ${BOLD}🔑 UUID${RESET}${CYAN}               │ ${YELLOW}${UUID}${RESET}"
  echo -e "${CYAN}│ ${BOLD}🚪 端口号${RESET}${CYAN}             │ ${YELLOW}${PORT}${RESET}"
  echo -e "${CYAN}│ ${BOLD}📁 项目目录${RESET}${CYAN}           │ ${YELLOW}${PROJECT_DIR}${RESET}"
  echo -e "${CYAN}│ ${BOLD}⚙️ 管理命令${RESET}${CYAN}           │ ${YELLOW}pm2 logs my-app${RESET}"
  echo -e "${CYAN}└──────────────────────────┴─────────────────────────────┘${RESET}"
  draw_line
}

# 启动主菜单
main_menu
