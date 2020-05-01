#!/usr/bin/bash

if [ $# -ne 2 ]; then
	echo "作成するサイトのFQDNとSSL証明書取得用メールアドレスを指定してください。"
	echo "ex. $ ./install-wordpress.sh www.tri-comma.com user@tri-comma.com"
	exit 1
fi
FQDN=$1
MADDR=$2

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
    listen 443 ssl;
    ssl on;
    ssl_certificate     /etc/letsencrypt/live/from-cloudfront.$FQDN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/from-cloudfront.$FQDN/privkey.pem;

    server_name $FQDN;
    access_log /var/log/nginx/$FQDN-access.log main;
    error_log /var/log/nginx/$FQDN-error.log;
    root /usr/share/nginx/vhosts/$FQDN;
    index index.php index.html;
    location / {
        try_files \$uri \$uri/ @wordpress;
    }
    location ~ \.php\$ {
        root /usr/share/nginx/vhosts/$FQDN;
        fastcgi_pass unix:/var/run/php-fpm/www.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \${document_root}\${fastcgi_script_name};
        include fastcgi_params;
    }
    location @wordpress {
        fastcgi_index index.php;
        fastcgi_split_path_info ^(.+\.php)(.*)\$;
        fastcgi_pass unix:/var/run/php-fpm/www.sock;
        fastcgi_param SCRIPT_FILENAME \${document_root}/index.php;
        include fastcgi_params;
    }
}
__NGINX_CONF__

sudo systemctl restart nginx.service

sudo /usr/local/bin/certbot-auto certonly --webroot -w /usr/share/nginx/vhosts/$FQDN -d from-cloudfront.$FQDN --email $MADDR -n --agree-tos --debug

DBNAME=`echo $FQDN | sed s/\\\./_/g | sed s/-/_/g`
mysql -u root -e "CREATE DATABASE $DBNAME DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci;" 

sudo systemctl restart nginx.service

echo "ブラウザで$FQDNにアクセスしてWordPressのインストールを開始してください。"
echo "その時、データベース名は$DBNAMEを指定してください。"

exit 0
