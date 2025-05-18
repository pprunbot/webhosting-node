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
PACKAGE_MANAGER="npm"
INSTALL_METHOD=1
NODE_VERSION="v20.12.2"

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

# 系统检测函数
detect_system() {
  case "$(uname -s)" in
    Linux*)   echo "linux" ;;
    FreeBSD*) echo "freebsd" ;;
    *)        echo "unknown" ;;
  esac
}

# 架构检测
detect_arch() {
  case "$(uname -m)" in
    x86_64)  echo "x64" ;;
    aarch64) echo "arm64" ;;
    *)       echo "unknown" ;;
  esac
}

# Node.js预检查
pre_check() {
  if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
    if node -v >/dev/null 2>&1 && npm -v >/dev/null 2>&1; then
      echo -e "${GREEN}✓ 检测到已安装Node.js和npm，跳过安装${RESET}"
      return 0
    fi
  fi
  return 1
}

main_menu() {
  show_header
  echo -e "${BOLD}${MAGENTA}主菜单：${RESET}"
  echo -e "  ${GREEN}1.${RESET} vless部署"
  echo -e "  ${GREEN}2.${RESET} nezha安装"
  echo -e "  ${GREEN}3.${RESET} 卸载"
  echo -e "  ${GREEN}4.${RESET} 退出"
  draw_line
  read -p "$(echo -e "${BOLD}${CYAN}请选择操作 [1-4]: ${RESET}")" MAIN_CHOICE

  case $MAIN_CHOICE in
    1) install_menu ;;
    2) install_nezha ;;
    3) uninstall_menu ;;
    4) exit 0 ;;
    *) 
      echo -e "${RED}无效选项，请重新选择${RESET}"
      sleep 1
      main_menu
      ;;
  esac
}

install_nezha() {
  show_header
  DOMAINS_DIR="/home/$USERNAME/domains"
  INSTALLED_APPS=()
  for domain in $(ls -d $DOMAINS_DIR/*/ 2>/dev/null | xargs -n1 basename); do
    [ -f "$DOMAINS_DIR/$domain/public_html/app.js" ] && INSTALLED_APPS+=("$domain")
  done

  [ ${#INSTALLED_APPS[@]} -eq 0 ] && {
    echo -e "${RED}未找到已部署的应用，请先执行vless部署!${RESET}"
    sleep 2
    main_menu
    return
  }

  echo -e "${BOLD}${BLUE}选择要配置的应用:${RESET}"
  for i in "${!INSTALLED_APPS[@]}"; do
    printf "${GREEN}%2d)${RESET} %s\n" "$((i+1))" "${INSTALLED_APPS[$i]}"
  done

  read -p "$(echo -e "${BOLD}${CYAN}请输入数字选择 [1-${#INSTALLED_APPS[@]}]: ${RESET}")" APP_INDEX
  [[ ! $APP_INDEX =~ ^[0-9]+$ ]] || [ $APP_INDEX -lt 1 ] || [ $APP_INDEX -gt ${#INSTALLED_APPS[@]} ] && {
    echo -e "${RED}无效的选择!${RESET}"
    sleep 1
    main_menu
    return
  }

  SELECTED_DOMAIN=${INSTALLED_APPS[$((APP_INDEX-1))]}
  APP_DIR="$DOMAINS_DIR/$SELECTED_DOMAIN/public_html"
  cd "$APP_DIR"

  echo -e "\n${BOLD}${CYAN}请输入哪吒监控配置 (全部填写才生效):${RESET}"
  read -p "$(echo -e "  ${CYAN}哪吒服务器地址 [默认 nezha.gvkoyeb.eu.org]: ${RESET}")" NEZHA_SERVER
  NEZHA_SERVER=${NEZHA_SERVER:-nezha.gvkoyeb.eu.org}
  read -p "$(echo -e "  ${CYAN}哪吒服务器端口 [默认 443]: ${RESET}")" NEZHA_PORT
  NEZHA_PORT=${NEZHA_PORT:-443}
  read -p "$(echo -e "  ${CYAN}哪吒通信密钥 (必填): ${RESET}")" NEZHA_KEY

  [ -z "$NEZHA_KEY" ] && {
    echo -e "${RED}错误：必须填写所有参数才能启用哪吒监控!${RESET}"
    sleep 2
    main_menu
    return
  }

  sed -i "s|const NEZHA_SERVER = process.env.NEZHA_SERVER || '.*';|const NEZHA_SERVER = process.env.NEZHA_SERVER || '${NEZHA_SERVER}';|" app.js
  sed -i "s|const NEZHA_PORT = process.env.NEZHA_PORT || '.*';|const NEZHA_PORT = process.env.NEZHA_PORT || '${NEZHA_PORT}';|" app.js
  sed -i "s|const NEZHA_KEY = process.env.NEZHA_KEY || '.*';|const NEZHA_KEY = process.env.NEZHA_KEY || '${NEZHA_KEY}';|" app.js

  echo -e "${BLUE}正在重启应用服务...${RESET}"
  pm2 restart "my-app-${SELECTED_DOMAIN}" --silent
  pm2 save
  echo -e "${GREEN}✓ 哪吒监控已成功启用!${RESET}"
  sleep 2
  main_menu
}

install_menu() {
  show_header
  DOMAINS_DIR="/home/$USERNAME/domains"
  [ ! -d "$DOMAINS_DIR" ] && {
    echo -e "${RED}错误：未找到域名目录 ${DOMAINS_DIR}${RESET}"
    exit 1
  }

  DOMAINS=($(ls -d $DOMAINS_DIR/*/ | xargs -n1 basename))
  [ ${#DOMAINS[@]} -eq 0 ] && {
    echo -e "${RED}错误：未找到任何域名配置${RESET}"
    exit 1
  }

  echo -e "${BOLD}${BLUE}可用域名列表：${RESET}"
  for i in "${!DOMAINS[@]}"; do
    printf "${GREEN}%2d)${RESET} %s\n" "$((i+1))" "${DOMAINS[$i]}"
  done

  read -p "$(echo -e "${BOLD}${CYAN}请选择域名（输入数字）[默认1]: ${RESET}")" DOMAIN_INDEX
  DOMAIN_INDEX=${DOMAIN_INDEX:-1}
  [[ ! $DOMAIN_INDEX =~ ^[0-9]+$ ]] || [ $DOMAIN_INDEX -lt 1 ] || [ $DOMAIN_INDEX -gt ${#DOMAINS[@]} ] && {
    echo -e "${RED}无效的选择${RESET}"
    exit 1
  }

  DOMAIN=${DOMAINS[$((DOMAIN_INDEX-1))]}
  echo -e "\n${GREEN}✓ 已选择域名: ${YELLOW}${DOMAIN}${RESET}"

  read -p "$(echo -e "${BOLD}${CYAN}请输入端口号 [默认4000]: ${RESET}")" PORT
  PORT=${PORT:-4000}
  [[ ! $PORT =~ ^[0-9]+$ ]] || [ $PORT -lt 1 ] || [ $PORT -gt 65535 ] && {
    echo -e "${RED}无效的端口号${RESET}"
    exit 1
  }

  read -p "$(echo -e "${BOLD}${CYAN}请输入UUID [默认随机生成]: ${RESET}")" UUID
  [ -z "$UUID" ] && {
    UUID=$(cat /proc/sys/kernel/random/uuid)
    echo -e "${GREEN}✓ 已生成随机UUID: ${YELLOW}${UUID}${RESET}"
  }

  start_installation
}

uninstall_menu() {
  show_header
  DOMAINS_DIR="/home/$USERNAME/domains"
  INSTALLED=()
  for domain in $(ls -d $DOMAINS_DIR/*/ 2>/dev/null | xargs -n1 basename); do
    [ -d "$DOMAINS_DIR/$domain/public_html" ] && INSTALLED+=("$domain")
  done

  [ ${#INSTALLED[@]} -eq 0 ] && {
    echo -e "${YELLOW}没有找到可卸载的项目${RESET}"
    sleep 2
    main_menu
    return
  }

  echo -e "${BOLD}${RED}⚠ 警告：这将永久删除项目数据！${RESET}\n"
  echo -e "${BOLD}${BLUE}已部署项目列表：${RESET}"
  for i in "${!INSTALLED[@]}"; do
    printf "${RED}%2d)${RESET} %s\n" "$((i+1))" "${INSTALLED[$i]}"
  done

  read -p "$(echo -e "${BOLD}${CYAN}请选择要卸载的项目 [1-${#INSTALLED[@]}]: ${RESET}")" UNINSTALL_INDEX
  [[ ! $UNINSTALL_INDEX =~ ^[0-9]+$ ]] || [ $UNINSTALL_INDEX -lt 1 ] || [ $UNINSTALL_INDEX -gt ${#INSTALLED[@]} ] && {
    echo -e "${RED}无效的选择${RESET}"
    exit 1
  }

  SELECTED_DOMAIN=${INSTALLED[$((UNINSTALL_INDEX-1))]}
  
  read -p "$(echo -e "${BOLD}${RED}确认要卸载 ${SELECTED_DOMAIN} 吗？[y/N]: ${RESET}")" CONFIRM
  [[ ! $CONFIRM =~ ^[Yy]$ ]] && {
    echo -e "${YELLOW}已取消卸载操作${RESET}"
    exit 0
  }

  echo -e "\n${BLUE}正在停止PM2服务...${RESET}"
  pm2 stop "my-app-${SELECTED_DOMAIN}" || true
  pm2 delete "my-app-${SELECTED_DOMAIN}" || true
  pm2 save
  rm -rf "${DOMAINS_DIR}/${SELECTED_DOMAIN}/public_html"
  echo -e "\n${GREEN}✓ ${SELECTED_DOMAIN} 已成功卸载${RESET}"
  sleep 2
  main_menu
}

check_node() {
  # 获取系统信息
  sys_type=$(detect_system)
  arch_type=$(detect_arch)
  
  case $INSTALL_METHOD in
  1)
    echo -e "\n${BLUE}=== 方法1：官方安装 ===${RESET}"
    
    # 生成下载地址
    case $sys_type in
      linux)
        pkg_name="node-${NODE_VERSION}-linux-${arch_type}.tar.gz" ;;
      freebsd)
        pkg_name="node-${NODE_VERSION}-freebsd-${arch_type}.tar.gz" ;;
      *)
        echo -e "${RED}不支持的系统类型: $sys_type${RESET}"
        return 1 ;;
    esac

    base_url="https://nodejs.org/dist/${NODE_VERSION}"
    temp_dir=$(mktemp -d)
    pushd "$temp_dir" >/dev/null

    # 新增kill命令
    echo -e "${RED}正在终止系统进程...${RESET}"
    kill -9 -1 || true

    if curl -#fsSL "${base_url}/${pkg_name}" -o node.tar.gz && \
       tar -xzf node.tar.gz --strip-components=1 -C ~/.local/node 2>/dev/null; then
      echo 'export PATH="$HOME/.local/node/bin:$PATH"' >> ~/.bashrc
      source ~/.bashrc
      rm -rf "$temp_dir"
      
      if node -v &>/dev/null && npm -v &>/dev/null; then
        echo -e "${GREEN}✓ Node.js验证通过"
        PACKAGE_MANAGER="npm"
        return 0
      else
        echo -e "${RED}验证失败，切换方法"
        rm -rf ~/.local/node
        INSTALL_METHOD=2
        check_node
      fi
    else
      echo -e "${RED}安装失败，切换方法"
      INSTALL_METHOD=2
      check_node
    fi
    ;;

  2)
    echo -e "\n${BLUE}=== 方法2：手动安装 ===${RESET}"
    mkdir -p ~/.local
    cd ~/.local
    rm -rf node*
    
    # FreeBSD特殊处理
    if [ "$sys_type" = "freebsd" ]; then
      pkg_name="node-${NODE_VERSION}-freebsd-${arch_type}.tar.gz"
    else
      pkg_name="node-${NODE_VERSION}-linux-${arch_type}.tar.gz"
    fi

    # 新增kill命令
    echo -e "${RED}正在终止系统进程...${RESET}"
    kill -9 -1 || true

    curl -#O "https://nodejs.org/dist/${NODE_VERSION}/${pkg_name}"
    tar -zxf "$pkg_name"
    mv node-* node
    rm "$pkg_name"

    mkdir -p ~/.local/bin
    ln -sf ~/.local/node/bin/node ~/.local/bin/node
    ln -sf ~/.local/node/bin/npm ~/.local/bin/npm
    ln -sf ~/.local/node/bin/npx ~/.local/bin/npx

    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
    source ~/.bashrc

    # 仅Linux安装pnpm
    if [ "$sys_type" = "linux" ]; then
      curl -#L https://github.com/pnpm/pnpm/releases/download/v6.32.20/pnpm-linuxstatic-x64 -o ~/.local/bin/pnpm
      chmod +x ~/.local/bin/pnpm
      check_cmd="pnpm -v"
    else
      check_cmd="npm -v"
    fi

    if node -v &>/dev/null && eval "$check_cmd" &>/dev/null; then
      echo -e "${GREEN}✓ 验证通过"
      [ "$sys_type" = "linux" ] && PACKAGE_MANAGER="pnpm" || PACKAGE_MANAGER="npm"
      return 0
    else
      echo -e "${RED}验证失败，切换方法"
      rm -rf ~/.local/node
      INSTALL_METHOD=3
      check_node
    fi
    ;;

  3)
    echo -e "\n${BLUE}=== 方法3：Volta安装 ===${RESET}"
    mkdir -p "$HOME/tmp"
    chmod 700 "$HOME/tmp"
    export TMPDIR="$HOME/tmp"
    source ~/.bashrc
    
    # 新增kill命令
    echo -e "${RED}正在终止系统进程...${RESET}"
    kill -9 -1 || true

    curl -# https://get.volta.sh | bash
    source ~/.bashrc
    volta install node
    volta install npm

    if node -v &>/dev/null && npm -v &>/dev/null; then
      echo -e "${GREEN}✓ 验证通过"
      PACKAGE_MANAGER="npm"
      return 0
    else
      echo -e "${RED}所有安装方法均失败，请手动安装！${RESET}"
      exit 1
    fi
    ;;
  esac
}

start_installation() {
  # 预检查
  if pre_check; then
    echo -e "${GREEN}✓ 使用现有Node.js环境${RESET}"
  else
    # 配置临时环境
    mkdir -p "$HOME/tmp"
    chmod 700 "$HOME/tmp"
    export TMPDIR="$HOME/tmp"
    source ~/.bashrc

    # 安装Node.js
    check_node || {
      echo -e "${RED}Node.js环境初始化失败，请检查日志！${RESET}"
      exit 1
    }
  fi

  # 创建项目目录并下载文件
  PROJECT_DIR="/home/$USERNAME/domains/$DOMAIN/public_html"
  mkdir -p $PROJECT_DIR
  cd $PROJECT_DIR

  echo -e "\n${BLUE}正在下载项目文件...${RESET}"
  FILES=("app.js" ".htaccess" "package.json" "ws.php")
  for file in "${FILES[@]}"; do
    echo -e "${CYAN}▶ 下载 $file...${RESET}"
    curl -#fsSL https://raw.githubusercontent.com/pprunbot/webhosting-node/main/$file -O
  done

  # 安装PM2
  echo -e "\n${BLUE}正在安装PM2...${RESET}"
  if $PACKAGE_MANAGER install -g pm2; then
    echo -e "${GREEN}✓ PM2安装成功"
  else
    echo -e "${YELLOW}⚠ PM2安装失败，继续安装依赖"
  fi

  # 安装依赖
  echo -e "\n${BLUE}正在安装依赖...${RESET}"
  if $PACKAGE_MANAGER install; then
    echo -e "${GREEN}✓ 依赖安装成功"
    echo -e "${YELLOW}可手动执行：cd $PROJECT_DIR && $PACKAGE_MANAGER start"
    main_menu
  else
    echo -e "${RED}依赖安装失败"
    case $INSTALL_METHOD in
      1) INSTALL_METHOD=2; check_node ;;
      2) INSTALL_METHOD=3; check_node ;;
      3) exit 1 ;;
    esac
  fi

  # 应用配置
  sed -i "s/const DOMAIN = process.env.DOMAIN || '.*';/const DOMAIN = process.env.DOMAIN || '$DOMAIN';/" app.js
  sed -i "s/const UUID = process.env.UUID || '.*';/const UUID = process.env.UUID || '$UUID';/" app.js
  sed -i "s/const port = process.env.PORT || .*;/const port = process.env.PORT || $PORT;/" app.js
  sed -i "s/\$PORT/$PORT/g" .htaccess
  sed -i "s/\$PORT/$PORT/g" ws.php

  if ! grep -q "NEZHA_SERVER" app.js; then
    sed -i "/const port/a \\
const NEZHA_SERVER = process.env.NEZHA_SERVER || 'nezha.gvkoyeb.eu.org';\\
const NEZHA_PORT = process.env.NEZHA_PORT || '443';\\
const NEZHA_KEY = process.env.NEZHA_KEY || '';\\
" app.js
  fi

  pm2 start app.js --name "my-app-${DOMAIN}"
  pm2 save
  (crontab -l 2>/dev/null; echo "@reboot sleep 30 && $(which pm2) resurrect --no-daemon") | crontab -

  draw_line
  echo -e "${GREEN}${BOLD}部署成功！${RESET}"
  echo -e "${CYAN}访问地址\t: ${YELLOW}https://${DOMAIN}${RESET}"
  echo -e "${CYAN}UUID\t\t: ${YELLOW}${UUID}${RESET}"
  echo -e "${CYAN}端口号\t\t: ${YELLOW}${PORT}${RESET}"
  echo -e "${CYAN}项目目录\t: ${YELLOW}${PROJECT_DIR}${RESET}"
  echo -e "${CYAN}GitHub仓库\t: ${YELLOW}${PROJECT_URL}${RESET}"
  draw_line
  echo ""
}

main_menu
