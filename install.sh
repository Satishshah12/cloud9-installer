#!/bin/bash

set -e

export DEBIAN_FRONTEND=noninteractive

clear

echo "=============================================="
echo "        VIPER CLOUD9 SUPER INSTALLER"
echo "        UBUNTU 24.04 EDITION"
echo "=============================================="


if [ "$EUID" -ne 0 ]; then
    echo "Run as root"
    exit 1
fi


################################
# CONFIG
################################

CONTAINER="cloud9"

PUBLIC_PORT="8000"

INTERNAL_PORT="8001"

WORKSPACE="/root/workspace"

AUTH_USER="viper"

AUTH_PASS="viperzone123@"


################################
# CHECK UBUNTU
################################

UBUNTU=$(lsb_release -rs)

echo "Ubuntu : $UBUNTU"


if [ "$UBUNTU" != "24.04" ]; then
    echo "Only Ubuntu 24.04 supported"
    exit 1
fi



################################
# CLEAN
################################

echo "[1/14] Cleaning old setup"


docker rm -f $CONTAINER >/dev/null 2>&1 || true


rm -f /etc/nginx/sites-enabled/cloud9

rm -f /etc/nginx/sites-available/cloud9



################################
# UPDATE
################################


echo "[2/14] Update system"


apt update -y

apt upgrade -y



################################
# PACKAGES
################################


echo "[3/14] Install packages"


apt install -y curl wget git zip unzip nano vim openssl ca-certificates nginx apache2-utils ufw python3 python3-pip htop net-tools



################################
# DOCKER
################################


echo "[4/14] Install Docker"


if ! command -v docker >/dev/null 2>&1
then

curl -fsSL https://get.docker.com | bash

fi


systemctl enable docker

systemctl start docker



################################
# WORKSPACE
################################


echo "[5/14] Workspace"


mkdir -p $WORKSPACE

chmod 777 $WORKSPACE



################################
# CLOUD9
################################


echo "[6/14] Cloud9"


docker pull lscr.io/linuxserver/cloud9:latest


docker run -d \
--name $CONTAINER \
-e PUID=0 \
-e PGID=0 \
-e TZ=Asia/Jakarta \
-p 127.0.0.1:$INTERNAL_PORT:8000 \
-v $WORKSPACE:/code \
--restart unless-stopped \
lscr.io/linuxserver/cloud9:latest




################################
# PHP
################################


echo "[7/14] PHP 8.3"


apt install -y php php-cli php-curl php-mbstring php-xml php-zip php-mysql


php -v




################################
# NODE
################################


echo "[8/14] Node.js 20"


cd /tmp


wget -q https://nodejs.org/dist/v20.19.3/node-v20.19.3-linux-x64.tar.xz


tar -xf node-v20.19.3-linux-x64.tar.xz


rm -rf /opt/node20


mv node-v20.19.3-linux-x64 /opt/node20


ln -sf /opt/node20/bin/node /usr/local/bin/node

ln -sf /opt/node20/bin/npm /usr/local/bin/npm

ln -sf /opt/node20/bin/npx /usr/local/bin/npx


node -v

npm -v



################################
# COMPOSER
################################


echo "[9/14] Composer"


php -r "copy('https://getcomposer.org/installer','composer-installer.php');"


php composer-installer.php --install-dir=/usr/local/bin --filename=composer


rm composer-installer.php


composer --version




################################
# NGINX AUTH
################################


echo "[10/14] Login protection"



htpasswd -bc \
/etc/nginx/cloud9.htpasswd \
$viper \
$AUTH_PASS 2>/dev/null || true



htpasswd -bc /etc/nginx/cloud9.htpasswd $AUTH_USER $AUTH_PASS





################################
# NGINX CONFIG
################################


echo "[11/14] Nginx"


cat > /etc/nginx/sites-available/cloud9 <<EOF

server {

listen $PUBLIC_PORT;

server_name _;


auth_basic "VIPER CLOUD9";

auth_basic_user_file /etc/nginx/cloud9.htpasswd;


client_max_body_size 200M;


location / {


proxy_pass http://127.0.0.1:$INTERNAL_PORT;


proxy_http_version 1.1;


proxy_set_header Upgrade \$http_upgrade;

proxy_set_header Connection "upgrade";


proxy_set_header Host \$host;

proxy_set_header X-Real-IP \$remote_addr;

proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;


proxy_read_timeout 86400;


}

}

EOF



rm -f /etc/nginx/sites-enabled/default


ln -sf /etc/nginx/sites-available/cloud9 /etc/nginx/sites-enabled/cloud9


nginx -t


systemctl restart nginx




################################
# FIREWALL
################################


echo "[12/14] Firewall"


ufw allow ssh || true

ufw allow $PUBLIC_PORT/tcp || true




################################
# CHECK
################################


echo "[13/14] Checking"


sleep 10


docker ps | grep cloud9


systemctl status nginx --no-pager | head -10




################################
# FINISH
################################


echo "[14/14] DONE"


IP=$(curl -4 -s ifconfig.me)



echo ""
echo "=============================================="
echo " VIPER CLOUD9 READY "
echo "=============================================="
echo ""

echo "URL:"
echo "http://$IP:$PUBLIC_PORT"

echo ""

echo "USERNAME:"
echo "$AUTH_USER"

echo ""

echo "PASSWORD:"
echo "$AUTH_PASS"

echo ""

echo "WORKSPACE:"
echo "$WORKSPACE"

echo ""

echo "=============================================="
