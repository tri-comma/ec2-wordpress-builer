#!/usr/bin/bash

if test "`cat /etc/system-release`" != "Amazon Linux release 2 (Karoo)"; then
	echo "このシェルはAmazon Linux 2にのみ対応しています。"
	exit 1
fi
# Amazon Linux release 2 (Karoo)
if [ $# -ne 2 ]; then
    echo "以下のパラメータを指定してください。"
    echo "第１引数：AWS CLIのアクセスキー"
    echo "第２引数：AWS CLIのシークレットキー"
    echo "ex. $ ./install-lnmp.sh XXXXXXXXXXXXXXXXXXXX xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
    exit 1
fi
ACCESS_KEY=$1
SECRET_KEY=$2

# nginxのインストール
sudo sudo yum -y update
sudo amazon-linux-extras install nginx1 -y
# install nginx.x86_64 1:1.16.1-1.amzn2.0.1 at 2020.4.18

# PHPのインストール
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

# MariaDBのインストール
sudo yum -y install mariadb-server
# install mariadb-server.x86_64 1:5.5.64-1.amzn2 at 2020.4.18

# 各種サーバの起動
sudo systemctl start php-fpm.service
sudo systemctl enable php-fpm.service
sudo systemctl start nginx.service
sudo systemctl enable nginx.service
sudo systemctl start mariadb
sudo systemctl enable mariadb

# SSL証明書作成コマンドの用意
sudo yum -y install ruby # 下記 certbot-autoの書き換え用
sudo wget https://dl.eff.org/certbot-auto
sudo chmod 700 certbot-auto
sudo cat << __CERTBOT__ | sudo ruby -e 'f = "certbot-auto";lines = File.read(f).gsub(/^elif \[ -f \/etc\/issue \] && grep -iq "Amazon Linux(.*\n){5}/, "#{STDIN.read}");  File.write(f, lines);'
elif grep -i "Amazon Linux" /etc/issue > /dev/null 2>&1 || \\
   grep 'cpe:.*:amazon_linux:2' /etc/os-release > /dev/null 2>&1; then
  Bootstrap() {
    ExperimentalBootstrap "Amazon Linux" BootstrapRpmCommon
  }
  BOOTSTRAP_VERSION="BootstrapRpmCommon \$BOOTSTRAP_RPM_COMMON_VERSION"
__CERTBOT__
sudo mv ./certbot-auto /usr/local/bin

# AWS CLIコマンドの用意
sudo yum -y install jq # aws-cli用
REGION=`curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone| sed -e 's/.$//'`
# aws configureと同じ処理（プロンプトを出したくないので自らファイル作成）
cd ~
mkdir .aws
sudo chown ec2-user:ec2-user .aws
sudo chmod 775 .aws
# ~/.aws/credentialsの設定（アクセスキーとシークレットキーを設定）
sudo cat << __CREDENTIALS__ | sudo tee ~/.aws/credentials > /dev/null
[default]
aws_access_key_id = $ACCESS_KEY
aws_secret_access_key = $SECRET_KEY
__CREDENTIALS__
# ~/.aws/configの設定（このEC2インスタンスのリージョンをデフォルトに設定）
sudo cat << __CONFIG__ | sudo tee ~/.aws/config > /dev/null
[default]
region = $REGION
output = json
__CONFIG__

exit 0
