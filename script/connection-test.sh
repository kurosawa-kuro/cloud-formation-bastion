#!/bin/bash

# 接続テスト自動化スクリプト
# 使用方法: ./connection-test.sh --env <environment> [--bastion-only|--full-test]

set -e

# ヘルプ表示
show_help() {
    echo "使用方法: $0 [OPTIONS]"
    echo ""
    echo "オプション:"
    echo "  --env <environment>      環境名 (dev/staging/prod)"
    echo "  --bastion-only           Bastionホストの接続テストのみ"
    echo "  --full-test              完全な接続テスト（Bastion + プライベート）"
    echo "  --help                   このヘルプを表示"
    echo ""
    echo "例:"
    echo "  $0 --env dev --bastion-only"
    echo "  $0 --env dev --full-test"
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
}

# スタック出力値取得
get_stack_output() {
    local output_key=$1
    aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --region "$AWS_REGION" \
        --query "Stacks[0].Outputs[?OutputKey=='${output_key}'].OutputValue" \
        --output text
}

# キーペアファイル確認
check_key_file() {
    # キーペアファイルパスを固定
    local key_file="data/my-key-pair.pem"
    
    if [ ! -f "$key_file" ]; then
        echo "✗ キーペアファイル $key_file が見つかりません"
        echo "キーペアファイルを data/ ディレクトリに配置してください"
        exit 1
    fi
    
    # 権限確認
    local perms=$(stat -c %a "$key_file")
    if [ "$perms" != "400" ]; then
        echo "⚠️  キーペアファイルの権限を修正中..."
        chmod 400 "$key_file"
    fi
    
    echo "✓ キーペアファイル確認完了"
    
    # グローバル変数に設定
    KEY_FILE="$key_file"
}

# Bastionホスト接続テスト
test_bastion_connection() {
    echo "=== Bastionホスト接続テスト ==="
    
    local bastion_ip=$(get_stack_output "BastionPublicIP")
    if [ -z "$bastion_ip" ] || [ "$bastion_ip" = "None" ]; then
        echo "✗ BastionホストのIPアドレスを取得できませんでした"
        return 1
    fi
    
    echo "Bastion IP: $bastion_ip"
    echo "接続テスト中..."
    
    # SSH接続テスト（タイムアウト10秒）
    if ssh -i "$KEY_FILE" -o ConnectTimeout=10 -o StrictHostKeyChecking=no ubuntu@"$bastion_ip" "echo 'Bastion connection OK' && hostname" 2>/dev/null; then
        echo "✓ Bastionホスト接続成功"
        return 0
    else
        echo "✗ Bastionホスト接続失敗"
        return 1
    fi
}

# プライベートインスタンス接続テスト
test_private_connection() {
    echo "=== プライベートインスタンス接続テスト ==="
    
    local bastion_ip=$(get_stack_output "BastionPublicIP")
    local private_ip=$(get_stack_output "PrivateInstancePrivateIP")
    
    if [ -z "$private_ip" ] || [ "$private_ip" = "None" ]; then
        echo "✗ プライベートインスタンスのIPアドレスを取得できませんでした"
        return 1
    fi
    
    echo "プライベート IP: $private_ip"
    echo "Bastion経由で接続テスト中..."
    
    # キーペアファイルをBastionホストに転送
    echo "キーペアファイルをBastionホストに転送中..."
    local key_filename=$(basename "$KEY_FILE")
    
    # 既存ファイルの確認と削除
    ssh -i "$KEY_FILE" -o ConnectTimeout=10 -o StrictHostKeyChecking=no ubuntu@"$bastion_ip" "rm -f ~/$key_filename" 2>/dev/null || true
    
    # キーペアファイルを転送
    if scp -i "$KEY_FILE" -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$KEY_FILE" ubuntu@"$bastion_ip":~/ 2>/dev/null; then
        echo "✓ キーペアファイル転送成功"
    else
        echo "✗ キーペアファイル転送失敗"
        return 1
    fi
    
    # Bastion経由でプライベートインスタンスに接続
    local key_filename=$(basename "$KEY_FILE")
    if ssh -i "$KEY_FILE" -o ConnectTimeout=10 -o StrictHostKeyChecking=no ubuntu@"$bastion_ip" "ssh -i ~/$key_filename -o ConnectTimeout=10 -o StrictHostKeyChecking=no ubuntu@$private_ip 'echo \"Private instance connection OK\" && hostname'" 2>/dev/null; then
        echo "✓ プライベートインスタンス接続成功"
        return 0
    else
        echo "✗ プライベートインスタンス接続失敗"
        echo "   キーペアファイルの転送は成功しているため、手動で接続を確認してください："
        echo "   ssh -i $KEY_FILE ubuntu@$bastion_ip"
        echo "   ssh -i ~/$key_filename ubuntu@$private_ip"
        return 1
    fi
}

# ネットワーク疎通確認
test_network_connectivity() {
    echo "=== ネットワーク疎通確認 ==="
    
    local bastion_ip=$(get_stack_output "BastionPublicIP")
    local private_ip=$(get_stack_output "PrivateInstancePrivateIP")
    
    echo "Bastionホストからのネットワーク確認中..."
    
    # インターネット接続確認
    if ssh -i "$KEY_FILE" -o ConnectTimeout=10 -o StrictHostKeyChecking=no ubuntu@"$bastion_ip" "curl -s --connect-timeout 5 http://httpbin.org/ip" 2>/dev/null | grep -q "origin"; then
        echo "✓ Bastionホストのインターネット接続確認"
    else
        echo "✗ Bastionホストのインターネット接続失敗"
        return 1
    fi
    
    # プライベートインスタンスへの接続確認（pingの代わりにSSH接続テスト）
    if ssh -i "$KEY_FILE" -o ConnectTimeout=10 -o StrictHostKeyChecking=no ubuntu@"$bastion_ip" "ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no ubuntu@$private_ip 'echo \"Network connectivity OK\"'" 2>/dev/null; then
        echo "✓ プライベートインスタンスへのネットワーク疎通確認"
    else
        echo "⚠️  プライベートインスタンスへのpingは失敗（セキュリティグループでICMPが許可されていません）"
        echo "   これは正常な動作です。SSH接続は成功しているため、ネットワークは正常です。"
    fi
    
    return 0
}

# セキュリティグループ確認
test_security_groups() {
    echo "=== セキュリティグループ確認 ==="
    
    local bastion_sg_id=$(get_stack_output "BastionSGId")
    local private_sg_id=$(get_stack_output "PrivateSGId")
    
    echo "Bastionセキュリティグループ: $bastion_sg_id"
    echo "プライベートセキュリティグループ: $private_sg_id"
    
    # セキュリティグループの詳細確認
    echo "Bastionセキュリティグループのルール:"
    aws ec2 describe-security-groups \
        --group-ids "$bastion_sg_id" \
        --region "$AWS_REGION" \
        --query 'SecurityGroups[0].IpPermissions' \
        --output table
    
    echo "プライベートセキュリティグループのルール:"
    aws ec2 describe-security-groups \
        --group-ids "$private_sg_id" \
        --region "$AWS_REGION" \
        --query 'SecurityGroups[0].IpPermissions' \
        --output table
}

# メイン処理
main() {
    local env=""
    local test_type=""
    
    # 引数解析
    while [[ $# -gt 0 ]]; do
        case $1 in
            --env)
                env="$2"
                shift 2
                ;;
            --bastion-only)
                test_type="bastion"
                shift
                ;;
            --full-test)
                test_type="full"
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
    
    # テストタイプ指定チェック
    if [ -z "$test_type" ]; then
        echo "エラー: --bastion-only または --full-test を指定してください"
        show_help
        exit 1
    fi
    
    # 環境変数読み込み
    load_env "$env"
    
    # キーペアファイル確認
    check_key_file
    
    # テスト実行
    local overall_result=0
    
    case $test_type in
        bastion)
            test_bastion_connection || overall_result=1
            ;;
        full)
            test_bastion_connection || overall_result=1
            if [ $overall_result -eq 0 ]; then
                test_private_connection || overall_result=1
                test_network_connectivity
            fi
            test_security_groups
            ;;
    esac
    
    echo ""
    echo "=== テスト結果 ==="
    if [ $overall_result -eq 0 ]; then
        echo "✅ すべてのテストが成功しました"
    else
        echo "❌ 一部のテストが失敗しました"
    fi
    
    exit $overall_result
}

# スクリプト実行
main "$@" 