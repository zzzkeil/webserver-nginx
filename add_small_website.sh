#!/bin/bash
clear
echo " test 5"
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
read -p "letsencypt registration and recovery mail: " -e -i yourname@$sitename sitemail


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

echo "
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <link rel="stylesheet" href="index.css">
  <title>$sitename</title>
</head>
<body>
<div class="bg"></div>
<div class="bg bg2"></div>
<div class="bg bg3"></div>
<div class="content">
<h1>Wellcome to $sitename</h1>
<p>This is a placeholder<p>
<p>I'll be back, soon .....<p>
</div>
</body>
</html>
" > /home/$sitename/html/index.html

echo "
html {
  height:100%;
}

body {
  margin:0;
}

.bg {
  animation:slide 10s ease-in-out infinite alternate;
  background-image: linear-gradient(-60deg, #6c3 50%, #09f 50%);
  bottom:0;
  left:-50%;
  opacity:.5;
  position:fixed;
  right:-50%;
  top:0;
  z-index:-1;
}

.bg2 {
  animation-direction:alternate-reverse;
  animation-duration:20s;
}

.bg3 {
  animation-duration:35s;
}

.content {
  background-color:rgba(255,255,255,.8);
  border-radius:.25em;
  box-shadow:0 0 .25em rgba(0,0,0,.25);
  box-sizing:border-box;
  left:50%;
  padding:10vmin;
  position:fixed;
  text-align:center;
  top:50%;
  transform:translate(-50%, -50%);
}

h1 {
  font-family:monospace;
}

@keyframes slide {
  0% {
    transform:translateX(-25%);
  }
  100% {
    transform:translateX(25%);
  }
}
" > /home/$sitename/html/index.css 


chown -R $siteuser:www-data /home/$sitename/html



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
certbot certonly -a webroot --webroot-path=/var/www/letsencrypt -m '$sitemail' --no-eff-email --key-type ecdsa --elliptic-curve secp521r1 --rsa-key-size 4096 -d $sitename -d www.$sitename
#certbot certonly -a webroot --webroot-path=/var/www/letsencrypt -m '$sitemail' --no-eff-email --key-type ecdsa --elliptic-curve secp521r1 --rsa-key-size 4096 --preferred-challenges dns -d '*.$sitename' -d $sitename
#certbot certonly -a webroot --webroot-path=/var/www/letsencrypt --register-unsafely-without-email --rsa-key-size 4096 -d $sitename -d www.$sitename
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
