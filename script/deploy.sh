#!/bin/bash

# 改善されたCloudFormation デプロイスクリプト
# 使用方法: ./deploy-enhanced.sh --env <environment> [--validate-only|--deploy|--destroy]

set -e

# ヘルプ表示
show_help() {
    echo "使用方法: $0 [OPTIONS]"
    echo ""
    echo "オプション:"
    echo "  --env <environment>      環境名 (dev/staging/prod)"
    echo "  --validate-only          テンプレートの検証のみ実行"
    echo "  --deploy                 スタックをデプロイ"
    echo "  --destroy                スタックを削除"
    echo "  --help                   このヘルプを表示"
    echo ""
    echo "例:"
    echo "  $0 --env dev --validate-only"
    echo "  $0 --env dev --deploy"
    echo "  $0 --env prod --destroy"
}

# 環境変数ファイル読み込み
load_env() {
    local env=$1
    local env_file=".env.${env}"
    
    if [ ! -f "$env_file" ]; then
        echo "エラー: 環境変数ファイル $env_file が見つかりません"
        echo "先に ./script/create-env.sh を実行してください"
        exit 1
    fi
    
    echo "✓ 環境変数ファイル $env_file を読み込み中..."
    source "$env_file"
    
    # 必須変数の確認
    local required_vars=("STACK_NAME" "KEY_NAME" "ALLOWED_CIDR")
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            echo "エラー: 必須変数 $var が設定されていません"
            exit 1
        fi
    done
}

# テンプレート検証
validate_template() {
    echo "=== テンプレート検証 ==="
    echo "テンプレートファイル: $TEMPLATE_FILE"
    
    if aws cloudformation validate-template --template-body "file://$TEMPLATE_FILE" --region "$AWS_REGION" > /dev/null 2>&1; then
        echo "✓ テンプレート検証成功"
    else
        echo "✗ テンプレート検証失敗"
        exit 1
    fi
}

# キーペア確認
check_keypair() {
    echo "=== キーペア確認 ==="
    echo "キーペア名: $KEY_NAME"
    
    if aws ec2 describe-key-pairs --key-names "$KEY_NAME" --region "$AWS_REGION" > /dev/null 2>&1; then
        echo "✓ キーペア '$KEY_NAME' が見つかりました"
    else
        echo "✗ キーペア '$KEY_NAME' が見つかりません"
        echo "既存のキーペア一覧:"
        aws ec2 describe-key-pairs --region "$AWS_REGION" --query 'KeyPairs[*].KeyName' --output table
        exit 1
    fi
}

# スタックデプロイ
deploy_stack() {
    echo "=== スタックデプロイ ==="
    echo "スタック名: $STACK_NAME"
    echo "環境: $ENVIRONMENT"
    echo "許可CIDR: $ALLOWED_CIDR"
    echo "インスタンスタイプ: $INSTANCE_TYPE"
    echo ""
    
    # スタックの存在確認
    if aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$AWS_REGION" > /dev/null 2>&1; then
        echo "スタック '$STACK_NAME' は既に存在します。更新しますか？ (y/N)"
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            echo "スタックを更新中..."
            aws cloudformation update-stack \
                --stack-name "$STACK_NAME" \
                --template-body "file://$TEMPLATE_FILE" \
                --parameters ParameterKey=KeyName,ParameterValue="$KEY_NAME" \
                             ParameterKey=AllowedSSHCidr,ParameterValue="$ALLOWED_CIDR" \
                             ParameterKey=InstanceType,ParameterValue="$INSTANCE_TYPE" \
                             ParameterKey=Environment,ParameterValue="$ENVIRONMENT" \
                --region "$AWS_REGION" | tee -a "$LOG_FILE"
            
            echo "スタック更新完了を待機中..."
            aws cloudformation wait stack-update-complete --stack-name "$STACK_NAME" --region "$AWS_REGION"
        else
            echo "デプロイをキャンセルしました"
            exit 0
        fi
    else
        echo "新しいスタックを作成中..."
        aws cloudformation create-stack \
            --stack-name "$STACK_NAME" \
            --template-body "file://$TEMPLATE_FILE" \
            --parameters ParameterKey=KeyName,ParameterValue="$KEY_NAME" \
                         ParameterKey=AllowedSSHCidr,ParameterValue="$ALLOWED_CIDR" \
                         ParameterKey=InstanceType,ParameterValue="$INSTANCE_TYPE" \
                         ParameterKey=Environment,ParameterValue="$ENVIRONMENT" \
            --region "$AWS_REGION" | tee -a "$LOG_FILE"
        
        echo "スタック作成完了を待機中..."
        aws cloudformation wait stack-create-complete --stack-name "$STACK_NAME" --region "$AWS_REGION"
    fi
}

# スタック削除
destroy_stack() {
    echo "=== スタック削除 ==="
    echo "スタック名: $STACK_NAME"
    echo ""
    
    echo "警告: この操作によりすべてのリソースが削除されます。"
    echo "続行しますか？ (yes/NO)"
    read -r response
    if [[ "$response" != "yes" ]]; then
        echo "削除をキャンセルしました"
        exit 0
    fi
    
    echo "スタックを削除中..."
    aws cloudformation delete-stack --stack-name "$STACK_NAME" --region "$AWS_REGION" | tee -a "$LOG_FILE"
    
    echo "削除完了を待機中..."
    aws cloudformation wait stack-delete-complete --stack-name "$STACK_NAME" --region "$AWS_REGION"
    echo "✓ スタック削除完了"
}

# 出力表示
show_outputs() {
    echo ""
    echo "=== デプロイ完了 ==="
    echo "スタック出力値:"
    aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --region "$AWS_REGION" \
        --query 'Stacks[0].Outputs' \
        --output table | tee -a "$LOG_FILE"
    
    echo ""
    echo "SSH接続例:"
    local bastion_ip=$(aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --region "$AWS_REGION" \
        --query 'Stacks[0].Outputs[?OutputKey==`BastionPublicIP`].OutputValue' \
        --output text)
    
    local private_ip=$(aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --region "$AWS_REGION" \
        --query 'Stacks[0].Outputs[?OutputKey==`PrivateInstancePrivateIP`].OutputValue' \
        --output text)
    
    echo "Bastionホスト: ssh -i $KEY_FILE ubuntu@$bastion_ip"
    echo "プライベートインスタンス: ssh -i $KEY_FILE ubuntu@$private_ip -J ubuntu@$bastion_ip"
    echo ""
    echo "ログファイル: $LOG_FILE"
}

# メイン処理
main() {
    local env=""
    local action=""
    
    # 引数解析
    while [[ $# -gt 0 ]]; do
        case $1 in
            --env)
                env="$2"
                shift 2
                ;;
            --validate-only)
                action="validate"
                shift
                ;;
            --deploy)
                action="deploy"
                shift
                ;;
            --destroy)
                action="destroy"
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                echo "不明なオプション: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # 環境指定チェック
    if [ -z "$env" ]; then
        echo "エラー: --env オプションが必要です"
        show_help
        exit 1
    fi
    
    # アクション指定チェック
    if [ -z "$action" ]; then
        echo "エラー: --validate-only, --deploy, --destroy のいずれかを指定してください"
        show_help
        exit 1
    fi
    
    # 環境変数読み込み
    load_env "$env"
    
    # キーペアファイルパスを固定
    KEY_FILE="data/my-key-pair.pem"
    
    # ログファイル初期化
    echo "=== CloudFormation デプロイログ ===" > "$LOG_FILE"
    echo "開始時刻: $(date)" >> "$LOG_FILE"
    echo "環境: $ENVIRONMENT" >> "$LOG_FILE"
    echo "スタック名: $STACK_NAME" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
    
    # アクション実行
    case $action in
        validate)
            validate_template
            ;;
        deploy)
            validate_template
            check_keypair
            deploy_stack
            show_outputs
            ;;
        destroy)
            destroy_stack
            ;;
    esac
    
    echo "終了時刻: $(date)" >> "$LOG_FILE"
    echo "✓ 処理完了"
}

# スクリプト実行
main "$@" 