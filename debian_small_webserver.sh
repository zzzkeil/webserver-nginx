#!/bin/bash


# visual text settings
RED="\e[31m"
GREEN="\e[32m"
GRAY="\e[37m"
YELLOW="\e[93m"

REDB="\e[41m"
GREENB="\e[42m"
GRAYB="\e[47m"
ENDCOLOR="\e[0m"


clear
echo -e " ${GRAYB}##############################################################################${ENDCOLOR}"
echo -e " ${GRAYB}#${ENDCOLOR} ${REDB}do not run this one --- its not finished :)  work in progress             ${ENDCOLOR}${GRAYB}#${ENDCOLOR}"
echo -e " ${GRAYB}#${ENDCOLOR} ${GREEN}test to create a small nginx webserver with letsencrypt                  ${ENDCOLOR}${GRAYB}#${ENDCOLOR}"
echo -e " ${GRAYB}##############################################################################${ENDCOLOR}"
echo -e " ${GRAYB}#${ENDCOLOR} ${GREEN}More information: https://github.com/zzzkeil/webserver-nginx             ${ENDCOLOR}${GRAYB}#${ENDCOLOR}"
echo -e " ${GRAYB}#${ENDCOLOR} ${YELLOW}Inspired by a script from  c-rieger.de  for nextcloud install           ${ENDCOLOR}${GRAYB}#${ENDCOLOR}"
echo -e " ${GRAYB}##############################################################################${ENDCOLOR}"
echo -e " ${GRAYB}#${ENDCOLOR}                 Version 2021.12.17 - changelog on github                   ${GRAYB}#${ENDCOLOR}"
echo -e " ${GRAYB}##############################################################################${ENDCOLOR}"
echo ""
echo ""
echo "To EXIT this script press  [ENTER]"
echo 
read -p "To RUN this script press  [Y]" -n 1 -r
echo
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    exit 1
fi
#
### root check
if [[ "$EUID" -ne 0 ]]; then
	echo "Sorry, you need to run this as root"
	exit 1
fi

#
### base_setup check
if [[ -e /root/base_setup.README ]]; then
     echo -e "base_setup script installed = ${GREEN}ok${ENDCOLOR}"
	 else
	 echo -e " ${YELLOW}Warning:${ENDCOLOR}"
	 echo -e " ${YELLOW}You need to install my base_setup script first!${ENDCOLOR}"
	 echo -e " ${YELLOW}Starting download base_setup.sh from my repository${ENDCOLOR}"
	 echo ""
	 echo ""
	 wget -O  base_setup.sh https://raw.githubusercontent.com/zzzkeil/base_setups/master/base_setup.sh
         chmod +x base_setup.sh
	 echo ""
	 echo ""
         echo -e " Now run ${YELLOW}./base_setup.sh${ENDCOLOR} manualy and reboot, then run this script again."
	 echo ""
	 echo ""
	 exit 1
fi


### check if Debian 11
. /etc/os-release
if [[ "$ID" = 'debian' ]]; then
   echo -e "OS ID check = ${GREEN}ok${ENDCOLOR}"
   else 
   echo -e "${RED}This script is only for Debian${ENDCOLOR}"
   exit 1
fi

if [[ "$VERSION_ID" = '11' ]]; then
   echo -e "OS Versions check = ${GREEN}ok${ENDCOLOR}"
   else
   echo -e "${RED}Only Debian 11 supported ${ENDCOLOR}"

   exit 1
fi



ufw allow 80/tcp
ufw allow 443/tcp


###global function to update and cleanup the environment
function update_and_clean() {
apt update
apt upgrade -y
apt autoclean -y
apt autoremove -y
}

### START ###
apt install gnupg2 -y 

curl https://nginx.org/keys/nginx_signing.key | gpg --dearmor \
    | sudo tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null

gpg --dry-run --quiet --import --import-options import-show /usr/share/keyrings/nginx-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] \
http://nginx.org/packages/debian `lsb_release -cs` nginx" \
    | sudo tee /etc/apt/sources.list.d/nginx.list

echo -e "Package: *\nPin: origin nginx.org\nPin: release o=nginx\nPin-Priority: 900\n" \
    | sudo tee /etc/apt/preferences.d/99nginx




#update_and_clean
#apt install software-properties-common zip unzip screen git libfile-fcntllock-perl locate ghostscript tree -y
#apt install screen git libfile-fcntllock-perl locate -y


###instal NGINX using TLSv1.3, OpenSSL 1.1.1
update_and_clean
apt install nginx certbot python3-certbot -y

###enable NGINX autostart
systemctl enable nginx.service

### prepare the NGINX
mv /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak && touch /etc/nginx/nginx.conf
echo "user www-data;
worker_processes auto;
pid /var/run/nginx.pid;
events {
worker_connections 1024;
multi_accept on;
use epoll;
}
http {
server_names_hash_bucket_size 64;
set_real_ip_from 127.0.0.1;
real_ip_header X-Forwarded-For;
real_ip_recursive on;
include /etc/nginx/mime.types;
#include /etc/nginx/proxy.conf;
#include /etc/nginx/ssl.conf;
#include /etc/nginx/header.conf;
#include /etc/nginx/optimization.conf;
default_type application/octet-stream;
access_log /var/log/nginx/access.log;
error_log /var/log/nginx/error.log warn;
sendfile on;
send_timeout 3600;
tcp_nopush on;
tcp_nodelay on;
open_file_cache max=500 inactive=10m;
open_file_cache_errors on;
keepalive_timeout 65;
reset_timedout_connection on;
server_tokens off;
resolver 127.0.0.53 valid=30s;
resolver_timeout 5s;
include /etc/nginx/conf.d/*.conf;
}
" > /etc/nginx/nginx.conf

###create folders
mkdir -p /var/www/letsencrypt /etc/letsencrypt/rsa-certs /etc/letsencrypt/ecc-certs

###apply permissions
chown -R www-data:www-data /var/www


###restart NGINX
/usr/sbin/service nginx restart

###install self signed certificates
apt install ssl-cert -y

###prepare NGINX for Site and SSL
[ -f /etc/nginx/conf.d/default.conf ] && mv /etc/nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf.bak
touch /etc/nginx/conf.d/default.conf

###create a Let's Encrypt vhost file
touch /etc/nginx/conf.d/letsencrypt.conf
echo "server
{
server_name 127.0.0.1;
listen 127.0.0.1:81 default_server;
charset utf-8;
location ^~ /.well-known/acme-challenge
{
default_type text/plain;
root /var/www/letsencrypt;
}
}
" > /etc/nginx/conf.d/letsencrypt.conf


###create a ssl configuration file
echo "ssl_dhparam /etc/ssl/certs/dhparam.pem;
ssl_session_timeout 1d;
ssl_session_cache shared:SSL:50m;
ssl_session_tickets off;
ssl_protocols TLSv1.3;
ssl_ciphers 'TLS-CHACHA20-POLY1305-SHA256:TLS-AES-256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384'; #:ECDHE-RSA-AES256-SHA384';
ssl_ecdh_curve X448:secp521r1:secp384r1:prime256v1;
ssl_prefer_server_ciphers on;
ssl_stapling on;
ssl_stapling_verify on;
#
ssl_certificate /etc/ssl/certs/ssl-cert-snakeoil.pem;
ssl_certificate_key /etc/ssl/private/ssl-cert-snakeoil.key;
ssl_trusted_certificate /etc/ssl/certs/ssl-cert-snakeoil.pem;
" > /etc/nginx/ssl.conf

###add a default dhparam.pem file // https://wiki.mozilla.org/Security/Server_Side_TLS#ffdhe4096

openssl dhparam -out /etc/ssl/certs/dhparam.pem 4096


###create a proxy configuration file
echo "proxy_set_header Host \$host;
proxy_set_header X-Real-IP \$remote_addr;
proxy_set_header X-Forwarded-Host \$host;
proxy_set_header X-Forwarded-Protocol \$scheme;
proxy_set_header X-Forwarded-For \$remote_addr;
proxy_set_header X-Forwarded-Port \$server_port;
proxy_set_header X-Forwarded-Server \$host;
proxy_connect_timeout 3600;
proxy_send_timeout 3600;
proxy_read_timeout 3600;
proxy_redirect off;
"  > /etc/nginx/proxy.conf


###create a header configuration file
echo 'add_header Strict-Transport-Security "max-age=15768000; includeSubDomains; preload;";
add_header X-Robots-Tag none; add_header X-Download-Options noopen;
add_header X-Permitted-Cross-Domain-Policies none;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "no-referrer" always;
add_header X-Frame-Options "SAMEORIGIN";
'  > /etc/nginx/header.conf


###create a nginx optimization file
echo 'fastcgi_hide_header X-Powered-By;
fastcgi_read_timeout 3600;
fastcgi_send_timeout 3600;
fastcgi_connect_timeout 3600;
fastcgi_buffers 64 64K;
fastcgi_buffer_size 256k;
fastcgi_busy_buffers_size 3840K;
fastcgi_cache_key \$http_cookie\$request_method\$host\$request_uri;
fastcgi_cache_use_stale error timeout invalid_header http_500;
fastcgi_ignore_headers Cache-Control Expires Set-Cookie;
gzip on;
gzip_vary on;
gzip_comp_level 4;
gzip_min_length 256;
gzip_proxied expired no-cache no-store private no_last_modified no_etag auth;
gzip_types application/atom+xml application/javascript application/json application/ld+json application/manifest+json application/rss+xml application/vnd.geo+json application/vnd.ms-fontobject application/x-font-ttf application/x-web-app-manifest+json application/xhtml+xml application/xml font/opentype image/bmp image/svg+xml image/x-icon text/cache-manifest text/css text/plain text/vcard text/vnd.rim.location.xloc text/vtt text/x-component text/x-cross-domain-policy;
gzip_disable "MSIE [1-6]\.";
' > /etc/nginx/optimization.conf



###enable all nginx configuration files
sed -i s/\#\include/\include/g /etc/nginx/nginx.conf


###restart NGINX
/usr/sbin/service nginx restart


cd
wget -O  add_small_website.sh https://raw.githubusercontent.com/zzzkeil/webserver-nginx/master/add_small_website.sh
chmod +x add_small_website.sh


clear
echo " ##############################################################################"
echo " ##############################################################################"
echo " To add your first website run ./add_small_website.sh "
echo " ##############################################################################"
echo " ##############################################################################"

### CleanUp
cat /dev/null > ~/.bash_history && history -c && history -w
exit 0
