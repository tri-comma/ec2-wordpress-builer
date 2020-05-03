#!/usr/bin/bash

echo "INFO: ========= Start! install-wordpress.sh ========="

if [ $# -ne 3 ]; then
    echo "ERROR: ========= Failed! install-wordpress.sh ========="
    echo "ERROR: パラメータが不正です。"
    echo "INFO: 以下のパラメータを指定してください。"
    echo "INFO: 第１引数：作成するサイトのFQDN"
    echo "INFO: 第２引数：Route 53で管理するホストゾーンのドメイン名"
    # echo "INFO: 第３引数：CloudFrontのID"
    echo "INFO: 第３引数：SSL証明書取得用メールアドレス"
    # echo "ex. $ ./install-wordpress.sh www.tri-comma.com tri-comma.com E9ZZ99ZZZ9ZZ9Z user@tri-comma.com"
    echo "INFO: ex. $ ./install-wordpress.sh www.tri-comma.com tri-comma.com user@tri-comma.com"
    exit 1
fi
FQDN=$1
DOMAIN=$2
# CF_ID=$3
MADDR=$3
echo ""
echo "INFO: ========= 指定された引数 ========="
echo "INFO: 作成するサイトのFQDN："$FQDN
echo "INFO: Route 53で管理するホストゾーンのドメイン名："$DOMAIN
# echo "CloudFrontのID："$CF_ID
echo "INFO: SSL証明書取得用メールアドレス："$MADDR
echo ""

# WordPressのダウンロード
cd ~
if [ -f ./latest-ja.zip ]; then
    sudo mv latest-ja.zip latest-ja.zip.`date "+%Y%m%d_%H%M%S"`
fi
wget http://ja.wordpress.org/latest-ja.zip
unzip ~/latest-ja.zip
rm ~/latest-ja.zip

# サイトのhtmlディレクトリ用意
sudo mkdir -p /usr/share/nginx/vhosts/$FQDN
sudo mv ~/wordpress/* /usr/share/nginx/vhosts/$FQDN/
sudo rmdir ~/wordpress
sudo chown -R nginx:nginx /usr/share/nginx/vhosts/$FQDN

# DNS登録するための準備
# (1) このシェルを実行するEC2インスタンスのID
INSTANCE_ID=`curl 'http://169.254.169.254/latest/meta-data/instance-id'`
if test $INSTANCE_ID == ""; then
    echo "ERROR: ========= Failed! install-wordpress.sh ========="
    echo "ERROR: EC2インスタンスIDの取得に失敗しました。"
    exit 1
fi
# (2) CloudFront情報(JSON)
# CF_JSON=`aws cloudfront get-distribution --id $CF_ID`
# if test $CF_JSON == ""; then
#     echo "CloudFront情報取得に失敗しました。"
#     exit 1
# fi
# (3) CloudFrontのドメイン名：FQDNのCNAMEに登録する
# CF_DOMAIN=`echo $CF_JSON | jq -r .Distribution.DomainName`
# if test $CF_DOMAIN == ""; then
#     echo "CloudFrontドメイン名取得に失敗しました。"
#     exit 1
# fi
# (4) CloudFrontのETag値：更新の時に利用
# CF_ETAG=`echo $CF_JSON | jq -r .ETag`
# if test $CF_ETAG == ""; then
#     echo "CloudFront更新用エンティティタグの取得に失敗しました。"
#     exit 1
# fi
# (5) このシェルを実行するEC2インスタンスのグローバルIPアドレス（EIPのように固定IPを想定）
GIP=`aws ec2 describe-instances --instance-id $INSTANCE_ID --query 'Reservations[].Instances[].{PublicIpAddress:PublicIpAddress}' | jq -r .[].PublicIpAddress`
if test $GIP == ""; then
    echo "ERROR: ========= Failed! install-wordpress.sh ========="
    echo "ERROR: EC2インスタンスのグローバルIPアドレス取得に失敗しました。"
    exit 1
fi
# (6) Route53のホストゾーンID
ZONE_ID=`aws route53 list-hosted-zones-by-name --dns-name $DOMAIN | jq .HostedZones[].Id | grep -o "[A-Z0-9]\+"`
if test $ZONE_ID == ""; then
    echo "ERROR: ========= Failed! install-wordpress.sh ========="
    echo "ERROR: Route53ホストゾーンIDの取得に失敗しました。"
    exit 1
fi

# 取得したデータの表示
echo ""
echo "INFO: ========= AWSから取得したデータ ========="
echo "INFO: EC2インスタンスID："$INSTANCE_ID
echo "INFO: EC2インスタンスグローバルIPアドレス："$GIP
# echo "CloudFrontドメイン名："$CF_DOMAIN
# echo "CloudFrontエンティティタグ："$CF_ETAG
echo "INFO: Route53ホストゾーンID："$ZONE_ID
echo ""

# (pend)クライアントとCloudFront間のhttps経路用にDNS登録（FQDN）
# (pend)CloudFrontとOrigin間のhttps経路用にDNS登録（from-cloudfront.FQDN）
# FQDNに対応するAレコードを追加（EC2にはEIPを割り当ててください）
aws route53 change-resource-record-sets --hosted-zone-id $ZONE_ID --change-batch file:///dev/stdin << __CHANGE_BATCH__
{
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "$FQDN.",
        "Type": "A",
        "TTL": 300,
        "ResourceRecords": [
          { "Value": "$GIP" }
        ]
      }
    }
  ]
}
__CHANGE_BATCH__
#    {
#      "Action": "UPSERT",
#      "ResourceRecordSet": {
#        "Name": "$FQDN.",
#        "Type": "CNAME",
#        "TTL": 300,
#        "ResourceRecords": [
#          { "Value": "$CF_DOMAIN" }
#        ]
#      }
#    }

# nginxの設定（まずはLet's Encrypt用に80番を開く）
NGINXCONF=/etc/nginx/conf.d/$FQDN.conf
sudo cat << __NGINX_CONF__ | sudo tee $NGINXCONF > /dev/null
server {
    listen 80;

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
    # server_name $FQDN from-cloudfront.$FQDN;

# nginxの設定が終わったのでnginxを再起動
sudo systemctl restart nginx.service
echo "INFO: DNSの反映およびnginx再起動が完了するまで待ちます・・・"
sleep 10s
RETRY_TIME=0
until dig $FQDN | grep "^$FQDN.*$IP\$" || [ $RETRY_TIME -eq 6 ]; do
   sleep 10s
done
if [ $RETRY_TIME -eq 6 ]; then
    echo "ERROR: ========= Failed! install-wordpress.sh ========="
    echo "ERROR: DNS登録が確認できません。"
    echo "INFO: \`dig $FQDN\` を6回トライしましたがAレコードに$GIPが設定されていることが確認できませんでした。"
    echo "INFO: ＜ここまでの処理結果＞"
    echo "INFO: ・nginxのwebページ公開ディレクトリとして /usr/share/nginx/vhosts/$FQDN を作成済み"
    echo "INFO: ・nginxのvhostコンフィグとして /etc/nginx/conf.d/$FQDN.conf を作成済み"
    exit 1
fi

# nginxにアクセス可能になったので --webroot オプションを用いてSSL証明書を作成
# sudo /usr/local/bin/certbot-auto certonly --webroot -w /usr/share/nginx/vhosts/$FQDN -d from-cloudfront.$FQDN --email $MADDR -n --agree-tos --debug
RETRY_TIME=0
until sudo /usr/local/bin/certbot-auto certonly --webroot -w /usr/share/nginx/vhosts/$FQDN -d $FQDN --email $MADDR -n --agree-tos --debug || [ $RETRY_TIME -eq 6 ]; do
   sleep 10s
done;    
if [ $RETRY_TIME -eq 6 ]; then
    echo "ERROR: ========= Failed! install-wordpress.sh ========="
    echo "ERROR: SSL証明書の作成に失敗しました。"
    echo "INFO: 詳しくは /var/log/letsencrypt/letsencrypt.log をご覧ください。"
    echo "INFO: ＜ここまでの処理結果＞"
    echo "INFO: ・nginxのwebページ公開ディレクトリとして /usr/share/nginx/vhosts/$FQDN を作成済み"
    echo "INFO: ・nginxのvhostコンフィグとして /etc/nginx/conf.d/$FQDN.conf を作成済み"
    echo "INFO: ・Route53に$FQDNに対して$GIPを設定するAレコードを作成済み"
    exit 1
fi
# SSL証明書が作成できたので、SSLが利用できるようにnginxの設定を変更（CloudFront・Origin間）
sudo cat << __NGINX_CONF__ | sudo ruby -e 'f = ARGV[0];lines = File.read(f).gsub(/^    listen 80;\n/, "    listen 80;\n#{STDIN.read}");  File.write(f, lines);' $NGINXCONF
    listen 443 ssl;
    ssl on;
    ssl_certificate     /etc/letsencrypt/live/$FQDN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$FQDN/privkey.pem;
__NGINX_CONF__
    # ssl_certificate     /etc/letsencrypt/live/from-cloudfront.$FQDN/fullchain.pem;
    # ssl_certificate_key /etc/letsencrypt/live/from-cloudfront.$FQDN/privkey.pem;

# WordPress用のデータベースを新規作成
DBNAME=`echo $FQDN | sed s/\\\./_/g | sed s/-/_/g`
mysql -u root -e "CREATE DATABASE $DBNAME DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci;" 

# すべての設定が終わったのでnginxを再起動
sudo systemctl restart nginx.service

# CloudFrontのAlternate Domain Names (CNAMEs)にFQDNを登録
# ALIASES_CNT=`echo $CF_JSON | jq '.Distribution.DistributionConfig.Aliases.Items|length'`
# echo $CF_JSON | jq '.Distribution.DistributionConfig.Aliases.Items['$ALIASES_CNT']|=.+"'$FQDN'"' \
# | jq '.Distribution.DistributionConfig.Aliases.Quantity|=.+1' \
# | jq -r '.Distribution|{ DistributionConfig: .DistributionConfig ,Id: .Id ,IfMatch: "'$CF_ETAG'" }' \
# | xargs -0 aws cloudfront update-distribution --cli-input-json

echo ""
echo "INFO: ========= Complete! install-wordpress.sh ========="
echo "INFO: サイトの初期化およびDNS設定が完了しました。"
echo "INFO: ブラウザで https://$FQDN にアクセスしてWordPressのインストールを開始してください。"
echo "INFO: その時、データベース名は $DBNAME を指定してください。"

exit 0
