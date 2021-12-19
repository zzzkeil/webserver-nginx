## A small nginx webserver with lets encrypt, tlsv1.3 only
### base install, just for multiple html sites, with index.html placeholder >>> .... (no php, no db installed)

#### (beta) for Debian 11 and Ubuntu 20.04

```

wget -O  debian_small_webserver.sh https://raw.githubusercontent.com/zzzkeil/webserver-nginx/master/debian_small_webserver.sh
chmod +x debian_small_webserver.sh
./debian_small_webserver.sh

```

-

-

-


old but with php8 and mariadb.....
<details>
<summary>example: click to expand!</summary>
  
##### For Ubuntu 18.04 / 20.04:
```
wget -O  webserver-nginx-php-mariadb.sh https://raw.githubusercontent.com/zzzkeil/webserver-nginx/master/old/webserver-nginx-php-mariadb.sh
chmod +x webserver-nginx-php-mariadb.sh
./webserver-nginx-php-mariadb.sh
```
</details>
