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

# 绘制美化标题
print_title() {
  echo -e "${GREEN}${BOLD}"
  echo " __        __   _     _           _           _   _           _       _             "
  echo " \ \      / /__| |__ (_)_ __  ___| |_ ___  __| | | |__   ___ | | ___ (_)_ __   __ _ "
  echo "  \ \ /\ / / _ \ '_ \| | '_ \/ __| __/ _ \/ _\` | | '_ \ / _ \| |/ _ \| | '_ \ / _\` |"
  echo "   \ V  V /  __/ |_) | | | | \__ \ ||  __/ (_| | | | | | (_) | | (_) | | | | | (_| |"
  echo "    \_/\_/ \___|_.__/|_|_| |_|___/\__\___|\__,_| |_| |_|\___/|_|\___/|_|_| |_|\__, |"
  echo "                                                                              |___/ "
  echo -e "${RESET}"
}

# 显示项目信息
show_header() {
  clear
  print_title
  echo -e "${CYAN}项目地址: ${YELLOW}${PROJECT_URL}${RESET}\n"
}

# 列出已部署域名
domains_list() {
  DOMAINS_DIR="/home/$USERNAME/domains"
  INSTALLED=()
  for d in $(ls -d $DOMAINS_DIR/*/ 2>/dev/null | xargs -n1 basename); do
    [ -d "$DOMAINS_DIR/$d/public_html" ] && INSTALLED+=("$d")
  done
  if [ ${#INSTALLED[@]} -eq 0 ]; then
    echo -e "${YELLOW}未找到部署项目${RESET}"
    sleep 1
    main_menu
    exit 0
  fi
}

# 选择域名
select_domain() {
  echo -e "${BOLD}${BLUE}可选域名：${RESET}"
  for i in "${!INSTALLED[@]}"; do
    printf "  ${GREEN}%2d)${RESET} %s\n" "$((i+1))" "${INSTALLED[$i]}"
  done
  read -p "$(echo -e "${BOLD}${CYAN}请选择 [1-${#INSTALLED[@]}]: ${RESET}")" DI
  if [[ ! $DI =~ ^[0-9]+$ ]] || [ $DI -lt 1 ] || [ $DI -gt ${#INSTALLED[@]} ]; then
    echo -e "${RED}无效选择${RESET}"
    sleep 1
    main_menu
    exit 0
  fi
  SELECTED_DOMAIN=${INSTALLED[$((DI-1))]}
}

# 安装哪吒监控
install_nezha() {
  show_header
  domains_list
  select_domain
  APP_DIR="/home/$USERNAME/domains/$SELECTED_DOMAIN/public_html"
  cd "$APP_DIR"

  echo -e "\n${BOLD}${CYAN}请输入哪吒监控配置 (必填):${RESET}"
  read -p "$(echo -e "  ${CYAN}哪吒服务器地址 [默认 nezha.gvkoyeb.eu.org]: ${RESET}")" NEZHA_SERVER
  NEZHA_SERVER=${NEZHA_SERVER:-nezha.gvkoyeb.eu.org}
  read -p "$(echo -e "  ${CYAN}哪吒服务器端口 [默认 443]: ${RESET}")" NEZHA_PORT
  NEZHA_PORT=${NEZHA_PORT:-443}
  read -p "$(echo -e "  ${CYAN}哪吒通信密钥: ${RESET}")" NEZHA_KEY

  if [[ -z "$NEZHA_KEY" ]]; then
    echo -e "${RED}错误：通信密钥不能为空!${RESET}"
    sleep 2
    main_menu
    exit 0
  fi

  sed -i "s|const NEZHA_SERVER = process.env.NEZHA_SERVER || '.*';|const NEZHA_SERVER = process.env.NEZHA_SERVER || '${NEZHA_SERVER}';|" app.js
  sed -i "s|const NEZHA_PORT = process.env.NEZHA_PORT || '.*';|const NEZHA_PORT = process.env.NEZHA_PORT || '${NEZHA_PORT}';|" app.js
  sed -i "s|const NEZHA_KEY = process.env.NEZHA_KEY || '.*';|const NEZHA_KEY = process.env.NEZHA_KEY || '${NEZHA_KEY}';|" app.js

  echo -e "${BLUE}正在重启服务...${RESET}"
  pm2 restart "my-app-${SELECTED_DOMAIN}" --silent
  echo -e "${GREEN}✓ 哪吒监控已启用!${RESET}"
  sleep 2
  main_menu
}

# 修改配置（vless 或 哪吒）
modify_config() {
  show_header
  domains_list
  select_domain
  APP_DIR="/home/$USERNAME/domains/$SELECTED_DOMAIN/public_html"
  cd "$APP_DIR"

  echo -e "\n${BOLD}${BLUE}选择要修改的配置类型:${RESET}"
  echo -e "  ${GREEN}1)${RESET} vless 参数"
  echo -e "  ${GREEN}2)${RESET} 哪吒 参数"
  echo -e "  ${GREEN}3)${RESET} 返回主菜单"
  read -p "$(echo -e "${BOLD}${CYAN}请输入 [1-3]: ${RESET}")" CFG_CHOICE

  case $CFG_CHOICE in
    1)
      read -p "$(echo -e "  ${CYAN}新的端口号 (留空保持不变): ${RESET}")" NEW_PORT
      read -p "$(echo -e "  ${CYAN}新的 UUID (留空保持不变): ${RESET}")" NEW_UUID
      if [[ -n "$NEW_PORT" ]]; then
        if [[ ! $NEW_PORT =~ ^[0-9]+$ ]] || [ $NEW_PORT -lt 1 ] || [ $NEW_PORT -gt 65535 ]; then
          echo -e "${RED}无效端口号${RESET}"; sleep 1; main_menu; fi
        sed -i "s/const port = process.env.PORT || .*;/const port = process.env.PORT || ${NEW_PORT};/" app.js
        sed -i "s/\\$PORT/${NEW_PORT}/g" .htaccess ws.php
      fi
      if [[ -n "$NEW_UUID" ]]; then
        sed -i "s/const UUID = process.env.UUID || '.*';/const UUID = process.env.UUID || '${NEW_UUID}';/" app.js
      fi
      echo -e "${GREEN}vless 参数更新完成!${RESET}"
      pm2 restart "my-app-${SELECTED_DOMAIN}" --silent
      ;;
    2)
      echo -e "\n${BOLD}${CYAN}输入新的哪吒配置 (留空保持不变):${RESET}"
      read -p "$(echo -e "  ${CYAN}服务器地址: ${RESET}")" NEW_NS
      read -p "$(echo -e "  ${CYAN}服务器端口: ${RESET}")" NEW_NP
      read -p "$(echo -e "  ${CYAN}通信密钥: ${RESET}")" NEW_NK
      [[ -n "$NEW_NS" ]] && sed -i "s|const NEZHA_SERVER = process.env.NEZHA_SERVER || '.*';|const NEZHA_SERVER = process.env.NEZHA_SERVER || '${NEW_NS}';|" app.js
      [[ -n "$NEW_NP" ]] && sed -i "s|const NEZHA_PORT = process.env.NEZHA_PORT || '.*';|const NEZHA_PORT = process.env.NEZHA_PORT || '${NEW_NP}';|" app.js
      [[ -n "$NEW_NK" ]] && sed -i "s|const NEZHA_KEY = process.env.NEZHA_KEY || '.*';|const NEZHA_KEY = process.env.NEZHA_KEY || '${NEW_NK}';|" app.js
      echo -e "${GREEN}哪吒 参数更新完成!${RESET}"
      pm2.restart "my-app-${SELECTED_DOMAIN}" --silent
      ;;
    *) main_menu ;;  
  esac

  sleep 1
  main_menu
}

# vless 部署菜单
install_menu() {
  show_header
  echo -e "${BOLD}${BLUE}vless 部署${RESET}"

  DOMAINS_DIR="/home/$USERNAME/domains"
  [ ! -d "$DOMAINS_DIR" ] && echo -e "${RED}未找到目录 $DOMAINS_DIR${RESET}" && exit 1
  DOMAINS=( $(ls -d $DOMAINS_DIR/*/ | xargs -n1 basename) )
  [ ${#DOMAINS[@]} -eq 0 ] && echo -e "${RED}未找到域名配置${RESET}" && exit 1

  for i in "${!DOMAINS[@]}"; do printf "  ${GREEN}%2d)${RESET} %s\n" "$((i+1))" "${DOMAINS[$i]}"; done
  read -p "$(echo -e "${BOLD}${CYAN}选择域名 [默认1]: ${RESET}")" IDX
  IDX=${IDX:-1}
  if [[ ! $IDX =~ ^[0-9]+$ ]] || [ $IDX -lt 1 ] || [ $IDX -gt ${#DOMAINS[@]} ]; then echo -e "${RED}无效选择${RESET}"; exit 1; fi
  DOMAIN=${DOMAINS[$((IDX-1))]}

  draw_line
  read -p "$(echo -e "${BOLD}${CYAN}端口号 [默认4000]: ${RESET}")" PORT
  PORT=${PORT:-4000}
  if [[ ! $PORT =~ ^[0-9]+$ ]] || [ $PORT -lt 1 ] || [ $PORT -gt 65535 ]; then echo -e "${RED}无效端口${RESET}"; exit 1; fi

  draw_line
  read -p "$(echo -e "${BOLD}${CYAN}UUID [默认自动生成]: ${RESET}")" UUID
  if [ -z "$UUID" ]; then
    UUID=$(cat /proc/sys/kernel/random/uuid)
    echo -e "${GREEN}已生成UUID: ${YELLOW}${UUID}${RESET}"
  fi

  start_installation
}

# 卸载菜单
uninstall_menu() {
  show_header
  echo -e "${BOLD}${RED}卸载${RESET}"
  domains_list
  select_domain
  read -p "$(echo -e "${BOLD}${RED}确认卸载 ${SELECTED_DOMAIN}? [y/N]: ${RESET}")" CONF
  if [[ ! $CONF =~ ^[Yy]$ ]]; then echo -e "${YELLOW}已取消${RESET}"; sleep 1; main_menu; fi

  echo -e "\n${BLUE}停止PM2服务...${RESET}"
  pm2 delete "my-app-${SELECTED_DOMAIN}" --silent || true
  pm2 save
  echo -e "${BLUE}清理文件...${RESET}"
  rm -rf "/home/$USERNAME/domains/$SELECTED_DOMAIN/public_html"
  echo -e "\n${GREEN}✓ 卸载成功!${RESET}"
  sleep 1
  main_menu
}

# 检测Node.js安装
check_node() {
  if ! command -v node &> /dev/null || ! command -v npm &> /dev/null; then
    echo -e "\n${BLUE}正在安装Node.js...${RESET}"
    mkdir -p ~/.local/node
    curl -#fsSL https://nodejs.org/dist/v20.12.2/node-v20.12.2-linux-x64.tar.gz -o node.tar.gz
    tar -xzf node.tar.gz --strip-components=1 -C ~/.local/node
    echo 'export PATH=$HOME/.local/node/bin:$PATH' >> ~/.bashrc
    echo 'export PATH=$HOME/.local/node/bin:$PATH' >> ~/.bash_profile
    source ~/.bashrc
    source ~/.bash_profile
    rm node.tar.gz
  fi
  if ! command -v node &> /dev/null; then
    echo -e "${RED}Node.js 安装失败，请手动安装后重试${RESET}"
    exit 1
  fi
}

# 安装流程
start_installation() {
  check_node
  echo -e "\n${BLUE}正在安装PM2...${RESET}"
  npm install -g pm2

  PROJECT_DIR="/home/$USERNAME/domains/$DOMAIN/public_html"
  mkdir -p "$PROJECT_DIR" && cd "$PROJECT_DIR"

  echo -e "\n${BLUE}正在下载项目文件...${RESET}"
  FILES=("app.js" ".htaccess" "package.json" "ws.php")
  for f in "${FILES[@]}"; do
    curl -#fsSL https://raw.githubusercontent.com/pprunbot/webhosting-node/main/$f -O
  done

  echo -e "\n${BLUE}正在安装依赖...${RESET}"
  npm install

  echo -e "\n${BLUE}配置应用参数...${RESET}"
  sed -i "s/const DOMAIN = process.env.DOMAIN || '.*';/const DOMAIN = process.env.DOMAIN || '$DOMAIN';/" app.js
  sed -i "s/const UUID = process.env.UUID || '.*';/const UUID = process.env.UUID || '$UUID';/" app.js
  sed -i "s/const port = process.env.PORT || .*;/const port = process.env.PORT || $PORT;/" app.js
  sed -i "s/\\$PORT/$PORT/g" .htaccess ws.php

  # 初始化哪吒监控默认配置
  if ! grep -q "NEZHA_SERVER" app.js; then
    sed -i "/const port/a \\const NEZHA_SERVER = process.env.NEZHA_SERVER || 'nezha.gvkoyeb.eu.org';\\
const NEZHA_PORT = process.env.NEZHA_PORT || '443';\\
const NEZHA_KEY = process.env.NEZHA_KEY || '';" app.js
  fi

  echo -e "\n${BLUE}启动PM2服务...${RESET}"
  pm2 start app.js --name "my-app-${DOMAIN}"
  pm2 save

  # 开机自启
  (crontab -l 2>/dev/null; echo "@reboot sleep 30 && $HOME/.local/node/bin/pm2 resurrect --no-daemon") | crontab -

  draw_line
  echo -e "${GREEN}${BOLD}部署成功！${RESET}"
  echo -e "${CYAN}访问地址	: ${YELLOW}https://${DOMAIN}${RESET}"
  echo -e "${CYAN}UUID		: ${YELLOW}${UUID}${RESET}"
  echo -e "${CYAN}端口号		: ${YELLOW}${PORT}${RESET}"
  echo -e "${CYAN}项目目录	: ${YELLOW}${PROJECT_DIR}${RESET}"
  echo -e "${CYAN}GitHub 仓库	: ${YELLOW}${PROJECT_URL}${RESET}"
  draw_line
  echo ""
  sleep 2
  main_menu
}

# 获取当前用户名
USERNAME=$(whoami)

# 启动主菜单
main_menu
