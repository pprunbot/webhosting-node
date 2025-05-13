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

# 图形元素（修正heredoc问题）
PROJECT_NAME=' ██████╗ ██████╗ ███████╗██╗  ██╗     ██████╗ ██████╗ ███╗   ██╗
██╔═══██╗██╔══██╗██╔════╝██║  ██║    ██╔════╝██╔═══██╗████╗  ██║
██║   ██║██████╔╝█████╗  ███████║    ██║     ██║   ██║██╔██╗ ██║
██║   ██║██╔═══╝ ██╔══╝  ██╔══██║    ██║     ██║   ██║██║╚██╗██║
╚██████╔╝██║     ███████╗██║  ██║    ╚██████╗╚██████╔╝██║ ╚████║
 ╚═════╝ ╚═╝     ╚══════╝╚═╝  ╚═╝     ╚═════╝ ╚═════╝ ╚═╝  ╚═══╝'

# 项目信息
PROJECT_URL="https://github.com/pprunbot/webhosting-node"
VERSION="2.1.1"

# 绘制分隔线
draw_line() {
  cols=$(tput cols)
  echo -e "${BLUE}┌$(printf "%*s" $((cols-2)) | tr ' ' '─')┐${RESET}"
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

# 进度动画（改进兼容性）
show_spinner() {
  local pid=$!
  local delay=0.1
  local spinstr='|/-\'
  while kill -0 $pid 2>/dev/null; do
    local temp=${spinstr#?}
    printf " [%c]  " "$spinstr"
    local spinstr=$temp${spinstr%"$temp"}
    sleep $delay
    printf "\b\b\b\b\b\b"
  done
  printf "    \b\b\b\b"
}

# 卸载功能（增加路径验证）
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
    [ -n "$PROJECT_DIR" ] && [ -d "$PROJECT_DIR" ] && rm -rf "$PROJECT_DIR"
    
    echo -e "${CYAN}▶ 移除Node.js环境...${RESET}"
    [ -d ~/.local/node ] && rm -rf ~/.local/node
    
    echo -e "\n${GREEN}✓ 卸载完成！${RESET}"
  else
    echo -e "\n${BLUE}操作已取消${RESET}"
  fi
  exit 0
}

# 主菜单（增加输入验证）
main_menu() {
  show_header
  echo -e "${BOLD}${GREEN}请选择操作：${RESET}"
  echo -e "  ${CYAN}1) 安装WebHosting节点${RESET}"
  echo -e "  ${ORANGE}2) 卸载WebHosting节点${RESET}"
  echo -e "  ${RED}3) 退出脚本${RESET}"
  echo
  draw_line
  
  while true; do
    read -p "$(echo -e "${BOLD}请输入选项 (1-3): ${RESET}")" choice
    case $choice in
      1) install_process; break ;;
      2) uninstall; break ;;
      3) exit 0 ;;
      *) echo -e "${RED}无效选项，请输入数字1-3${RESET}"; sleep 1 ;;
    esac
  done
}

# 安装流程（增强错误处理）
install_process() {
  USERNAME=$(whoami)
  DOMAINS_DIR="/home/$USERNAME/domains"
  
  # 域名目录验证
  if [ ! -d "$DOMAINS_DIR" ]; then
    echo -e "${RED}错误：未找到域名目录 ${DOMAINS_DIR}${RESET}"
    exit 1
  fi

  DOMAINS=($(ls -d $DOMAINS_DIR/*/ 2>/dev/null | xargs -n1 basename))
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

  while true; do
    read -p "$(echo -e "${BOLD}${CYAN}请选择域名（输入数字）[默认1]: ${RESET}")" DOMAIN_INDEX
    DOMAIN_INDEX=${DOMAIN_INDEX:-1}
    if [[ $DOMAIN_INDEX =~ ^[0-9]+$ ]] && [ $DOMAIN_INDEX -ge 1 ] && [ $DOMAIN_INDEX -le ${#DOMAINS[@]} ]; then
      break
    else
      echo -e "${RED}无效的选择，请重新输入${RESET}"
    fi
  done

  DOMAIN=${DOMAINS[$((DOMAIN_INDEX-1))]}
  PROJECT_DIR="/home/$USERNAME/domains/$DOMAIN/public_html"
  
  # 获取端口（增强验证）
  while true; do
    show_header
    read -p "$(echo -e "${BOLD}${CYAN}🚪 请输入端口号 [4000-50000] [默认4000]: ${RESET}")" PORT
    PORT=${PORT:-4000}
    if [[ $PORT =~ ^[0-9]+$ ]] && [ $PORT -ge 4000 ] && [ $PORT -le 50000 ]; then
      break
    else
      echo -e "${RED}端口号必须在4000-50000之间${RESET}"
      sleep 2
    fi
  done

  # 获取UUID（增强格式验证）
  while true; do
    show_header
    read -p "$(echo -e "${BOLD}${CYAN}🔑 请输入UUID [默认随机生成]: ${RESET}")" UUID
    if [ -z "$UUID" ]; then
      UUID=$(cat /proc/sys/kernel/random/uuid)
      echo -e "${GREEN}✓ 已生成随机UUID: ${YELLOW}${UUID}${RESET}"
      sleep 1
      break
    elif [[ $UUID =~ ^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$ ]]; then
      break
    else
      echo -e "${RED}UUID格式无效，必须为UUIDv4格式${RESET}"
      sleep 2
    fi
  done

  # Node.js安装检测（改进安装流程）
  check_node() {
    if ! command -v node &> /dev/null; then
      show_header
      echo -e "${CYAN}▶ 安装Node.js运行环境...${RESET}"
      mkdir -p ~/.local/node
      echo -e "${YELLOW}下载Node.js二进制包...${RESET}"
      curl -#fSL https://nodejs.org/dist/v20.12.2/node-v20.12.2-linux-x64.tar.gz -o node.tar.gz &
      show_spinner
      echo -e "\n${YELLOW}解压文件...${RESET}"
      tar -xzf node.tar.gz --strip-components=1 -C ~/.local/node
      echo 'export PATH="$HOME/.local/node/bin:$PATH"' >> ~/.bashrc
      echo 'export PATH="$HOME/.local/node/bin:$PATH"' >> ~/.bash_profile
      source ~/.bashrc
      source ~/.bash_profile
      rm -f node.tar.gz
    fi
  }

  # 安装流程（分步骤显示）
  show_header
  echo -e "${CYAN}▶ 开始安装流程...${RESET}"
  
  check_node
  echo -e "${GREEN}✓ Node.js环境就绪 (版本: $(node -v))${RESET}"
  
  echo -e "${CYAN}▶ 安装PM2进程管理器...${RESET}"
  npm install -g pm2 &> /dev/null &
  show_spinner
  echo -e "${GREEN}✓ PM2安装完成 (版本: $(pm2 --version))${RESET}"
  
  mkdir -p $PROJECT_DIR
  cd $PROJECT_DIR
  
  # 下载文件（显示进度）
  FILES=("app.js" ".htaccess" "package.json" "ws.php")
  for file in "${FILES[@]}"; do
    echo -e "${CYAN}▶ 下载 $file...${RESET}"
    curl -#fSL https://raw.githubusercontent.com/pprunbot/webhosting-node/main/$file -O
  done
  
  # 安装依赖（错误捕获）
  echo -e "${CYAN}▶ 安装项目依赖...${RESET}"
  if ! npm install &> npm.log; then
    echo -e "${RED}依赖安装失败，错误日志：${RESET}"
    cat npm.log
    exit 1
  fi
  
  # 配置修改（增加备份）
  cp app.js app.js.bak
  sed -i "s/const DOMAIN = process.env.DOMAIN || '.*';/const DOMAIN = process.env.DOMAIN || '${DOMAIN}';/" app.js
  sed -i "s/const UUID = process.env.UUID || '.*';/const UUID = process.env.UUID || '${UUID}';/" app.js
  sed -i "s/const port = process.env.PORT || .*;/const port = process.env.PORT || ${PORT};/" app.js
  sed -i "s/\$PORT/${PORT}/g" .htaccess
  sed -i "s/\$PORT/${PORT}/g" ws.php
  
  # 启动服务（错误处理）
  echo -e "${CYAN}▶ 启动PM2服务...${RESET}"
  if ! pm2 start app.js --name my-app; then
    echo -e "${RED}服务启动失败，请检查日志${RESET}"
    pm2 logs my-app
    exit 1
  fi
  pm2 save
  
  # 定时任务（验证存在性）
  if ! crontab -l | grep -q 'pm2 resurrect'; then
    (crontab -l 2>/dev/null; echo "@reboot sleep 30 && $HOME/.local/node/bin/pm2 resurrect --no-daemon") | crontab -
  fi
  
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
