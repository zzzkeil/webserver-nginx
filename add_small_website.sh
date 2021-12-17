#!/bin/bash
clear
echo "3"
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

echo "
$sitename
Adminname : $siteuser
Adminpassword : $userpass
#
" >> /root/website_user_list.txt


###create sftp user
useradd -g www-data -m -d /home/$sitename -s /sbin/nologin $siteuser
echo "$siteuser:$userpass" | chpasswd

echo "
Match User $siteuser
   ChrootDirectory %h
   ForceCommand internal-sftp
   AllowTcpForwarding no
   X11Forwarding no
   " >> /etc/ssh/sshd_config

chown root: /home/$sitename
chmod 755 /home/$sitename
   
###create folders
mkdir /home/$sitename/html
chmod 775 /home/$sitename/html
chown $siteuser:www-data /home/$sitename/html

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


###restart nginx
/usr/sbin/service nginx restart


### letsencrypt 
certbot certonly -a webroot --webroot-path=/var/www/letsencrypt --register-unsafely-without-email --rsa-key-size 4096 -d $sitename -d www.$sitename
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
systemctl restart sshd.service

### CleanUp
cat /dev/null > ~/.bash_history && history -c && history -w
exit 0
