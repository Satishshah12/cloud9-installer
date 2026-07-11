#!/bin/bash

set -e

clear

echo "=============================================="
echo "          VIPER CLOUD9 IDE INSTALLER"
echo "          Universal Ubuntu Edition"
echo "=============================================="
echo ""


############################################
# ROOT CHECK
############################################

if [ "$EUID" -ne 0 ]; then
    echo "ERROR: Please run this installer as root."
    echo ""
    echo "Example:"
    echo "curl -fsSL URL | sudo bash"
    exit 1
fi


############################################
# CONFIG
############################################

CLOUD9_NAME="cloud9"
CLOUD9_PORT="8181"
WORKSPACE="/root/workspace"
TIMEZONE="Asia/Jakarta"



############################################
# DETECT UBUNTU
############################################

echo "[INFO] Detecting Ubuntu version..."

UBUNTU_VERSION=$(lsb_release -rs)

echo "Ubuntu Version: $UBUNTU_VERSION"


if [[ "$UBUNTU_VERSION" == "18.04" ]]; then

    NODE_VERSION="18"

else

    NODE_VERSION="22"

fi


echo "Node.js Version: $NODE_VERSION"



############################################
# UPDATE SYSTEM
############################################

echo ""
echo "[1/10] Updating system..."

apt-get update -y
apt-get upgrade -y



############################################
# BASIC PACKAGE
############################################

echo ""
echo "[2/10] Installing dependencies..."

apt-get install -y \
curl \
wget \
git \
zip \
unzip \
openssl \
ufw \
iptables \
lsb-release



############################################
# FIREWALL
############################################

echo ""
echo "[3/10] Opening port $CLOUD9_PORT..."

if command -v ufw >/dev/null 2>&1
then
    ufw allow ${CLOUD9_PORT}/tcp || true
fi


iptables -I INPUT -p tcp --dport ${CLOUD9_PORT} -j ACCEPT || true



############################################
# DOCKER
############################################

echo ""
echo "[4/10] Installing Docker..."


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
echo "[5/10] Creating workspace..."

mkdir -p ${WORKSPACE}



############################################
# PASSWORD
############################################

PASSWORD=$(openssl rand -base64 12)



############################################
# CLOUD9 INSTALL
############################################

echo ""
echo "[6/10] Installing Cloud9 IDE..."


docker rm -f ${CLOUD9_NAME} >/dev/null 2>&1 || true


docker pull lscr.io/linuxserver/cloud9:latest



docker run -d \
--name ${CLOUD9_NAME} \
-e PUID=0 \
-e PGID=0 \
-e TZ=${TIMEZONE} \
-e PASSWORD=${PASSWORD} \
-p ${CLOUD9_PORT}:8000 \
-v ${WORKSPACE}:/code \
--restart unless-stopped \
lscr.io/linuxserver/cloud9:latest



############################################
# DEV TOOLS
############################################

echo ""
echo "[7/10] Installing PHP Python Git..."


sleep 15


docker exec ${CLOUD9_NAME} bash -c "

apt-get update -y

apt-get install -y \
php \
php-cli \
php-curl \
php-json \
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
# NODE JS
############################################

echo ""
echo "[8/10] Installing Node.js $NODE_VERSION..."


docker exec ${CLOUD9_NAME} bash -c "

curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash -

apt-get install nodejs -y

"



############################################
# COMPOSER
############################################

echo ""
echo "[9/10] Installing Composer..."


docker exec ${CLOUD9_NAME} bash -c "

php -r \"copy('https://getcomposer.org/installer', 'composer-setup.php');\"

php composer-setup.php \
--install-dir=/usr/local/bin \
--filename=composer

rm composer-setup.php

"



############################################
# FINAL CHECK
############################################

echo ""
echo "[10/10] Finishing..."


SERVER_IP=$(curl -4 -s ifconfig.me || hostname -I | awk '{print $1}')



echo ""
echo "=============================================="
echo "       VIPER CLOUD9 INSTALL SUCCESS"
echo "=============================================="
echo ""

echo "Cloud9 URL:"
echo ""
echo "http://${SERVER_IP}:${CLOUD9_PORT}"

echo ""

echo "Password:"
echo ""
echo "${PASSWORD}"

echo ""

echo "Workspace:"
echo ""
echo "${WORKSPACE}"

echo ""

echo "Ubuntu:"
echo "${UBUNTU_VERSION}"

echo ""

echo "Node.js:"
echo "v${NODE_VERSION}"

echo ""

echo "Container:"
echo "${CLOUD9_NAME}"

echo ""
echo "=============================================="
echo "       READY FOR DEVELOPMENT"
echo "=============================================="
