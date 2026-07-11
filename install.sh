#!/bin/bash

set -e

export DEBIAN_FRONTEND=noninteractive

clear

echo "=============================================="
echo "          VIPER CLOUD9 IDE INSTALLER"
echo "          NGINX AUTH EDITION"
echo "=============================================="
echo ""


############################################
# ROOT CHECK
############################################

if [ "$EUID" -ne 0 ]; then

echo "ERROR: Please run installer as root"
echo "Example:"
echo "curl -fsSL URL | sudo bash"

exit 1

fi



############################################
# UBUNTU CHECK
############################################


UBUNTU_VERSION=$(lsb_release -rs)


echo "Detected Ubuntu:"
echo $UBUNTU_VERSION



if [[ "$UBUNTU_VERSION" != "22.04" && "$UBUNTU_VERSION" != "24.04" ]]; then

echo "Unsupported Ubuntu version"

exit 1

fi




############################################
# CONFIGURATION
############################################


CONTAINER_NAME="cloud9"

PORT="8181"

CLOUD9_PORT="8000"

WORKSPACE="/root/workspace"

TIMEZONE="Asia/Jakarta"



# NGINX LOGIN

AUTH_USERNAME="viper"

AUTH_PASSWORD="viperzone123@"




############################################
# UPDATE SYSTEM
############################################


echo ""
echo "[1/12] Updating system..."


apt update -y

apt upgrade -y




############################################
# INSTALL DEPENDENCIES
############################################


echo ""
echo "[2/12] Installing dependencies..."


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
apache2-utils \
nginx




############################################
# FIREWALL
############################################


echo ""
echo "[3/12] Configuring firewall..."


ufw allow ${PORT}/tcp || true

iptables -I INPUT -p tcp --dport ${PORT} -j ACCEPT || true




############################################
# DOCKER INSTALL
############################################


echo ""
echo "[4/12] Installing Docker..."


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
echo "[5/12] Creating workspace..."


mkdir -p ${WORKSPACE}




############################################
# CREATE NGINX LOGIN
############################################


echo ""
echo "[6/12] Creating authentication..."


mkdir -p /etc/nginx/auth



htpasswd -bc \
/etc/nginx/auth/cloud9.htpasswd \
${AUTH_USERNAME} \
${AUTH_PASSWORD}




############################################
# REMOVE OLD CLOUD9
############################################


echo ""
echo "[7/12] Removing old Cloud9..."


docker rm -f ${CONTAINER_NAME} >/dev/null 2>&1 || true




############################################
# INSTALL CLOUD9
############################################


echo ""
echo "[8/12] Installing Cloud9 IDE..."


docker pull lscr.io/linuxserver/cloud9:latest



docker run -d \
--name ${CONTAINER_NAME} \
-e PUID=0 \
-e PGID=0 \
-e TZ=${TIMEZONE} \
-v ${WORKSPACE}:/code \
--restart unless-stopped \
lscr.io/linuxserver/cloud9:latest




echo ""

echo "Waiting Cloud9..."

sleep 20



if ! docker ps | grep ${CONTAINER_NAME} >/dev/null

then

echo "Cloud9 failed"

docker logs ${CONTAINER_NAME}

exit 1

fi




############################################
# NGINX REVERSE PROXY
############################################


echo ""
echo "[9/12] Configuring Nginx Proxy..."



cat > /etc/nginx/sites-available/cloud9 <<EOF

server {

listen ${PORT};


server_name _;


location / {


auth_basic "VIPER CLOUD9 LOGIN";

auth_basic_user_file /etc/nginx/auth/cloud9.htpasswd;


proxy_pass http://127.0.0.1:${CLOUD9_PORT};


proxy_http_version 1.1;


proxy_set_header Upgrade \$http_upgrade;

proxy_set_header Connection "upgrade";


proxy_set_header Host \$host;

proxy_set_header X-Real-IP \$remote_addr;


proxy_read_timeout 86400;


}

}

EOF



rm -f /etc/nginx/sites-enabled/default



ln -sf \
/etc/nginx/sites-available/cloud9 \
/etc/nginx/sites-enabled/cloud9



nginx -t


systemctl restart nginx

############################################
# DEVELOPMENT TOOLS
############################################


echo ""
echo "[10/12] Installing Development Tools..."



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
unzip \
nano \
vim

"



############################################
# NODE.JS 18 INSTALL
############################################


echo ""
echo "[11/12] Installing Node.js 18..."



docker exec ${CONTAINER_NAME} bash -c "


cd /tmp



curl -fsSL \
https://nodejs.org/dist/v18.20.8/node-v18.20.8-linux-x64.tar.xz \
-o node.tar.xz



tar -xf node.tar.xz



rm -rf /opt/nodejs



mv node-v18.20.8-linux-x64 /opt/nodejs



ln -sf /opt/nodejs/bin/node /usr/local/bin/node

ln -sf /opt/nodejs/bin/npm /usr/local/bin/npm

ln -sf /opt/nodejs/bin/npx /usr/local/bin/npx



node -v

npm -v



rm -f node.tar.xz


"




############################################
# COMPOSER
############################################


echo ""
echo "[12/12] Installing Composer..."



docker exec ${CONTAINER_NAME} bash -c "


php -r \"copy('https://getcomposer.org/installer','composer-setup.php');\"



php composer-setup.php \
--install-dir=/usr/local/bin \
--filename=composer



rm composer-setup.php



composer --version


"





############################################
# RESTART SERVICES
############################################


systemctl restart nginx

docker restart ${CONTAINER_NAME}




############################################
# FINAL INFORMATION
############################################


SERVER_IP=$(curl -4 -s ifconfig.me || hostname -I | awk '{print $1}')




clear


echo ""
echo "=============================================="
echo "       VIPER CLOUD9 INSTALL SUCCESS"
echo "=============================================="
echo ""


echo "Cloud9 URL:"
echo ""

echo "http://${SERVER_IP}:${PORT}"


echo ""

echo "=============================================="

echo "LOGIN INFORMATION"

echo "=============================================="


echo ""

echo "Username:"
echo "${AUTH_USERNAME}"


echo ""

echo "Password:"
echo "${AUTH_PASSWORD}"



echo ""

echo "=============================================="


echo "Workspace:"
echo "${WORKSPACE}"


echo ""

echo "Ubuntu:"
echo "${UBUNTU_VERSION}"


echo ""

echo "Node:"
echo "Node.js 18"



echo ""

echo "Container:"
echo "${CONTAINER_NAME}"


echo ""

echo "=============================================="

echo "       READY FOR DEVELOPMENT"

echo "=============================================="
