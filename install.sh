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

CLOUD9_PORT="8000"

NGINX_PORT="8000"

CLOUD9_PROXY_PORT="8001"


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
# CLEAN OLD INSTALL
############################################


echo "[1/16] Cleaning old configuration"



docker rm -f cloud9 >/dev/null 2>&1 || true


rm -f /etc/nginx/sites-enabled/cloud9

rm -f /etc/nginx/sites-available/cloud9


systemctl stop nginx || true



############################################
# UPDATE
############################################


echo "[2/16] Updating system"


apt update -y

apt upgrade -y




############################################
# PACKAGE
############################################


echo "[3/16] Installing packages"


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

htop \

net-tools \

python3 \

python3-pip




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
# CLOUD9
############################################


echo "[6/16] Installing Cloud9"



docker pull lscr.io/linuxserver/cloud9:latest




docker run -d \

--name $CLOUD9_CONTAINER \

-e PUID=0 \

-e PGID=0 \

-e TZ=$TIMEZONE \

-p 127.0.0.1:$CLOUD9_PROXY_PORT:8000 \

-v $WORKSPACE:/code \

--restart unless-stopped \

lscr.io/linuxserver/cloud9:latest





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
# NODE
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
# AUTH
############################################


echo "[10/16] Creating login"



rm -f /etc/nginx/cloud9.htpasswd



htpasswd -bc \

/etc/nginx/cloud9.htpasswd \

$AUTH_USER \

$AUTH_PASS





############################################
# NGINX
############################################


echo "[11/16] Configuring Nginx"



cat > /etc/nginx/sites-available/cloud9 <<EOF


server {


listen $NGINX_PORT;


server_name _;



auth_basic "VIPER CLOUD9 LOGIN";


auth_basic_user_file /etc/nginx/cloud9.htpasswd;




client_max_body_size 100M;


proxy_buffering off;


proxy_request_buffering off;




location / {



proxy_pass http://127.0.0.1:$CLOUD9_PROXY_PORT;



proxy_http_version 1.1;



proxy_set_header Host \$host;


proxy_set_header X-Real-IP \$remote_addr;


proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;



proxy_set_header Upgrade \$http_upgrade;


proxy_set_header Connection "upgrade";



proxy_read_timeout 86400;


proxy_send_timeout 86400;



}



}


EOF




ln -s /etc/nginx/sites-available/cloud9 \

/etc/nginx/sites-enabled/cloud9




nginx -t



systemctl restart nginx






############################################
# FIREWALL
############################################


echo "[12/16] Firewall"



ufw allow ssh || true


ufw allow $NGINX_PORT/tcp || true





############################################
# CHECK CLOUD9
############################################


echo "[13/16] Checking Cloud9"



sleep 15



if ! docker ps | grep cloud9 >/dev/null

then


docker logs cloud9


exit 1


fi





############################################
# CLEAN
############################################


echo "[14/16] Cleaning"



rm -f /tmp/node-v20.19.3-linux-x64.tar.xz





############################################
# STATUS
############################################


echo "[15/16] Checking service"



systemctl status nginx --no-pager | head -20



docker ps






############################################
# FINISH
############################################


echo "[16/16] COMPLETE"



IP=$(curl -4 -s ifconfig.me)



echo ""

echo "=============================================="

echo " VIPER CLOUD9 INSTALL SUCCESS "

echo "=============================================="

echo ""

echo "URL"

echo "http://$IP:$NGINX_PORT"


echo ""

echo "LOGIN"

echo "Username : $AUTH_USER"

echo "Password : $AUTH_PASS"


echo ""

echo "Workspace"

echo "$WORKSPACE"


echo ""

echo "Cloud9 Container"

echo "$CLOUD9_CONTAINER"



echo ""

echo "=============================================="

echo " READY FOR DEVELOPMENT "

echo "=============================================="
