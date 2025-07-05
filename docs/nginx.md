以下の手順で、Ubuntu 22.04 上に Nginx を導入しブラウザからアクセスできるように設定します。

---

## 1. Nginx のインストール

```bash
sudo apt update
sudo apt install -y nginx
```

インストール後、自動で起動しているはずです。
念のためステータスを確認：

```bash
sudo systemctl status nginx
```

---

## 2. ファイアウォール（UFW）の確認

もし UFW を有効化している場合、HTTP（80番）を通す：

```bash
sudo ufw allow 'Nginx HTTP'
# または
sudo ufw allow 80/tcp
```

※AWS セキュリティグループでポート 80 が開いていることは既にクリア済みとのことなので、UFW 側の設定のみご確認ください。

---

## 3. デフォルトサイトの確認

デフォルトでは `/var/www/html` に置かれた `index.html` が返されます。
ブラウザで EC2 のパブリック IP またはドメイン名にアクセスして確認：

```
http://<YOUR_PUBLIC_IP>/
```

「Welcome to nginx!」ページが表示されれば成功です。

---

## 4. サイトを自分のコンテンツで置き換える

### 4-1. ドキュメントルートを準備

例として、`/var/www/html` に `index.html` を置き換えます：

```bash
sudo nano /var/www/html/index.html
```

中身を例えばこんな簡易ページにして保存：

```html
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>My Nginx on Ubuntu 22</title>
</head>
<body>
  <h1>Hello from Nginx!</h1>
  <p>Powered by Ubuntu 22 on AWS EC2</p>
</body>
</html>
```

### 4-2. 権限確認

```bash
sudo chown -R www-data:www-data /var/www/html
sudo chmod -R 755 /var/www/html
```

---

## 5. カスタムサーバブロックの作成（任意）

複数サイトやドメイン運用を想定する場合は、`sites-available` にサーバブロックを置き、有効化します。

```bash
sudo nano /etc/nginx/sites-available/my-site.conf
```

以下サンプルを貼り付けて保存：

```nginx
server {
    listen 80;
    server_name example.com www.example.com;    # あなたのドメイン

    root /var/www/my-site/html;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }
}
```

ドキュメントルートを作成し、サンプルページを配置：

```bash
sudo mkdir -p /var/www/my-site/html
echo '<h1>My Custom Site</h1>' | sudo tee /var/www/my-site/html/index.html
sudo chown -R www-data:www-data /var/www/my-site
sudo chmod -R 755 /var/www/my-site
```

有効化 → 無効化されている既存のデフォルトを無効化：

```bash
sudo ln -s /etc/nginx/sites-available/my-site.conf /etc/nginx/sites-enabled/
sudo rm /etc/nginx/sites-enabled/default
```

---

## 6. 設定テスト＆リロード

Nginx の設定に誤りがないかテスト：

```bash
sudo nginx -t
```

問題なければリロード：

```bash
sudo systemctl reload nginx
```

---

## 7. ブラウザからアクセス

* **IPアクセス**

  ```
  http://<YOUR_PUBLIC_IP>/
  ```
* **ドメインアクセス**（DNS設定済みの場合）

  ```
  http://example.com/
  ```

上記で設定したコンテンツが表示されれば完了です。

---

### 🎉 **これで Nginx 経由でブラウザアクセスが可能になりました！**

* 追加で HTTPS 化する場合は Let's Encrypt（`certbot --nginx`）をご検討ください。
* 複数サイトをホストする場合は `sites-available`／`sites-enabled` を使い分けて管理します。
