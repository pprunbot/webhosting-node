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
  printf "%$(tput cols)s\n" | tr ' ' '-'
}

# 显示项目信息
show_header() {
  clear
  echo -e "${GREEN}${BOLD}"
  draw_line
  printf "%*s\n" $(((${#1}+$(tput cols))/2)) "$1"
  draw_line
  echo -e "${RESET}"
  echo -e "${CYAN}项目地址: ${YELLOW}${PROJECT_URL}${RESET}\n"
}

# 获取当前用户名
USERNAME=$(whoami)

# 初始界面
show_header "WebHosting Node 部署工具"

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
echo -e "${BOLD}${BLUE}可用的域名列表：${RESET}"
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

# 检测Node.js安装
check_node() {
  if ! command -v node &> /dev/null || ! command -v npm &> /dev/null; then
    echo -e "\n${BLUE}正在安装Node.js...${RESET}"
    
    # 创建安装目录
    mkdir -p ~/.local/node
    
    # 下载Node.js
    echo -e "${CYAN}▶ 下载Node.js运行环境...${RESET}"
    curl -#fsSL https://nodejs.org/dist/v20.12.2/node-v20.12.2-linux-x64.tar.gz -o node.tar.gz
    
    # 解压文件
    echo -e "\n${CYAN}▶ 解压文件...${RESET}"
    tar -xzf node.tar.gz --strip-components=1 -C ~/.local/node
    
    # 添加环境变量
    echo -e "\n${CYAN}▶ 配置环境变量...${RESET}"
    echo 'export PATH=$HOME/.local/node/bin:$PATH' >> ~/.bashrc
    echo 'export PATH=$HOME/.local/node/bin:$PATH' >> ~/.bash_profile
    
    # 立即生效
    source ~/.bashrc
    source ~/.bash_profile
    
    # 清理临时文件
    rm node.tar.gz
  fi

  # 再次验证安装
  if ! command -v node &> /dev/null || ! command -v npm &> /dev/null; then
    echo -e "${RED}Node.js安装失败，请手动安装后重试${RESET}"
    exit 1
  fi
}

check_node

# 安装PM2
echo -e "\n${BLUE}正在安装PM2进程管理器...${RESET}"
npm install -g pm2

# 创建项目目录
PROJECT_DIR="/home/$USERNAME/domains/$DOMAIN/public_html"
mkdir -p $PROJECT_DIR
cd $PROJECT_DIR

# 下载项目文件
echo -e "\n${BLUE}正在下载项目文件...${RESET}"
FILES=("app.js" ".htaccess" "package.json" "ws.php")
for file in "${FILES[@]}"; do
  echo -e "${CYAN}▶ 下载 $file...${RESET}"
  curl -#fsSL https://raw.githubusercontent.com/pprunbot/webhosting-node/main/$file -O
done

# 项目依赖安装
echo -e "\n${BLUE}正在安装项目依赖...${RESET}"
npm install

# 新增依赖安装验证
if [ $? -ne 0 ]; then
  echo -e "${RED}错误：npm依赖安装失败，请检查网络连接和package.json配置${RESET}"
  exit 1
fi

# 修改配置文件
echo -e "\n${BLUE}正在配置应用参数...${RESET}"
sed -i "s/const DOMAIN = process.env.DOMAIN || '.*';/const DOMAIN = process.env.DOMAIN || '$DOMAIN';/" app.js
sed -i "s/const UUID = process.env.UUID || '.*';/const UUID = process.env.UUID || '$UUID';/" app.js
sed -i "s/const port = process.env.PORT || .*;/const port = process.env.PORT || $PORT;/" app.js
sed -i "s/\$PORT/$PORT/g" .htaccess
sed -i "s/\$PORT/$PORT/g" ws.php

# 启动服务
echo -e "\n${BLUE}正在启动PM2服务...${RESET}"
pm2 start app.js --name my-app
pm2 save

# 添加定时任务
(crontab -l 2>/dev/null; echo "@reboot sleep 30 && /home/$USERNAME/.local/node/bin/pm2 resurrect --no-daemon") | crontab -

# 最终输出
draw_line
echo -e "${GREEN}${BOLD}部署成功！${RESET}"
echo -e "${CYAN}访问地址\t: ${YELLOW}https://${DOMAIN}${RESET}"
echo -e "${CYAN}UUID\t\t: ${YELLOW}${UUID}${RESET}"
echo -e "${CYAN}端口号\t\t: ${YELLOW}${PORT}${RESET}"
echo -e "${CYAN}项目目录\t: ${YELLOW}${PROJECT_DIR}${RESET}"
echo -e "${CYAN}GitHub仓库\t: ${YELLOW}${PROJECT_URL}${RESET}"
draw_line
echo ""
