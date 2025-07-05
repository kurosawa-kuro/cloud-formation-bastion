#!/bin/bash

# 環境変数ファイル作成スクリプト
# 使用方法: ./create-env.sh <environment> <stack-name> <key-name> <allowed-cidr> [instance-type]

set -e

# パラメータチェック
if [ $# -lt 4 ]; then
    echo "使用方法: $0 <environment> <stack-name> <key-name> <allowed-cidr> [instance-type]"
    echo "例: $0 dev private-ec2-stack my-key-pair 203.0.113.0/24 t3.micro"
    exit 1
fi

ENVIRONMENT=$1
STACK_NAME=$2
KEY_NAME=$3
ALLOWED_CIDR=$4
INSTANCE_TYPE=${5:-t3.micro}

# 環境変数ファイル作成
cat > .env.${ENVIRONMENT} << EOF
# CloudFormation Private EC2 Environment Configuration
# Generated on: $(date)

# 基本設定
ENVIRONMENT=${ENVIRONMENT}
STACK_NAME=${STACK_NAME}
KEY_NAME=${KEY_NAME}
ALLOWED_CIDR=${ALLOWED_CIDR}
INSTANCE_TYPE=${INSTANCE_TYPE}

# AWS設定
AWS_REGION=ap-northeast-1
TEMPLATE_FILE=src/private-ec2-ssh.yaml

# キーペアファイルパス
KEY_FILE=data/my-key-pair.pem

# 出力ファイル
LOG_FILE=logs/deploy-${ENVIRONMENT}-$(date +%Y%m%d-%H%M%S).log
EOF

echo "✓ 環境変数ファイル .env.${ENVIRONMENT} を作成しました"
echo ""
echo "設定内容:"
echo "  環境: ${ENVIRONMENT}"
echo "  スタック名: ${STACK_NAME}"
echo "  キーペア名: ${KEY_NAME}"
echo "  許可CIDR: ${ALLOWED_CIDR}"
echo "  インスタンスタイプ: ${INSTANCE_TYPE}"
echo ""

# ログディレクトリ作成
mkdir -p logs

# キーペアファイルの存在確認
if [ ! -f "$KEY_FILE" ]; then
    echo "⚠️  警告: キーペアファイル $KEY_FILE が見つかりません"
    echo "キーペアファイルを $KEY_FILE に配置してください"
else
    echo "✓ キーペアファイル $KEY_FILE を確認しました"
    # 権限を設定
    chmod 400 "$KEY_FILE"
fi

echo ""
echo "次のコマンドでデプロイできます:"
echo "  ./script/deploy-enhanced.sh --env ${ENVIRONMENT} --validate-only"
echo "  ./script/deploy-enhanced.sh --env ${ENVIRONMENT} --deploy" 