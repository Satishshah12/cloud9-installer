#!/bin/bash

set -e

clear

echo "=============================================="
echo "          VIPER CLOUD9 IDE INSTALLER"
echo "          Ubuntu 22.04 Edition"
echo "=============================================="
echo ""

############################################
# ROOT CHECK
############################################

if [ "$EUID" -ne 0 ]; then
    echo "ERROR: Please run as root"
    echo "Example:"
    echo "curl -fsSL URL | sudo bash"
    exit 1
fi


############################################
# CHECK UBUNTU
############################################

UBUNTU_VERSION=$(lsb_release -rs)

echo "Detected Ubuntu: $UBUNTU_VERSION"

if [[ "$UBUNTU_VERSION" != "22.04" ]]; then
    echo ""
    echo "WARNING: This installer is optimized for Ubuntu 22.04"
    echo ""
fi


############################################
# CONFIG
############################################

CONTAINER_NAME="cloud9"
PORT="8181"
WORKSPACE="/root/workspace"
TIMEZONE="Asia/Jakarta"

PASSWORD=$(openssl rand -base64 12)


############################################
# SYSTEM UPDATE
############################################

echo ""
echo "[1/10] Updating system..."

apt update -y
apt upgrade -y



############################################
# INSTALL DEPENDENCIES
############################################

echo ""
echo "[2/10] Installing dependencies..."

apt install -y \
curl \
wget \
git \
zip \
unzip \
openssl \
ufw \
ca-certificates



############################################
# FIREWALL
############################################

echo ""
echo "[3/10] Opening port ${PORT}"

ufw allow ${PORT}/tcp || true

iptables -I INPUT -p tcp --dport ${PORT} -j ACCEPT || true



############################################
# DOCKER INSTALL
############################################

echo ""
echo "[4/10] Installing Docker"


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
echo "[5/10] Creating workspace"


mkdir -p ${WORKSPACE}



############################################
# REMOVE OLD
############################################

echo ""
echo "[6/10] Preparing Cloud9"


docker rm -f ${CONTAINER_NAME} >/dev/null 2>&1 || true



############################################
# INSTALL CLOUD9
############################################

echo ""
echo "[7/10] Starting Cloud9 IDE"


docker pull lscr.io/linuxserver/cloud9:latest



docker run -d \
--name ${CONTAINER_NAME} \
-e PUID=0 \
-e PGID=0 \
-e TZ=${TIMEZONE} \
-e PASSWORD=${PASSWORD} \
-p ${PORT}:8000 \
-v ${WORKSPACE}:/code \
--restart unless-stopped \
lscr.io/linuxserver/cloud9:latest



############################################
# INSTALL DEV TOOLS
############################################

echo ""
echo "[8/10] Installing Development Environment"


sleep 15


docker exec ${CONTAINER_NAME} bash -c "

apt update -y

apt install -y \
php8.1 \
php8.1-cli \
php8.1-curl \
php8.1-mbstring \
php8.1-xml \
php8.1-zip \
php8.1-mysql \
python3 \
python3-pip \
git \
curl \
wget \
zip \
unzip

"



############################################
# NODE JS 22
############################################

echo ""
echo "[9/10] Installing Node.js 22"


docker exec ${CONTAINER_NAME} bash -c "

curl -fsSL https://deb.nodesource.com/setup_22.x | bash -

apt install -y nodejs

"



############################################
# COMPOSER
############################################

echo ""
echo "[10/10] Installing Composer"


docker exec ${CONTAINER_NAME} bash -c "

php -r \"copy('https://getcomposer.org/installer','composer-setup.php');\"

php composer-setup.php \
--install-dir=/usr/local/bin \
--filename=composer

rm composer-setup.php

"



############################################
# RESULT
############################################

IP=$(curl -4 -s ifconfig.me)


echo ""
echo "=============================================="
echo "        VIPER CLOUD9 READY"
echo "=============================================="
echo ""

echo "URL:"
echo ""
echo "http://${IP}:${PORT}"

echo ""

echo "PASSWORD:"
echo ""
echo "${PASSWORD}"

echo ""

echo "WORKSPACE:"
echo ""
echo "${WORKSPACE}"

echo ""

echo "CONTAINER:"
echo "${CONTAINER_NAME}"

echo ""
echo "=============================================="
