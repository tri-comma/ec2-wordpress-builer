# ec2-wordpress-builer
AWSのEC2上にWordPress環境を作成するためのスクリプト

## 使い方

### 1. EC2の起動

1. AWS ConsoleでEC2を新規作成します。
1. AMIは `Amazon Linux 2` を選択してください。
1. 他の項目は任意に設定して、起動してください。
1. sshで起動したEC2にログインします。
```
ssh -i xxx.pem ec2-user@www.hogehoge.com
```

### 2. Nginx1.x / PHP7.2 / MariaDB10のインストール

1. 以下のコマンドを実行してください。
```
cd ~
wget https://github.com/tri-comma/ec2-wordpress-builer/install-lnmp.sh
chmod 744 install-lnmp.sh
./install-lnmp.sh
```
2. ブラウザでページが参照できるか確認してください。
```
http://www.hogehoge.com
```

### 3. WordPressのインストール

1. 以下のコマンドを実行してください。
（最後のシェル実行では新規サイトのFQDNを指定します）
```
cd ~
wget https://github.com/tri-comma/ec2-wordpress-builer/install-wordpress.sh
chmod 744 install-wordpress.sh
./install-wordpress.sh www.hogehoge.com
```
2. ブラウザでWordPressのインストールを開始してください。
```
http://www.hogehoge.com
```
- データベース名：FQDNのドットおよびハイフンをアンダースコアに変換した名称
- ユーザ名：root
- パスワード：なし
- ホスト名：localhost
- テーブル接頭子：wp_（任意に設定可能）