#!/bin/bash

set -e

export DEBIAN_FRONTEND=noninteractive

clear

echo "=============================================="
echo "         VIPER CLOUD9 IDE INSTALLER"
echo "         Ubuntu 22.04 / 24.04 Edition"
echo "=============================================="
echo ""


############################################
# ROOT CHECK
############################################

if [ "$EUID" -ne 0 ]; then
    echo "ERROR: Please run this installer as root"
    echo ""
    echo "Example:"
    echo "curl -fsSL URL | sudo bash"
    exit 1
fi



############################################
# DETECT UBUNTU
############################################

UBUNTU_VERSION=$(lsb_release -rs)

echo "Detected Host Ubuntu: $UBUNTU_VERSION"


if [[ "$UBUNTU_VERSION" != "22.04" && "$UBUNTU_VERSION" != "24.04" ]]; then

    echo ""
    echo "ERROR: Unsupported Ubuntu version"
    echo "Supported:"
    echo "Ubuntu 22.04"
    echo "Ubuntu 24.04"
    exit 1

fi



############################################
# CONFIGURATION
############################################

CONTAINER_NAME="cloud9"
PORT="8181"
INTERNAL_PORT="8182"  # Kontainer dipindah ke port internal agar tidak bisa di-bypass lewat IP langsung
WORKSPACE="/root/workspace"
TIMEZONE="Asia/Jakarta"

CUSTOM_USER="admin"
CUSTOM_PASS=$(openssl rand -base64 12)



############################################
# CLEAN OLD REPOSITORY
############################################

echo ""
echo "[1/12] Cleaning old repository..."


rm -f /etc/apt/sources.list.d/docker.list
rm -f /etc/apt/sources.list.d/docker-ce.list
rm -f /etc/apt/sources.list.d/nodesource.list


apt update -y



############################################
# UPDATE SYSTEM
############################################

echo ""
echo "[2/12] Updating system..."


apt upgrade -y



############################################
# BASIC PACKAGE & NGINX
############################################

echo ""
echo "[3/12] Installing dependencies and Nginx..."


apt install -y \
curl \
wget \
git \
zip \
unzip \
openssl \
ca-certificates \
gnupg \
lsb-release \
ufw \
iptables \
nginx \
apache2-utils  # Dibutuhkan untuk perintah htpasswd



############################################
# FIREWALL
############################################

echo ""
echo "[4/12] Opening port ${PORT}"


ufw allow ${PORT}/tcp || true

iptables -I INPUT -p tcp --dport ${PORT} -j ACCEPT || true



############################################
# DOCKER
############################################

echo ""
echo "[5/12] Installing Docker..."


if ! command -v docker >/dev/null 2>&1
then

curl -fsSL https://get.docker.com | sh

fi


systemctl enable docker
systemctl start docker



############################################
# WORKSPACE
############################################

echo ""
echo "[6/12] Creating workspace..."


mkdir -p ${WORKSPACE}



############################################
# REMOVE OLD CLOUD9 & NGINX CONFIG
############################################

echo ""
echo "[7/12] Removing old Cloud9 container and Nginx configs..."


docker rm -f ${CONTAINER_NAME} >/dev/null 2>&1 || true
rm -f /etc/nginx/sites-enabled/cloud9
rm -f /etc/nginx/sites-available/cloud9



############################################
# INSTALL CLOUD9
############################################

echo ""
echo "[8/12] Installing Cloud9 IDE..."


docker pull lscr.io/linuxserver/cloud9:latest


# Jalankan kontainer pada 127.0.0.1 agar tidak bisa diakses dari luar kecuali lewat Nginx
docker run -d \
--name ${CONTAINER_NAME} \
-e PUID=0 \
-e PGID=0 \
-e TZ=${TIMEZONE} \
-p 127.0.0.1:${INTERNAL_PORT}:8000 \
-v ${WORKSPACE}:/code \
--restart unless-stopped \
lscr.io/linuxserver/cloud9:latest



############################################
# CONFIGURING NGINX AUTH PROXY
############################################

echo ""
echo "Configuring Nginx Reverse Proxy with Auth..."

# Membuat file password untuk basic-auth Nginx
mkdir -p /etc/nginx/auth
htpasswd -b -c /etc/nginx/auth/.cloud9_htpasswd "${CUSTOM_USER}" "${CUSTOM_PASS}"

# Membuat konfigurasi Virtual Host Nginx
cat << 'EOF' > /etc/nginx/sites-available/cloud9
server {
    listen NGINX_PORT;
    server_name _;

    auth_basic "Restricted Access - Cloud9 IDE";
    auth_basic_user_file /etc/nginx/auth/.cloud9_htpasswd;

    location / {
        proxy_pass http://127.0.0.1:INTERNAL_PORT;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Dukungan WebSocket untuk terminal Cloud9
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 86400;
    }
}
EOF

# Mengganti placeholder port di dalam file Nginx
sed -i "s/NGINX_PORT/${PORT}/g" /etc/nginx/sites-available/cloud9
sed -i "s/INTERNAL_PORT/${INTERNAL_PORT}/g" /etc/nginx/sites-available/cloud9

# Mengaktifkan konfigurasi dan merestart Nginx
ln -s /etc/nginx/sites-available/cloud9 /etc/nginx/sites-enabled/
systemctl restart nginx



############################################
# WAIT CLOUD9
############################################

echo ""
echo "Waiting Cloud9 container..."


sleep 20


if ! docker ps | grep ${CONTAINER_NAME} >/dev/null
then

echo "Cloud9 failed to start"

docker logs ${CONTAINER_NAME}

exit 1

fi



############################################
# DEVELOPMENT TOOLS
############################################

echo ""
echo "[9/12] Installing PHP Python Git..."


docker exec ${CONTAINER_NAME} bash -c "

export DEBIAN_FRONTEND=noninteractive

apt update -y

apt install -y \
php \
php-cli \
php-curl \
php-mbstring \
php-xml \
php-zip \
php-mysql \
python3 \
python3-pip \
git \
curl \
wget \
zip \
unzip

"



############################################
# NODE JS 18 BINARY INSTALL
############################################

echo ""
echo "[10/12] Installing Node.js 18..."


docker exec ${CONTAINER_NAME} bash -c "

cd /tmp

curl -fsSL https://nodejs.org/dist/v18.20.8/node-v18.20.8-linux-x64.tar.xz -o node.tar.xz

tar -xf node.tar.xz

mv node-v18.20.8-linux-x64 /opt/nodejs

ln -sf /opt/nodejs/bin/node /usr/local/bin/node
ln -sf /opt/nodejs/bin/npm /usr/local/bin/npm
ln -sf /opt/nodejs/bin/npx /usr/local/bin/npx


node -v

npm -v

rm node.tar.xz

"



############################################
# COMPOSER
############################################

echo ""
echo "[11/12] Installing Composer..."


docker exec ${CONTAINER_NAME} bash -c "

php -r \"copy('https://getcomposer.org/installer','composer-setup.php');\"

php composer-setup.php \
--install-dir=/usr/local/bin \
--filename=composer

rm composer-setup.php

composer --version

"



############################################
# FINAL
############################################

echo ""
echo "[12/12] Finishing installation..."


SERVER_IP=$(curl -4 -s ifconfig.me || hostname -I | awk '{print $1}')



echo ""
echo "=============================================="
echo "        VIPER CLOUD9 INSTALL SUCCESS"
echo "=============================================="
echo ""

echo "Cloud9 URL:"
echo "http://${SERVER_IP}:${PORT}"
echo ""

echo "Login Credentials (SYSTEM ENFORCED):"
echo "Username : ${CUSTOM_USER}"
echo "Password : ${CUSTOM_PASS}"
echo ""

echo "Workspace:"
echo "${WORKSPACE}"
echo ""

echo "Host Ubuntu:"
echo "${UBUNTU_VERSION}"
echo ""

echo "Node:"
echo "Node.js 18"
echo ""

echo "Container:"
echo "${CONTAINER_NAME}"
echo ""
echo "=============================================="
echo "      READY FOR DEVELOPMENT"
echo "=============================================="
