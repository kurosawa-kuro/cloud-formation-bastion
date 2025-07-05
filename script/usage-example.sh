#!/bin/bash

# 改善されたスクリプトの使用例
# このファイルは実行例を示すためのものです

echo "=== CloudFormation Private EC2 自動化スクリプト使用例 ==="
echo ""

echo "1. 環境変数ファイルの作成"
echo "   ./script/create-env.sh dev private-ec2-stack my-key-pair 203.0.113.0/24 t3.micro"
echo ""

echo "2. テンプレートの検証"
echo "   ./script/deploy-enhanced.sh --env dev --validate-only"
echo ""

echo "3. スタックのデプロイ"
echo "   ./script/deploy-enhanced.sh --env dev --deploy"
echo ""

echo "4. Bastionホストの接続テスト"
echo "   ./script/connection-test.sh --env dev --bastion-only"
echo ""

echo "5. 完全な接続テスト"
echo "   ./script/connection-test.sh --env dev --full-test"
echo ""

echo "6. スタックの削除"
echo "   ./script/deploy-enhanced.sh --env dev --destroy"
echo ""

echo "=== 実際の使用例 ==="
echo ""

# 現在のIPアドレスを取得
CURRENT_IP=$(curl -4 -s ifconfig.me 2>/dev/null || echo "203.0.113.0")

echo "現在のIPアドレス: $CURRENT_IP"
echo ""

echo "# 1. 環境変数ファイル作成"
echo "./script/create-env.sh dev private-ec2-stack my-key-pair ${CURRENT_IP}/32 t3.micro"
echo ""

echo "# 2. デプロイ"
echo "./script/deploy-enhanced.sh --env dev --deploy"
echo ""

echo "# 3. 接続テスト"
echo "./script/connection-test.sh --env dev --full-test"
echo ""

echo "=== 環境別デプロイ例 ==="
echo ""

echo "# 開発環境"
echo "./script/create-env.sh dev dev-private-ec2 my-key-pair ${CURRENT_IP}/32 t3.micro"
echo "./script/deploy-enhanced.sh --env dev --deploy"
echo ""

echo "# ステージング環境"
echo "./script/create-env.sh staging staging-private-ec2 my-key-pair ${CURRENT_IP}/32 t3.small"
echo "./script/deploy-enhanced.sh --env staging --deploy"
echo ""

echo "# 本番環境"
echo "./script/create-env.sh prod prod-private-ec2 my-key-pair ${CURRENT_IP}/32 t3.medium"
echo "./script/deploy-enhanced.sh --env prod --deploy"
echo ""

echo "=== トラブルシューティング ==="
echo ""

echo "# ログファイルの確認"
echo "tail -f logs/deploy-dev-*.log"
echo ""

echo "# スタック状態の確認"
echo "aws cloudformation describe-stacks --stack-name private-ec2-stack --region ap-northeast-1"
echo ""

echo "# セキュリティグループの確認"
echo "aws ec2 describe-security-groups --filters Name=group-name,Values=dev-bastion-sg --region ap-northeast-1"
echo "" 