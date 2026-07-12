#!/bin/bash

set -e

export DEBIAN_FRONTEND=noninteractive


clear


echo "=============================================="
echo "        VIPER CLOUD9 FULL INSTALLER"
echo "        UBUNTU 24.04 DEVELOPMENT EDITION"
echo "=============================================="



############################################
# ROOT CHECK
############################################

if [ "$EUID" -ne 0 ]; then

echo "ERROR: Run as root"

exit 1

fi



############################################
# VARIABLES
############################################


CLOUD9_CONTAINER="cloud9"

PUBLIC_PORT="8000"

CLOUD9_PORT="8001"

WORKSPACE="/root/workspace"

TIMEZONE="Asia/Jakarta"


AUTH_USER="viper"

AUTH_PASS="viperzone123@"



############################################
# UBUNTU CHECK
############################################


VERSION=$(lsb_release -rs)


echo "Ubuntu Version: $VERSION"


if [[ "$VERSION" != "24.04" ]]; then

echo "Only Ubuntu 24.04 supported"

exit 1

fi





############################################
# CLEAN OLD CONFIG
############################################


echo "[1/16] Cleaning old configuration"



rm -f /etc/nginx/sites-enabled/cloud9

rm -f /etc/nginx/sites-available/cloud9

rm -f /etc/nginx/cloud9.htpasswd



docker rm -f cloud9 >/dev/null 2>&1 || true



############################################
# UPDATE SYSTEM
############################################


echo "[2/16] Updating system"



apt update -y

apt upgrade -y




############################################
# INSTALL PACKAGE
############################################


echo "[3/16] Installing packages"


PACKAGES="
curl
wget
git
zip
unzip
nano
vim
openssl
ca-certificates
nginx
apache2-utils
ufw
python3
python3-pip
net-tools
htop
"


for pkg in $PACKAGES
do

apt install -y $pkg

done





############################################
# DOCKER
############################################


echo "[4/16] Installing Docker"



if ! command -v docker >/dev/null

then

curl -fsSL https://get.docker.com | bash

fi



systemctl enable docker

systemctl restart docker





############################################
# WORKSPACE
############################################


echo "[5/16] Creating workspace"



mkdir -p $WORKSPACE

chmod 777 $WORKSPACE





############################################
# CLOUD9 INSTALL
############################################


echo "[6/16] Installing Cloud9"



docker pull lscr.io/linuxserver/cloud9:latest



docker run -d \

--name $CLOUD9_CONTAINER \

-e PUID=0 \

-e PGID=0 \

-e TZ=$TIMEZONE \

-p 127.0.0.1:$CLOUD9_PORT:8000 \

-v $WORKSPACE:/code \

--restart unless-stopped \

lscr.io/linuxserver/cloud9:latest





############################################
# WAIT CLOUD9
############################################


echo "Waiting Cloud9..."

sleep 15



if ! curl -I http://127.0.0.1:$CLOUD9_PORT >/dev/null 2>&1

then


echo "Cloud9 failed"

docker logs cloud9

exit 1


fi





############################################
# PHP
############################################


echo "[7/16] Installing PHP 8.3"



apt install -y \

php \

php-cli \

php-curl \

php-mbstring \

php-xml \

php-zip \

php-mysql



php -v






############################################
# NODE JS
############################################


echo "[8/16] Installing Node.js 20"



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





############################################
# COMPOSER
############################################


echo "[9/16] Installing Composer"



php -r "copy('https://getcomposer.org/installer','composer.php');"



php composer.php \

--install-dir=/usr/local/bin \

--filename=composer



rm composer.php



composer --version






############################################
# BASIC AUTH
############################################


echo "[10/16] Creating Login"



htpasswd -bc \

/etc/nginx/cloud9.htpasswd \

$AUTH_USER \

$AUTH_PASS





############################################
# NGINX CONFIG
############################################


echo "[11/16] Configuring Nginx"



cat > /etc/nginx/sites-available/cloud9 <<EOF


server {


listen $PUBLIC_PORT;


server_name _;



auth_basic "VIPER CLOUD9 LOGIN";


auth_basic_user_file /etc/nginx/cloud9.htpasswd;



location / {


proxy_pass http://127.0.0.1:$CLOUD9_PORT;



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






############################################
# ENABLE NGINX
############################################


echo "[12/16] Enabling nginx"



rm -f /etc/nginx/sites-enabled/default



ln -sf \

/etc/nginx/sites-available/cloud9 \

/etc/nginx/sites-enabled/cloud9





nginx -t



systemctl restart nginx






############################################
# FIREWALL
############################################


echo "[13/16] Firewall"



ufw allow ssh || true

ufw allow $PUBLIC_PORT/tcp || true






############################################
# TEST
############################################


echo "[14/16] Testing"



systemctl status nginx --no-pager || true



docker ps





############################################
# CLEAN
############################################


echo "[15/16] Cleaning"



rm -f /tmp/node-v20.19.3-linux-x64.tar.xz





############################################
# FINAL
############################################


echo "[16/16] Finished"



IP=$(curl -4 -s ifconfig.me)



echo ""

echo "=============================================="

echo "     VIPER CLOUD9 INSTALL SUCCESS"

echo "=============================================="

echo ""

echo "URL"

echo "http://$IP:$PUBLIC_PORT"


echo ""

echo "LOGIN"

echo "Username : $AUTH_USER"

echo "Password : $AUTH_PASS"


echo ""

echo "Cloud9 Backend"

echo "127.0.0.1:$CLOUD9_PORT"



echo ""

echo "Workspace"

echo "$WORKSPACE"


echo ""

echo "=============================================="

echo "READY FOR DEVELOPMENT"

echo "=============================================="
