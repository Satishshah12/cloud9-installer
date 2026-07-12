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

echo "Example:"
echo "sudo bash install.sh"

exit 1

fi



############################################
# CONFIGURATION
############################################


CLOUD9_CONTAINER="cloud9"

CLOUD9_PORT="8181"

PUBLIC_PORT="8000"

WORKSPACE="/root/workspace"

TIMEZONE="Asia/Jakarta"


AUTH_USER="viper"

AUTH_PASS="viperzone123@"


echo ""



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
# UPDATE
############################################


echo "[1/15] Updating system"


apt update -y

apt upgrade -y




############################################
# PACKAGE
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
gnupg \
lsb-release \
htop \
net-tools \
python3 \
python3-pip



############################################
# DOCKER
############################################


echo "[3/15] Installing Docker"



if ! command -v docker >/dev/null
then

curl -fsSL https://get.docker.com | bash

fi



systemctl enable docker

systemctl restart docker





############################################
# WORKSPACE
############################################


echo "[4/15] Creating workspace"


mkdir -p $WORKSPACE

chmod 777 $WORKSPACE





############################################
# REMOVE OLD
############################################


echo "[5/15] Removing old Cloud9"


docker rm -f $CLOUD9_CONTAINER >/dev/null 2>&1 || true





############################################
# CLOUD9
############################################


echo "[6/15] Installing Cloud9"



docker pull lscr.io/linuxserver/cloud9:latest



docker run -d \
--name $CLOUD9_CONTAINER \
-e PUID=0 \
-e PGID=0 \
-e TZ=$TIMEZONE \
-v $WORKSPACE:/code \
-p 127.0.0.1:$CLOUD9_PORT:8000 \
--restart unless-stopped \
lscr.io/linuxserver/cloud9:latest





############################################
# PHP
############################################


echo "[7/15] Installing PHP"



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
# NODE 20
############################################


echo "[8/15] Installing Node.js 20"



cd /tmp



wget -q \
https://nodejs.org/dist/v20.19.3/node-v20.19.3-linux-x64.tar.xz



tar xf node-v20.19.3-linux-x64.tar.xz



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


echo "[9/15] Installing Composer"



php -r "copy('https://getcomposer.org/installer','composer.php');"



php composer.php \
--install-dir=/usr/local/bin \
--filename=composer



rm composer.php



composer --version





############################################
# NGINX AUTH
############################################


echo "[10/15] Creating login"



htpasswd -bc \
/etc/nginx/cloud9.htpasswd \
$AUTH_USER \
$AUTH_PASS





############################################
# NGINX
############################################


echo "[11/15] Configuring Nginx"



cat > /etc/nginx/sites-available/cloud9 <<EOF


server {


listen $PUBLIC_PORT;


server_name _;



auth_basic "VIPER CLOUD9 LOGIN";


auth_basic_user_file /etc/nginx/cloud9.htpasswd;



large_client_header_buffers 4 32k;



location / {


proxy_pass http://127.0.0.1:$CLOUD9_PORT;



proxy_http_version 1.1;



proxy_set_header Upgrade \$http_upgrade;


proxy_set_header Connection "upgrade";



proxy_set_header Host \$host;


proxy_set_header X-Real-IP \$remote_addr;


proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;



proxy_read_timeout 3600;


proxy_send_timeout 3600;



proxy_buffering off;


proxy_request_buffering off;



}



}

EOF





rm -f /etc/nginx/sites-enabled/default



ln -s \
/etc/nginx/sites-available/cloud9 \
/etc/nginx/sites-enabled/cloud9





nginx -t



systemctl restart nginx






############################################
# FIREWALL
############################################


echo "[12/15] Firewall"



ufw allow ssh || true

ufw allow $PUBLIC_PORT/tcp || true






############################################
# CHECK
############################################


echo "[13/15] Checking"



sleep 20



if ! docker ps | grep cloud9 >/dev/null

then

echo "Cloud9 failed"

docker logs cloud9

exit 1

fi






############################################
# CLEAN
############################################


echo "[14/15] Cleaning"



rm -f /tmp/node-v20.19.3-linux-x64.tar.xz





############################################
# FINAL
############################################


echo "[15/15] Finished"



IP=$(curl -4 -s ifconfig.me)



echo ""

echo "=============================================="

echo "     VIPER CLOUD9 INSTALL SUCCESS"

echo "=============================================="



echo ""

echo "URL:"

echo "http://$IP:$PUBLIC_PORT"



echo ""

echo "LOGIN"

echo ""

echo "Username:"
echo "$AUTH_USER"



echo ""

echo "Password:"
echo "$AUTH_PASS"



echo ""

echo "Workspace:"
echo "$WORKSPACE"



echo ""

echo "Docker Port:"
echo "127.0.0.1:$CLOUD9_PORT"



echo ""

echo "=============================================="

echo "READY FOR DEVELOPMENT"

echo "=============================================="
