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
echo -e " ${GRAYB}#${ENDCOLOR} ${GREEN}Advanced script to install apache webserver on Debian 12                   ${ENDCOLOR}${GRAYB}#${ENDCOLOR}"
echo -e " ${GRAYB}#${ENDCOLOR} ${GREEN}Settings : TLSv1.3 only | lets encrypt ecdsa | other mods | php | mariadb  ${ENDCOLOR}${GRAYB}#${ENDCOLOR}"
echo -e " ${GRAYB}##############################################################################${ENDCOLOR}"
echo -e " ${GRAYB}#${ENDCOLOR} ${GREEN}My base_setup.sh script is needed to setup this script correctly!!         ${ENDCOLOR}${GRAYB}#${ENDCOLOR}"
echo -e " ${GRAYB}#${ENDCOLOR} ${GREEN}If not installed, a automatic download starts, then follow the instructions${ENDCOLOR}${GRAYB}#${ENDCOLOR}"
echo -e " ${GRAYB}#${ENDCOLOR} ${GREEN}More information: https://github.com/zzzkeil/webserver                     ${ENDCOLOR}${GRAYB}#${ENDCOLOR}"
echo -e " ${GRAYB}##############################################################################${ENDCOLOR}"
echo -e " ${GRAYB}#${ENDCOLOR}                 Version 2025.03.23 - changelog on github                   ${GRAYB}#${ENDCOLOR}"
echo -e " ${GRAYB}##############################################################################${ENDCOLOR}"
echo ""
echo ""
echo ""
echo  -e "                    ${RED}To EXIT this script press any key${ENDCOLOR}"
echo ""
echo  -e "                  ${GREEN}Press [Y] to begin  -  script not testet - ${ENDCOLOR}"
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


### check if Debian
. /etc/os-release
if [[ "$ID" = 'debian' ]]; then
   echo -e "OS ID check = ${GREEN}ok${ENDCOLOR}"
   else 
   echo -e "${RED}This script is only for Debian ${ENDCOLOR}"
   exit 1
fi

###global function to update and cleanup the environment
function update_and_clean() {
apt update
apt upgrade -y
apt autoclean -y
apt autoremove -y
}


### START ###
# Debian 12
if [[ "$VERSION_ID" = '12' ]]; then
apt install curl gnupg2 ca-certificates apt-transport-https lsb-release debian-archive-keyring zlib1g imagemagick libxml2 memcached unzip libmagickcore-6.q16-6-extra -y

###sury apache repo 
curl -sSLo /tmp/debsuryorg-archive-keyring.deb https://packages.sury.org/debsuryorg-archive-keyring.deb
dpkg -i /tmp/debsuryorg-archive-keyring.deb
sh -c 'echo "deb [signed-by=/usr/share/keyrings/debsuryorg-archive-keyring.gpg] https://packages.sury.org/apache2/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/apache2.list'
###sury php repo
sh -c 'echo "deb [signed-by=/usr/share/keyrings/debsuryorg-archive-keyring.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list'

###maria-db repo
mkdir -p /etc/apt/keyrings
curl -o /etc/apt/keyrings/mariadb-keyring.pgp 'https://mariadb.org/mariadb_release_signing_key.pgp'
echo "
# MariaDB 11.4 repository list - created 2025-03-23 09:39 UTC
# https://mariadb.org/download/
X-Repolib-Name: MariaDB
Types: deb
# deb.mariadb.org is a dynamic mirror if your preferred mirror goes offline. See https://mariadb.org/mirrorbits/ for details.
# URIs: https://deb.mariadb.org/11.4/debian
URIs: https://mirror1.hs-esslingen.de/pub/Mirrors/mariadb/repo/11.4/debian
Suites: bookworm
Components: main
Signed-By: /etc/apt/keyrings/mariadb-keyring.pgp
" > /etc/apt/sources.list.d/mariadb.sources


update_and_clean
###php overflow 4 WP and NC......
apt install apache2 apache2-mpm-itk libapache2-mod-php certbot python3-certbot-apache mariadb-server php8.3 php8.3-fpm php8.3-cli php-mbstring php8.3-curl php8.3-igbinary php8.3-imagick php8.3-ssh2 php8.3-intl php8.3-mbstring php8.3-xml php8.3-zip php8.3-apcu php8.3-memcached php8.3-opcache php8.3-redis php8.3-mysql php8.3-gd php8.3-gmp php8.3-bcmath php8.3-bz2 php8.3-common -y
fi


#clear
#echo ""
#echo -e " ${YELLOW}Get some coffee, restore your energy, this can take a while or just seconds :) ${ENDCOLOR}"
#echo ""
#openssl dhparam -out /etc/apache2/dhparam.pem 4096
#clear
#echo -e " ${GREEN}:) done ${ENDCOLOR}"
#####dummykey for testing
echo "-----BEGIN DH PARAMETERS-----
MIICCAKCAgEA+4jEuqUsyMD8lsnCB5HU0HTKpoXn45GQBm2E+lS6WGjqnJHrREMP
P8z4LnBAMKzHmGRUs5SbelXghDqoHh18FkrEltZTUnJhhLe42HYdL3uSKhJdUN5n
Ml8eHu+CX1CmmHTxJQZLSPV/nGtM5le6yT5zMDda2EEtH7x9wAzkkaaTGZTaQd+J
G3vW6uuAIVwaWqDKUHmRzEpmcfgWTJFwRMHqGrVID4dOuoBAiKBmNxwsmEy61rBe
dkWwgcuNShWSyerWJMxOMfqbh45pNx9/gLluZxDdDUgrvkkOgVqx7POWwWrl16vf
LomR+GcqQs2q1B8qaMboSGUOgfAq4kLY5EyeSwbsIcn9SmEDAEGGafxNz8lxFlB2
rqRQuWGj05A4nJWmgZanbwqmjvF+gBWERIHhJpIkGWRz2qUNiKaYiStX9ffSqRao
veIcraRZqyGIJib/YqF7+wkyGDlosJ08dzwU4EqMUQE7EOvJa4L3V9e8tA0jHSQD
IIuxsmo/AJVFYB3BSGgFC6mZ47ehn1Eqpb6goJaVh9BS4Ohj1wiL6p2u917bkvO7
Hd42NTmIniebiGTRPwugwR/QIMG3cfqx5NrfnBkkVSE0umC+Nfj6dUXGZSo9p+HS
DrypuQUHgJNWZIhhNhXnlFnFHb1ezRpxhKi5GGrgZPUvePMYi0ubHicCAQI=
-----END DH PARAMETERS-----" > /etc/apache2/dhparam.pem



mv /etc/apache2/mods-available/ssl.conf /etc/apache2/mods-available/ssl.conf.bak
echo 'SSLProtocol -all +TLSv1.3
SSLOpenSSLConfCmd Curves X25519:secp521r1:secp384r1:prime256v1
SSLOpenSSLConfCmd DHParameters "/etc/apache2/dhparam.pem"
SSLCipherSuite TLSv1.3 TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256
SSLRandomSeed startup builtin
SSLRandomSeed startup file:/dev/urandom 512
SSLRandomSeed connect builtin
SSLRandomSeed connect file:/dev/urandom 512
SSLHonorCipherOrder     off
SSLSessionTickets       off
AddType application/x-x509-ca-cert .crt
AddType application/x-pkcs7-crl .crl
SSLPassPhraseDialog  exec:/usr/share/apache2/ask-for-passphrase
SSLSessionCache     shmcb:${APACHE_RUN_DIR}/ssl_scache(512000)
SSLSessionCacheTimeout  300
SSLUseStapling On
SSLStaplingCache "shmcb:logs/ssl_stapling(32768)"
' > /etc/apache2/mods-available/ssl.conf

###certbot options-ssl-apache mod
mv /etc/letsencrypt/options-ssl-apache.conf /etc/letsencrypt/options-ssl-apache.conf.bak

cat <<EOF >> /etc/letsencrypt/options-ssl-apache.conf
SSLEngine on
SSLProtocol             -all +TLSv1.3
SSLCipherSuite TLSv1.3 TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256
SSLOpenSSLConfCmd Curves X25519:secp521r1:secp384r1:prime256v1
SSLOpenSSLConfCmd DHParameters "/etc/apache2/dhparam.pem"
SSLHonorCipherOrder     off
SSLSessionTickets       off
SSLCompression          off
SSLUseStapling          on
SSLOptions +StrictRequire
Header always set Strict-Transport-Security "max-age=63072000"
Header always set X-Frame-Options DENY
Header always set X-Content-Type-Options nosniff
LogFormat "%h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-agent}i\"" vhost_combined
LogFormat "%v %h %l %u %t \"%r\" %>s %b" vhost_common
EOF



### apache part
a2enmod ssl
a2enmod rewrite
a2enmod headers
a2enmod socache_shmcb
a2enmod env
a2enmod dir
a2enmod mime
a2enmod proxy_fcgi setenvif
a2enconf php8.3-fpm

a2dissite 000-default.conf


### self-signed  certificate
#openssl req -x509 -newkey ec:<(openssl ecparam -name secp384r1) -days 1800 -nodes -keyout /etc/apache2/selfsigned-key.key -out /etc/apache2/selfsigned-cert.crt -subj "/C=DE/ST=Self/L=Signed/O=For/OU=You/CN=$hostipv4"

hostipv4=$(hostname -I | awk '{print $1}')

mkdir -p /home/$hostipv4/html

cat <<EOF >> /etc/apache2/sites-available/000-base.conf
<VirtualHost *:80>
   ServerName $hostipv4
   DocumentRoot /home/$hostipv4/html

<Directory /home/$hostipv4/html>
   Options Indexes FollowSymLinks
   AllowOverride All
   Require all granted
</Directory>
 ErrorLog /home/$hostipv4/error.log
 CustomLog /home/$hostipv4/access.log combined
</VirtualHost>
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
<br>
<h1>Test page</h1>
<p>Webserver is running<p>
<p>cu<p>
</center>
</body>
</html>
" > /home/$hostipv4/html/index.html


echo "
<?php
phpinfo();
?>
" > /home/$hostipv4/html/checkphp.php


##php settings 4 nextcloud wordpress
timezone1=$(cat /etc/timezone | cut -d '/' -f 1)
timezone2=$(cat /etc/timezone | cut -d '/' -f 2)
cp /etc/php/8.3/fpm/php.ini /etc/php/8.3/fpm/php.ini.bak
sed -i "s/memory_limit = 128M/memory_limit = 512M/" /etc/php/8.3/fpm/php.ini
sed -i "s/output_buffering =.*/output_buffering = '0'/" /etc/php/8.3/fpm/php.ini
sed -i "s/max_execution_time =.*/max_execution_time = 400/" /etc/php/8.3/fpm/php.ini
sed -i "s/max_input_time =.*/max_input_time = 400/" /etc/php/8.3/fpm/php.ini
sed -i "s/post_max_size =.*/post_max_size = 2G/" /etc/php/8.3/fpm/php.ini
sed -i "s/upload_max_filesize =.*/upload_max_filesize = 2G/" /etc/php/8.3/fpm/php.ini
sed -i "s/;date.timezone.*/date.timezone = $timezone1\/\\$timezone2/" /etc/php/8.3/fpm/php.ini
sed -i "s/;cgi.fix_pathinfo.*/cgi.fix_pathinfo=0/" /etc/php/8.3/fpm/php.ini
sed -i "s/;session.cookie_secure.*/session.cookie_secure = True/" /etc/php/8.3/fpm/php.ini
sed -i "s/;opcache.enable=.*/opcache.enable=1/" /etc/php/8.3/fpm/php.ini
sed -i "s/;opcache.validate_timestamps=.*/opcache.validate_timestamps=0/" /etc/php/8.3/fpm/php.ini
sed -i "s/;opcache.enable_cli=.*/opcache.enable_cli=1/" /etc/php/8.3/fpm/php.ini
sed -i "s/;opcache.memory_consumption=.*/opcache.memory_consumption=256/" /etc/php/8.3/fpm/php.ini
sed -i "s/;opcache.interned_strings_buffer=.*/opcache.interned_strings_buffer=64/" /etc/php/8.3/fpm/php.ini
sed -i "s/;opcache.max_accelerated_files=.*/opcache.max_accelerated_files=100000/" /etc/php/8.3/fpm/php.ini
sed -i "s/;opcache.revalidate_freq=.*/opcache.revalidate_freq=60/" /etc/php/8.3/fpm/php.ini
sed -i "s/;opcache.save_comments=.*/opcache.save_comments=1/" /etc/php/8.3/fpm/php.ini
sed -i "s/max_file_uploads =.*/max_file_uploads = 20/" /etc/php/8.3/fpm/php.ini

sed -i '$aopcache.jit=1255' /etc/php/8.3/fpm/php.ini
sed -i '$aopcache.jit_buffer_size=256M' /etc/php/8.3/fpm/php.ini

sed -i '$aapc.enable_cli=1' /etc/php/8.3/fpm/php.ini
sed -i '$aapc.enable_cli=1' /etc/php/8.3/mods-available/apcu.ini
sed -i '$aopcache.jit=1255' /etc/php/8.3/mods-available/opcache.ini
sed -i '$aopcache.jit_buffer_size=256M' /etc/php/8.3/mods-available/opcache.ini


sed -i '$a[mysql]' /etc/php/8.3/mods-available/mysqli.ini
sed -i '$amysql.allow_local_infile=On' /etc/php/8.3/mods-available/mysqli.ini
sed -i '$amysql.allow_persistent=On' /etc/php/8.3/mods-available/mysqli.ini
sed -i '$amysql.cache_size=2000' /etc/php/8.3/mods-available/mysqli.ini
sed -i '$amysql.max_persistent=-1' /etc/php/8.3/mods-available/mysqli.ini
sed -i '$amysql.max_links=-1' /etc/php/8.3/mods-available/mysqli.ini
sed -i '$amysql.connect_timeout=60' /etc/php/8.3/mods-available/mysqli.ini
sed -i '$amysql.trace_mode=Off' /etc/php/8.3/mods-available/mysqli.ini

a2ensite 000-base.conf

###apply permissions
chown -R www-data:www-data /var/www
chown -R www-data:www-data /home/$hostipv4


###mariadb install

echo "--------------------------------------------------------------------------------------------------------"
echo "--------------------------------------------------------------------------------------------------------"
read -p "Set your mariaDB port: " -e -i 3306 dbport
echo "--------------------------------------------------------------------------------------------------------"
echo "--------------------------------------------------------------------------------------------------------"
mv /etc/mysql/my.cnf /etc/mysql/my.cnf.bak
echo "
[mysqld]
bind-address = 127.0.0.1
port = $dbport

slow_query_log_file    = /var/log/mysql/mariadb-slow.log
long_query_time        = 10
log_slow_rate_limit    = 1000
log_slow_verbosity     = query_plan
log-queries-not-using-indexes
" > /etc/mysql/my.cnf


echo "--------------------------------------------------------------------------------------------------------"
echo "--------------------------------------------------------------------------------------------------------"
echo " Your database server will now be hardened - just follow the instructions."
echo " Keep in mind: your MariaDB root password is still NOT set !"
echo -e "${YELLOW} You should set a root password, when asked${ENDCOLOR}"
echo "--------------------------------------------------------------------------------------------------------"
echo "--------------------------------------------------------------------------------------------------------"
mariadb-secure-installation


###enable  autostart
systemctl enable apache2.service
systemctl restart apache2.service
systemctl restart mariadb.service
systemctl restart php8.3-fpm


### open ports firewalld
firewall-cmd --zone=public --add-port=80/tcp
firewall-cmd --zone=public --add-port=443/tcp
firewall-cmd --runtime-to-permanent

cd
wget -O  apache_add_website.sh https://raw.githubusercontent.com/zzzkeil/webserver/refs/heads/master/apache_add_website.sh
chmod +x apache_add_website.sh

echo -e " ${GRAYB}##############################################################################${ENDCOLOR}"
echo -e " ${GRAYB}#${ENDCOLOR} ${GREEN}To add your first website run ./apache_add_website.sh                      ${ENDCOLOR}${GRAYB}#${ENDCOLOR}"
echo -e " ${GRAYB}##############################################################################${ENDCOLOR}"

### CleanUp
cat /dev/null > ~/.bash_history && history -c && history -w
exit 0
