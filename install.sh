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
show_header

# 主菜单
main_menu() {
  echo -e "${BOLD}${MAGENTA}主菜单：${RESET}"
  echo -e "  ${GREEN}1)${RESET} vless 部署"
  echo -e "  ${GREEN}2)${RESET} 安装哪吒监控"
  echo -e "  ${GREEN}3)${RESET} 修改配置"
  echo -e "  ${GREEN}4)${RESET} 卸载"
  echo -e "  ${GREEN}5)${RESET} 退出"
  draw_line
  read -p "$(echo -e "${BOLD}${CYAN}请选择操作 [1-5]: ${RESET}")" MAIN_CHOICE

  case $MAIN_CHOICE in
    1) install_menu ;;
    2) install_nezha ;;
    3) modify_config ;;
    4) uninstall_menu ;;
    5) exit 0 ;;
    *)
      echo -e "${RED}无效选项，请重新选择${RESET}"
      sleep 1
      main_menu
      ;;
  esac
}

# 安装哪吒监控
install_nezha() {
  show_header
  echo -e "${MAGENTA}哪吒监控 安装${RESET}"
  select_domain_app || { main_menu; return; }
  # 获取哪吒配置参数
  echo -e "\n${BOLD}${CYAN}请输入哪吒监控配置 (全部填写才生效):${RESET}"
  read -p "  哪吒服务器地址 [默认 nezha.gvkoyeb.eu.org]: " NEZHA_SERVER
  NEZHA_SERVER=${NEZHA_SERVER:-nezha.gvkoyeb.eu.org}
  read -p "  哪吒服务器端口 [默认 443]: " NEZHA_PORT
  NEZHA_PORT=${NEZHA_PORT:-443}
  read -p "  哪吒通信密钥 (必填): " NEZHA_KEY

  if [[ -z "$NEZHA_KEY" ]]; then
    echo -e "${RED}错误：NEZHA_KEY 必填!${RESET}"
    sleep 2
    main_menu
    return
  fi

  # 修改 app.js
  sed -i "s|const NEZHA_SERVER = process.env.NEZHA_SERVER || '.*';|const NEZHA_SERVER = process.env.NEZHA_SERVER || '${NEZHA_SERVER}';|" "$APP_DIR/app.js"
  sed -i "s|const NEZHA_PORT = process.env.NEZHA_PORT || '.*';|const NEZHA_PORT = process.env.NEZHA_PORT || '${NEZHA_PORT}';|" "$APP_DIR/app.js"
  sed -i "s|const NEZHA_KEY = process.env.NEZHA_KEY || '.*';|const NEZHA_KEY = process.env.NEZHA_KEY || '${NEZHA_KEY}';|" "$APP_DIR/app.js"

  echo -e "${BLUE}正在重启应用服务...${RESET}"
  pm2 restart "my-app-${SELECTED_DOMAIN}" --silent
  echo -e "${GREEN}✓ 哪吒监控 配置更新成功!${RESET}"
  sleep 2
  main_menu
}

# 修改配置（VLESS & 哪吒）
modify_config() {
  show_header
  echo -e "${MAGENTA}修改配置${RESET}"
  select_domain_app || { main_menu; return; }

  # 当前值提取
  CURRENT_PORT=$(grep "process.env.PORT" "$APP_DIR/app.js" | sed -E "s/.*\|\| ([0-9]+);/\1/")
  CURRENT_UUID=$(grep "process.env.UUID" "$APP_DIR/app.js" | sed -E "s/.*\|\| '(.+)';/\1/")
  NEZHA_CFG=$(grep -E "NEZHA_SERVER|NEZHA_PORT|NEZHA_KEY" "$APP_DIR/app.js")

  echo -e "\n${BOLD}${BLUE}当前 VLESS 配置:${RESET}"
  echo "  端口: ${YELLOW}${CURRENT_PORT}${RESET}"
  echo "  UUID: ${YELLOW}${CURRENT_UUID}${RESET}"
  echo -e "\n${BOLD}${BLUE}当前 哪吒 配置 从 app.js:${RESET}"
  echo -e "${YELLOW}${NEZHA_CFG}${RESET}"

  # 输入新参数
  echo -e "\n${BOLD}${CYAN}请输入新的 VLESS 参数（留空保持不变）:${RESET}"
  read -p "  端口 [默认 ${CURRENT_PORT}]: " NEW_PORT
  NEW_PORT=${NEW_PORT:-$CURRENT_PORT}
  read -p "  UUID [默认 ${CURRENT_UUID}]: " NEW_UUID
  NEW_UUID=${NEW_UUID:-$CURRENT_UUID}

  echo -e "\n${BOLD}${CYAN}请输入新的 哪吒 参数（留空保持不变）:${RESET}"
  read -p "  哪吒服务器地址 [来自当前]: " NEW_NEZHA_SERVER
  read -p "  哪吒服务器端口 [来自当前]: " NEW_NEZHA_PORT
  read -p "  哪吒通信密钥 [来自当前]: " NEW_NEZHA_KEY

  # 更新 VLESS
  sed -i "s|process.env.PORT || .*;|process.env.PORT || ${NEW_PORT};|" "$APP_DIR/app.js"
  sed -i "s|process.env.UUID || '.*';|process.env.UUID || '${NEW_UUID}';|" "$APP_DIR/app.js"
  sed -i "s|\$PORT|${NEW_PORT}|g" "$APP_DIR/.htaccess" "$APP_DIR/ws.php"

  # 更新 哪吒（仅在输入时更新）
  if [ -n "$NEW_NEZHA_SERVER" ]; then
    sed -i "s|const NEZHA_SERVER = process.env.NEZHA_SERVER || '.*';|const NEZHA_SERVER = process.env.NEZHA_SERVER || '${NEW_NEZHA_SERVER}';|" "$APP_DIR/app.js"
  fi
  if [ -n "$NEW_NEZHA_PORT" ]; then
    sed -i "s|const NEZHA_PORT = process.env.NEZHA_PORT || '.*';|const NEZHA_PORT = process.env.NEZHA_PORT || '${NEW_NEZHA_PORT}';|" "$APP_DIR/app.js"
  fi
  if [ -n "$NEW_NEZHA_KEY" ]; then
    sed -i "s|const NEZHA_KEY = process.env.NEZHA_KEY || '.*';|const NEZHA_KEY = process.env.NEZHA_KEY || '${NEW_NEZHA_KEY}';|" "$APP_DIR/app.js"
  fi

  echo -e "${BLUE}正在重启应用服务...${RESET}"
  pm2 restart "my-app-${SELECTED_DOMAIN}" --silent
  echo -e "${GREEN}✓ 配置已更新并重启服务!${RESET}"
  sleep 2
  main_menu
}

# 选择已部署域名/应用通用函数
select_domain_app() {
  DOMAINS_DIR="/home/$USERNAME/domains"
  INSTALLED=()
  for d in $(ls -d $DOMAINS_DIR/*/ 2>/dev/null | xargs -n1 basename); do
    if [ -f "$DOMAINS_DIR/$d/public_html/app.js" ]; then
      INSTALLED+=("$d")
    fi
  done
  if [ ${#INSTALLED[@]} -eq 0 ]; then
    echo -e "${RED}未找到已部署的应用，请先部署!${RESET}"
    sleep 2
    return 1
  fi
  echo -e "${BOLD}${BLUE}请选择要操作的应用:${RESET}"
  for i in "${!INSTALLED[@]}"; do
    printf "${GREEN}%2d)${RESET} %s\n" "$((i+1))" "${INSTALLED[$i]}"
  done
  read -p "输入数字选择 [1-${#INSTALLED[@]}]: " IDX
  if [[ ! $IDX =~ ^[0-9]+$ ]] || [ $IDX -lt 1 ] || [ $IDX -gt ${#INSTALLED[@]} ]; then
    echo -e "${RED}无效选择${RESET}"
    sleep 1
    return 1
  fi
  SELECTED_DOMAIN=${INSTALLED[$((IDX-1))]}
  APP_DIR="$DOMAINS_DIR/$SELECTED_DOMAIN/public_html"
  return 0
}

# 安装菜单
install_menu() {
  show_header
  echo -e "${MAGENTA}vless 部署${RESET}"
  DOMAINS_DIR="/home/$USERNAME/domains"
  [ -d "$DOMAINS_DIR" ] || { echo -e "${RED}未找到域名目录${RESET}"; exit 1; }
  DOMAINS=($(ls -d $DOMAINS_DIR/*/ | xargs -n1 basename))
  [ ${#DOMAINS[@]} -gt 0 ] || { echo -e "${RED}未找到任何域名配置${RESET}"; exit 1; }

  echo -e "${BOLD}${BLUE}可用域名列表：${RESET}"
  for i in "${!DOMAINS[@]}"; do
    printf "${GREEN}%2d)${RESET} %s\n" "$((i+1))" "${DOMAINS[$i]}"
  done
  read -p "$(echo -e "${BOLD}${CYAN}请选择域名 [默认1]: ${RESET}")" IDX
  IDX=${IDX:-1}
  [[ $IDX =~ ^[0-9]+$ && $IDX -ge 1 && $IDX -le ${#DOMAINS[@]} ]] || { echo -e "${RED}无效选择${RESET}"; exit 1; }
  DOMAIN=${DOMAINS[$((IDX-1))]}
  echo -e "${GREEN}已选择域名: ${YELLOW}${DOMAIN}${RESET}"

  draw_line
  read -p "请输入端口号 [默认4000]: " PORT
  PORT=${PORT:-4000}
  if [[ ! $PORT =~ ^[0-9]+$ ]] || [ $PORT -lt 1 ] || [ $PORT -gt 65535 ]; then
    echo -e "${RED}无效端口号${RESET}"; exit 1
  fi

  draw_line
  read -p "请输入UUID [默认随机生成]: " UUID
  if [ -z "$UUID" ]; then
    UUID=$(cat /proc/sys/kernel/random/uuid)
    echo -e "${GREEN}已生成随机UUID: ${YELLOW}${UUID}${RESET}"
  fi

  start_installation
}

# 卸载菜单
uninstall_menu() {
  show_header
  echo -e "${MAGENTA}卸载 应用${RESET}"
  DOMAINS_DIR="/home/$USERNAME/domains"
  INSTALLED=()
  for d in $(ls -d $DOMAINS_DIR/*/ 2>/dev/null | xargs -n1 basename); do
    [ -d "$DOMAINS_DIR/$d/public_html" ] && INSTALLED+=("$d")
  done
  [ ${#INSTALLED[@]} -gt 0 ] || { echo -e "${YELLOW}没有找到可卸载的项目${RESET}"; sleep 2; main_menu; return; }
  echo -e "${BOLD}${RED}⚠ 警告：这将永久删除数据！${RESET}"
  for i in "${!INSTALLED[@]}"; do
    printf "${RED}%2d)${RESET} %s\n" "$((i+1))" "${INSTALLED[$i]}"
  done
  read -p "请选择要卸载的项目: " IDX
  [[ $IDX =~ ^[0-9]+$ && $IDX -ge 1 && $IDX -le ${#INSTALLED[@]} ]] || { echo -e "${RED}无效选择${RESET}"; exit 1; }
  SELECTED_DOMAIN=${INSTALLED[$((IDX-1))]}
  read -p "确认卸载 ${SELECTED_DOMAIN}? [y/N]: " CONF
  [[ $CONF =~ ^[Yy]$ ]] || { echo -e "${YELLOW}已取消${RESET}"; exit 0; }

  echo -e "${BLUE}停止 PM2 服务...${RESET}"
  pm2 stop "my-app-${SELECTED_DOMAIN}" || true
  pm2 delete "my-app-${SELECTED_DOMAIN}" || true
  pm2 save

  echo -e "${BLUE}清理项目文件...${RESET}"
  rm -rf "${DOMAINS_DIR}/${SELECTED_DOMAIN}/public_html"

  echo -e "${GREEN}✓ ${SELECTED_DOMAIN} 已卸载${RESET}"
  sleep 2
  main_menu
}

# 检测 Node.js 安装
check_node() {
  if ! command -v node &>/dev/null || ! command -v npm &>/dev/null; then
    echo -e "${BLUE}安装 Node.js...${RESET}"
    mkdir -p ~/.local/node
    curl -#fsSL https://nodejs.org/dist/v20.12.2/node-v20.12.2-linux-x64.tar.gz -o node.tar.gz
    tar -xzf node.tar.gz --strip-components=1 -C ~/.local/node
    echo 'export PATH=$HOME/.local/node/bin:$PATH' >> ~/.bashrc
    echo 'export PATH=$HOME/.local/node/bin:$PATH' >> ~/.bash_profile
    source ~/.bashrc; source ~/.bash_profile
    rm node.tar.gz
  fi
  command -v node &>/dev/null || { echo -e "${RED}Node.js 安装失败${RESET}"; exit 1; }
}

# 安装流程
start_installation() {
  check_node
  echo -e "${BLUE}安装 PM2...${RESET}"
  npm install -g pm2

  PROJECT_DIR="/home/$USERNAME/domains/$DOMAIN/public_html"
  mkdir -p "$PROJECT_DIR"
  cd "$PROJECT_DIR"

  echo -e "${BLUE}下载项目文件...${RESET}"
  FILES=(app.js .htaccess package.json ws.php)
  for f in "${FILES[@]}"; do
    curl -#fsSL "https://raw.githubusercontent.com/pprunbot/webhosting-node/main/$f" -O
  done

  echo -e "${BLUE}安装依赖...${RESET}"
  npm install

  echo -e "${BLUE}配置应用参数...${RESET}"
  sed -i "s/const DOMAIN = process.env.DOMAIN || '.*';/const DOMAIN = process.env.DOMAIN || '$DOMAIN';/" app.js
  sed -i "s/const UUID = process.env.UUID || '.*';/const UUID = process.env.UUID || '$UUID';/" app.js
  sed -i "s/const port = process.env.PORT || .*;/const port = process.env.PORT || $PORT;/" app.js
  sed -i "s/\$PORT/$PORT/g" .htaccess ws.php

  # 哪吒 默认变量
  if ! grep -q "NEZHA_SERVER" app.js; then
    sed -i "/const port/a \\    const NEZHA_SERVER = process.env.NEZHA_SERVER || 'nezha.gvkoyeb.eu.org';\\
    const NEZHA_PORT = process.env.NEZHA_PORT || '443';\\
    const NEZHA_KEY = process.env.NEZHA_KEY || '';\\
    " app.js
  fi

  echo -e "${BLUE}启动 PM2 服务...${RESET}"
  pm2 start app.js --name "my-app-${DOMAIN}"
  pm2 save
  (crontab -l 2>/dev/null; echo "@reboot sleep 30 && $HOME/.local/node/bin/pm2 resurrect --no-daemon") | crontab -

  draw_line
  echo -e "${GREEN}${BOLD}部署成功！${RESET}"
  echo -e "访问地址 : https://${DOMAIN}"
  echo -e "UUID      : ${UUID}"
  echo -e "端口号    : ${PORT}"
  echo -e "项目目录  : ${PROJECT_DIR}"
  echo -e "仓库地址  : ${PROJECT_URL}"
  draw_line
  echo ""
  sleep 2
  main_menu
}

# 启动主菜单
main_menu
