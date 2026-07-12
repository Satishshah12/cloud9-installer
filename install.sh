#!/bin/bash

# Color Definitions
GREEN='\033[0;32m'
CYAN='\033[0;36m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
RESET='\033[0m'

set -e
export DEBIAN_FRONTEND=noninteractive
clear

# Function for animated loading indicator
run_task() {
    local message="$1"
    local command="$2"
    
    echo -ne "${CYAN}[>] ${message}...${RESET}"
    
    # Run command silently in background
    eval "$command" > /dev/null 2>&1 &
    local pid=$!
    
    # Loading animation loops while command runs
    local spin='-\|/'
    local i=0
    while kill -0 $pid 2>/dev/null; do
        i=$(( (i+1) % 4 ))
        echo -ne "\b${spin:$i:1}"
        sleep 0.1
    done
    
    # Check exit status
    wait $pid
    if [ $? -eq 0 ]; then
        echo -e "\b${GREEN}[DONE]${RESET}"
    else
        echo -e "\b${RED}[FAILED]${RESET}"
        exit 1
    fi
}

echo -e "${GREEN}"
echo "██╗   ██╗██╗██████╗ ███████╗██████╗     ███████╗ ██████╗ ███╗   ██╗███████╗"
echo "██║   ██║██║██╔══██╗██╔════╝██╔══██╗    ╚══███╔╝██╔═══██╗████╗  ██║██╔════╝"
echo "██║   ██║██║██████╔╝█████╗  ██████╔╝      ███╔╝ ██║   ██║██╔██╗ ██║█████╗  "
echo "╚██╗ ██╔╝██║██╔═══╝ ██╔══╝  ██╔══██╗     ███╔╝  ██║   ██║██║╚██╗██║██╔══╝  "
echo " ╚████╔╝ ██║██║     ███████╗██║  ██║    ███████╗╚██████╔╝██║ ╚████║███████╗"
echo "  ╚═══╝  ╚═╝╚═╝     ╚══════╝╚═╝  ╚═╝    ╚══════╝ ╚═════╝ ╚═╝  ╚═══╝╚══════╝"
echo "=========================================================================="
echo "                   CLOUD9 IDE - SYSTEM RECON & OVERRIDE                   "
echo "=========================================================================="
echo -e "${RESET}"

############################################
# ROOT & OS CHECK
############################################
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[!] ACCESS DENIED: Please escalate to root (sudo bash)${RESET}\n"
    exit 1
fi

UBUNTU_VERSION=$(lsb_release -rs 2>/dev/null || echo "Unknown")
if [[ "$UBUNTU_VERSION" != "22.04" && "$UBUNTU_VERSION" != "24.04" ]]; then
    echo -e "${RED}[!] ERROR: Target OS Architecture ($UBUNTU_VERSION) unsupported.${RESET}\n"
    exit 1
fi

echo -e "${GREEN}[+] Target System Identified: Ubuntu $UBUNTU_VERSION${RESET}"
echo -e "${GREEN}[+] Initializing Payload Injection...${RESET}\n"

############################################
# CONFIGURATION
############################################
CONTAINER_NAME="cloud9"
PORT="8181"
INTERNAL_PORT="8182"
WORKSPACE="/root/workspace"
TIMEZONE="Asia/Jakarta"

CUSTOM_USER="admin"
CUSTOM_PASS=$(openssl rand -base64 12)

# Emergency Backup
echo -e "User: ${CUSTOM_USER}\nPass: ${CUSTOM_PASS}" > /root/c9_access_backup.txt

############################################
# EXECUTION MATRIX (SILENT RUN)
############################################

run_task "Purging old core repositories" \
"rm -f /etc/apt/sources.list.d/docker*.list /etc/apt/sources.list.d/nodesource.list && apt update -y"

run_task "Synchronizing system packages" \
"apt upgrade -y"

run_task "Injecting required network dependencies" \
"apt install -y curl wget git zip unzip openssl ca-certificates gnupg lsb-release ufw iptables nginx apache2-utils"

run_task "Bypassing firewall vectors (Port ${PORT})" \
"ufw allow ${PORT}/tcp || true && iptables -I INPUT -p tcp --dport ${PORT} -j ACCEPT || true"

run_task "Deploying Docker Main Engine" \
"if ! command -v docker >/dev/null 2>&1; then curl -fsSL https://get.docker.com | sh; fi && systemctl enable docker && systemctl start docker"

run_task "Allocating secure environment space" \
"mkdir -p ${WORKSPACE}"

run_task "Terminating previous instances" \
"docker rm -f ${CONTAINER_NAME} >/dev/null 2>&1 || true && rm -f /etc/nginx/sites-enabled/cloud9 /etc/nginx/sites-available/cloud9"

run_task "Downloading fresh Cloud9 Binary Matrix" \
"docker pull lscr.io/linuxserver/cloud9:latest"

run_task "Spawning isolated sandbox container" \
"docker run -d --name ${CONTAINER_NAME} -e PUID=0 -e PGID=0 -e TZ=${TIMEZONE} -p 127.0.0.1:${INTERNAL_PORT}:8000 -v ${WORKSPACE}:/code --restart unless-stopped lscr.io/linuxserver/cloud9:latest"

run_task "Locking down Gateway Proxy via Nginx" \
"mkdir -p /etc/nginx/auth && \
htpasswd -b -c /etc/nginx/auth/.cloud9_htpasswd '${CUSTOM_USER}' '${CUSTOM_PASS}' && \
cat << 'EOF' > /etc/nginx/sites-available/cloud9
server {
    listen NGINX_PORT;
    server_name _;
    auth_basic \"Viper Zone - System Lockdown\";
    auth_basic_user_file /etc/nginx/auth/.cloud9_htpasswd;
    location / {
        proxy_pass http://127.0.0.1:INTERNAL_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \"upgrade\";
        proxy_read_timeout 86400;
    }
}
EOF
sed -i 's/NGINX_PORT/'${PORT}'/g' /etc/nginx/sites-available/cloud9 && \
sed -i 's/INTERNAL_PORT/'${INTERNAL_PORT}'/g' /etc/nginx/sites-available/cloud9 && \
ln -sf /etc/nginx/sites-available/cloud9 /etc/nginx/sites-enabled/ && \
systemctl restart nginx"

run_task "Stabilizing environment protocols" \
"sleep 15"

run_task "Compiling Backend Core (PHP, Python3, Git)" \
"docker exec ${CONTAINER_NAME} bash -c 'export DEBIAN_FRONTEND=noninteractive && apt update -y && apt install -y php php-cli php-curl php-mbstring php-xml php-zip php-mysql python3 python3-pip git curl wget zip unzip'"

run_task "Injecting Node.js runtime environment (v18)" \
"docker exec ${CONTAINER_NAME} bash -c 'cd /tmp && curl -fsSL https://nodejs.org/dist/v18.20.8/node-v18.20.8-linux-x64.tar.xz -o node.tar.xz && tar -xf node.tar.xz && mv node-v18.20.8-linux-x64 /opt/nodejs && ln -sf /opt/nodejs/bin/node /usr/local/bin/node && ln -sf /opt/nodejs/bin/npm /usr/local/bin/npm && ln -sf /opt/nodejs/bin/npx /usr/local/bin/npx && rm node.tar.xz'"

run_task "Deploying dependency manager (Composer)" \
"docker exec ${CONTAINER_NAME} bash -c 'php -r \"copy(\"https://getcomposer.org/installer\",\"composer-setup.php\");\" && php composer-setup.php --install-dir=/usr/local/bin --filename=composer && rm composer-setup.php'"

############################################
# MINIMALIST OUTPUT OVERRIDE
############################################
SERVER_IP=$(curl -4 -s ifconfig.me || hostname -I | awk '{print $1}')

# Hapus backup darurat karena proses berhasil 100%
rm -f /root/c9_access_backup.txt

clear
echo -e "${GREEN}DONE${RESET}"
echo -e "${GREEN}URL      : http://${SERVER_IP}:${PORT}${RESET}"
echo -e "${GREEN}Username : ${CUSTOM_USER}${RESET}"
echo -e "${GREEN}Pass     : ${CUSTOM_PASS}${RESET}"
