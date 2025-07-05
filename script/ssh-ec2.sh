#!/bin/bash

# AWS設定スクリプト - デバッグ版
# 各ステップの実行結果を明確に表示

set -e  # エラー時にスクリプトを停止

# ========================================
# 設定定数
# ========================================
EC2_PUBLIC_DNS="ec2-13-114-167-182.ap-northeast-1.compute.amazonaws.com"
EC2_USER="ubuntu"
KEY_NAME="my-key-pair.pem"

# スクリプトのディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
KEY_FILE="$PROJECT_ROOT/data/$KEY_NAME"

echo "=== SSH EC2開始 ==="
echo "EC2インスタンス: $EC2_PUBLIC_DNS"
echo "ユーザー: $EC2_USER"
echo "キーファイル: $KEY_FILE"

# キーファイルの存在確認
if [ ! -f "$KEY_FILE" ]; then
    echo "エラー: キーファイルが見つかりません: $KEY_FILE"
    exit 1
fi

# キーファイルのパーミッション確認
if [ "$(stat -c %a "$KEY_FILE")" != "600" ]; then
    echo "キーファイルのパーミッションを修正中..."
    chmod 600 "$KEY_FILE"
fi

echo "EC2インスタンスに接続中..."
ssh -i "$KEY_FILE" "$EC2_USER@$EC2_PUBLIC_DNS"