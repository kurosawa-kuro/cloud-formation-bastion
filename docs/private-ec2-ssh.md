# Private EC2 with Bastion Host - CloudFormation テンプレート

追加対応、プライベートサブネットに配置したEC2にNginxを設置
API Gateway

ドメインを購入せずに AWS 上で “ブラウザ警告が出ない” HTTPS を成立させる方法は、実は **ALB/NLB だけでは到達できません**。
しかし **「AWS が保有する既定ドメイン」** をそのまま使うという割り切りをすれば、追加コストなしで正規の TLS 証明書が付きます。

---

### 1. そもそも ALB/NLB では無理

* HTTPS リスナーには **X.509 証明書を必ずアタッチ**。証明書には FQDN が必要で、`*.elb.amazonaws.com` をカバーする証明書は AWS 側では提供されていません。([docs.aws.amazon.com][1])

---

### 2. 「AWS 既定ドメインをそのまま使う」3 パターン

| パターン | サービス                             | 既定ドメイン例                                             | 仕組み                                                                             |
| ---- | -------------------------------- | --------------------------------------------------- | ------------------------------------------------------------------------------- |
| A    | **CloudFront**                   | `d111111abcdef8.cloudfront.net`                     | `*.cloudfront.net` の証明書が自動添付。独自ドメイン不要でも HTTPS が即時有効([docs.aws.amazon.com][2])   |
| B    | **API Gateway** (REST/HTTP)      | `abcd1234.execute-api.ap-northeast-1.amazonaws.com` | `execute-api` ドメインは API Gateway が証明書を管理し、常に HTTPS で公開([docs.aws.amazon.com][3]) |
| C    | **Amplify/Cognito Hosted UI** など | サービス固有サブドメイン                                        | 背後で CloudFront を利用しており同様に証明書自動付与                                                |

> URL が長くなっても構わない PoC であれば、このどれかを採用するのが最速。

---

### 3. 内向き PoC 専用: 自己署名証明書 + SSH ポートフォワード

* EC2 に Nginx を置き、`openssl` で自己署名証明書を作成して 443 を開放
* 踏み台経由で `ssh -L 8443:10.0.1.10:443 …`
* ブラウザで `https://localhost:8443` を開けば暗号化通信は確認できる（警告は無視）

完全無料・ドメイン不要だが、警告を許容できるメンバー限定の検証向け。

---

### 4. 選択早見表

| 要件                 | 推奨方式                   |
| ------------------ | ---------------------- |
| 外部公開／警告なし／ドメイン買わない | **CloudFront 既定ドメイン**  |
| API だけ公開／ドメイン買わない  | **API Gateway 既定ドメイン** |
| 社内限定／踏み台経由で十分      | **自己署名 + ポートフォワード**    |

---

### 5. CloudFront 例 ─ 最小手順

```bash
# S3 を静的オリジン化
aws s3 mb s3://my-poc-site
aws s3 cp index.html s3://my-poc-site --acl public-read

# CloudFront ディストリビューション作成
aws cloudfront create-distribution \
  --origin-domain-name my-poc-site.s3.amazonaws.com \
  --default-root-object index.html \
  --query 'Distribution.DomainName'
# => d111111abcdef8.cloudfront.net

# 数分後にブラウザで https://d111111abcdef8.cloudfront.net
```

ACM、Route 53、ドメイン購入は一切不要。

---

## ✅ 結論

* **ALB だけで“証明書レス”HTTPSは物理的に不可**。
* **ドメイン購入ゼロで警告なし HTTPS** を実現したいなら

  1. **CloudFront** 既定ドメイン
  2. **API Gateway** 既定ドメイン
     が王道（いずれも AWS 側がワイルドカード証明書を保有）。([docs.aws.amazon.com][2], [docs.aws.amazon.com][3])
* 完全クローズドな検証なら自己署名でも OK。

CloudFront / API Gateway の Terraform テンプレートや Nginx SSL 設定スニペットが必要なら、いつでも声をかけてください！

[1]: https://docs.aws.amazon.com/elasticloadbalancing/latest/application/https-listener-certificates.html "SSL certificates for your Application Load Balancer - Elastic Load Balancing"
[2]: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/DownloadDistValuesGeneral.html "Distribution settings - Amazon CloudFront"
[3]: https://docs.aws.amazon.com/apigateway/latest/developerguide/data-protection-encryption.html "Data encryption in Amazon API Gateway - Amazon API Gateway"


以下、**「Nginx設置 → ブラウザアクセス可能化」** を
現在の **private EC2 +踏み台 + ALB構造** に準拠しつつ **AWS CloudFormationで実現する方法** をわかりやすく整理します。

---

## 1️⃣ 前提（現状）

* プライベートサブネット内に **Nginxを設置したEC2** がいる
* このEC2には **Public IPがなく直接外部アクセス不可**
* 現状は踏み台経由でのみSSH可能

---

## 2️⃣ 目標

* **外部ブラウザから直接Nginx（HTTP:80）へアクセス可能にする**
* ただし **privateサブネットのままで運用（Public IPを付与しない）**

---

## 3️⃣ 実現アプローチ

### ✅ **ALB (Application Load Balancer) を配置する**

ALBはPublicサブネットに配置し、インターネット経由でHTTP(80)をリスン。
ターゲットグループには **privateサブネット内のNginx EC2** を登録。

ブラウザからのフロー：

```
Client Browser
     ↓
ALB (Public Subnet, Public IP, HTTP:80)
     ↓
Nginx EC2 (Private Subnet, Private IP, HTTP:80)
```

---

## 4️⃣ ALB構築時に必要なリソース

✅ **ALB**

* Public Subnetに配置
* Internet-facing（Public IP持ち）
* HTTP (Port 80) Listener設定

✅ **Target Group**

* ターゲット：プライベートサブネットのNginx EC2 (HTTP:80)
* ヘルスチェックパス `/`（またはNginxの任意のヘルスエンドポイント）

✅ **Security Groups**

* ALB SG:

  * `0.0.0.0/0` からの `Port 80` を許可
* Private EC2 SG:

  * ALB SG からの `Port 80` を許可

---

## 5️⃣ CloudFormation実装フロー

1️⃣ VPC・Public Subnet・Private Subnet（すでに作成済）
2️⃣ ALB作成（`AWS::ElasticLoadBalancingV2::LoadBalancer`）
3️⃣ ALB用SG作成（HTTP:80を開放）
4️⃣ Target Group作成（`AWS::ElasticLoadBalancingV2::TargetGroup`）
5️⃣ ALB Listener作成（`AWS::ElasticLoadBalancingV2::Listener`）
6️⃣ Private EC2 SGにALB SGからのHTTP(80)許可ルール追加
7️⃣ プライベートサブネットに配置したNginx EC2をターゲットグループに登録

---

## 6️⃣ 運用イメージ

✅ ALBのDNS名をブラウザに入力
✅ HTTPリクエストがALBへ到達
✅ ALBがターゲットグループ（Nginx EC2）へHTTP(80)で転送
✅ Nginxがレスポンスを返す
✅ ALB経由でブラウザに返答

---

## 7️⃣ メリット

✅ プライベートサブネットにPublic IP不要でセキュリティを確保
✅ ALB経由の可用性・拡張性（複数EC2構成、AutoScaling対応可）
✅ CloudFormationによりIaCで再現性確保

---

## まとめ

「Nginx設置 → ブラウザアクセス可能化」を踏み台不要で実現するには：

✅ **ALBをPublic Subnetに配置し、ALB経由でPrivate SubnetのNginxへ転送する**

これが **最適かつ企業PoC・本番向けのベストプラクティス** です。

---

## 🚀 次アクション

この理解の上で、
✅ **即適用可能な CloudFormation YAMLサンプル**
✅ **CLIテスト手順**

を作成可能です。
**必要であれば「作成OK」とだけお伝えください。即作成に移行します。**


## 概要

このCloudFormationテンプレートは、セキュアなプライベートEC2環境を構築します。Bastionホストを経由してプライベートサブネット内のEC2インスタンスにSSHアクセスできる構成です。

## アーキテクチャ

```
Internet
    │
    ▼
┌─────────────────┐
│  Bastion Host   │ ← パブリックサブネット (10.0.1.0/24)
│  (Public IP)    │
└─────────────────┘
    │
    ▼
┌─────────────────┐
│ Private EC2     │ ← プライベートサブネット (10.0.2.0/24)
│ (Private IP)    │
└─────────────────┘
```

## 作成されるリソース

### ネットワーク
- **VPC**: `10.0.0.0/16`
- **パブリックサブネット**: `10.0.1.0/24` (Bastionホスト用)
- **プライベートサブネット**: `10.0.2.0/24` (プライベートEC2用)
- **インターネットゲートウェイ**: パブリックサブネット用
- **ルートテーブル**: パブリックサブネット用

### セキュリティ
- **Bastionセキュリティグループ**: SSH (22) を指定IPからのみ許可
- **プライベートセキュリティグループ**: SSH (22) をBastionホストからのみ許可

### インスタンス
- **Bastionホスト**: Ubuntu 22.04 LTS (パブリックサブネット)
- **プライベートEC2**: Ubuntu 22.04 LTS (プライベートサブネット)

## パラメータ

| パラメータ名 | 型 | デフォルト | 説明 |
|-------------|----|-----------|------|
| `KeyName` | AWS::EC2::KeyPair::KeyName | - | SSHアクセス用の既存キーペア名 |
| `InstanceType` | String | `t3.micro` | EC2インスタンスタイプ |
| `AllowedSSHCidr` | String | `0.0.0.0/0` | SSHアクセスを許可するCIDRブロック |
| `Environment` | String | `dev` | 環境名 (dev/staging/prod) |

## 使用方法

### 1. 前提条件

- AWS CLIが設定済み
- 既存のキーペアが作成済み
- 東京リージョン (ap-northeast-1) で使用

### 2. 自動化スクリプト（推奨）

#### 環境変数ファイルの作成

```bash
# 環境変数ファイルを作成
./script/create-env.sh <environment> <stack-name> <key-name> <allowed-cidr> [instance-type]

# 例
./script/create-env.sh dev private-ec2-stack my-key-pair 61.27.85.98/32 t3.micro
```

#### 改善されたデプロイスクリプト

```bash
# テンプレートの検証
./script/deploy.sh --env dev --validate-only

# スタックのデプロイ
./script/deploy.sh --env dev --deploy

# スタックの削除
./script/deploy.sh --env dev --destroy
```

#### 接続テスト自動化

```bash
# Bastionホストの接続テスト
./script/connection-test.sh --env dev --bastion-only

# 完全な接続テスト（Bastion + プライベート）
./script/connection-test.sh --env dev --full-test
```

### 3. 従来のデプロイ方法

#### 自動デプロイスクリプトを使用

```bash
# デプロイスクリプトを実行
./script/deploy.sh <stack-name> <key-name> <allowed-cidr>

# 例
./script/deploy.sh private-ec2-stack my-key-pair 203.0.113.0/24
```

#### 手動デプロイ

```bash
# スタック作成
aws cloudformation create-stack \
  --stack-name private-ec2-stack \
  --template-body file://src/private-ec2-ssh.yaml \
  --parameters ParameterKey=KeyName,ParameterValue=my-key-pair \
               ParameterKey=AllowedSSHCidr,ParameterValue=203.0.113.0/24 \
               ParameterKey=Environment,ParameterValue=dev \
  --region ap-northeast-1

# スタック作成完了を待機
aws cloudformation wait stack-create-complete \
  --stack-name private-ec2-stack \
  --region ap-northeast-1
```

### 3. 出力値の確認

```bash
# スタック出力値を表示
aws cloudformation describe-stacks \
  --stack-name private-ec2-stack \
  --region ap-northeast-1 \
  --query 'Stacks[0].Outputs' \
  --output table
```

## SSH接続

### Bastionホストへの接続

```bash
# キーペアの権限を設定
chmod 400 data/my-key-pair.pem

# Bastionホストに接続
ssh -i data/my-key-pair.pem ubuntu@<BastionPublicIP>
```

### プライベートインスタンスへの接続

#### 方法1: キーペアファイルを転送してから接続（推奨）

```bash
# 1. キーペアファイルをBastionホストに転送
scp -i data/my-key-pair.pem data/my-key-pair.pem ubuntu@<BastionPublicIP>:~/

# 2. Bastionホストに接続
ssh -i data/my-key-pair.pem ubuntu@<BastionPublicIP>

# 3. Bastionホスト上でプライベートインスタンスに接続
ssh -i my-key-pair.pem ubuntu@<PrivateIP>
```

#### 方法2: SSH ProxyJumpを使用

```bash
# ローカルから直接プライベートインスタンスに接続（キーペアファイルが必要）
ssh -i data/my-key-pair.pem ubuntu@<PrivateIP> -J ubuntu@<BastionPublicIP>
```

#### 方法3: SSH Config設定（便利）

```bash
# ~/.ssh/config に以下を追加
Host bastion
    HostName <BastionPublicIP>
    User ubuntu
    IdentityFile ~/path/to/my-key-pair.pem

Host private-ec2
    HostName <PrivateIP>
    User ubuntu
    IdentityFile ~/path/to/my-key-pair.pem
    ProxyJump bastion

# 使用例
ssh bastion      # Bastionホストに接続
ssh private-ec2  # プライベートインスタンスに接続

### 実際の接続例

```bash
# キーペアファイルをBastionホストに転送
scp -i data/my-key-pair.pem data/my-key-pair.pem ubuntu@54.199.35.225:~/

# Bastionホストに接続
ssh -i data/my-key-pair.pem ubuntu@54.199.35.225

# Bastionホスト上でプライベートインスタンスに接続
ssh -i my-key-pair.pem ubuntu@10.0.2.211
```

## セキュリティ考慮事項

### 推奨設定

1. **IP制限**: `AllowedSSHCidr`を特定のIPアドレスまたはCIDRブロックに制限
2. **キーペア管理**: キーペアファイルを安全に保管
3. **定期的な更新**: Ubuntu 22.04 LTSのセキュリティアップデートを適用

### セキュリティグループ

- **Bastion**: 指定IPからのSSH (22) のみ許可
- **プライベート**: BastionホストからのSSH (22) のみ許可

## トラブルシューティング

### よくある問題

1. **AMI IDエラー**
   - 東京リージョンで利用可能なUbuntu 22.04 LTSのAMI IDを確認
   - 現在使用中: `ami-07b3f199a3bed006a`

2. **セキュリティグループエラー**
   - セキュリティグループの説明はASCII文字のみ使用
   - 日本語文字は使用不可

3. **SSH接続エラー**
   - キーペアファイルの権限を確認 (`chmod 400`)
   - 許可IPアドレスを確認
   - インスタンスの起動完了を確認
   - プライベートインスタンス接続時はキーペアファイルをBastionホストに転送が必要

### ログ確認

```bash
# CloudFormationイベントを確認
aws cloudformation describe-stack-events \
  --stack-name private-ec2-stack \
  --region ap-northeast-1 \
  --query 'StackEvents[?ResourceStatus==`CREATE_FAILED`]' \
  --output table
```

## クリーンアップ

```bash
# スタック削除
aws cloudformation delete-stack \
  --stack-name private-ec2-stack \
  --region ap-northeast-1

# 削除完了を待機
aws cloudformation wait stack-delete-complete \
  --stack-name private-ec2-stack \
  --region ap-northeast-1
```

## カスタマイズ

### インスタンスタイプの変更

```bash
# より大きなインスタンスタイプを使用
aws cloudformation update-stack \
  --stack-name private-ec2-stack \
  --template-body file://src/private-ec2-ssh.yaml \
  --parameters ParameterKey=KeyName,ParameterValue=my-key-pair \
               ParameterKey=InstanceType,ParameterValue=t3.small \
               ParameterKey=AllowedSSHCidr,ParameterValue=203.0.113.0/24 \
  --region ap-northeast-1
```

### 環境別デプロイ

```bash
# 本番環境用
./script/deploy.sh prod-private-ec2-stack my-key-pair 203.0.113.0/24

# ステージング環境用
./script/deploy.sh staging-private-ec2-stack my-key-pair 203.0.113.0/24
```

## 参考情報

- [AWS CloudFormation ユーザーガイド](https://docs.aws.amazon.com/ja_jp/AWSCloudFormation/latest/UserGuide/)
- [Amazon EC2 セキュリティグループ](https://docs.aws.amazon.com/ja_jp/AWSEC2/latest/UserGuide/ec2-security-groups.html)
- [Ubuntu 22.04 LTS AMI](https://ubuntu.com/server/docs/cloud-images/amazon-ec2)

## ライセンス

このテンプレートはMITライセンスの下で提供されています。
