#!/bin/bash

set -e

# 颜色定义
RED='\033[31m'; GREEN='\033[32m'; YELLOW='\033[33m'
BLUE='\033[34m'; MAGENTA='\033[35m'; CYAN='\033[36m'
BOLD='\033[1m'; RESET='\033[0m'

PROJECT_URL="https://github.com/pprunbot/webhosting-node"

draw_line() {
  printf "%$(tput cols)s\n" | tr ' ' '─'
}

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

show_header() {
  clear
  print_title
  echo -e "${CYAN}项目地址: ${YELLOW}${PROJECT_URL}${RESET}\n"
}

USERNAME=$(whoami)
DOMAINS_DIR="/home/$USERNAME/domains"

main_menu() {
  show_header
  echo -e "${BOLD}${MAGENTA}主菜单：${RESET}"
  echo -e "  ${GREEN}1)${RESET} vless 部署"
  echo -e "  ${GREEN}2)${RESET} 安装 哪吒 监控"
  echo -e "  ${GREEN}3)${RESET} 修改 配置"
  echo -e "  ${GREEN}4)${RESET} 卸载"
  echo -e "  ${GREEN}5)${RESET} 退出"
  draw_line
  read -p "请选择操作 [1-5]: " opt
  case $opt in
    1) install_menu ;;
    2) install_nezha ;;
    3) modify_menu ;;
    4) uninstall_menu ;;
    5) exit 0 ;;
    *) echo -e "${RED}无效选项${RESET}"; sleep 1; main_menu ;;
  esac
}

select_app() {
  INSTALLED=()
  for d in $(ls -d "$DOMAINS_DIR"/*/ 2>/dev/null | xargs -n1 basename); do
    [ -f "$DOMAINS_DIR/$d/public_html/app.js" ] && INSTALLED+=("$d")
  done
  if [ ${#INSTALLED[@]} -eq 0 ]; then
    echo -e "${RED}未找到已部署应用${RESET}"; sleep 2; return 1
  fi
  echo -e "${BOLD}${BLUE}请选择应用:${RESET}"
  for i in "${!INSTALLED[@]}"; do
    printf "  ${GREEN}%d)${RESET} %s\n" "$((i+1))" "${INSTALLED[$i]}"
  done
  read -p "输入 [1-${#INSTALLED[@]}]: " idx
  if ! [[ $idx =~ ^[1-9][0-9]*$ ]] || [ $idx -lt 1 ] || [ $idx -gt ${#INSTALLED[@]} ]; then
    echo -e "${RED}无效选择${RESET}"; sleep 1; return 1
  fi
  SELECTED_DOMAIN=${INSTALLED[$((idx-1))]}
  APP_DIR="$DOMAINS_DIR/$SELECTED_DOMAIN/public_html"
  return 0
}

install_menu() {
  show_header
  echo -e "${MAGENTA}vless 部署${RESET}"
  [ -d "$DOMAINS_DIR" ] || { echo -e "${RED}未找到域名目录${RESET}"; exit 1; }
  DOMAINS=($(ls -d "$DOMAINS_DIR"/*/ | xargs -n1 basename))
  [ ${#DOMAINS[@]} -gt 0 ] || { echo -e "${RED}无域名配置${RESET}"; exit 1; }
  for i in "${!DOMAINS[@]}"; do printf "  ${GREEN}%d)${RESET} %s\n" "$((i+1))" "${DOMAINS[$i]}"; done
  read -p "选择域名 [1]: " di; di=${di:-1}
  DOMAIN=${DOMAINS[$((di-1))]}
  echo -e "已选: ${YELLOW}$DOMAIN${RESET}"
  draw_line
  read -p "端口 [4000]: " PORT; PORT=${PORT:-4000}
  [[ $PORT =~ ^[0-9]+$ && $PORT -ge 1 && $PORT -le 65535 ]] || { echo -e "${RED}端口无效${RESET}"; exit 1; }
  draw_line
  read -p "UUID [随机生成]: " UUID
  [ -z "$UUID" ] && UUID=$(cat /proc/sys/kernel/random/uuid)
  echo -e "UUID: ${YELLOW}$UUID${RESET}"
  start_installation
}

install_nezha() {
  show_header
  echo -e "${MAGENTA}哪吒 监控 安装${RESET}"
  select_app || { main_menu; return; }
  cd "$APP_DIR"
  read -p "哪吒服务器 [nezha.gvkoyeb.eu.org]: " NS; NS=${NS:-nezha.gvkoyeb.eu.org}
  read -p "哪吒端口 [443]: " NP; NP=${NP:-443}
  read -p "哪吒密钥 (必填): " NK
  [ -n "$NK" ] || { echo -e "${RED}密钥必填${RESET}"; sleep 1; main_menu; return; }
  sed -i "s|^const NEZHA_SERVER.*|const NEZHA_SERVER = process.env.NEZHA_SERVER || '$NS';|" app.js
  sed -i "s|^const NEZHA_PORT.*|const NEZHA_PORT = process.env.NEZHA_PORT || '$NP';|" app.js
  sed -i "s|^const NEZHA_KEY.*|const NEZHA_KEY = process.env.NEZHA_KEY || '$NK';|" app.js
  pm2 restart "my-app-$SELECTED_DOMAIN" --silent
  echo -e "${GREEN}哪吒 安装/更新 完成${RESET}"; sleep 2
  main_menu
}

modify_menu() {
  show_header
  echo -e "${MAGENTA}修改 配置${RESET}"
  select_app || { main_menu; return; }
  echo -e "已选应用: ${YELLOW}$SELECTED_DOMAIN${RESET}"
  echo -e "  ${GREEN}1)${RESET} 修改 VLESS"
  echo -e "  ${GREEN}2)${RESET} 修改 哪吒"
  echo -e "  ${GREEN}3)${RESET} 返回 主菜单"
  read -p "请选择 [1-3]: " mopt
  case $mopt in
    1) modify_vless ;;
    2) modify_nezha ;;
    3) main_menu ;;
    *) echo -e "${RED}无效${RESET}"; sleep 1; modify_menu ;;
  esac
}

modify_vless() {
  cd "$APP_DIR"
  # 读取当前
  CUR_PORT=$(grep -E "^const port" app.js | grep -oE "[0-9]+")
  CUR_UUID=$(grep -E "^const UUID" app.js | sed -E "s/.*'\s*\|\|\s*'([^']+)'.*/\1/")
  echo -e "当前端口: ${YELLOW}$CUR_PORT${RESET}"
  echo -e "当前UUID: ${YELLOW}$CUR_UUID${RESET}"
  read -p "新端口 [保持 $CUR_PORT]: " NP; NP=${NP:-$CUR_PORT}
  read -p "新UUID [保持当前]: " NU; NU=${NU:-$CUR_UUID}
  # 应用
  sed -i "s|^const port = process.env.PORT.*|const port = process.env.PORT || $NP;|" app.js
  sed -i "s|^const UUID = process.env.UUID.*|const UUID = process.env.UUID || '$NU';|" app.js
  sed -i "s|\$PORT|$NP|g" .htaccess ws.php
  pm2 restart "my-app-$SELECTED_DOMAIN" --silent
  echo -e "${GREEN}VLESS 更新完成${RESET}"; sleep 2
  main_menu
}

modify_nezha() {
  cd "$APP_DIR"
  # 读取当前
  C_NS=$(grep "^const NEZHA_SERVER" app.js | sed -E "s/.*'\s*\|\|\s*'([^']+)'.*/\1/")
  C_NP=$(grep "^const NEZHA_PORT" app.js | sed -E "s/.*'\s*\|\|\s*'([^']+)'.*/\1/")
  C_NK=$(grep "^const NEZHA_KEY" app.js | sed -E "s/.*'\s*\|\|\s*'([^']*)'.*/\1/")
  echo -e "当前 哪吒 服务器: ${YELLOW}$C_NS${RESET}"
  echo -e "当前 哪吒 端口: ${YELLOW}$C_NP${RESET}"
  echo -e "当前 哪吒 密钥: ${YELLOW}$C_NK${RESET}"
  read -p "新服务器 [保持 $C_NS]: " NS; NS=${NS:-$C_NS}
  read -p "新端口 [保持 $C_NP]: " NP; NP=${NP:-$C_NP}
  read -p "新密钥 [保持当前]: " NK; NK=${NK:-$C_NK}
  sed -i "s|^const NEZHA_SERVER.*|const NEZHA_SERVER = process.env.NEZHA_SERVER || '$NS';|" app.js
  sed -i "s|^const NEZHA_PORT.*|const NEZHA_PORT = process.env.NEZHA_PORT || '$NP';|" app.js
  sed -i "s|^const NEZHA_KEY.*|const NEZHA_KEY = process.env.NEZHA_KEY || '$NK';|" app.js
  pm2 restart "my-app-$SELECTED_DOMAIN" --silent
  echo -e "${GREEN}哪吒 更新完成${RESET}"; sleep 2
  main_menu
}

uninstall_menu() {
  show_header
  echo -e "${MAGENTA}卸载 应用${RESET}"
  select_app || { main_menu; return; }
  read -p "确认卸载 $SELECTED_DOMAIN? [y/N]: " c
  [[ $c =~ ^[Yy]$ ]] || { echo -e "${YELLOW}取消${RESET}"; exit 0; }
  pm2 stop "my-app-$SELECTED_DOMAIN" || true
  pm2 delete "my-app-$SELECTED_DOMAIN" || true
  rm -rf "$APP_DIR"
  echo -e "${GREEN}已卸载${RESET}"; sleep 2
  main_menu
}

check_node() {
  if ! command -v node &>/dev/null; then
    echo -e "${BLUE}安装 Node.js...${RESET}"
    mkdir -p ~/.local/node
    curl -fsSL https://nodejs.org/dist/v20.12.2/node-v20.12.2-linux-x64.tar.gz -o node.tar.gz
    tar -xzf node.tar.gz --strip-components=1 -C ~/.local/node
    echo 'export PATH=$HOME/.local/node/bin:$PATH' >> ~/.bashrc
    source ~/.bashrc
    rm node.tar.gz
  fi
  command -v node &>/dev/null || { echo -e "${RED}Node.js 安装失败${RESET}"; exit 1; }
}

start_installation() {
  check_node
  npm install -g pm2
  PROJECT_DIR="$APP_DIR"
  mkdir -p "$PROJECT_DIR"
  cd "$PROJECT_DIR"
  for f in app.js .htaccess package.json ws.php; do
    curl -#fsSL "https://raw.githubusercontent.com/pprunbot/webhosting-node/main/$f" -O
  done
  npm install
  sed -i "s|const DOMAIN.*|const DOMAIN = process.env.DOMAIN || '$DOMAIN';|" app.js
  sed -i "s|const port.*|const port = process.env.PORT || $PORT;|" app.js
  sed -i "s|const UUID.*|const UUID = process.env.UUID || '$UUID';|" app.js
  sed -i "s|\$PORT|$PORT|g" .htaccess ws.php
  if ! grep -q "NEZHA_SERVER" app.js; then
    sed -i "/const port/a \\    const NEZHA_SERVER = process.env.NEZHA_SERVER || 'nezha.gvkoyeb.eu.org';\\
    const NEZHA_PORT = process.env.NEZHA_PORT || '443';\\
    const NEZHA_KEY = process.env.NEZHA_KEY || '';\\
    " app.js
  fi
  pm2 start app.js --name "my-app-$DOMAIN"
  pm2 save
  (crontab -l 2>/dev/null; echo "@reboot sleep 30 && $HOME/.local/node/bin/pm2 resurrect --no-daemon") | crontab -
  draw_line
  echo -e "${GREEN}部署成功!${RESET}"
  echo -e "访问: https://$DOMAIN"
  echo -e "UUID : $UUID"
  echo -e "端口 : $PORT"
  draw_line
  sleep 2
  main_menu
}

main_menu
