#!/usr/bin/bash

if [ $# -ne 1 ]; then
	echo "作成するデータベース名を指定してください。"
	echo "ex. $ ./install-wordpress.sh wordpress"
	exit 1
fi

cd ~
if [ -f ./latest-ja.zip ]; then
	sudo mv latest-ja.zip latest-ja.zip.`date "+%Y%m%d_%H%M%S"`
fi
wget http://ja.wordpress.org/latest-ja.zip
unzip ~/latest-ja.zip
sudo mv ~/wordpress /usr/share/nginx/html/
sudo chown -R nginx:nginx /usr/share/nginx/html/wordpress

mysql -u root -e "CREATE DATABASE $1 DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci;" 

exit 0



