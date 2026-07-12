#!/bin/bash

set -e

export DEBIAN_FRONTEND=noninteractive

clear


echo "=============================================="
echo "        VIPER CLOUD9 FULL INSTALLER"
echo "        DEVELOPMENT EDITION"
echo "=============================================="



############################################
# ROOT CHECK
############################################


if [ "$EUID" -ne 0 ]; then

echo "Run as root"

echo "sudo bash install.sh"

exit 1

fi




############################################
# CONFIG
############################################


CONTAINER_NAME="cloud9"

PORT="8000"

INTERNAL_PORT="9000"

WORKSPACE="/root/workspace"

TIMEZONE="Asia/Jakarta"


AUTH_USER="viper"

AUTH_PASS="viperzone123@"




############################################
# SYSTEM UPDATE
############################################


echo "[1/15] Updating system"


apt update -y

apt upgrade -y




############################################
# BASIC PACKAGE
############################################


echo "[2/15] Installing packages"


apt install -y \

curl \
wget \
git \
zip \
unzip \
nano \
vim \
openssl \
ca-certificates \
nginx \
apache2-utils \
ufw \
software-properties-common




############################################
# DOCKER
############################################


echo "[3/15] Installing Docker"



if ! command -v docker >/dev/null 2>&1

then

curl -fsSL https://get.docker.com | bash

fi



systemctl enable docker

systemctl start docker





############################################
# FIREWALL
############################################


echo "[4/15] Firewall"


ufw allow ${PORT}/tcp || true




############################################
# WORKSPACE
############################################


echo "[5/15] Workspace"


mkdir -p ${WORKSPACE}





############################################
# REMOVE OLD CLOUD9
############################################


echo "[6/15] Cleaning old Cloud9"


docker rm -f ${CONTAINER_NAME} >/dev/null 2>&1 || true





############################################
# CLOUD9 CONTAINER
############################################


echo "[7/15] Installing Cloud9"



docker pull lscr.io/linuxserver/cloud9:latest



docker run -d \

--name ${CONTAINER_NAME} \

-e PUID=0 \

-e PGID=0 \

-e TZ=${TIMEZONE} \

-p 127.0.0.1:${INTERNAL_PORT}:8000 \

-v ${WORKSPACE}:/code \

--restart unless-stopped \

lscr.io/linuxserver/cloud9:latest




sleep 15






############################################
# NGINX LOGIN
############################################


echo "[8/15] Installing Login Protection"



mkdir -p /etc/nginx/auth



htpasswd -bc \

/etc/nginx/auth/cloud9.htpasswd \

${AUTH_USER} \

${AUTH_PASS}





cat > /etc/nginx/sites-available/cloud9 <<EOF


server {


listen ${PORT};


server_name _;



auth_basic "VIPER CLOUD9 LOGIN";

auth_basic_user_file /etc/nginx/auth/cloud9.htpasswd;



location / {



proxy_pass http://127.0.0.1:${INTERNAL_PORT};



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
# DEV TOOLS
############################################


echo "[9/15] Installing PHP Python Git"



docker exec ${CONTAINER_NAME} bash -c "


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
# NODE JS 18
############################################


echo "[10/15] Installing Node.js 18"



docker exec ${CONTAINER_NAME} bash -c "


cd /tmp



curl -L \

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



rm node.tar.xz



"







############################################
# COMPOSER
############################################


echo "[11/15] Installing Composer"



docker exec ${CONTAINER_NAME} bash -c "


php -r \"copy('https://getcomposer.org/installer','composer.php');\"


php composer.php \

--install-dir=/usr/local/bin \

--filename=composer



rm composer.php



composer --version



"







############################################
# VERIFY
############################################


echo "[12/15] Checking Installation"



docker exec ${CONTAINER_NAME} bash -c "

echo PHP:

php -v | head -1


echo Node:

node -v


echo NPM:

npm -v


echo Python:

python3 --version


echo Composer:

composer --version


"






############################################
# RESTART
############################################


echo "[13/15] Restart Services"


systemctl restart nginx

docker restart ${CONTAINER_NAME}






############################################
# FINAL
############################################


echo "[14/15] Finalizing"


IP=$(curl -4 -s ifconfig.me)





clear



echo ""
echo "=============================================="
echo "      VIPER CLOUD9 INSTALL SUCCESS"
echo "=============================================="

echo ""

echo "URL:"
echo ""

echo "http://${IP}:8000"



echo ""

echo "LOGIN"

echo ""

echo "Username:"
echo "${AUTH_USER}"

echo ""

echo "Password:"
echo "${AUTH_PASS}"



echo ""

echo "Workspace:"
echo "${WORKSPACE}"



echo ""

echo "Installed:"

echo "- Cloud9 IDE"

echo "- PHP"

echo "- Composer"

echo "- Node.js 18"

echo "- NPM"

echo "- Python3"

echo "- Git"



echo ""

echo "=============================================="

echo "READY FOR DEVELOPMENT"

echo "=============================================="
