#!/bin/bash

# AWS設定スクリプト - デバッグ版
# 各ステップの実行結果を明確に表示

set -e  # エラー時にスクリプトを停止

echo "=== AWS設定スクリプト開始 ==="
echo "実行日時: $(date)"
echo ""

# 1. AWS CLI バージョン確認
echo "1. AWS CLI バージョン確認中..."
if aws --version; then
    echo "✅ AWS CLI が正常にインストールされています"
else
    echo "❌ AWS CLI のインストールに問題があります"
    exit 1
fi
echo ""

# 2. AWS設定実行
echo "2. AWS設定を開始します..."
echo "以下の情報を入力してください:"
echo "- AWS Access Key ID"
echo "- AWS Secret Access Key" 
echo "- Default region name (例: us-east-1)"
echo "- Default output format (例: json)"
echo ""

if aws configure; then
    echo "✅ AWS設定が正常に完了しました"
else
    echo "❌ AWS設定中にエラーが発生しました"
    exit 1
fi
echo ""

# 3. 設定内容確認
echo "3. 現在のAWS設定を確認中..."
if aws configure list; then
    echo "✅ 設定内容の確認が完了しました"
else
    echo "❌ 設定内容の確認中にエラーが発生しました"
    exit 1
fi
echo ""

# 4. S3バケット一覧表示（接続テスト）
echo "4. S3バケット一覧を取得中（接続テスト）..."
if aws s3 ls; then
    echo "✅ AWS接続が正常に動作しています"
    echo "利用可能なS3バケット:"
    aws s3 ls --output table
else
    echo "❌ S3バケット一覧の取得に失敗しました"
    echo "設定内容を確認してください"
    exit 1
fi
echo ""

# 5. 現在のAWSアカウント情報確認
echo "5. 現在のAWSアカウント情報を確認中..."
if aws sts get-caller-identity; then
    echo "✅ アカウント情報の取得が完了しました"
else
    echo "❌ アカウント情報の取得に失敗しました"
    exit 1
fi
echo ""

echo "=== AWS設定スクリプト完了 ==="
echo "すべての設定が正常に完了しました！"
echo "実行日時: $(date)"