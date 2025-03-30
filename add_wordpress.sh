#!/bin/bash

exit

#get enabled sites from apache

#select site 

#cd into site html

#download unpack app
wget http://wordpress.org/latest.tar.gz
tar -xzvf latest.tar.gz
mv wordpress/* .
rm -rf wordpress latest.tar.gz

chown -R $siteuser:www-data /home/$sitename/html
