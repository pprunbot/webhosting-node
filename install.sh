#!/bin/bash
set -e

# 颜色定义
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
NC='\033[0m'
BOLD='\033[1m'

# 图形元素
HR="${BLUE}===================================================${NC}"
CHECK="${GREEN}✔${NC}"
CROSS="${RED}✘${NC}"
ARROW="${CYAN}➜${NC}"

# 显示标题
print_title() {
  clear
  echo -e "${HR}"
  echo -e "${BLUE} ██████╗ ██████╗ ███████╗██╗   ██╗${YELLOW}██╗  ██╗${NC}"
  echo -e "${BLUE}██╔═══██╗██╔══██╗██╔════╝██║   ██║${YELLOW}╚██╗██╔╝${NC}"
  echo -e "${BLUE}██║   ██║██████╔╝█████╗  ██║   ██║${YELLOW} ╚███╔╝ ${NC}"
  echo -e "${BLUE}██║   ██║██╔═══╝ ██╔══╝  ██║   ██║${YELLOW} ██╔██╗ ${NC}"
  echo -e "${BLUE}╚██████╔╝██║     ██║     ╚██████╔╝${YELLOW}██╔╝ ██╗${NC}"
  echo -e "${BLUE} ╚═════╝ ╚═╝     ╚═╝      ╚═════╝ ${YELLOW}╚═╝  ╚═╝${NC}"
  echo -e "${HR}"
}

# 进度显示
progress() {
  echo -ne "${CYAN}${1}...${NC}"
  shift
  ("$@") >/dev/null 2>&1
  echo -e "\r${CHECK} ${CYAN}${1}完成${NC}"
}

# 错误处理
error_exit() {
  echo -e "\n${RED}╔══════════════════════════════════════════╗"
  echo -e "║              安装遇到错误              ║"
  echo -e "╠══════════════════════════════════════════╣"
  echo -e "║ ${BOLD}原因: ${1}${RED}                     ║"
  echo -e "╚══════════════════════════════════════════╝${NC}\n"
  exit 1
}

# 初始化检测
print_title
echo -e "${CHECK} ${CYAN}开始系统检测...${NC}"

# 获取用户名
USERNAME=$(whoami)
echo -e "${ARROW} ${BOLD}当前用户: ${GREEN}${USERNAME}${NC}"

# 域名检测
DOMAINS_DIR="/home/${USERNAME}/domains"
[ ! -d "${DOMAINS_DIR}" ] && error_exit "域名目录不存在"

DOMAINS=($(ls -d ${DOMAINS_DIR}/*/ | xargs -n1 basename))
[ ${#DOMAINS[@]} -eq 0 ] && error_exit "未找到可用域名"

# 域名选择
echo -e "\n${CHECK} ${CYAN}检测到可用域名:${NC}"
for i in "${!DOMAINS[@]}"; do
  echo -e " ${BOLD}${GREEN}$((i+1)).${NC} ${DOMAINS[$i]}"
done

read -p "$(echo -e "${ARROW} ${BOLD}请选择域名 [${GREEN}1-${#DOMAINS[@]}${NC}]: ")" DOMAIN_INDEX
DOMAIN_INDEX=${DOMAIN_INDEX:-1}
[[ ! $DOMAIN_INDEX =~ ^[0-9]+$ ]] && error_exit "无效数字输入"
DOMAIN=${DOMAINS[$((DOMAIN_INDEX-1))]}
echo -e "${CHECK} 已选域名: ${GREEN}${DOMAIN}${NC}"

# 端口输入
while true; do
  read -p "$(echo -e "${ARROW} ${BOLD}请输入服务端口 [${GREEN}4000${NC}]: ")" PORT
  PORT=${PORT:-4000}
  [[ $PORT =~ ^[0-9]+$ && $PORT -gt 0 && $PORT -lt 65536 ]] && break
  echo -e "${CROSS} 端口必须为1-65535之间的数字"
done

# UUID生成
read -p "$(echo -e "${ARROW} ${BOLD}输入UUID [按Enter自动生成]: ")" UUID
if [ -z "${UUID}" ]; then
  UUID=$(cat /proc/sys/kernel/random/uuid)
  echo -e "${CHECK} 生成UUID: ${GREEN}${UUID}${NC}"
else
  echo -e "${CHECK} 使用自定义UUID"
fi

# Node.js安装检测
install_node() {
  echo -e "\n${HR}"
  echo -e "${CHECK} ${CYAN}开始Node.js环境部署${NC}"
  
  mkdir -p ~/.local/node || error_exit "创建目录失败"
  
  progress "下载Node.js" curl -fsSL https://nodejs.org/dist/v20.12.2/node-v20.12.2-linux-x64.tar.gz -o node.tar.gz
  progress "解压文件" tar -xzf node.tar.gz --strip-components=1 -C ~/.local/node
  rm node.tar.gz

  echo -e "export PATH=\$HOME/.local/node/bin:\$PATH" >> ~/.bashrc
  echo -e "export PATH=\$HOME/.local/node/bin:\$PATH" >> ~/.bash_profile
  source ~/.bashrc
  source ~/.bash_profile

  echo -e "\n${CHECK} ${GREEN}Node.js版本: ${BOLD}$(node -v)${NC}"
  echo -e "${CHECK} ${GREEN}npm版本: ${BOLD}$(npm -v)${NC}"
}

if ! command -v node &>/dev/null; then
  install_node
else
  echo -e "\n${CHECK} ${GREEN}已安装Node.js ${BOLD}$(node -v)${NC}"
fi

# 安装PM2
echo -e "\n${HR}"
progress "安装PM2守护进程" npm install -g pm2
echo -e "${CHECK} ${GREEN}PM2版本: ${BOLD}$(pm2 -v)${NC}"

# 项目部署
echo -e "\n${HR}"
echo -e "${CHECK} ${CYAN}开始部署项目文件${NC}"
PROJECT_DIR="/home/${USERNAME}/domains/${DOMAIN}/public_html"
mkdir -p "${PROJECT_DIR}"
cd "${PROJECT_DIR}" || error_exit "进入项目目录失败"

FILES=("app.js" ".htaccess" "package.json" "ws.php")
for file in "${FILES[@]}"; do
  progress "下载${file}" curl -fsSL "https://raw.githubusercontent.com/pprunbot/webhosting-node/main/${file}" -O
done

# 配置文件修改
echo -e "\n${CHECK} ${CYAN}配置应用参数${NC}"
sed -i "s/const DOMAIN = process.env.DOMAIN || '.*';/const DOMAIN = process.env.DOMAIN || '${DOMAIN}';/" app.js
sed -i "s/const UUID = process.env.UUID || '.*';/const UUID = process.env.UUID || '${UUID}';/" app.js
sed -i "s/const port = process.env.PORT || .*;/const port = process.env.PORT || ${PORT};/" app.js

# 安装依赖
echo -e "\n${HR}"
progress "安装项目依赖" npm install

# 启动服务
echo -e "\n${HR}"
echo -e "${CHECK} ${CYAN}启动应用服务${NC}"
pm2 start app.js --name my-app
pm2 save

# 定时任务
CRON_JOB="@reboot sleep 30 && /home/${USERNAME}/.local/node/bin/pm2 resurrect --no-daemon"
if ! crontab -l | grep -qF "${CRON_JOB}"; then
  (crontab -l 2>/dev/null; echo "${CRON_JOB}") | crontab -
  echo -e "${CHECK} 已添加开机启动任务"
else
  echo -e "${CHECK} 开机启动任务已存在"
fi

# 完成界面
echo -e "\n${HR}"
echo -e "${GREEN}╔══════════════════════════════════════════╗"
echo -e "║            🎉 安装成功！               ║"
echo -e "╠══════════════════════════════════════════╣"
echo -e "║ ${BOLD}访问地址: ${CYAN}https://${DOMAIN}${GREEN}           ║"
echo -e "║ ${BOLD}UUID: ${YELLOW}${UUID}${GREEN}     ║"
echo -e "║ ${BOLD}服务端口: ${BLUE}${PORT}${GREEN}                     ║"
echo -e "║                                        ║"
echo -e "║ ${BOLD}管理命令:                          ${GREEN}║"
echo -e "║ ${ARROW} ${CYAN}pm2 list    ${GREEN}查看服务状态       ║"
echo -e "║ ${ARROW} ${CYAN}pm2 logs    ${GREEN}查看实时日志       ║"
echo -e "║ ${ARROW} ${CYAN}pm2 stop my-app   ${GREEN}停止服务     ║"
echo -e "╚══════════════════════════════════════════╝${NC}\n"
