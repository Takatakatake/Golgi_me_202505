#!/bin/bash
# /srv/ansible/safe_apply.sh
# Golgiクラスター用Ansible Playbookを安全に適用するためのスクリプト
#
# 使用方法:
#   1. このスクリプトに実行権限があることを確認: chmod +x /srv/ansible/safe_apply.sh
#   2. スクリプトを実行: ./safe_apply.sh
#   3. メニューから実行したい操作を選択
#
# 機能:
#   - 親ノード/子ノードへの設定適用
#   - GPUタイプ別の設定適用
#   - チェックモードでの実行（変更なし）
#   - システム状態の検証
#   - バックアップの作成
#
# 注意:
#   - sudo/root権限が必要です
#   - /srv/ansible ディレクトリで実行してください

ANSIBLE_DIR="/srv/ansible"
DATE_STAMP=$(date +%Y%m%d_%H%M%S)
LOG_DIR="${ANSIBLE_DIR}/logs"
LOG_FILE="${LOG_DIR}/ansible_${DATE_STAMP}.log"

# ログディレクトリの作成と古いログの整理
mkdir -p ${LOG_DIR}
# 30日以上前のログファイルを削除
find ${LOG_DIR} -name "ansible_*.log" -type f -mtime +30 -delete

echo "ログは ${LOG_FILE} に保存されます"
echo "（古いログファイルは30日後に自動削除されます）"

# 関数定義: 安全な適用
safe_apply() {
    local playbook=$1
    local limit=$2
    local options=$3
    
    echo "========================================================"
    echo "実行するPlaybook: ${playbook}"
    echo "対象ホスト: ${limit:-「全ノード」}"
    echo "追加オプション: ${options}"
    echo "========================================================"
    
    echo "続行しますか？ (yes/no/check)"
    echo "  yes   - 実行します"
    echo "  no    - キャンセルします"
    echo "  check - チェックモードで実行します（変更なし）"
    read -p "> " choice
    
    case $choice in
        yes)
            echo "Playbookを実行します..."
            if [ -n "$limit" ]; then
                ansible-playbook -i production ${playbook} --limit=${limit} ${options} --ask-become-pass | tee -a ${LOG_FILE}
            else
                ansible-playbook -i production ${playbook} ${options} --ask-become-pass | tee -a ${LOG_FILE}
            fi
            ;;
        check)
            echo "チェックモードで実行します（変更は適用されません）..."
            if [ -n "$limit" ]; then
                ansible-playbook -i production ${playbook} --limit=${limit} ${options} --check --ask-become-pass | tee -a ${LOG_FILE}
            else
                ansible-playbook -i production ${playbook} ${options} --check --ask-become-pass | tee -a ${LOG_FILE}
            fi
            ;;
        *)
            echo "キャンセルしました"
            return 1
            ;;
    esac
    
    # 変更後の検証（checkモードでなければ）
    if [ "$choice" == "yes" ]; then
        echo "システム状態を検証しています..."
        if [ -n "$limit" ]; then
            ansible-playbook -i production verify_changes.yml --limit=${limit} | tee -a ${LOG_FILE}
        else
            ansible-playbook -i production verify_changes.yml | tee -a ${LOG_FILE}
        fi
    fi
    
    return 0
}

# メインメニュー
show_menu() {
    clear
    echo "Golgi クラスター管理ツール"
    echo "=========================="
    echo "1) 親ノード（GolgiAdmin）の設定適用"
    echo "2) すべての子ノードに設定適用"
    echo "3) 特定の子ノードのみに設定適用"
    echo "4) GPUタイプ別に設定適用（GTX 780Ti）"
    echo "5) GPUタイプ別に設定適用（RTX 2080）"
    echo "6) バックアップの作成のみ"
    echo "7) システム状態の検証のみ"
    echo "8) 接続可能なノードのみに設定適用"  # 新しい選択肢
    echo "9) 終了"
    echo
    read -p "選択してください> " choice
    
    case $choice in
        1)
            safe_apply "admin.yml" "" ""
            ;;
        2)
            safe_apply "nodes.yml" "" ""
            ;;
        3)
            read -p "対象ノード（カンマ区切り、例: golgi01,golgi02）> " target_nodes
            safe_apply "nodes.yml" "$target_nodes" ""
            ;;
        4)
            safe_apply "nodes.yml" "nodes_gtx780ti" ""
            ;;
        5)
            safe_apply "nodes.yml" "nodes_rtx2080" ""
            ;;
        6)
            ansible-playbook -i production backup_configs.yml --ask-become-pass | tee -a ${LOG_FILE}
            ;;
        7)
            ansible-playbook -i production verify_changes.yml | tee -a ${LOG_FILE}
            ;;
        8)
            safe_apply "nodes.yml" "nodes_online" ""
            ;;
        9)
            echo "終了します"
            exit 0
            ;;
        *)
            echo "無効な選択です"
            ;;
    esac
    
    echo
    read -p "メインメニューに戻りますか？ (y/n) " back_to_menu
    if [ "$back_to_menu" == "y" ] || [ "$back_to_menu" == "Y" ]; then
        show_menu
    else
        echo "終了します"
        exit 0
    fi
}

# スクリプト開始
cd ${ANSIBLE_DIR}
show_menu