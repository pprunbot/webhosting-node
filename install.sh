#!/bin/bash

set -e

RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
MAGENTA='\033[35m'
CYAN='\033[36m'
BOLD='\033[1m'
RESET='\033[0m'

PROJECT_URL="https://github.com/pprunbot/webhosting-node"

draw_line() {
  printf "%$(tput cols)s\n" | tr ' ' '─'
}

print_title() {
  echo -e "${BOLD}${CYAN}"
  cat << "EOF"
__        __   _     _           _   _             _           
\ \      / /__| |__ (_) ___  ___| |_(_)_   _____  | | ___  ___ 
 \ \ /\ / / _ \ '_ \| |/ _ \/ __| __| \ \ / / _ \ | |/ _ \/ __|
  \ V  V /  __/ |_) | |  __/\__ \ |_| |\ V /  __/ | | (_) \__ \
   \_/\_/ \___|_.__/|_|\___||___/\__|_| \_/ \___| |_|\___/|___/
EOF
  echo -e "${RESET}"
}

show_header() {
  clear
  print_title
  echo -e "${CYAN}项目地址: ${YELLOW}${PROJECT_URL}${RESET}\n"
}

USERNAME=$(whoami)

main_menu() {
  echo -e "${BOLD}${MAGENTA}主菜单：${RESET}"
  echo -e "  ${GREEN}1)${RESET} 新建项目部署"
  echo -e "  ${GREEN}2)${RESET} 卸载现有项目"
  echo -e "  ${GREEN}3)${RESET} 退出系统"
  echo -e "  ${GREEN}4)${RESET} 修改端口和UUID"
  draw_line
  read -p "$(echo -e "${BOLD}${CYAN}请选择操作 [1-4]: ${RESET}")" MAIN_CHOICE

  case $MAIN_CHOICE in
    1) install_menu ;;
    2) uninstall_menu ;;
    3) exit 0 ;;
    4) modify_config_menu ;;
    *) 
      echo -e "${RED}无效选项，请重新选择${RESET}"
      sleep 1
      main_menu
      ;;
  esac
}

install_menu() {
  show_header
  echo -e "${BOLD}${BLUE}请输入以下信息以开始部署：${RESET}"
  read -p "$(echo -e "${CYAN}域名 (例如 a.360.cloudns.be): ${RESET}")" DOMAIN
  read -p "$(echo -e "${CYAN}端口号 (默认 4000): ${RESET}")" PORT
  PORT=${PORT:-4000}
  read -p "$(echo -e "${CYAN}自定义 UUID (默认随机): ${RESET}")" UUID
  if [ -z "$UUID" ]; then
    UUID=$(cat /proc/sys/kernel/random/uuid)
    echo -e "${GREEN}生成的 UUID: ${YELLOW}$UUID${RESET}"
  fi
  read -p "$(echo -e "${CYAN}自定义用户名 (默认 user): ${RESET}")" USERNAME_INPUT
  USERNAME_INPUT=${USERNAME_INPUT:-user}

  check_node

  echo -e "\n${BLUE}开始部署...${RESET}"

  BASE_DIR="/home/${USERNAME}/domains/${DOMAIN}/public_nodejs"
  mkdir -p "${BASE_DIR}"

  cd "${BASE_DIR}"
  rm -rf webhosting-node
  git clone "${PROJECT_URL}" webhosting-node

  cd webhosting-node
  npm install

  sed -i "s|process.env.DOMAIN || '.*'|process.env.DOMAIN || '${DOMAIN}'|" app.js
  sed -i "s|process.env.PORT || .*|process.env.PORT || ${PORT}|" app.js
  sed -i "s|process.env.UUID || '.*'|process.env.UUID || '${UUID}'|" app.js
  sed -i "s/user/${USERNAME_INPUT}/g" app.js
  sed -i "s/\$PORT/${PORT}/g" .htaccess ws.php

  npx pm2 start app.js --name "my-app-${DOMAIN}"
  npx pm2 save
  npx pm2 startup | tail -n1 | bash

  draw_line
  echo -e "${GREEN}${BOLD}部署完成！${RESET}"
  echo -e "${CYAN}访问地址\t: ${YELLOW}https://${DOMAIN}${RESET}"
  echo -e "${CYAN}UUID\t\t: ${YELLOW}${UUID}${RESET}"
  echo -e "${CYAN}端口号\t\t: ${YELLOW}${PORT}${RESET}"
  echo -e "${CYAN}用户名\t\t: ${YELLOW}${USERNAME_INPUT}${RESET}"
  echo -e "${CYAN}项目目录\t: ${YELLOW}${BASE_DIR}/webhosting-node${RESET}"
  draw_line
  echo ""
  read -p "$(echo -e "${BOLD}${CYAN}按任意键返回主菜单...${RESET}")" _
  main_menu
}

uninstall_menu() {
  show_header
  echo -e "${BOLD}${BLUE}请输入要卸载的域名项目：${RESET}"
  read -p "$(echo -e "${CYAN}域名 (例如 a.360.cloudns.be): ${RESET}")" DOMAIN
  BASE_DIR="/home/${USERNAME}/domains/${DOMAIN}/public_nodejs/webhosting-node"

  if [ ! -d "$BASE_DIR" ]; then
    echo -e "${RED}未找到对应项目目录！${RESET}"
    sleep 2
    main_menu
    return
  fi

  pm2 delete "my-app-${DOMAIN}" || true
  rm -rf "$BASE_DIR"

  draw_line
  echo -e "${GREEN}已卸载 ${DOMAIN} 项目${RESET}"
  draw_line
  echo ""
  read -p "$(echo -e "${BOLD}${CYAN}按任意键返回主菜单...${RESET}")" _
  main_menu
}

check_node() {
  if ! command -v node >/dev/null 2>&1; then
    echo -e "${YELLOW}未检测到 Node.js，正在安装...${RESET}"
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
    apt-get install -y nodejs
  fi

  if ! command -v pm2 >/dev/null 2>&1; then
    echo -e "${YELLOW}未检测到 PM2，正在安装...${RESET}"
    npm install -g pm2
  fi
}

modify_config_menu() {
  show_header "修改端口与 UUID"

  DOMAINS_DIR="/home/$USERNAME/domains"
  DEPLOYED=()
  for domain in $(ls -d $DOMAINS_DIR/*/ 2>/dev/null | xargs -n1 basename); do
    if [ -d "$DOMAINS_DIR/$domain/public_nodejs/webhosting-node" ]; then
      DEPLOYED+=("$domain")
    fi
  done

  if [ ${#DEPLOYED[@]} -eq 0 ]; then
    echo -e "${YELLOW}未找到已部署项目${RESET}"
    sleep 2
    main_menu
    return
  fi

  echo -e "${BOLD}${BLUE}已部署项目列表：${RESET}"
  for i in "${!DEPLOYED[@]}"; do
    printf "${GREEN}%2d)${RESET} %s\n" "$((i+1))" "${DEPLOYED[$i]}"
  done

  echo ""
  read -p "$(echo -e "${BOLD}${CYAN}请选择要修改的项目 [1-${#DEPLOYED[@]}]: ${RESET}")" SELECTED_INDEX
  if [[ ! $SELECTED_INDEX =~ ^[0-9]+$ ]] || [ $SELECTED_INDEX -lt 1 ] || [ $SELECTED_INDEX -gt ${#DEPLOYED[@]} ]; then
    echo -e "${RED}无效的选择${RESET}"
    exit 1
  fi

  DOMAIN=${DEPLOYED[$((SELECTED_INDEX-1))]}
  APP_DIR="${DOMAINS_DIR}/${DOMAIN}/public_nodejs/webhosting-node"

  echo ""
  read -p "$(echo -e "${BOLD}${CYAN}请输入新端口号 [默认4000]: ${RESET}")" NEW_PORT
  NEW_PORT=${NEW_PORT:-4000}
  if [[ ! $NEW_PORT =~ ^[0-9]+$ ]] || [ $NEW_PORT -lt 1 ] || [ $NEW_PORT -gt 65535 ]; then
    echo -e "${RED}无效的端口号${RESET}"
    exit 1
  fi

  read -p "$(echo -e "${BOLD}${CYAN}请输入新UUID [默认随机生成]: ${RESET}")" NEW_UUID
  if [ -z "$NEW_UUID" ]; then
    NEW_UUID=$(cat /proc/sys/kernel/random/uuid)
    echo -e "${GREEN}✓ 已生成随机UUID: ${YELLOW}${NEW_UUID}${RESET}"
  fi

  echo -e "\n${BLUE}正在修改配置文件...${RESET}"
  sed -i "s/const DOMAIN = process.env.DOMAIN || '.*';/const DOMAIN = process.env.DOMAIN || '$DOMAIN';/" "$APP_DIR/app.js"
  sed -i "s/const UUID = process.env.UUID || '.*';/const UUID = process.env.UUID || '$NEW_UUID';/" "$APP_DIR/app.js"
  sed -i "s/const port = process.env.PORT || .*;/const port = process.env.PORT || $NEW_PORT;/" "$APP_DIR/app.js"
  sed -i "s/\$PORT/$NEW_PORT/g" "$APP_DIR/.htaccess"
  sed -i "s/\$PORT/$NEW_PORT/g" "$APP_DIR/ws.php"

  echo -e "\n${BLUE}正在重启 PM2 服务...${RESET}"
  pm2 restart "my-app-${DOMAIN}"

  draw_line
  echo -e "${GREEN}${BOLD}修改完成！${RESET}"
  echo -e "${CYAN}访问地址\t: ${YELLOW}https://${DOMAIN}${RESET}"
  echo -e "${CYAN}UUID\t\t: ${YELLOW}${NEW_UUID}${RESET}"
  echo -e "${CYAN}端口号\t\t: ${YELLOW}${NEW_PORT}${RESET}"
  echo -e "${CYAN}项目目录\t: ${YELLOW}${APP_DIR}${RESET}"
  draw_line
  echo ""
  read -p "$(echo -e "${BOLD}${CYAN}按任意键返回主菜单...${RESET}")" _
  main_menu
}

show_header
main_menu
