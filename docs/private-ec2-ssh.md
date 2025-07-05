# Private EC2 with Bastion Host - CloudFormation テンプレート

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
