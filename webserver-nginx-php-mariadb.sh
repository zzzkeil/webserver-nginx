#!/bin/bash
clear
echo " ##############################################################################"
echo " ##############################################################################"
echo " 2021.02.19 16:55  "
echo " this is a test, do not run this script now ITS NOT READY !  "
echo " check script status here : "
echo " https://github.com/zzzkeil/webserver-nginx "
echo " # Inspired by a script from  c-rieger.de  for nextcloud install #"
echo " ##############################################################################"
echo " ##############################################################################"

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
     echo "base_setup script installed - OK"
	 else
	 wget -O  base_setup.sh https://raw.githubusercontent.com/zzzkeil/base_setups/master/base_setup.sh
         chmod +x base_setup.sh
	 echo ""
	 echo ""
	 echo " Attention !!! "
	 echo " My base_setup script not installed,"
         echo " you have to run ./base_setup.sh manualy now and reboot, after that you can run this script again."
	 echo ""
	 echo ""
	 exit 1
fi
#
### OS version check
if [[ -e /etc/debian_version ]]; then
      echo "Debian Distribution"
      else
      echo "This is not a Debian Distribution."
      exit 1
fi

wget -O  add_website.sh https://raw.githubusercontent.com/zzzkeil/webserver-nginx/master/add_website.sh
chmod +x add_website.sh
wget -O  add_database.sh https://raw.githubusercontent.com/zzzkeil/webserver-nginx/master/add_database.sh
chmod +x add_database.sh

uri=$uri
read -p "sitename: " -e -i your.domain servername
randomkey1=$(date +%s | cut -c 3-)
read -p "sql databasename: " -e -i db$randomkey1 databasename
read -p "sql databaseuser: " -e -i dbuser$randomkey1 databaseuser
randomkey2=$(</dev/urandom tr -dc 'A-Za-z0-9.:_' | head -c 12  ; echo)
read -p "sql databaseuserpasswd: " -e -i $randomkey2 databaseuserpasswd
echo "
$servername
databasename : $databasename
databaseuser : $databaseuser
databaseuserpasswd : $databaseuserpasswd
#
" >> /root/mysql_database_list.txt
ufw allow 80/tcp
ufw allow 443/tcp

###global function to update and cleanup the environment
function update_and_clean() {
apt update
apt upgrade -y
apt autoclean -y
apt autoremove -y
}
###
function copy4SSL() {
cp /etc/nginx/conf.d/$servername.conf /etc/nginx/conf.d/$servername.conf.orig
cp /etc/nginx/ssl.conf /etc/nginx/ssl.conf.orig
}
###
function errorSSL() {

echo "!!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!!"
echo "*** ERROR while requesting your certificate(s) ***"
echo ""
echo "Verify that both ports (80 + 443) are forwarded to this server!"
echo "And verify, your dyndns points to your IP either!"
echo "Then retry..."
echo "!!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!!"
echo ""
}
### START ###
apt install gnupg gnupg2 lsb-release wget curl -y
###prepare the server environment
cd /etc/apt/sources.list.d
echo "deb [arch=amd64,arm64] http://ppa.launchpad.net/ondrej/php/ubuntu $(lsb_release -cs) main" | tee php.list
echo "deb [arch=amd64,arm64] http://nginx.org/packages/mainline/ubuntu $(lsb_release -cs) nginx" | tee nginx.list
echo "deb [arch=amd64,arm64] http://ftp.hosteurope.de/mirror/mariadb.org/repo/10.5/ubuntu $(lsb_release -cs) main" | tee mariadb.list
###
curl -fsSL https://nginx.org/keys/nginx_signing.key | sudo apt-key add -
apt-key adv --recv-keys --keyserver hkps://keyserver.ubuntu.com:443 4F4EA0AAE5267A6C
apt-key adv --recv-keys --keyserver hkps://keyserver.ubuntu.com:443 0xF1656F24C74CD1D8
update_and_clean
apt install software-properties-common zip unzip screen git wget ffmpeg libfile-fcntllock-perl locate ghostscript tree htop -y
#apt remove nginx nginx-common nginx-full -y --allow-change-held-packages
###instal NGINX using TLSv1.3, OpenSSL 1.1.1
update_and_clean
apt install nginx certbot -y
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
upstream php-handler {
server unix:/run/php/php8.0-fpm.sock;
}
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
###restart NGINX
/usr/sbin/service nginx restart
###create folders
mkdir -p /var/www/$servername/
mkdir -p /var/www/letsencrypt /etc/letsencrypt/rsa-certs /etc/letsencrypt/ecc-certs
###create temp html and php file
echo "<html><body><center>test HTML file</center></body></html>" >> /var/www/$servername/index.html
echo "<?php
phpinfo();
?>" >> /var/www/$servername/info.php
###apply permissions
chown -R www-data:www-data /var/www
###install PHP - Backup default files





## Baustelle
apt install php8.0-fpm php8.0-curl php8.0-common php8.0-mbstring php8.0-mysql php8.0-imagick php8.0-xml php8.0-zip php8.0-gd php8.0-xml php8.0-intl php8.0-bz2 php8.0-ldap php-apcu imagemagick -y
## Baustelle







###PHP Mods: cli/php.ini
sed -i "s/output_buffering =.*/output_buffering = 'Off'/" /etc/php/8.0/cli/php.ini
sed -i "s/max_execution_time =.*/max_execution_time = 3600/" /etc/php/8.0/cli/php.ini
sed -i "s/max_input_time =.*/max_input_time = 3600/" /etc/php/8.0/cli/php.ini
sed -i "s/post_max_size =.*/post_max_size = 10240M/" /etc/php/8.0/cli/php.ini
sed -i "s/upload_max_filesize =.*/upload_max_filesize = 10240M/" /etc/php/8.0/cli/php.ini
sed -i "s/;date.timezone.*/date.timezone = Europe\/\Berlin/" /etc/php/8.0/cli/php.ini
###PHP Mods: fpm/php.ini
sed -i "s/memory_limit = 128M/memory_limit = 512M/" /etc/php/8.0/fpm/php.ini
sed -i "s/output_buffering =.*/output_buffering = 'Off'/" /etc/php/8.0/fpm/php.ini
sed -i "s/max_execution_time =.*/max_execution_time = 3600/" /etc/php/8.0/fpm/php.ini
sed -i "s/max_input_time =.*/max_input_time = 3600/" /etc/php/8.0/fpm/php.ini
sed -i "s/post_max_size =.*/post_max_size = 10240M/" /etc/php/8.0/fpm/php.ini
sed -i "s/upload_max_filesize =.*/upload_max_filesize = 10240M/" /etc/php/8.0/fpm/php.ini
sed -i "s/;date.timezone.*/date.timezone = Europe\/\Berlin/" /etc/php/8.0/fpm/php.ini
sed -i "s/;session.cookie_secure.*/session.cookie_secure = True/" /etc/php/8.0/fpm/php.ini
sed -i "s/;opcache.enable=.*/opcache.enable=1/" /etc/php/8.0/fpm/php.ini
sed -i "s/;opcache.enable_cli=.*/opcache.enable_cli=1/" /etc/php/8.0/fpm/php.ini
sed -i "s/;opcache.memory_consumption=.*/opcache.memory_consumption=128/" /etc/php/8.0/fpm/php.ini
sed -i "s/;opcache.interned_strings_buffer=.*/opcache.interned_strings_buffer=8/" /etc/php/8.0/fpm/php.ini
sed -i "s/;opcache.max_accelerated_files=.*/opcache.max_accelerated_files=10000/" /etc/php/8.0/fpm/php.ini
sed -i "s/;opcache.revalidate_freq=.*/opcache.revalidate_freq=1/" /etc/php/8.0/fpm/php.ini
sed -i "s/;opcache.save_comments=.*/opcache.save_comments=1/" /etc/php/8.0/fpm/php.ini
sed -i "$aapc.enable_cli=1" /etc/php/8.0/mods-available/apcu.ini

###restart PHP and NGINX
/usr/sbin/service php8.0-fpm restart
/usr/sbin/service nginx restart
###install MariaDB
apt update && apt install mariadb-server -y
/usr/sbin/service mysql stop
###configure MariaDB
mv /etc/mysql/my.cnf /etc/mysql/my.cnf.bak
echo "[client]
default-character-set = utf8mb4
port = 3306
[mysqld_safe]
log_error=/var/log/mysql/mysql_error.log
nice = 0
socket = /var/run/mysqld/mysqld.sock
[mysqld]
basedir = /usr
bind-address = 127.0.0.1
binlog_format = ROW
bulk_insert_buffer_size = 16M
character-set-server = utf8mb4
collation-server = utf8mb4_general_ci
concurrent_insert = 2
connect_timeout = 5
datadir = /var/lib/mysql
default_storage_engine = InnoDB
expire_logs_days = 10
general_log_file = /var/log/mysql/mysql.log
general_log = 0
innodb_buffer_pool_size = 1024M
innodb_buffer_pool_instances = 1
innodb_flush_log_at_trx_commit = 2
innodb_log_buffer_size = 32M
innodb_max_dirty_pages_pct = 90
innodb_file_per_table = 1
innodb_open_files = 400
innodb_io_capacity = 4000
innodb_flush_method = O_DIRECT
key_buffer_size = 128M
lc_messages_dir = /usr/share/mysql
lc_messages = en_US
log_bin = /var/log/mysql/mariadb-bin
log_bin_index = /var/log/mysql/mariadb-bin.index
log_error = /var/log/mysql/mysql_error.log
log_slow_verbosity = query_plan
log_warnings = 2
long_query_time = 1
max_allowed_packet = 16M
max_binlog_size = 100M
max_connections = 200
max_heap_table_size = 64M
myisam_recover_options = BACKUP
myisam_sort_buffer_size = 512M
port = 3306
pid-file = /var/run/mysqld/mysqld.pid
query_cache_limit = 2M
query_cache_size = 64M
query_cache_type = 1
query_cache_min_res_unit = 2k
read_buffer_size = 2M
read_rnd_buffer_size = 1M
skip-external-locking
skip-name-resolve
slow_query_log_file = /var/log/mysql/mariadb-slow.log
slow-query-log = 1
socket = /var/run/mysqld/mysqld.sock
sort_buffer_size = 4M
table_open_cache = 400
thread_cache_size = 128
tmp_table_size = 64M
tmpdir = /tmp
transaction_isolation = READ-COMMITTED
user = mysql
wait_timeout = 600
[mysqldump]
max_allowed_packet = 16M
quick
quote-names
[isamchk]
key_buffer = 16M
" > /etc/mysql/my.cnf
/usr/sbin/service mysql restart
###restart MariaDB server and connect to MariaDB to create the database
/usr/sbin/service mysql restart && mysql -uroot <<EOF
CREATE DATABASE $databasename CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE USER $databaseuser@localhost identified by '$databaseuserpasswd';
GRANT ALL PRIVILEGES on $databasename.* to $databaseuser@localhost;
FLUSH privileges;
EOF
clear
echo ""
echo " Your database server will now be hardened - just follow the instructions."
echo " Keep in mind: your MariaDB root password is still NOT set!"
echo ""
###harden your MariDB server
mysql_secure_installation
update_and_clean
###install self signed certificates
apt install ssl-cert -y
###prepare NGINX for Site and SSL
[ -f /etc/nginx/conf.d/default.conf ] && mv /etc/nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf.bak
touch /etc/nginx/conf.d/default.conf
touch /etc/nginx/conf.d/$servername.conf
cat <<EOF >/etc/nginx/conf.d/$servername.conf
server {
server_name $servername www.$servername;
listen 80;
listen [::]:80;
location ^~ /.well-known/acme-challenge {
proxy_pass http://127.0.0.1:81;
proxy_set_header Host \$host;
}
location / {
return 301 https://\$host\$request_uri;
}
}
server {
server_name $servername www.$servername;
listen 443 ssl http2;
listen [::]:443 ssl http2;
root /var/www/$servername;
index index.php index.html index.htm;
location / {
		try_files $uri $uri/ =404;
	}
location ~ \.php$ {
    include /etc/nginx/fastcgi_params;
    fastcgi_pass unix:/run/php/php8.0-fpm.sock;
    fastcgi_index index.php;
    fastcgi_param SCRIPT_FILENAME var/www/$servername/\$fastcgi_script_name;
}
# letsencrypt for $servername
#ssl_certificate /etc/letsencrypt/live/$servername/fullchain.pem;
#ssl_certificate_key /etc/letsencrypt/live/$servername/privkey.pem;
#ssl_trusted_certificate /etc/letsencrypt/live/$servername/chain.pem;
#
# logs
access_log /var/log/nginx/$servername.access.log;
error_log /var/log/nginx/$servername.error.log warn;
#
}
EOF
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
### a preset pem file for  quick setup -- make a new one after setup
echo "
-----BEGIN DH PARAMETERS-----
MIICCAKCAgEA4dVOH17fdmSkEXS1rZV3tGbFpGbiOE7uhZS39HRPGFb9fQWx/8me
bttfJLaJGED06fO46i8w0o2XZsFW+u6MY7c3ZpzuXFh3g1o3FCebgWLlEnEP8VEo
IVllMFi6VsRQ8d4yMMPNFMOBCwercj09cwbx+LVHE2LerXjz8GTpj/gOvDFZeHV7
BeKP/Rljfyhx7v/vxgU6jCHb5lvFcghBhcmBsuoHFxg+1oeLTK8kZxaDSjuwd0bt
rCk44ChFiN/ivK9GWeHbTMWGh1BV6cKbOvEam5H1Z7XJsD5jvI9GinXR2r7E5EPs
kMn1Nd89JZTjkPa9DabhWIZf/WNIMfJ4EfwuNzH5ZmvMBGQZ/DytOkXl5ZR2OxX6
aKBIJmw2bjzZ9nBAgp+VPPCC3MPLmumV4KxIk2UrJDxutYt0ZXIdWkll+ofasn7F
YAn+i40sfRvYJO/qcqM2I0YD9mqrROzq8sIBUXd3TbsMk+3+rQEdM5FzxHuQYE2I
S5IlLRFLNCKlEVW3N7hK7byQWnioVzY7K7WYKAHTgX7dNZEMGLeyiL1YGp6ieZD6
AykQF0llZYIM012q9XvxDXu5Elba8m5XRHgNTIDvmJXp2MoQJoBuE4dxO2wMs5ys
XDRdH8lxYqiqk9oE+QL+rITf3pCAwq2qGxZARtWNNE+42TJgPmUGc4MCAQI=
-----END DH PARAMETERS-----
" > /etc/ssl/certs/dhparam.pem
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
###create a nginx php optimization file
echo "fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
fastcgi_param PATH_INFO \$path_info;
fastcgi_param modHeadersAvailable true;
fastcgi_param front_controller_active true;
fastcgi_pass php-handler;
fastcgi_param HTTPS on;
fastcgi_intercept_errors on;
fastcgi_request_buffering off;
fastcgi_cache_valid 404 1m;
fastcgi_cache_valid any 1h;
fastcgi_cache_methods GET HEAD;
" > /etc/nginx/php_optimization.conf
###enable all nginx configuration files
sed -i s/\#\include/\include/g /etc/nginx/nginx.conf


###restart NGINX
/usr/sbin/service nginx restart
#openssl dhparam -out /etc/ssl/certs/dhparam.pem 4096




certbot certonly -a webroot --webroot-path=/var/www/letsencrypt --rsa-key-size 4096 -d $servername -d www.$servername
#certbot certonly --dry-run -a webroot --webroot-path=/var/www/letsencrypt --rsa-key-size 4096 -d $servername

if [ ! -d "/etc/letsencrypt/live" ]; then
errorSSL
else
copy4SSL
sed -i '/ssl-cert-snakeoil/d' /etc/nginx/ssl.conf
sed -i s/\#\ssl/\ssl/g /etc/nginx/conf.d/$servername.conf
sed -i s/ssl_dhparam/\#ssl_dhparam/g /etc/nginx/ssl.conf
fi
systemctl restart nginx.service

### CleanUp
cat /dev/null > ~/.bash_history && history -c && history -w
exit 0
