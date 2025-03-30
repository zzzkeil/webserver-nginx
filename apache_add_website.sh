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
echo -e " ${GRAYB}#${ENDCOLOR} ${GREEN}Script to add a new website to your apache2 webserver                      ${ENDCOLOR}${GRAYB}#${ENDCOLOR}"
echo -e " ${GRAYB}#${ENDCOLOR} ${GREEN}1. You need to check your DNS settings for your domain                     ${ENDCOLOR}${GRAYB}#${ENDCOLOR}"
echo -e " ${GRAYB}##############################################################################${ENDCOLOR}"
echo ""
echo ""
echo ""
echo  -e "                    ${RED}To EXIT this script press any key${ENDCOLOR}"
echo ""
echo  -e "                            ${GREEN}Press [Y] to begin${ENDCOLOR}"
read -p "" -n 1 -r
echo ""
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    exit 1
fi
#
### root check
if [[ "$EUID" -ne 0 ]]; then
	echo -e "${RED}Sorry, you need to run this as root${ENDCOLOR}"
	exit 1
fi



### site data
randomkeyuser=$(</dev/urandom tr -dc 'A-Za-z0-9._' | head -c 32  ; echo)
randomkey1=$(date +%s | cut -c 7-)
randomkey2=$(shuf -i 1000-9999 -n 1)
randomkey3=$(</dev/urandom tr -dc 'A-Za-z0-9._' | head -c 32  ; echo)
read -p "sitename: " -e -i example.domain sitename
read -p "siteuser: " -e -i user$randomkey1$randomkey2 siteuser
read -p "userpass: " -e -i $randomkeyuser userpass
read -p "sql databasename: " -e -i db$randomkey2$randomkey1 databasename
read -p "sql databaseuser: " -e -i dbuser$randomkey1$randomkey2 databaseuser
read -p "sql databaseuserpasswd: " -e -i $randomkey3 databaseuserpasswd


###create sftp user
useradd -g www-data -m -d /home/$sitename -s /sbin/nologin $siteuser
echo "$siteuser:$userpass" | chpasswd
cp /etc/ssh/sshd_config /root/script_backupfiles/sshd_config.bak01
echo "
Match User $siteuser
   AuthenticationMethods password
   PubkeyAuthentication no
   PasswordAuthentication yes
   ChrootDirectory %h
   ForceCommand internal-sftp
   AllowTcpForwarding no
   X11Forwarding no
   " >> /etc/ssh/sshd_config

chown root: /home/$sitename
chmod 755 /home/$sitename

###create folders and files
mkdir /home/$sitename/html
chmod 775 /home/$sitename/html

cat <<EOF >> /etc/apache2/sites-available/$sitename.conf
<VirtualHost *:80>
  ServerName $sitename
  RewriteEngine On
  DocumentRoot /home/$sitename/html    
<Directory /home/$sitename/html>
  Options Indexes FollowSymLinks
  AllowOverride All
  Require all granted
</Directory>
  ErrorLog /home/$sitename/error.log
  CustomLog /home/$sitename/access.log combined
</VirtualHost>
EOF

mariadb -uroot <<EOF
CREATE DATABASE $databasename CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE USER '$databaseuser'@'localhost' identified by '$databaseuserpasswd';
GRANT ALL PRIVILEGES on $databasename.* to '$databaseuser'@'localhost' identified by '$databaseuserpasswd';
FLUSH privileges;
EOF

echo "
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <title>$sitename</title>
</head>
<body>
<center>
<h1>Wellcome to $sitename</h1>
<p>maintenance mode<p>
<p>I'll be back, soon .....<p>
</center>
</body>
</html>
" > /home/$sitename/html/index.html

echo "
<?php
phpinfo();
?>
" > /home/$sitename/html/checkphp.php
 
chown -R $siteuser:www-data /home/$sitename/html

a2ensite $sitename.conf
systemctl reload apache2

###letsencrypt
certbot --apache --agree-tos --register-unsafely-without-email --key-type ecdsa --elliptic-curve secp384r1 -d $sitename

systemctl restart apache2.service
systemctl restart sshd.service

echo "
$sitename
Adminname : user$randomkey1$randomkey2 
Adminpassword : $userpass
Databasename : db$randomkey2$randomkey1
Databaseuser : dbuser$randomkey1$randomkey2
Databaseuserpasswd : $randomkey3
#

" >> /root/website_user_list.txt

echo -e " ${GRAYB}##############################################################################${ENDCOLOR}"
echo -e " ${GRAYB}#${ENDCOLOR} ${GREEN}Done. Test your site now.                                                  ${ENDCOLOR}${GRAYB}#${ENDCOLOR}"
echo -e " ${GRAYB}##############################################################################${ENDCOLOR}"

### CleanUp
cat /dev/null > ~/.bash_history && history -c && history -w
exit 0
