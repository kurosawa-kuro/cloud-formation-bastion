# CloudFormation Private EC2 with Bastion Host

セキュアなプライベートEC2環境を構築するためのCloudFormationテンプレートと自動化スクリプトのコレクションです。

## 🏗️ アーキテクチャ

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

## ✨ 主な機能

- **セキュアなSSHアクセス**: Bastionホスト経由でのプライベートインスタンスアクセス
- **環境分離**: dev/staging/prod環境の分離対応
- **自動化スクリプト**: ワンクリックデプロイと接続テスト
- **Ubuntu 22.04 LTS**: 最新のLTS版を使用
- **東京リージョン対応**: ap-northeast-1専用最適化
- **接続テスト自動化**: SSH接続とネットワーク疎通確認

## 📁 プロジェクト構成

```
cloud-formation-eks/
├── src/
│   └── private-ec2-ssh.yaml          # CloudFormationテンプレート
├── script/
│   ├── create-env.sh                 # 環境変数ファイル作成
│   ├── deploy.sh                     # デプロイスクリプト
│   ├── connection-test.sh            # 接続テスト自動化
│   └── usage-example.sh              # 使用例
├── docs/
│   └── private-ec2-ssh.md            # 詳細ドキュメント
├── data/
│   └── my-key-pair.pem               # SSHキーペアファイル
└── logs/                             # デプロイログ（自動作成）
```

## 🚀 クイックスタート

### 1. 前提条件

```bash
# AWS CLIの確認
aws --version

# AWS認証情報の設定
aws configure

# 認証情報の確認
aws configure list

# S3バケットの確認
aws s3 ls
```

### 2. 環境変数ファイルの作成

```bash
# 現在のIPアドレスを取得
CURRENT_IP=$(curl -4 -s ifconfig.me)

# 環境変数ファイルを作成
./script/create-env.sh dev private-ec2-stack my-key-pair ${CURRENT_IP}/32 t3.micro
```

### 3. デプロイ

```bash
# テンプレートの検証
./script/deploy.sh --env dev --validate-only

# スタックのデプロイ
./script/deploy.sh --env dev --deploy
```

### 4. 接続テスト

```bash
# 完全な接続テスト
./script/connection-test.sh --env dev --full-test
```

## 📖 詳細な使用方法

### 自動化スクリプト（推奨）

#### 環境変数ファイルの作成

```bash
./script/create-env.sh <environment> <stack-name> <key-name> <allowed-cidr> [instance-type]

# 例
./script/create-env.sh dev private-ec2-stack my-key-pair 203.0.113.0/24 t3.micro
```

#### デプロイスクリプト

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



## 🔧 環境別デプロイ

### 開発環境

```bash
./script/create-env.sh dev dev-private-ec2 my-key-pair 203.0.113.0/24 t3.micro
./script/deploy.sh --env dev --deploy
```

### ステージング環境

```bash
./script/create-env.sh staging staging-private-ec2 my-key-pair 203.0.113.0/24 t3.small
./script/deploy.sh --env staging --deploy
```

### 本番環境

```bash
./script/create-env.sh prod prod-private-ec2 my-key-pair 203.0.113.0/24 t3.medium
./script/deploy.sh --env prod --deploy
```

## 🔐 SSH接続

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
# ローカルから直接プライベートインスタンスに接続
ssh -i data/my-key-pair.pem ubuntu@<PrivateIP> -J ubuntu@<BastionPublicIP>
```

### 実際の接続例

```bash
# キーペアファイルをBastionホストに転送
scp -i data/my-key-pair.pem data/my-key-pair.pem ubuntu@54.199.35.225:~/

# Bastionホストに接続
ssh -i data/my-key-pair.pem ubuntu@54.199.35.225

# Bastionホスト上でプライベートインスタンスに接続
ssh -i my-key-pair.pem ubuntu@10.0.2.211
```

## 🛠️ トラブルシューティング

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

4. **pingテストの失敗**
   - セキュリティグループでICMPが制限されているため、pingテストは失敗する場合があります
   - 接続テストスクリプトでは、pingテストの失敗を警告として扱い、SSH接続テストを優先します

### ログ確認

```bash
# ログファイルの確認
tail -f logs/deploy-dev-*.log

# CloudFormationイベントを確認
aws cloudformation describe-stack-events \
  --stack-name private-ec2-stack \
  --region ap-northeast-1 \
  --query 'StackEvents[?ResourceStatus==`CREATE_FAILED`]' \
  --output table
```

## 🧹 クリーンアップ

```bash
# スタック削除
./script/deploy.sh --env dev --destroy

# または手動で削除
aws cloudformation delete-stack \
  --stack-name private-ec2-stack \
  --region ap-northeast-1
```

## 🔄 スクリプトの改善点

### 最新の改善内容

1. **キーペアファイルの固定パス**: `data/my-key-pair.pem`に統一
2. **権限設定の自動化**: スクリプト実行時にキーペアファイルの権限を自動設定
3. **存在確認の追加**: 必要なファイルやディレクトリの存在確認
4. **pingテストの修正**: ICMP制限により失敗するpingテストをSSH接続テストに置き換え
5. **エラーハンドリングの改善**: より詳細なエラーメッセージとログ出力

### 使用例スクリプト

```bash
# 完全な使用例を実行
./script/usage-example.sh

# 出力例:
# ✅ 環境変数ファイル作成: 成功
# ✅ テンプレート検証: 成功
# ✅ スタックデプロイ: 成功
# ✅ Bastionホスト接続テスト: 成功
# ✅ プライベートインスタンス接続テスト: 成功
# ✅ SSH接続テスト: 成功
```

## 📚 詳細ドキュメント

詳細な使用方法とトラブルシューティングについては、[docs/private-ec2-ssh.md](docs/private-ec2-ssh.md) を参照してください。

## 🚀 今後の拡張予定

この基盤環境を活用した以下の拡張を検討中です：

- **EKS (Elastic Kubernetes Service)**: コンテナオーケストレーション
- **RDS (Relational Database Service)**: マネージドデータベース
- **ALB (Application Load Balancer)**: ロードバランシング
- **Auto Scaling**: 自動スケーリング
- **CI/CD Pipeline**: 継続的インテグレーション/デプロイメント

## 🤝 貢献

1. このリポジトリをフォーク
2. 機能ブランチを作成 (`git checkout -b feature/amazing-feature`)
3. 変更をコミット (`git commit -m 'Add amazing feature'`)
4. ブランチにプッシュ (`git push origin feature/amazing-feature`)
5. プルリクエストを作成

## 📄 ライセンス

このプロジェクトはMITライセンスの下で公開されています。詳細は [LICENSE](LICENSE) ファイルを参照してください。

## 🆘 サポート

問題が発生した場合や質問がある場合は、以下の方法でサポートを受けることができます：

1. [Issues](../../issues) でバグを報告
2. [Discussions](../../discussions) で質問を投稿
3. 詳細ドキュメントを確認: [docs/private-ec2-ssh.md](docs/private-ec2-ssh.md)

---

**注意**: このテンプレートは東京リージョン (ap-northeast-1) 専用です。他のリージョンで使用する場合は、AMI IDを適切に変更してください。