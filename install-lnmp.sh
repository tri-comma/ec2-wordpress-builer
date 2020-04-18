#!/usr/bin/bash

if test "`cat /etc/system-release`" != "Amazon Linux release 2 (Karoo)"; then exit 2; fi
# Amazon Linux release 2 (Karoo)

sudo sudo yum -y update
sudo amazon-linux-extras install nginx1 -y
# install nginx.x86_64 1:1.16.1-1.amzn2.0.1 at 2020.4.18

sudo amazon-linux-extras install php7.2 -y
# install php7.2.28 at 2020.4.18
#   php-json-7.2.28-1.amzn2.x86_64
#   php-common-7.2.28-1.amzn2.x86_64
#   php-pdo-7.2.28-1.amzn2.x86_64
#   php-mysqlnd-7.2.28-1.amzn2.x86_64
#   php-cli-7.2.28-1.amzn2.x86_64
#   php-fpm-7.2.28-1.amzn2.x86_64
sudo yum -y install php-devel php-mbstring php-pecl-apcu php-opcache
sudo cp /etc/php-fpm.d/www.conf /etc/php-fpm.d/www.conf.origin
sudo sed -i -e 's/ = apache$/ = nginx/g' /etc/php-fpm.d/www.conf

sudo yum -y install mariadb-server
# install mariadb-server.x86_64 1:5.5.64-1.amzn2 at 2020.4.18

sudo systemctl start php-fpm.service
sudo systemctl enable php-fpm.service
sudo systemctl start nginx.service
sudo systemctl enable nginx.service
sudo systemctl start mariadb
sudo systemctl enable mariadb

exit 0