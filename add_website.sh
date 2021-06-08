#!/bin/bash
clear
echo "1"
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

read -p "sitename: " -e -i example.domain sitename
read -p "siteuser: " -e -i user-$sitename siteuser
randomkeyuser=$(</dev/urandom tr -dc 'A-Za-z0-9.:_' | head -c 32  ; echo)
read -p "userpass: " -e -i $randomkeyuser userpass
randomkey1=$(date +%s | cut -c 3-)
read -p "sql databasename: " -e -i db$randomkey1 databasename
read -p "sql databaseuser: " -e -i dbuser$randomkey1 databaseuser
randomkey2=$(</dev/urandom tr -dc 'A-Za-z0-9.:_' | head -c 12  ; echo)
read -p "sql databaseuserpasswd: " -e -i $randomkey2 databaseuserpasswd
echo "
$sitename
Adminname : $siteuser
Adminpassword : $userpass
databasename : $databasename
databaseuser : $databaseuser
databaseuserpasswd : $databaseuserpasswd
#
" >> /root/user_and_mysql_database_list.txt


###create sftp user

useradd -m -p $userpass $siteuser -s /sbin/nologin -M
usermod -aG www-data $siteuser

echo "
Match User $siteuser
   ChrootDirectory /home/$sitename/html
   ForceCommand internal-sftp
   AllowTcpForwarding no
   X11Forwarding no
   " >> /etc/ssh/sshd_config


###
function copy4SSL() {
cp /etc/nginx/conf.d/$sitename.conf /etc/nginx/conf.d/$sitename.conf.orig
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
mkdir -p /home/$sitename/html
###create temp html and php file
echo "<html><body><center>test HTML file</center></body></html>" >> /home/$sitename/html/index.html
echo "<?php
phpinfo();
?>" >> /home/$sitename/html/info.php
###apply permissions
chown -R www-data:www-data /home/$sitename/html
### add database
mysql -uroot <<EOF
CREATE DATABASE $databasename CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE USER $databaseuser@localhost identified by '$databaseuserpasswd';
GRANT ALL PRIVILEGES on $databasename.* to $databaseuser@localhost;
FLUSH privileges;
EOF
###prepare NGINX for Site and SSL
echo "server {
server_name $sitename;
listen 80;
listen [::]:80;
location ^~ /.well-known/acme-challenge {
proxy_pass http://127.0.0.1:81;
proxy_set_header Host \$host;
}
}
" > /etc/nginx/conf.d/$sitename.conf


###restart nginx php db
/usr/sbin/service php8.0-fpm restart
/usr/sbin/service nginx restart
/usr/sbin/service mysql restart


### letsencrypt 
certbot certonly -a webroot --webroot-path=/var/www/letsencrypt --rsa-key-size 4096 -d $sitename -d www.$sitename 
#certbot certonly --dry-run -a webroot --webroot-path=/var/www/letsencrypt --rsa-key-size 4096 -d $sitename

if [ ! -d "/etc/letsencrypt/live" ]; then
errorSSL
else
copy4SSL
mv /etc/nginx/conf.d/$sitename.conf /etc/nginx/conf.d/$sitename.conf.bak
touch /etc/nginx/conf.d/$sitename.conf
cat <<EOF >/etc/nginx/conf.d/$sitename.conf
server {
server_name $sitename www.$sitename;
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
server_name $sitename www.$sitename;
listen 443 ssl http2;
listen [::]:443 ssl http2;
root /home/$sitename/html;
index index.php index.html index.htm;
location / {
		try_files \$uri \$uri/ =404;
	}
location ~ \.php$ {
    include /etc/nginx/fastcgi_params;
    fastcgi_pass unix:/run/php/php8.0-fpm.sock;
    fastcgi_index index.php;
    fastcgi_param SCRIPT_FILENAME /home/$sitename/html\$fastcgi_script_name;
}
# letsencrypt for $sitename
ssl_certificate /etc/letsencrypt/live/$sitename/fullchain.pem;
ssl_certificate_key /etc/letsencrypt/live/$sitename/privkey.pem;
ssl_trusted_certificate /etc/letsencrypt/live/$sitename/chain.pem;
#
# logs
access_log /var/log/nginx/$sitename.access.log;
error_log /var/log/nginx/$sitename.error.log warn;
#
}
EOF


sed -i "s/server_name.*;/server_name $sitename;/" /etc/nginx/conf.d/$sitename.conf
sed -i s/\#\ssl/\ssl/g /etc/nginx/ssl.conf
fi
systemctl restart nginx.service

### CleanUp
cat /dev/null > ~/.bash_history && history -c && history -w
exit 0
