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
  echo "  \ \ /\ / / _ \ '_ \| | '_ \/ __| __/ _ \/ _\ | | '_ \ / _ \| |/ _ \| | '_ \ / _\ |"
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

# 获取当前用户名
USERNAME=$(whoami)

# 初始界面
show_header "WebHosting Node 管理工具"

# 主菜单
main_menu() {
  echo -e "${BOLD}${MAGENTA}主菜单：${RESET}"
  echo -e "  ${GREEN}1)${RESET} vless部署"
  echo -e "  ${GREEN}2)${RESET} 安装哪吒监控"
  echo -e "  ${GREEN}3)${RESET} 修改配置"
  echo -e "  ${GREEN}4)${RESET} 卸载"
  echo -e "  ${GREEN}5)${RESET} 退出"
  draw_line
  read -p "$(echo -e "${BOLD}${CYAN}请选择操作 [1-5]: ${RESET}")" MAIN_CHOICE

  case $MAIN_CHOICE in
    1) install_menu ;;
    2) install_nezha ;;
    3) modify_config_menu ;;
    4) uninstall_menu ;;
    5) exit 0 ;;
    *)
      echo -e "${RED}无效选项，请重新选择${RESET}"
      sleep 1
      main_menu
      ;;
  esac
}

# 修改配置菜单
modify_config_menu() {
  show_header "修改配置"

  # 查找所有部署的应用
  DOMAINS_DIR="/home/$USERNAME/domains"
  INSTALLED_APPS=()
  for domain in $(ls -d $DOMAINS_DIR/*/ 2>/dev/null | xargs -n1 basename); do
    if [ -f "$DOMAINS_DIR/$domain/public_html/app.js" ]; then
      INSTALLED_APPS+=("$domain")
    fi
  done

  if [ ${#INSTALLED_APPS[@]} -eq 0 ]; then
    echo -e "${RED}未找到已部署的应用，请先执行vless部署!${RESET}"
    sleep 2
    main_menu
    return
  fi

  # 显示应用选择菜单
  echo -e "${BOLD}${BLUE}选择要修改的应用:${RESET}"
  for i in "${!INSTALLED_APPS[@]}"; do
    printf "${GREEN}%2d)${RESET} %s\n" "$((i+1))" "${INSTALLED_APPS[$i]}"
  done

  read -p "$(echo -e "${BOLD}${CYAN}请输入数字选择 [1-${#INSTALLED_APPS[@]}]: ${RESET}")" APP_INDEX
  if [[ ! $APP_INDEX =~ ^[0-9]+$ ]] || [ $APP_INDEX -lt 1 ] || [ $APP_INDEX -gt ${#INSTALLED_APPS[@]} ]; then
    echo -e "${RED}无效的选择!${RESET}"
    sleep 1
    main_menu
    return
  fi

  SELECTED_DOMAIN=${INSTALLED_APPS[$((APP_INDEX-1))]}
  APP_DIR="$DOMAINS_DIR/$SELECTED_DOMAIN/public_html"
  
  # 配置类型选择
  echo -e "\n${BOLD}${BLUE}选择要修改的配置类型:${RESET}"
  echo -e "  ${GREEN}1)${RESET} 修改vless参数"
  echo -e "  ${GREEN}2)${RESET} 修改哪吒监控参数"
  read -p "$(echo -e "${BOLD}${CYAN}请选择 [1-2]: ${RESET}")" CONFIG_TYPE

  case $CONFIG_TYPE in
    1) modify_vless ;;
    2) modify_nezha ;;
    *)
      echo -e "${RED}无效选项!${RESET}"
      sleep 1
      modify_config_menu
      ;;
  esac
}

# 修改vless参数
modify_vless() {
  show_header "修改vless参数"
  cd "$APP_DIR"

  # 获取当前配置
  CURRENT_PORT=$(grep -oP "const port = process.env.PORT || \K\d+" app.js)
  CURRENT_UUID=$(grep -oP "const UUID = process.env.UUID || '\K[^']+" app.js)

  echo -e "${BOLD}当前配置:${RESET}"
  echo -e "  ${CYAN}端口: ${YELLOW}$CURRENT_PORT${RESET}"
  echo -e "  ${CYAN}UUID: ${YELLOW}$CURRENT_UUID${RESET}\n"

  # 输入新参数
  read -p "$(echo -e "${BOLD}${CYAN}请输入新端口号 [留空保持当前]: ${RESET}")" NEW_PORT
  read -p "$(echo -e "${BOLD}${CYAN}请输入新UUID [留空保持当前]: ${RESET}")" NEW_UUID

  # 应用修改
  if [[ -n "$NEW_PORT" ]]; then
    if [[ ! $NEW_PORT =~ ^[0-9]+$ ]] || [ $NEW_PORT -lt 1 ] || [ $NEW_PORT -gt 65535 ]; then
      echo -e "${RED}无效的端口号!${RESET}"
      return 1
    fi
    # 更新 app.js
    sed -i "s/const port = process.env.PORT || .*;/const port = process.env.PORT || $NEW_PORT;/" app.js
    # 同步替换 .htaccess 和 ws.php 中的旧端口
    sed -i "s/${CURRENT_PORT}/${NEW_PORT}/g" .htaccess
    sed -i "s/${CURRENT_PORT}/${NEW_PORT}/g" ws.php
  fi

  if [[ -n "$NEW_UUID" ]]; then
    sed -i "s/const UUID = process.env.UUID || '.*';/const UUID = process.env.UUID || '$NEW_UUID';/" app.js
  fi

  # 重启服务并保存
  pm2 restart "my-app-${SELECTED_DOMAIN}" --silent
  pm2 save

  echo -e "\n${GREEN}✓ vless配置已更新!${RESET}"
  sleep 2
  main_menu
}

# 修改哪吒监控参数
modify_nezha() {
  show_header "修改哪吒监控参数"
  cd "$APP_DIR"

  # 获取当前配置
  CURRENT_NEZHA_SERVER=$(grep -oP "const NEZHA_SERVER = process.env.NEZHA_SERVER || '\K[^']+" app.js)
  CURRENT_NEZHA_PORT=$(grep -oP "const NEZHA_PORT = process.env.NEZHA_PORT || '\K[^']+" app.js)
  CURRENT_NEZHA_KEY=$(grep -oP "const NEZHA_KEY = process.env.NEZHA_KEY || '\K[^']+" app.js)

  echo -e "${BOLD}当前配置:${RESET}"
  echo -e "  ${CYAN}服务器地址: ${YELLOW}$CURRENT_NEZHA_SERVER${RESET}"
  echo -e "  ${CYAN}服务器端口: ${YELLOW}$CURRENT_NEZHA_PORT${RESET}"
  echo -e "  ${CYAN}通信密钥: ${YELLOW}$CURRENT_NEZHA_KEY${RESET}\n"

  # 输入新参数
  read -p "$(echo -e "${BOLD}${CYAN}哪吒服务器地址 [留空保持当前]: ${RESET}")" NEW_NEZHA_SERVER
  read -p "$(echo -e "${BOLD}${CYAN}哪吒服务器端口 [留空保持当前]: ${RESET}")" NEW_NEZHA_PORT
  read -p "$(echo -e "${BOLD}${CYAN}哪吒通信密钥 [留空保持当前]: ${RESET}")" NEW_NEZHA_KEY

  # 应用修改
  [[ -n "$NEW_NEZHA_SERVER" ]] && sed -i "s/const NEZHA_SERVER = process.env.NEZHA_SERVER || '.*';/const NEZHA_SERVER = process.env.NEZHA_SERVER || '${NEW_NEZHA_SERVER}';/" app.js
  [[ -n "$NEW_NEZHA_PORT" ]]   && sed -i "s/const NEZHA_PORT = process.env.NEZHA_PORT || '.*';/const NEZHA_PORT = process.env.NEZHA_PORT || '${NEW_NEZHA_PORT}';/"   app.js
  [[ -n "$NEW_NEZHA_KEY" ]]    && sed -i "s/const NEZHA_KEY = process.env.NEZHA_KEY || '.*';/const NEZHA_KEY = process.env.NEZHA_KEY || '${NEW_NEZHA_KEY}';/"    app.js

  # 重启服务并保存
  pm2 restart "my-app-${SELECTED_DOMAIN}" --silent
  pm2 save

  echo -e "\n${GREEN}✓ 哪吒监控配置已更新!${RESET}"
  sleep 2
  main_menu
}

# 安装哪吒监控
install_nezha() {
  show_header "哪吒监控配置"

  # 查找所有部署的应用
  DOMAINS_DIR="/home/$USERNAME/domains"
  INSTALLED_APPS=()
  for domain in $(ls -d $DOMAINS_DIR/*/ 2>/dev/null | xargs -n1 basename); do
    if [ -f "$DOMAINS_DIR/$domain/public_html/app.js" ]; then
      INSTALLED_APPS+=("$domain")
    fi
  done

  if [ ${#INSTALLED_APPS[@]} -eq 0 ]; then
    echo -e "${RED}未找到已部署的应用，请先执行vless部署!${RESET}"
    sleep 2
    main_menu
    return
  fi

  # 显示应用选择菜单
  echo -e "${BOLD}${BLUE}选择要配置的应用:${RESET}"
  for i in "${!INSTALLED_APPS[@]}"; do
    printf "${GREEN}%2d)${RESET} %s\n" "$((i+1))" "${INSTALLED_APPS[$i]}"
  done

  read -p "$(echo -e "${BOLD}${CYAN}请输入数字选择 [1-${#INSTALLED_APPS[@]}]: ${RESET}")" APP_INDEX
  if [[ ! $APP_INDEX =~ ^[0-9]+$ ]] || [ $APP_INDEX -lt 1 ] || [ $APP_INDEX -gt ${#INSTALLED_APPS[@]} ]; then
    echo -e "${RED}无效的选择!${RESET}"
    sleep 1
    main_menu
    return
  fi

  SELECTED_DOMAIN=${INSTALLED_APPS[$((APP_INDEX-1))]}
  APP_DIR="$DOMAINS_DIR/$SELECTED_DOMAIN/public_html"
  cd "$APP_DIR"

  # 获取哪吒配置参数
  echo -e "\n${BOLD}${CYAN}请输入哪吒监控配置 (全部填写才生效):${RESET}"
  read -p "$(echo -e "  ${CYAN}哪吒服务器地址 [默认 nezha.gvkoyeb.eu.org]: ${RESET}")" NEZHA_SERVER
  NEZHA_SERVER=${NEZHA_SERVER:-nezha.gvkoyeb.eu.org}
  read -p "$(echo -e "  ${CYAN}哪吒服务器端口 [默认 443]: ${RESET}")" NEZHA_PORT
  NEZHA_PORT=${NEZHA_PORT:-443}
  read -p "$(echo -e "  ${CYAN}哪吒通信密钥 (必填): ${RESET}")" NEZHA_KEY

  # 验证参数
  if [[ -z "$NEZHA_SERVER" || -z "$NEZHA_PORT" || -z "$NEZHA_KEY" ]]; then
    echo -e "${RED}错误：必须填写所有参数才能启用哪吒监控!${RESET}"
    sleep 2
    main_menu
    return
  fi

  # 修改app.js配置
  sed -i "s|const NEZHA_SERVER = process.env.NEZHA_SERVER || '.*';|const NEZHA_SERVER = process.env.NEZHA_SERVER || '${NEZHA_SERVER}';|" app.js
  sed -i "s|const NEZHA_PORT = process.env.NEZHA_PORT || '.*';|const NEZHA_PORT = process.env.NEZHA_PORT || '${NEZHA_PORT}';|" app.js
  sed -i "s|const NEZHA_KEY = process.env.NEZHA_KEY || '.*';|const NEZHA_KEY = process.env.NEZHA_KEY || '${NEZHA_KEY}';|" app.js

  # 重启服务并保存
  echo -e "${BLUE}正在重启应用服务...${RESET}"
  pm2 restart "my-app-${SELECTED_DOMAIN}" --silent
  pm2 save

  echo -e "${GREEN}✓ 哪吒监控已成功启用!${RESET}"
  sleep 2
  main_menu
}

# 安装菜单
install_menu() {
  show_header "vless部署"
  
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

  # 显示域名选择菜单
  echo -e "${BOLD}${BLUE}可用域名列表：${RESET}"
  for i in "${!DOMAINS[@]}"; do
    printf "${GREEN}%2d)${RESET} %s\n" "$((i+1))" "${DOMAINS[$i]}"
  done

  # 获取用户选择的域名
  echo ""
  read -p "$(echo -e "${BOLD}${CYAN}请选择域名（输入数字）[默认1]: ${RESET}")" DOMAIN_INDEX
  DOMAIN_INDEX=${DOMAIN_INDEX:-1}
  if [[ ! $DOMAIN_INDEX =~ ^[0-9]+$ ]] || [ $DOMAIN_INDEX -lt 1 ] || [ $DOMAIN_INDEX -gt ${#DOMAINS[@]} ]; then
    echo -e "${RED}无效的选择${RESET}"
    exit 1
  fi

  DOMAIN=${DOMAINS[$((DOMAIN_INDEX-1))]}
  echo -e "\n${GREEN}✓ 已选择域名: ${YELLOW}${DOMAIN}${RESET}"

  # 自定义端口输入
  draw_line
  echo ""
  read -p "$(echo -e "${BOLD}${CYAN}请输入端口号 [默认4000]: ${RESET}")" PORT
  PORT=${PORT:-4000}

  # 验证端口号
  if [[ ! $PORT =~ ^[0-9]+$ ]] || [ $PORT -lt 1 ] || [ $PORT -gt 65535 ]; then
    echo -e "${RED}无效的端口号${RESET}"
    exit 1
  fi

  # UUID输入
  draw_line
  echo ""
  read -p "$(echo -e "${BOLD}${CYAN}请输入UUID [默认随机生成]: ${RESET}")" UUID
  if [ -z "$UUID" ]; then
    UUID=$(cat /proc/sys/kernel/random/uuid)
    echo -e "${GREEN}✓ 已生成随机UUID: ${YELLOW}${UUID}${RESET}"
  fi

  # 开始部署流程
  start_installation
}

# …（后续 uninstall_menu、check_node、start_installation 等保持不变）…

# 启动主菜单
main_menu
