#!/usr/bin/bash

if [ $# -ne 1 ]; then
	echo "作成するサイトのFQDNを指定してください。"
	echo "ex. $ ./install-wordpress.sh www.hogehoge.com"
	exit 1
fi
FQDN=$1

cd ~
if [ -f ./latest-ja.zip ]; then
	sudo mv latest-ja.zip latest-ja.zip.`date "+%Y%m%d_%H%M%S"`
fi
wget http://ja.wordpress.org/latest-ja.zip
unzip ~/latest-ja.zip
rm ~/latest-ja.zip

sudo mkdir -p /usr/share/nginx/vhosts/$FQDN
sudo mv ~/wordpress/* /usr/share/nginx/vhosts/$FQDN/
sudo rmdir ~/wordpress
sudo chown -R nginx:nginx /usr/share/nginx/vhosts/$FQDN

sudo cat << __NGINX_CONF__ | sudo tee /etc/nginx/conf.d/$FQDN.conf > /dev/null
server {
    listen 80;
    server_name $FQDN;
    access_log /var/log/nginx/$FQDN-access.log main;
    error_log /var/log/nginx/$FQDN-error.log;
    root /usr/share/nginx/vhosts/$FQDN;
    index index.php index.html;
    location / {
        try_files $uri $uri/ @wordpress;
    }
    location ~ \.php$ {
        root /usr/share/nginx/vhosts/$FQDN;
        fastcgi_pass unix:/var/run/php-fpm/www.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME ${document_root}${fastcgi_script_name};
        include fastcgi_params;
    }
    location @wordpress {
        fastcgi_index index.php;
        fastcgi_split_path_info ^(.+\.php)(.*)$;
        fastcgi_pass unix:/var/run/php-fpm/www.sock;
        fastcgi_param SCRIPT_FILENAME ${document_root}/index.php;
        include fastcgi_params;
    }
}
__NGINX_CONF__

DBNAME=`echo $FQDN | sed s/\\\./_/g | sed s/-/_/g`
mysql -u root -e "CREATE DATABASE $DBNAME DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci;" 

sudo systemctl restart nginx.service

exit 0
