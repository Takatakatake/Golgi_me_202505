# Golgi 管理マニュアル（生成AI用参照資料）

## 1. システム概要

Golgiは高性能計算用のLinuxクラスタシステムであり、GPUを搭載した複数の計算ノードで構成されています。システムは以下の主要コンポーネントから構成されています：

- **GolgiAdmin**：親ノード/ヘッドノード (IPアドレス: 外向き 10.1.1.226、内向き 192.168.2.200)
- **計算ノード**：golgi01～golgi15 (IPアドレス: 192.168.2.1～192.168.2.15)
- **ファイルサーバー**：GolgiFS (IPアドレス: 192.168.2.201)、GolgiFS02 (IPアドレス: 192.168.2.202)

### 1.1 システムアーキテクチャ

```
[外部ネットワーク]
       |
       ↓
 [GolgiAdmin] ------ [GolgiFS/GolgiFS02]
       |
       ↓
[スイッチ/内部ネットワーク]
     / | \
    /  |  \
[golgi01][golgi02]...[golgi15]
```

- **OS**: Ubuntu (親ノード: Ubuntu 18.04/22.04、子ノード: Ubuntu 18.04/20.04)
- **ジョブスケジューラ**: Slurm
- **分散ファイルシステム**: NFS
- **ユーザー認証**: NIS
- **内部ネットワーク**: 192.168.2.0/24
- **外部ネットワーク接続**: 10.1.1.0/24 (GolgiAdminのみ)

## 2. 基本管理コマンド

### 2.1 システム状態確認

```bash
# Slurmクラスタの状態確認
sinfo                    # ノードの状態確認
squeue                   # 実行中/待機中ジョブの確認
scontrol show node       # ノードの詳細情報

# 計算ノードの温度監視
sensors                  # CPUの温度を表示

# GPUの状態確認
nvidia-smi               # GPUの状態と使用状況を表示
```

### 2.2 マジックコマンド（障害ノード復旧）

```bash
# 停止したノードを復旧させる魔法のコマンド
sudo systemctl restart slurmd              # ノード上でslurmデーモンを再起動
sudo /opt/slurm/bin/scontrol update nodename=golgi<XX> state=resume  # 親ノード上で実行して状態をresumeに変更
```

## 3. 主要システムコンポーネント

### 3.1 Slurm (ジョブスケジューラ)

Slurmは計算ジョブの投入・実行・管理を行うソフトウェアです。

#### 重要ファイル
- `/opt/slurm/etc/slurm.conf` - Slurmの主設定ファイル
- `/opt/slurm/etc/gres.conf` - GPUリソース設定ファイル
- `/var/log/slurm/` - Slurmのログディレクトリ

#### 主要サービス
- `slurmctld` - 親ノード上で動作する制御デーモン
- `slurmd` - 子ノード上で動作する実行デーモン
- `munge` - 認証サービス

#### 基本コマンド
```bash
# サービス管理
sudo systemctl status slurmctld     # 親ノードのSlurmサービス状態確認
sudo systemctl status slurmd        # 子ノードのSlurmサービス状態確認
sudo systemctl restart slurmctld    # 親ノードのSlurmサービス再起動
sudo systemctl restart slurmd       # 子ノードのSlurmサービス再起動

# ノード状態管理
sudo /opt/slurm/bin/scontrol update node=golgi<XX> state=idle    # ノードをアイドル状態に
sudo /opt/slurm/bin/scontrol update node=golgi<XX> state=drain   # ノードをドレイン状態に（新規ジョブ割り当て停止）
sudo /opt/slurm/bin/scontrol update node=golgi<XX> state=resume  # ドレイン状態から復帰
```

### 3.2 NFS (ネットワークファイルシステム)

NFSはファイルサーバー上のディレクトリを各ノードでマウントし、共有するためのシステムです。

#### 重要ファイル（親ノード/ファイルサーバー）
- `/etc/exports` - 共有設定ファイル
- `/etc/fstab` - マウント設定ファイル

#### 共有されているディレクトリ
- `/home` - ユーザーホームディレクトリ
- `/usr/local` - 共有ソフトウェア
- `/research_data` - 研究データ用ディレクトリ（GolgiFS02）

#### 基本コマンド
```bash
# ファイルサーバー側
exportfs -ra                        # 共有設定を再読み込み

# クライアント側（各ノード）
sudo mount -a                       # fstabに基づいて全てマウント
sudo mount GolgiFS:/home /home     # 手動でマウント
sudo umount /home                   # アンマウント

# マウント状態確認
df -h                              # マウントされているファイルシステムと使用量確認
mount | grep nfs                   # NFSマウントの確認
```

### 3.3 NIS（ネットワーク情報サービス）

NISはユーザーアカウント情報を一元管理するためのサービスです。

#### 重要ファイル
- `/etc/yp.conf` - NISクライアント設定
- `/etc/defaultdomain` - NISドメイン名設定
- `/var/yp/Makefile` - NISサーバー設定

#### 基本コマンド
```bash
# サーバー側（親ノード）
sudo service nis restart           # NISサービス再起動
cd /var/yp && sudo make            # NISデータベース更新

# クライアント側
ypcat passwd                       # NISユーザーリスト表示
```

### 3.4 GPU管理

GolgiクラスタはNVIDIA GPUを使用しています。

#### 重要ファイル
- `/etc/modprobe.d/blacklist-nouveau.conf` - Nouveauドライバーブラックリスト
- `/proc/driver/nvidia/` - NVIDIAドライバー情報

#### 基本コマンド
```bash
nvidia-smi                         # GPU状態表示
sudo lsmod | grep nvidia           # NVIDIAドライバーモジュール確認
sudo lsmod | grep nouveau          # Nouveauドライバー確認
lspci | grep -i nvidia             # GPUハードウェア確認
```

## 4. よくある問題と解決方法

### 4.1 計算ノードがダウンしている場合

#### 問題: `sinfo`で特定のノードが`down`または`down*`状態になっている

**確認手順:**
1. 親ノードから該当ノードにSSH接続できるか確認
   ```bash
   ssh golgi<XX>
   ```

2. ノードにログインできる場合は、slurmdサービスの状態を確認
   ```bash
   sudo systemctl status slurmd
   ```

**解決方法（一般的なケース）:**
1. ノード上でslurmdを再起動
   ```bash
   sudo systemctl restart slurmd
   ```

2. 親ノードに戻り、ノードの状態を更新
   ```bash
   sudo /opt/slurm/bin/scontrol update nodename=golgi<XX> state=resume
   ```

3. 状態を確認
   ```bash
   sinfo
   ```

#### 問題: ノードにSSH接続できない場合

1. サーバールームで物理的に電源が入っているか確認
2. 電源を手動で入れ直す
3. 再起動後、SSHで接続を試みる
4. 接続できたら、上記の解決方法を試す

### 4.2 GPU関連の問題

#### 問題: `nvidia-smi`が応答しない

```
NVIDIA-SMI has failed because it couldn't communicate with the NVIDIA driver. Make sure that the latest NVIDIA driver is installed and running.
```

**確認手順:**
1. NVIDIAドライバーが読み込まれているか確認
   ```bash
   lsmod | grep nvidia
   ```

2. 競合するNouveauドライバーが有効になっていないか確認
   ```bash
   lsmod | grep nouveau
   ```

**解決方法:**

1. GUIインターフェースを停止（特にGolgi07で頻発）
   ```bash
   sudo systemctl stop gdm
   ```

2. Nouveauドライバーをブラックリストに追加
   ```bash
   sudo bash -c 'cat > /etc/modprobe.d/blacklist-nouveau.conf << EOF
   blacklist nouveau
   options nouveau modeset=0
   EOF'
   ```

3. 初期RAMディスクを更新
   ```bash
   sudo update-initramfs -u
   ```

4. NVIDIAドライバーを再読み込み
   ```bash
   sudo rmmod nvidia_drm nvidia_modeset nvidia_uvm nvidia 2>/dev/null
   sudo modprobe nvidia
   ```

5. NVIDIA永続サービスを有効化
   ```bash
   sudo systemctl enable nvidia-persistenced
   sudo systemctl start nvidia-persistenced
   ```

6. 再度`nvidia-smi`を実行して確認

7. 永続的な設定（再起動時も保持）
   ```bash
   # GDMを永続的に無効化
   sudo systemctl disable gdm

   # 起動時にNVIDIAドライバーを確実に読み込むスクリプトを作成
   sudo bash -c 'cat > /etc/rc.local << EOF
   # !/bin/bash
   # 既存のnouveauをアンロード
   rmmod nouveau 2>/dev/null
   # NVIDIAドライバーを読み込み
   modprobe nvidia
   exit 0
   EOF'

   # 実行権限を付与
   sudo chmod +x /etc/rc.local

   # サービスを有効化
   sudo systemctl enable rc-local
   ```

8. ノードを復旧
   ```bash
   # 親ノードで実行
   sudo scontrol update nodename=golgi<XX> state=resume
   ```

**注意:** `sudo apt upgrade`を実行すると（特にカーネルアップデート時）、この問題が再発することがあります。

### 4.3 Mungeキー問題

#### 問題: Slurmdが起動しない、認証エラーが発生する

Mungeは認証に使用されるサービスであり、キーが一致していないと問題が発生します。

**確認手順:**
```bash
sudo systemctl status munge
```

**解決方法:**

1. 親ノードからキーをコピー
   ```bash
   # 親ノードで実行
   sudo scp /etc/munge/munge.key golgi<XX>:/tmp/munge.key

   # 子ノードで実行
   sudo systemctl stop munge
   sudo mv /tmp/munge.key /etc/munge/
   sudo chown munge:munge /etc/munge/munge.key
   sudo chmod 400 /etc/munge/munge.key
   sudo systemctl start munge
   ```

2. Slurmdを再起動
   ```bash
   sudo systemctl restart slurmd
   ```

### 4.4 NFSマウントの問題

#### 問題: 子ノードでホームディレクトリが見えない、マウントエラー

**確認手順:**
```bash
df -h | grep home
mount | grep nfs
```

**解決方法:**

1. マウントを手動で再実行
   ```bash
   sudo mount -a
   ```

2. エラーがある場合、マウントを一旦解除してから再マウント
   ```bash
   sudo umount -f /home  # 強制的にアンマウント
   sudo mount -a
   ```

3. それでも失敗する場合、親ノードとファイルサーバーの状態を確認
   ```bash
   # 親ノードで実行
   sudo systemctl status nfs-server
   sudo exportfs -v
   ```

## 5. システム復旧手順

### 5.1 停電後の復旧手順

停電からの復旧時には、以下の順序で起動する必要があります：

1. ファイルサーバー（GolgiFS, GolgiFS02）を起動
2. 親ノード（GolgiAdmin）を起動
3. 親ノードでansibleを実行して設定を復元
   ```bash
   cd /srv/ansible
   ansible-playbook -i "localhost," admin.yml --ask-become-pass --connection=local -vvv
   ansible-playbook -i production nodes.yml --ask-become-pass -vvv
   ```
4. 子ノードを起動

### 5.2 停電前の手順

停電前には、データ損失を防ぐため以下の手順を実行します：

```bash
# 全計算ノードに対してコマンドを一括実行
for i in {01..15}; do
  echo "=== Shutting down Golgi$i ==="
  # Slurmデーモンの停止
  ssh golgi$i "sudo systemctl stop slurmd"
  # NFSのアンマウント
  ssh golgi$i "sudo umount /home; sudo umount /usr/local"
  # シャットダウン
  ssh golgi$i "sudo shutdown -h now"
done

# 親ノードのシャットダウン
sudo shutdown -h now

# 最後にファイルサーバーをシャットダウン
```

## 6. Ansible による自動化管理

Golgiクラスタはansibleを使って設定が管理されています。

### 6.1 基本コマンド

```bash
# 親ノードの設定適用
cd /srv/ansible
ansible-playbook -i "localhost," admin.yml --ask-become-pass --connection=local

# 子ノードの設定適用
ansible-playbook -i production nodes.yml --ask-become-pass

# 特定のノードにのみ適用
ansible-playbook -i production -l golgi<XX> nodes.yml --ask-become-pass
```

### 6.2 主要ディレクトリ

- `/srv/ansible/` - ansibleの主要ディレクトリ
- `/srv/ansible/roles/` - 各種ロール定義
- `/srv/ansible/production` - ノードリスト

## 7. ハードウェア情報

### 7.1 GPU構成

- golgi01-07: 12コア CPU, GPU 2枚/ノード
- golgi08-12: 20コア CPU, GPU 2枚/ノード
- golgi13: 20コア CPU, GPU 1枚/ノード (元々2枚あったが1枚認識しなくなった)
- golgi14-15: 20コア CPU, GPU 1枚/ノード

### 7.2 ネットワーク構成

- 内部ネットワーク: 192.168.2.0/24
- 外部ネットワーク: 10.1.1.0/24
- GolgiAdmin: 2つのNIC (外向き: 10.1.1.226, 内向き: 192.168.2.200)
- 子ノード: 1つのNIC (内向き: 192.168.2.XX)
- ファイルサーバー: 内部ネットワーク上 (GolgiFS: 192.168.2.201, GolgiFS02: 192.168.2.202)

## 8. ファイルサーバー管理

### 8.1 GolgiFS02 (2024年導入)

IPアドレス: 192.168.2.202
アクセス: ssh root@192.168.2.202 (GolgiAdmin経由)

#### 共有ディレクトリ
- `/research_data` - 研究データ用大容量ストレージ

#### 基本操作
```bash
# GolgiFS02上での操作
vim /etc/exports                    # 共有設定編集
exportfs -ra                        # 共有設定反映

# GolgiAdmin側での操作
sudo mount -a                       # fstabに基づいてマウント
```

#### 新しいユーザー追加時の設定
```bash
# GolgiFS02側
mkdir -p /research_data/<username>
chmod 777 /research_data/<username>

# GolgiAdmin側
ln -sf /research_data/<username> /home/<username>/research_data
```

## 9. 診断ツール

以下のスクリプトを使用して、クラスタ全体の健全性を診断できます：

```bash
# 全ノードに対して軽量診断ジョブを投入
bash light_submit_jobs_to_all_nodes.sh

# 詳細なエラーログを取得する重量診断ジョブを投入
bash heavy_submit_jobs_to_all_nodes.sh
```

これらのスクリプトの出力をAI助手に提供することで、より具体的な診断と解決策を得ることができます。

## 10. 注意事項

1. **適切なメンテナンスの順序**：ファイルサーバー → 親ノード → 子ノード（起動時）、子ノード → 親ノード → ファイルサーバー（シャットダウン時）

2. **aptの注意点**：`sudo apt update`は安全ですが、`sudo apt upgrade`はカーネルが更新されると問題を引き起こす可能性があります。特にGPUドライバーに関連する問題が発生しやすいです。

3. **バックアップ**：重要な設定ファイルを変更する前にバックアップを取ってください。
   ```bash
   sudo cp /etc/slurm/slurm.conf /etc/slurm/slurm.conf.bak
   ```

4. **マウントポイントの整合性**：子ノードのマウントポイントが親ノードと一致していることを確認してください。

5. **セキュリティ**：クラスタは内部ネットワークに保護されていますが、親ノードは外部ネットワークに接続されているため、適切なセキュリティ対策を講じてください。



# Golgi 管理マニュアル（生成AI用参照資料）- 続き

## 11. 詳細なトラブルシューティング手順

### 11.1 Slurm関連の詳細なトラブルシューティング

#### 問題: slurmctldが起動しない (親ノード)

**エラーログの確認:**
```bash
sudo systemctl status slurmctld
sudo journalctl -u slurmctld
cat /var/log/slurm/slurmctld.log
```

**一般的な解決方法:**

1. 設定ファイルの構文エラーチェック
   ```bash
   sudo /opt/slurm/bin/slurmctld -c
   ```

2. サービスの再起動
   ```bash
   sudo systemctl restart slurmctld
   ```

3. マンジエラー (AccountingStorageLoc エラー)
   ```bash
   # slurm.confから以下の行を削除または修正
   # AccountingStorageLoc=/var/spool/slurm.accounting
   # 代わりに以下を使用
   AccountingStorageType=accounting_storage/none
   ```

4. パーミッションの修正
   ```bash
   sudo chown -R slurm:slurm /var/spool/slurm*
   sudo chmod 755 /var/spool/slurm*
   ```

#### 問題: 子ノードがSlurmクラスタに参加できない

**エラーログの確認:**
```bash
sudo systemctl status slurmd
sudo journalctl -u slurmd
cat /var/log/slurm/slurmd.log
```

**一般的な解決方法:**

1. 親ノードとの通信確認
   ```bash
   ping GolgiAdmin
   ```

2. マンジ認証の確認
   ```bash
   sudo systemctl status munge
   munge -n | unmunge
   ```

3. slurm.confの整合性確認
   ```bash
   # 子ノードと親ノードのslurm.confが同一か確認
   diff <(ssh GolgiAdmin "cat /opt/slurm/etc/slurm.conf") /opt/slurm/etc/slurm.conf
   ```

4. ホスト名の解決確認
   ```bash
   # /etc/hostsに正しいエントリがあるか確認
   cat /etc/hosts | grep GolgiAdmin
   ```

### 11.2 NFS関連の詳細なトラブルシューティング

#### 問題: NFSマウントが機能しない

**エラーログの確認:**
```bash
dmesg | grep nfs
cat /var/log/syslog | grep nfs
```

**一般的な解決方法:**

1. NFS関連サービスの状態確認
   ```bash
   # ファイルサーバー側
   sudo systemctl status nfs-server

   # クライアント側
   sudo systemctl status nfs-common
   sudo systemctl status rpcbind
   ```

2. エクスポートの確認
   ```bash
   # ファイルサーバー側
   sudo exportfs -v
   ```

3. ファイアウォールの確認
   ```bash
   sudo iptables -L
   ```

4. 強制的なアンマウントと再マウント
   ```bash
   sudo umount -f /home
   sudo mount -a
   ```

5. RPC通信の確認
   ```bash
   rpcinfo -p GolgiFS
   ```

6. NFSのバージョン互換性問題が発生した場合
   ```bash
   # 特定のバージョンを指定してマウント
   sudo mount -t nfs -o vers=3 GolgiFS:/home /home
   ```

### 11.3 NIS関連の詳細なトラブルシューティング

#### 問題: ユーザー情報が同期されない

**エラーログの確認:**
```bash
cat /var/log/syslog | grep ypbind
cat /var/log/syslog | grep nis
```

**一般的な解決方法:**

1. NISサービスの状態確認
   ```bash
   # サーバー側
   sudo systemctl status nis

   # クライアント側
   sudo systemctl status ypbind
   ```

2. systemd-logindとNISの競合解決（頻発する問題）
   ```bash
   # IPAddressDeny=anyの行をコメントアウト
   sudo sed -i 's/^IPAddressDeny=any/#IPAddressDeny=any/' /lib/systemd/system/systemd-logind.service
   sudo systemctl daemon-reload
   sudo systemctl restart systemd-logind
   ```

3. NISドメイン設定の確認
   ```bash
   domainname
   cat /etc/defaultdomain
   cat /etc/yp.conf
   ```

4. NISデータベースの更新
   ```bash
   # 親ノードでのみ実行
   cd /var/yp && sudo make
   ```

5. グループIDの最小値問題（発生することがある問題）
   ```bash
   # MINGIDの値を確認し修正（999が適切）
   sudo grep MINGID /var/yp/Makefile
   sudo sed -i 's/MINGID=.*/MINGID=999/' /var/yp/Makefile
   cd /var/yp && sudo make
   ```

## 12. 定期的なメンテナンス手順

### 12.1 ディスクスペース管理

```bash
# ディスク使用状況確認
df -h

# ディレクトリごとの使用量確認
du -sh /home/*
du -sh /research_data/*

# 大きなファイルの特定
find /home -type f -size +1G -exec ls -lh {} \;

# 不要なログファイルのクリーンアップ
sudo find /var/log -name "*.gz" -type f -mtime +30 -delete
```

### 12.2 ジョブ統計情報の収集と分析

```bash
# 過去のジョブ情報を表示
sacct -a --format=JobID,JobName,User,Partition,NodeList,Elapsed,State,ExitCode,Start,End

# 特定ユーザーのジョブ履歴
sacct -u <username> --format=JobID,JobName,Elapsed,State,ExitCode,Start,End

# 各ユーザーのジョブ数統計
sacct -a -n -p --format=User | sort | uniq -c
```

### 12.3 システムログの確認と分析

```bash
# 重要なシステムログの確認
journalctl -p err..emerg --since "24 hours ago"

# ハードウェア関連のエラーを確認
journalctl | grep -i error
dmesg | grep -i error

# GPUエラーの確認
nvidia-smi -q | grep -i error
```

## 13. ユーザー管理

### 13.1 新規ユーザーの追加

親ノードで以下の手順を実行します：

```bash
# 1. ユーザー追加
sudo adduser <username>

# 2. NISデータベース更新
cd /var/yp && sudo make

# 3. GolgiFS02上にresearch_dataディレクトリ作成
ssh root@192.168.2.202 "mkdir -p /research_data/<username> && chmod 777 /research_data/<username>"

# 4. ホームディレクトリにresearch_dataリンク作成
sudo ln -sf /research_data/<username> /home/<username>/research_data
sudo chown <username>:<username> /home/<username>/research_data
```

### 13.2 ユーザーパスワードの変更

```bash
# NISデータベースのパスワード変更
sudo yppasswd <username>

# NISデータベース更新
cd /var/yp && sudo make
```

### 13.3 ユーザー削除

```bash
# ユーザーアカウント削除（ホームディレクトリは残す）
sudo userdel <username>

# ホームディレクトリ含めて完全削除
sudo userdel -r <username>

# NISデータベース更新
cd /var/yp && sudo make

# GolgiFS02上のresearch_dataバックアップ
ssh root@192.168.2.202 "mv /research_data/<username> /research_data/<username>_backup_$(date +%Y%m%d)"
```

## 14. GPUリソース管理詳細

### 14.1 Slurm GPUリソース設定

#### gres.confの修正

ノードのGPU構成が変更された場合（例：golgi13のGPU数が2から1に減少）、以下のようにgres.confとslurm.confを更新します：

```bash
# /opt/slurm/etc/gres.conf
# 2 GPUを持つノード
Nodename=golgi[04-12] Name=gpu File=/dev/nvidia[0-1]
# 1 GPUを持つノード
Nodename=golgi13 Name=gpu File=/dev/nvidia0
Nodename=golgi[14-15] Name=gpu File=/dev/nvidia0
```

```bash
# /opt/slurm/etc/slurm.conf（一部）
NodeName=golgi[04-07] Procs=12 ThreadsPerCore=2 State=UNKNOWN Gres=gpu:2
NodeName=golgi[08-12] Procs=20 ThreadsPerCore=2 State=UNKNOWN Gres=gpu:2
NodeName=golgi13 Procs=20 ThreadsPerCore=2 State=UNKNOWN Gres=gpu:1
NodeName=golgi[14-15] Procs=20 ThreadsPerCore=2 State=UNKNOWN Gres=gpu:1
```

変更後、以下のコマンドで設定を反映：

```bash
# 親ノードで実行
sudo systemctl restart slurmctld

# 子ノードで実行
sudo systemctl restart slurmd

# 親ノードで実行
sudo /opt/slurm/bin/scontrol update nodename=golgi13 state=resume
```

### 14.2 GPUモニタリングと診断

```bash
# GPU使用状況の詳細情報
nvidia-smi -q

# GPU温度モニタリング
nvidia-smi --query-gpu=temperature.gpu --format=csv

# GPU利用率モニタリング
nvidia-smi --query-gpu=utilization.gpu --format=csv

# GPUプロセスモニタリング
nvidia-smi --query-compute-apps=pid,used_memory,gpu_uuid --format=csv

# 継続的なモニタリング
watch -n 1 nvidia-smi
```

### 14.3 CUDA環境の管理

```bash
# インストールされているCUDAバージョン確認
nvcc --version
/usr/local/cuda/bin/nvcc --version

# CUDAライブラリパス確認
echo $LD_LIBRARY_PATH

# 特定のCUDAバージョンを使用する環境変数設定
export PATH=/usr/local/cuda-10.2/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/cuda-10.2/lib64:$LD_LIBRARY_PATH
```

## 15. クラスタ全体の監視スクリプト

### 15.1 GPUステータスチェックスクリプト

以下は、すべてのノードのGPUステータスを確認するスクリプト例です：

```bash
# !/bin/bash
# gpu_check.sh - すべてのノードのGPUステータスを確認

nodes=(golgi04 golgi05 golgi06 golgi07 golgi08 golgi09 golgi10 golgi11 golgi12 golgi13 golgi14 golgi15)

echo "=== GPU Status Check - $(date) ==="
echo "Node | GPU Detection | GPU Count | Driver Version"
echo "----------------------------------------"

for node in "${nodes[@]}"; do
  # SSHでノードに接続してGPU情報を取得
  status=$(ssh -o ConnectTimeout=5 $node "nvidia-smi --query-gpu=count,driver_version --format=csv,noheader 2>/dev/null || echo 'NVIDIA-SMI failed'")

  # 結果を解析
  if [[ $status == *"NVIDIA-SMI failed"* ]]; then
    echo "$node | FAILED | N/A | N/A"
  else
    count=$(echo $status | cut -d',' -f1 | tr -d ' ')
    driver=$(echo $status | cut -d',' -f2 | tr -d ' ')
    echo "$node | OK | $count | $driver"
  fi
done
```

### 15.2 全ノードステータスチェックスクリプト

```bash
# !/bin/bash
# nodes_check.sh - すべてのノードの基本状態を確認

nodes=(golgi04 golgi05 golgi06 golgi07 golgi08 golgi09 golgi10 golgi11 golgi12 golgi13 golgi14 golgi15)

echo "=== Node Status Check - $(date) ==="
echo "Node | SSH | Load Avg | Memory | Disk | NFS (/home) | Slurmd"
echo "------------------------------------------------------------"

for node in "${nodes[@]}"; do
  # SSHでノードに接続して情報を取得
  result=$(ssh -o ConnectTimeout=5 $node "
    load=\$(cat /proc/loadavg | cut -d' ' -f1-3)
    mem=\$(free -h | grep Mem | awk '{print \$3\"/\"\$2}')
    disk=\$(df -h / | grep / | awk '{print \$5}')
    nfs=\$(df -h | grep /home | wc -l)
    slurmd=\$(systemctl is-active slurmd)
    echo \"\$load|\$mem|\$disk|\$nfs|\$slurmd\"
  " 2>/dev/null)

  # 結果を解析
  if [ -z "$result" ]; then
    echo "$node | FAILED | N/A | N/A | N/A | N/A | N/A"
  else
    IFS="|" read -r load mem disk nfs slurmd <<< "$result"
    nfs_status="Not Mounted"
    if [ "$nfs" -gt 0 ]; then
      nfs_status="Mounted"
    fi
    echo "$node | OK | $load | $mem | $disk | $nfs_status | $slurmd"
  fi
done
```

## 16. 性能最適化とチューニング

### 16.1 Slurmスケジューラの最適化

```bash
# QOS（サービス品質）設定の確認
sacctmgr show qos format=name,priority,maxjobs,maxtres

# プライオリティ設定の確認
sprio -l

# ジョブの優先度を上げる
scontrol update job=<jobid> nice=-10000

# バックフィルスケジューリングの確認
scontrol show config | grep SchedulerType
```

### 16.2 メモリ使用率の監視と最適化

```bash
# メモリ使用状況の詳細表示
free -h
vmstat 1 10

# キャッシュの状態確認
cat /proc/meminfo

# スワップ使用状況の確認
swapon --show

# メモリ使用量の多いプロセスを特定
ps aux --sort=-%mem | head -10
```

### 16.3 ネットワーク性能の監視

```bash
# ネットワークインターフェースの状態確認
ip -s link

# ネットワーク使用状況の監視
iftop -i enp3s0
nethogs

# 特定ポートの接続状況確認
netstat -tunapl | grep <port>

# NFS性能テスト
dd if=/dev/zero of=/home/test_file bs=1M count=1000 oflag=direct
```

## 17. セキュリティ管理

### 17.1 ファイアウォール設定

GolgiAdminは外部ネットワークに接続されているため、適切なファイアウォール設定が重要です。

```bash
# ファイアウォール状態確認
sudo iptables -L

# 基本的なセキュリティルール設定
sudo iptables -A INPUT -i lo -j ACCEPT
sudo iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 80 -j REJECT
sudo iptables -A INPUT -j DROP

# ルールの永続化
sudo iptables-save > /etc/iptables.rules
```

### 17.2 SSH強化

```bash
# SSH設定の変更
sudo nano /etc/ssh/sshd_config

# 以下の設定を推奨
# PermitRootLogin no
# PasswordAuthentication no
# MaxStartups 10:30:100
# LoginGraceTime 120
# ClientAliveInterval 300
# ClientAliveCountMax 2

# 設定反映
sudo systemctl restart sshd
```

### 17.3 セキュリティアップデート管理

```bash
# セキュリティアップデートの確認
sudo apt update
apt list --upgradable | grep security

# セキュリティパッチの適用（注意して実行）
sudo apt-get upgrade -s # シミュレーションモード
sudo apt-get install --only-upgrade <package-name>
```

## 18. バックアップと復元

### 18.1 重要設定ファイルのバックアップ

```bash
# バックアップディレクトリ作成
mkdir -p ~/golgi_backup/$(date +%Y%m%d)

# 重要設定ファイルのバックアップ
cp /opt/slurm/etc/slurm.conf ~/golgi_backup/$(date +%Y%m%d)/
cp /opt/slurm/etc/gres.conf ~/golgi_backup/$(date +%Y%m%d)/
cp /etc/network/interfaces ~/golgi_backup/$(date +%Y%m%d)/
cp /etc/hosts ~/golgi_backup/$(date +%Y%m%d)/
cp /etc/exports ~/golgi_backup/$(date +%Y%m%d)/
cp /etc/fstab ~/golgi_backup/$(date +%Y%m%d)/
cp /etc/yp.conf ~/golgi_backup/$(date +%Y%m%d)/

# バックアップの圧縮
tar -czvf ~/golgi_backup_$(date +%Y%m%d).tar.gz ~/golgi_backup/$(date +%Y%m%d)
```

### 18.2 重要データのバックアップ戦略

```bash
# ユーザーホームディレクトリの重要データをバックアップ
rsync -avz --progress /home/<username>/important_data /research_data/backups/<username>/

# クロネ設定（定期バックアップ用）
# 毎日午前2時に実行
# 0 2 * * * rsync -avz --progress /home/important /research_data/backups/ >> /var/log/backup.log 2>&1
```

### 18.3 設定復元手順

```bash
# バックアップから設定を復元
cp ~/golgi_backup/$(date +%Y%m%d)/slurm.conf /opt/slurm/etc/
cp ~/golgi_backup/$(date +%Y%m%d)/gres.conf /opt/slurm/etc/

# サービス再起動
sudo systemctl restart slurmctld # 親ノードのみ
sudo systemctl restart slurmd   # 子ノードのみ
```

## 19. クラスタ拡張ガイド

### 19.1 新規ノード追加手順

1. **ハードウェア設置**
   - サーバーに電源とネットワークを接続
   - BIOS設定を確認（特にSecure Bootを無効化）

2. **OSインストール**
   - Ubuntu Server 20.04 LTSをインストール
   - 基本設定（ネットワーク、SSHなど）

3. **IPアドレス設定**
   ```bash
   # /etc/netplan/01-netcfg.yaml
   network:
     version: 2
     ethernets:
       enp1s0:  # インターフェース名は実際のものに合わせる
         addresses: [192.168.2.XX/24]  # 新ノードのIP
         gateway: 192.168.2.200
         nameservers:
           addresses: [8.8.8.8]
   ```

4. **Ansibleアカウント設定**
   ```bash
   # ユーザー作成
   sudo adduser ansible
   sudo usermod -aG sudo ansible

   # ホームディレクトリ変更
   sudo usermod -d /srv/ansible ansible
   sudo mkdir -p /srv/ansible
   sudo chown ansible:ansible /srv/ansible
   ```

5. **親ノードの設定更新**
   ```bash
   # /etc/hosts に新ノードを追加
   sudo nano /etc/hosts
   # 192.168.2.XX golgiXX

   # Slurm設定更新
   sudo nano /opt/slurm/etc/slurm.conf
   # NodeName=golgiXX Procs=XX ThreadsPerCore=2 State=UNKNOWN Gres=gpu:X

   # gres.conf更新
   sudo nano /opt/slurm/etc/gres.conf
   # 適切なGPU設定を追加

   # Ansibleインベントリ更新
   sudo nano /srv/ansible/production
   # [nodes]セクションに新ノードを追加
   ```

6. **Ansibleによる設定**
   ```bash
   cd /srv/ansible
   ansible-playbook -i production -l golgiXX nodes.yml --ask-become-pass
   ```

7. **Slurmサービス再起動**
   ```bash
   # 親ノード
   sudo systemctl restart slurmctld

   # 新ノード
   sudo systemctl restart slurmd

   # ノード状態の更新
   sudo /opt/slurm/bin/scontrol update nodename=golgiXX state=resume
   ```

### 19.2 ファイルサーバー容量拡張

```bash
# ディスク追加後の確認
lsblk

# パーティション作成
sudo fdisk /dev/sdX

# ファイルシステム作成
sudo mkfs.ext4 /dev/sdX1

# マウントポイント作成
sudo mkdir -p /mnt/expansion

# マウント
sudo mount /dev/sdX1 /mnt/expansion

# fstabに追加
echo "/dev/sdX1 /mnt/expansion ext4 defaults 0 2" | sudo tee -a /etc/fstab

# データ移行
sudo rsync -avz /research_data /mnt/expansion/

# 設定変更
sudo nano /etc/exports
# /mnt/expansion/research_data 192.168.2.0/255.255.255.0(rw,async,no_root_squash)

# 設定反映
sudo exportfs -ra
```

## 20. 特殊なケース対応

### 20.1 計画停電からの復旧

**計画停電復旧手順：**

1. **サービス起動順序の遵守**
   - ファイルサーバー → 親ノード → 子ノード の順で電源投入

2. **親ノードでの設定復元**
   ```bash
   cd /srv/ansible
   ansible-playbook -i "localhost," admin.yml --ask-become-pass --connection=local -vvv
   ansible-playbook -i production nodes.yml --ask-become-pass -vvv
   ```

3. **特定のノードのGPU問題解決（特にgolgi07）**
   ```bash
   # GDM停止
   sudo systemctl stop gdm

   # Nouveauドライバーの無効化
   sudo bash -c 'cat > /etc/modprobe.d/blacklist-nouveau.conf << EOF
   blacklist nouveau
   options nouveau modeset=0
   EOF'

   # 初期RAMディスク更新
   sudo update-initramfs -u

   # NVIDIAドライバー再読み込み
   sudo modprobe nvidia

   # Slurmdの再起動
   sudo systemctl restart slurmd

   # 親ノードでノード状態を更新
   sudo /opt/slurm/bin/scontrol update nodename=golgi07 state=resume
   ```

### 20.2 クラスタ全体のOSアップグレード計画

OSアップグレードは慎重に行う必要があります。以下は計画の概略です：

1. **事前計画**
   - バックアップの作成
   - 各ノードの現状を文書化
   - テストノードでアップグレードをテスト

2. **アップグレード順序**
   - 子ノード → 親ノード の順でアップグレード
   - クリティカルなノードは最後に

3. **子ノードアップグレード手順**
   ```bash
   # テストノードを選択
   sudo /opt/slurm/bin/scontrol update nodename=golgiXX state=drain

   # 現在のジョブ完了を待機
   squeue -w golgiXX

   # アップグレード（注意して実行）
   sudo apt update
   sudo apt upgrade
   sudo apt dist-upgrade

   # 再起動
   sudo reboot

   # テスト成功後、他のノードも同様に
   ```

4. **親ノードアップグレード手順**
   ```bash
   # すべての子ノードをドレイン
   for i in {01..15}; do
     sudo /opt/slurm/bin/scontrol update node=golgi$i state=drain
   done

   # すべてのジョブ完了を待機
   squeue

   # アップグレード（注意して実行）
   sudo apt update
   sudo apt upgrade
   sudo apt dist-upgrade

   # 再起動
   sudo reboot
   ```

5. **検証**
   ```bash
   # すべてのノードを復帰
   for i in {01..15}; do
     sudo /opt/slurm/bin/scontrol update node=golgi$i state=resume
   done

   # テストジョブの実行
   sbatch test_job.sh
   ```

### 20.3 ハードウェア障害対応

1. **GPUハードウェア障害**
   ```bash
   # 故障したGPUを特定
   nvidia-smi
   lspci | grep -i nvidia

   # 設定更新
   sudo nano /opt/slurm/etc/gres.conf
   sudo nano /opt/slurm/etc/slurm.conf

   # サービス再起動
   sudo systemctl restart slurmd
   # 親ノードで
   sudo systemctl restart slurmctld
   sudo /opt/slurm/bin/scontrol update nodename=golgiXX state=resume
   ```

2. **ディスク障害**
   ```bash
   # 障害検出
   dmesg | grep -i error
   smartctl -a /dev/sdX

   # ディスク交換後の手順
   sudo fdisk /dev/sdX
   sudo mkfs.ext4 /dev/sdX1
   sudo mount /dev/sdX1 /mount/point
   ```

3. **ネットワーク障害**
   ```bash
   # ネットワーク診断
   ping GolgiAdmin
   traceroute GolgiAdmin
   ip addr show
   ethtool enp1s0

   # ケーブル、スイッチ、NICの物理的確認
   ```

## 21. 各ノードの固有設定と注意点

### 21.1 特定ノードの挙動と対策

#### golgi07
- **特有の問題**: カーネルアップデート後にGPUドライバーが動作しなくなることがある
- **対策**: グラフィカルインターフェースを無効化し、Nouveauドライバーを無効化

#### golgi13
- **特有の問題**: 2枚あるGPUのうち1枚が認識しなくなった
- **対策**: gres.confとslurm.confをGPU 1枚に変更して運用

#### golgi14, golgi15
- **特有の問題**: SSHが繋がらなくなることがある
- **対策**: 物理的に電源を入れ直すことで解決することが多い

### 21.2 GPU互換性の問題

```bash
# 異なるGPUアーキテクチャ間の互換性確認
nvidia-smi -L

# CUDA互換性の確認
nvcc --version

# ノード間でコンパイルされたバイナリの移動に注意
# 特にNehalem→Haswellなど世代が異なるCPUでは警告が出ることがある
```

## 22. システム監視とアラート設定

### 22.1 基本的な監視設定

```bash
# システムリソース監視
htop
iotop
nvidia-smi

# プロセス監視
ps aux --sort=-%cpu | head -10
ps aux --sort=-%mem | head -10

# ディスク使用率監視
df -h
du -sh /*
```

### 22.2 障害検出スクリプト例

```bash
# !/bin/bash
# health_check.sh - システム健全性チェック

# システム負荷確認
load=$(cat /proc/loadavg | awk '{print $1}')
cpu_count=$(nproc)
load_per_cpu=$(echo "$load / $cpu_count" | bc -l)

if (( $(echo "$load_per_cpu > 2.0" | bc -l) )); then
  echo "WARNING: High CPU load detected: $load (per CPU: $load_per_cpu)"
fi

# メモリ使用率確認
mem_total=$(free -m | grep Mem | awk '{print $2}')
mem_used=$(free -m | grep Mem | awk '{print $3}')
mem_percent=$(echo "scale=2; $mem_used * 100 / $mem_total" | bc)

if (( $(echo "$mem_percent > 90" | bc -l) )); then
  echo "WARNING: High memory usage detected: ${mem_percent}%"
fi

# ディスク使用率確認
disk_usage=$(df -h / | grep / | awk '{print $5}' | sed 's/%//')

if [ "$disk_usage" -gt 90 ]; then
  echo "WARNING: High disk usage detected: ${disk_usage}%"
fi

# GPUステータス確認
nvidia-smi > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "ERROR: NVIDIA driver not functioning properly"
else
  gpu_temp=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader)

  for temp in $gpu_temp; do
    if [ "$temp" -gt 80 ]; then
      echo "WARNING: High GPU temperature detected: ${temp}°C"
    fi
  done
fi

# NFSマウント確認
if ! mount | grep "/home" > /dev/null; then
  echo "ERROR: /home not mounted"
fi

# Slurmデーモン確認
if ! systemctl is-active slurmd > /dev/null; then
  echo "ERROR: slurmd service not running"
fi
```

このスクリプトをcronで定期実行し、エラーがあればメール通知などを設定することができます。

## 23. まとめと参考情報

### 23.1 重要コマンドサマリー

```bash
# システム状態確認
sinfo                                              # ノード状態確認
nvidia-smi                                         # GPU状態確認
df -h                                              # ディスク使用状況

# 障害対応
sudo systemctl restart slurmd                      # Slurmデーモン再起動
sudo /opt/slurm/bin/scontrol update node=golgiXX state=resume  # ノード復帰
sudo systemctl stop gdm                            # GUI停止（GPUトラブル対応）
sudo update-initramfs -u                           # 初期RAMディスク更新

# 設定管理
cd /srv/ansible                                    # Ansible設定ディレクトリ
ansible-playbook -i production nodes.yml --ask-become-pass  # 設定適用

# ファイルシステム
sudo exportfs -ra                                  # NFS設定更新
sudo mount -a                                      # すべてのファイルシステムマウント
```

### 23.2 トラブルシューティングのフローチャート

1. **ノードがダウン状態**
   - SSHできるか？ → Yes → slurmdのステータス確認 → サービス再起動と状態更新
   - SSHできるか？ → No → 物理的な電源確認 → 再起動 → SSHできるか再確認

2. **GPUが認識されない**
   - `nvidia-smi`エラー → Nouveauドライバー確認 → GDM停止 → ドライバー再読み込み
   - それでも解決しない → カーネルアップデート確認 → ドライバー再インストール検討

3. **NFSマウントの問題**
   - マウント失敗 → ファイルサーバー状態確認 → rpcbindサービス確認 → 再マウント

### 23.3 参考ドキュメント

- Slurm公式ドキュメント: https://slurm.schedmd.com/
- NVIDIA Driver Documentation: https://docs.nvidia.com/
- NFS Server Configuration: https://help.ubuntu.com/community/NFSv4Howto
- NIS Configuration: https://www.server-world.info/query?os=Ubuntu_20.04&p=nis

このマニュアルを参照することで、Golgiクラスタの管理においてほとんどの問題を解決できるはずです。不明点があれば、マニュアルの内容をAI助手に提供することで、具体的なアドバイスを得られます。



# Golgi 管理マニュアル（生成AI用参照資料）- 最終部

## 24. 実践的なトラブルシューティング例

以下は実際に遭遇した問題と解決プロセスの具体例です。これらの例は、類似の問題が発生した際の参考として役立てることができます。

### 24.1 実例: golgi07のNVIDIA-SMIエラー

**問題の症状:**
```
NVIDIA-SMI has failed because it couldn't communicate with the NVIDIA driver. Make sure that the latest NVIDIA driver is installed and running.
```

**診断ステップ:**

1. ドライバーモジュールの確認:
   ```bash
   lsmod | grep nvidia
   # 出力なし → ドライバーが読み込まれていない

   lsmod | grep nouveau
   # nouveau 2506752 1
   # drm_kms_helper 274432 1 nouveau
   # drm 557056 3 drm_kms_helper,nouveau
   # ... 出力あり → 競合ドライバーが有効
   ```

2. カーネル更新履歴の確認:
   ```bash
   cat /var/log/apt/history.log | grep linux-image
   # 直近にカーネル更新が行われていた
   ```

3. グラフィックスサービスの確認:
   ```bash
   systemctl status gdm
   # ● gdm.service - GNOME Display Manager
   # Active: active (running)
   ```

**解決手順:**

1. グラフィックスマネージャの停止:
   ```bash
   sudo systemctl stop gdm
   ```

2. Nouveauドライバーのブラックリスト:
   ```bash
   sudo bash -c 'cat > /etc/modprobe.d/blacklist-nouveau.conf << EOF
   blacklist nouveau
   options nouveau modeset=0
   EOF'
   ```

3. 初期RAMディスクの更新:
   ```bash
   sudo update-initramfs -u
   # update-initramfs: Generating /boot/initrd.img-5.4.0-125-generic
   ```

4. システム再起動:
   ```bash
   sudo reboot
   ```

5. 起動後の確認:
   ```bash
   lsmod | grep nvidia
   # nvidia_uvm 1105920 0
   # nvidia_drm 57344 0
   # nvidia_modeset 1228800 1 nvidia_drm
   # nvidia 34168832 2 nvidia_modeset,nvidia_uvm

   nvidia-smi
   # Thu Jan 18 10:14:36 2023
   # +-----------------------------------------------------------------------------+
   # | NVIDIA-SMI 450.102.04   Driver Version: 450.102.04   CUDA Version: 11.0     |
   # |-------------------------------+----------------------+----------------------+
   # | GPU  Name        Persistence-M| Bus-Id        Disp.A | Volatile Uncorr. ECC |
   # | Fan  Temp  Perf  Pwr:Usage/Cap|         Memory-Usage | GPU-Util  Compute M. |
   # |                               |                      |               MIG M. |
   # |===============================+======================+======================|
   # |   0  GeForce RTX 208...  Off  | 00000000:02:00.0 Off |                  N/A |
   # | 30%   40C    P0    33W / 215W |      0MiB / 7979MiB |      0%      Default |
   # |                               |                      |                  N/A |
   # +-------------------------------+----------------------+----------------------+
   ```

6. Slurmdの再起動と状態更新:
   ```bash
   sudo systemctl restart slurmd
   # 親ノードで実行:
   sudo /opt/slurm/bin/scontrol update nodename=golgi07 state=resume
   ```

**永続的解決策:**
グラフィックスマネージャを永続的に無効化し、NVIDIAドライバーが起動時に確実に読み込まれるようにしました:
```bash
sudo systemctl disable gdm
```

### 24.2 実例: ファイルサーバーマウントの失敗

**問題の症状:**
停電後、複数の子ノードで`/home`ディレクトリが空になっていた。

**診断ステップ:**

1. マウント状態の確認:
   ```bash
   df -h | grep home
   # 出力なし → マウントされていない

   mount | grep nfs
   # 出力なし
   ```

2. 手動マウント試行:
   ```bash
   sudo mount -a
   # mount.nfs: access denied by server while mounting GolgiFS:/home
   ```

3. ファイルサーバー側の確認:
   ```bash
   # GolgiFSにSSH接続
   ssh root@192.168.2.201

   # エクスポート確認
   exportfs -v
   # /home         192.168.2.0/255.255.255.0(rw,async,wdelay,no_root_squash)

   # NFSサービス状態確認
   systemctl status nfs-server
   # ● nfs-server.service - NFS server and services
   # Active: active (exited)

   # /etc/exportsの確認
   cat /etc/exports
   # /home 192.168.2.0/255.255.255.0(rw,async,no_root_squash)
   ```

**解決手順:**

1. ファイルサーバー側でエクスポート設定を再適用:
   ```bash
   exportfs -ra
   ```

2. 子ノード側でマウント再試行:
   ```bash
   sudo mount -a

   # 確認
   df -h | grep home
   # GolgiFS:/home       2.7T  1.4T  1.2T  54% /home
   ```

3. すべての子ノードで同様のコマンドを実行:
   ```bash
   for i in {01..15}; do
     ssh golgi$i "sudo mount -a"
     ssh golgi$i "df -h | grep home"
   done
   ```

**永続的解決策:**
起動順序の重要性を文書化し、停電復旧手順を明確にしました:
1. ファイルサーバー(GolgiFS, GolgiFS02)の電源を入れる
2. 親ノード(GolgiAdmin)の電源を入れる
3. 子ノード(golgi01-15)の電源を入れる

このシーケンスにより、マウントポイントが常に利用可能な状態になります。

### 24.3 実例: Slurmジョブスケジューラの問題

**問題の症状:**
ジョブが投入されず、`sinfo`コマンドで複数のノードが`down*`状態と表示される。

**診断ステップ:**

1. スケジューラ状態の確認:
   ```bash
   sinfo
   # PARTITION AVAIL TIMELIMIT NODES STATE NODELIST
   # debug*    up   infinite     3 down* golgi[05,11,15]
   # debug*    up   infinite     9 down  golgi[04,06-10,12-14]
   ```

2. 詳細な理由の確認:
   ```bash
   sinfo -R
   # REASON               USER      TIMESTAMP           NODELIST
   # Not responding       slurm     2023-01-10T09:15:38 golgi[04-15]
   ```

3. 親ノードのSlurmコントローラステータス確認:
   ```bash
   systemctl status slurmctld
   # ● slurmctld.service - Slurm controller daemon
   # Active: active (running)
   ```

4. 問題ノードの一つに接続して状態確認:
   ```bash
   ssh golgi05

   systemctl status slurmd
   # ● slurmd.service - Slurm node daemon
   # Active: failed (Result: exit-code)
   # Process: 15876 ExecStart=/opt/slurm/sbin/slurmd -D -s $SLURMD_OPTIONS (code=exited, status=1/FAILURE)
   # Jan 11 11:19:23 golgi05 slurmd[15876]: fatal: The AccountingStorageLoc option has been removed.
   ```

**解決手順:**

1. 親ノードでslurm.confを修正:
   ```bash
   sudo nano /opt/slurm/etc/slurm.conf

   # AccountingStorageLoc=/var/spool/slurm.accounting を削除
   # 代わりに
   AccountingStorageType=accounting_storage/none
   ```

2. 親ノードでSlurmコントローラを再起動:
   ```bash
   sudo systemctl restart slurmctld
   ```

3. 各子ノードでSlurmdを再起動:
   ```bash
   for i in {04..15}; do
     ssh golgi$i "sudo systemctl restart slurmd"
   done
   ```

4. ノードの状態を更新:
   ```bash
   for i in {04..15}; do
     sudo /opt/slurm/bin/scontrol update nodename=golgi$i state=resume
   done
   ```

5. 状態確認:
   ```bash
   sinfo
   # PARTITION AVAIL TIMELIMIT NODES STATE NODELIST
   # debug*    up   infinite    12 idle  golgi[04-15]
   ```

**永続的解決策:**
Ansibleの設定を更新して、すべてのノードに正しい`slurm.conf`が配布されるようにしました。また、Slurmのバージョンアップデート時の互換性チェックプロセスを作成しました。
