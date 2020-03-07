#!/bin/bash
clear
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

if [[ "$EUID" -ne 0 ]]; then
	echo "Sorry, you need to run this as root"
	exit 1
fi

randomkey1=$(</dev/urandom tr -dc '0-9' | head -c 6  ; echo)
randomkey2=$(</dev/urandom tr -dc '0-9' | head -c 6  ; echo)
randomkey3=$(</dev/urandom tr -dc 'A-Za-z0-9!"#.:-_' | head -c 12  ; echo)
read -p "sitename: " -e -i exsample.domain servername
read -p "sql databasename: " -e -i db$randomkey1 databasename
read -p "sql databaseuser: " -e -i dbuser$randomkey2 databaseuser
read -p "sql databaseuserpasswd: " -e -i $randomkey3 databaseuserpasswd


###
function copy4SSL() {
cp /etc/nginx/conf.d/$servername.conf /etc/nginx/conf.d/$servername.conf.orig
cp /etc/nginx/ssl.conf /etc/nginx/ssl.conf.orig
}
###
function errorSSL() {
clear
echo "!!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!!"
echo "*** ERROR while requesting your certificate(s) ***"
echo ""
echo "Verify that both ports (80 + 443) are forwarded to this server!"
echo "And verify, your dyndns points to your IP either!"
echo "Then retry..."
echo "!!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!!"
echo ""
}

###create folders
mkdir -p /var/www/$servername/
###create temp html and php file
echo "<html><body><center>test HTML file</center></body></html>" >> /var/www/$servername/index.html
echo "<?php
phpinfo();
?>" >> /var/www/$servername/info.php
###apply permissions
chown -R www-data:www-data /var/www/$servername
###restart PHP, NGINX, MariaDB server and connect to MariaDB to create the database
/usr/sbin/service php7.4-fpm restart
/usr/sbin/service nginx restart
/usr/sbin/service mysql restart && mysql -uroot <<EOF
CREATE DATABASE $databasename CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE USER $databaseuser@localhost identified by '$databaseuserpasswd';
GRANT ALL PRIVILEGES on $databasename.* to $databaseuser@localhost;
FLUSH privileges;
EOF
###prepare NGINX for Site and SSL
cat <<EOF >/etc/nginx/conf.d/$servername.conf
server {
server_name $servername;
listen 80;
listen [::]:80;
location ^~ /.well-known/acme-challenge {
proxy_pass http://127.0.0.1:81;
proxy_set_header Host \$host;
}
}
EOF

cat <<EOF >/etc/nginx/ssl.conf
#ssl_certificate /etc/letsencrypt/live/$servername/fullchain.pem;
#ssl_certificate_key /etc/letsencrypt/live/$servername/privkey.pem;
#ssl_trusted_certificate /etc/letsencrypt/live/$servername/chain.pem;
EOF


###restart NGINX
/usr/sbin/service nginx restart

letsencrypt certonly -a webroot --webroot-path=/var/www/letsencrypt --rsa-key-size 4096 -d $servername
#letsencrypt certonly --dry-run -a webroot --webroot-path=/var/www/letsencrypt --rsa-key-size 4096 -d $servername

if [ ! -d "/etc/letsencrypt/live" ]; then
errorSSL
else
copy4SSL
mv /etc/nginx/conf.d/$servername.conf /etc/nginx/conf.d/$servername.conf.bak
cat <<EOF >/etc/nginx/conf.d/$servername.conf
server {
server_name $servername;
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
server_name $servername;
listen 443 ssl http2;
listen [::]:443 ssl http2;
root /var/www/$servername;
index index.php index.html index.htm;

location ~ \.php$ {
    include /etc/nginx/fastcgi_params;
    fastcgi_pass unix:/run/php/php7.4-fpm.sock;
    fastcgi_index index.php;
    fastcgi_param SCRIPT_FILENAME var/www/$servername/$fastcgi_script_name;
}
}
EOF
sed -i "s/server_name.*;/server_name $servername;/" /etc/nginx/conf.d/$servername.conf
sed -i s/\#\ssl/\ssl/g /etc/nginx/ssl.conf
fi
systemctl restart nginx.service

### CleanUp
cat /dev/null > ~/.bash_history && history -c && history -w
exit 0
