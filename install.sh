#!/bin/bash

set -e

clear

echo "=============================================="
echo "          VIPER CLOUD9 IDE INSTALLER"
echo "=============================================="
echo ""

# Check root

if [ "$EUID" -ne 0 ]; then
    echo "ERROR: Please run this installer as root."
    echo ""
    echo "Example:"
    echo "sudo bash install.sh"
    exit 1
fi


############################################
# CONFIGURATION
############################################

CLOUD9_NAME="cloud9"
CLOUD9_PORT="8181"
WORKSPACE="/root/workspace"
TIMEZONE="Asia/Jakarta"


############################################
# UPDATE SYSTEM
############################################

echo "[1/9] Updating Ubuntu system..."

apt-get update -y
apt-get upgrade -y



############################################
# INSTALL BASIC PACKAGE
############################################

echo "[2/9] Installing required packages..."

apt-get install -y \
curl \
wget \
git \
zip \
unzip \
openssl \
ufw \
iptables



############################################
# FIREWALL
############################################

echo "[3/9] Opening Cloud9 port..."

if command -v ufw >/dev/null 2>&1
then
    ufw allow ${CLOUD9_PORT}/tcp || true
fi


iptables -I INPUT -p tcp --dport ${CLOUD9_PORT} -j ACCEPT || true



############################################
# INSTALL DOCKER
############################################

echo "[4/9] Installing Docker..."

if ! command -v docker >/dev/null 2>&1
then

curl -fsSL https://get.docker.com | sh

fi


systemctl enable docker
systemctl start docker



############################################
# CREATE WORKSPACE
############################################

echo "[5/9] Creating workspace..."

mkdir -p ${WORKSPACE}



############################################
# PASSWORD GENERATOR
############################################

PASSWORD=$(openssl rand -base64 12)



############################################
# INSTALL CLOUD9
############################################

echo "[6/9] Installing Cloud9 IDE..."

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
# DEVELOPMENT ENVIRONMENT
############################################

echo "[7/9] Installing Development Tools..."


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

echo "[8/9] Installing Node.js..."

docker exec ${CLOUD9_NAME} bash -c "

curl -fsSL https://deb.nodesource.com/setup_22.x | bash -

apt-get install nodejs -y

"



############################################
# COMPOSER
############################################

echo "[9/9] Installing Composer..."


docker exec ${CLOUD9_NAME} bash -c "

php -r \"copy('https://getcomposer.org/installer', 'composer-setup.php');\"

php composer-setup.php \
--install-dir=/usr/local/bin \
--filename=composer

rm composer-setup.php

"



############################################
# RESULT
############################################

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

echo "Container:"
echo "${CLOUD9_NAME}"

echo ""
echo "=============================================="
echo "      Enjoy Your Cloud9 Development IDE"
echo "=============================================="
