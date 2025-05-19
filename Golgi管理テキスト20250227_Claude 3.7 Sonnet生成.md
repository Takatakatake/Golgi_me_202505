# 生成AI用 Golgi管理マニュアル  Claude 3.7 Sonnet

## はじめに

このマニュアルは高田研究室のGolgiクラスタ計算サーバーに関するトラブルシューティングと管理のためのリファレンスです。生成AI（Claude、ChatGPTなど）に投げることで、システム管理の問題解決を支援できるよう構成されています。

## Golgiクラスタの概要

### 基本構成

Golgiは以下の構成からなる計算機クラスタです：

- **ヘッドノード（管理ノード）**: GolgiAdmin（192.168.2.200、外部向けIP: 10.1.1.226）
- **計算ノード**: golgi01〜golgi15（192.168.2.1〜192.168.2.15）
- **ファイルサーバー**:
  - GolgiFS（旧、IP: 192.168.2.201）
  - GolgiFS02（新、IP: 192.168.2.202）
- **ネットワーク構成**: 内部ネットワーク（192.168.2.0/24）、外部接続（10.1.1.0/24）
- **OS**: Ubuntu（ヘッドノード: 18.04、子ノード: 20.04または22.04）

### システム仕様

- **ジョブスケジューラ**: Slurm（バージョン22.05.7）
- **ユーザー管理**: NIS（Network Information Service）
- **ファイル共有**: NFS（Network File System）
- **GPU**: NVIDIA GeForce RTXシリーズ、GTXシリーズ（ノードによって異なる）
- **CUDA**: 10.2、11.4、11.7、12.0（ノードによって異なる）
- **主要ソフトウェア**: Gromacs、AlphaFold、Tensorflow

### 管理アカウント

- **主要管理アカウント**: `ansible`（ユーザーID: 1100）
- **パスワード**: `ansible`
- **ホームディレクトリ**: `/srv/ansible`

## トラブルシューティングガイド

### 一般的な問題診断法

1. **基本確認コマンド**:
   ```bash
   # ノード状態確認
   sinfo

   # ジョブ状態確認
   squeue

   # GPU状態確認
   nvidia-smi

   # サービス状態確認
   systemctl status slurmd
   systemctl status slurmctld  # ヘッドノードのみ
   systemctl status rpcbind
   systemctl status nis
   ```

2. **ログの確認**:
   ```bash
   # Slurmのログ
   cat /var/log/slurm/slurmd.log

   # システムログ
   journalctl -xe

   # カーネルログ
   dmesg | grep -i nvidia
   dmesg | grep -i error
   ```

### 子ノードがダウン状態の復旧

#### CASE 1: 基本的な再起動（最も一般的）

```bash
# ヘッドノードで実行
sudo /opt/slurm/bin/scontrol update nodename=golgi[XX] state=resume

# 子ノードで実行
sudo systemctl restart slurmd
```

#### CASE 2: NVIDIAドライバー関連の問題

多くの場合、GPUドライバーが正しく読み込まれていないことが原因です：

```bash
# 症状確認
nvidia-smi  # "NVIDIA-SMI has failed..."のエラーが表示される場合

# 1. グラフィカルインターフェースの停止（存在する場合）
sudo systemctl stop gdm

# 2. nouveauドライバーの無効化
sudo bash -c 'cat > /etc/modprobe.d/blacklist-nouveau.conf << EOF
blacklist nouveau
options nouveau modeset=0
EOF'

# 3. 既存のドライバーをアンロード
sudo rmmod nouveau 2>/dev/null
sudo rmmod nvidia_drm nvidia_modeset nvidia_uvm nvidia 2>/dev/null

# 4. 初期RAMディスクの更新
sudo update-initramfs -u

# 5. NVIDIAドライバーの再読み込み
sudo modprobe nvidia

# 6. 動作確認
nvidia-smi

# 7. Slurmデーモンの再起動
sudo systemctl restart slurmd

# 8. ノードの復旧（ヘッドノードで実行）
sudo /opt/slurm/bin/scontrol update nodename=golgi[XX] state=resume
```

#### CASE 3: NIS/NFSの問題（ユーザー認証・ファイルマウント障害）

```bash
# 1. NISサービスの状態確認
ypwhich
ypcat passwd

# 2. NISサービスの再起動（必要に応じて）
sudo systemctl restart ypbind

# 3. NFSマウントの確認
df -h
mount | grep nfs

# 4. NFSマウントの再実行
sudo mount -a

# 5. Slurmデーモンの再起動
sudo systemctl restart slurmd
```

#### CASE 4: Mungeキーの問題

Mungeはノード間通信の認証に使われ、キーが一致しないとSlurmが機能しません：

```bash
# 1. Mungeサービスの状態確認
systemctl status munge

# 2. Mungeキーのコピー（ヘッドノードから）
# ヘッドノードで実行
scp /etc/munge/munge.key ansible@golgi[XX]:/tmp/

# 子ノードで実行
sudo cp /tmp/munge.key /etc/munge/
sudo chown munge:munge /etc/munge/munge.key
sudo chmod 400 /etc/munge/munge.key
sudo systemctl restart munge
sudo systemctl restart slurmd
```

### ファイルサーバー関連の問題

#### ファイルサーバーの基本設定

GolgiFS02のNFS設定（/etc/exports）:

```
/research_data 192.168.2.0/255.255.255.0(rw,async,no_root_squash)
/research_data 192.168.2.200(rw,sync,no_subtree_check)
```

ヘッドノードのNFSマウント設定（/etc/fstab）:

```
192.168.2.202:/research_data /research_data nfs defaults 0 0
GolgiFS02:/research_data /research_data nfs defaults 0 0
```

#### マウント問題の解決

```bash
# ヘッドノードでファイルサーバーが認識されない場合
ping 192.168.2.202  # 通信確認
sudo exportfs -ra  # NFSエクスポートの更新（ファイルサーバーで実行）
sudo mount -a  # マウントの再実行（ヘッドノードで実行）

# 子ノードでマウントされない場合
# 親ノードの/etc/fstabの内容を子ノードにコピーして実行
sudo mount -a
```

### セキュリティと接続の問題

#### SSH接続ができない場合

```bash
# MaxStartupsの問題が疑われる場合（接続が複数残っている）
# ヘッドノードで実行
ps aux | grep ssh
kill -9 [PID]  # 不要なSSH接続を終了

# IPアドレスが解決できない場合
cat /etc/hosts  # ホスト名とIPの確認
```

#### ネットワーク問題

```bash
# IPフォワーディングの確認
cat /proc/sys/net/ipv4/ip_forward  # 1であるべき

# IPテーブルの確認
sudo iptables -t nat -L
sudo iptables-save

# ネットワークインターフェース確認
ip a
```

## 定期メンテナンス作業

### 計画停電時の対応

#### 停電前の作業（順序: 子ノード→親ノード→ファイルサーバー）

```bash
# 全計算ノードのシャットダウン
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

# ファイルサーバーは手動で電源を切る
```

#### 停電後の作業（順序: ファイルサーバー→親ノード→子ノード）

```bash
# 各機器の電源を手動でオンにした後、以下を実行

# 1. 親ノードのplaybookの実行
ansible-playbook -i "localhost," admin.yml --ask-become-pass --connection=local -vvv

# 2. 子ノードのplaybookの実行
ansible-playbook -i production nodes.yml --ask-become-pass -vvv
```

### 異常が検出された際の全子ノード一括診断

以下の診断スクリプトを実行することで、全子ノードの状態を効率的に確認できます：

```bash
# 全子ノードの状態確認（軽量スクリプト）
bash light_submit_jobs_to_all_nodes.sh

# 詳細なエラーログを取得（問題解析用）
bash heavy_submit_jobs_to_all_nodes.sh
```

## システム設定・構成ファイル

### 重要な設定ファイル

```
/etc/slurm/slurm.conf  # Slurm設定
/opt/slurm/etc/slurm.conf  # Slurm設定（実際の場所）
/opt/slurm/etc/gres.conf  # GPUリソース設定
/etc/exports  # NFSエクスポート設定
/etc/fstab  # ファイルシステムマウント設定
/etc/hosts  # ホスト名解決
/etc/network/interfaces  # ネットワーク設定
/etc/yp.conf  # NIS設定
/var/yp/Makefile  # NISマップ生成設定
/etc/munge/munge.key  # Munge認証キー
```

### Gres.conf設定例

```
# GPUが2枚の標準ノード
Nodename=golgi[04-12] Name=gpu File=/dev/nvidia[0-1]

# GPUが1枚のノード
Nodename=golgi13 Name=gpu File=/dev/nvidia0
Nodename=golgi[14-15] Name=gpu File=/dev/nvidia0
```

### Slurm.conf設定例（関連部分）

```
# ノード定義
NodeName=golgi[04-07] Procs=12 ThreadsPerCore=2 State=UNKNOWN Gres=gpu:2
NodeName=golgi[08-12] Procs=20 ThreadsPerCore=2 State=UNKNOWN Gres=gpu:2
NodeName=golgi13 Procs=20 ThreadsPerCore=2 State=UNKNOWN Gres=gpu:1
NodeName=golgi[14-15] Procs=20 ThreadsPerCore=2 State=UNKNOWN Gres=gpu:1
```

## Golgi管理に関する上級トピック

### Ansible自動化

Golgiのシステム設定はAnsibleによって自動化されています。主要なplaybookは次のとおりです：

```bash
# ヘッドノード設定
ansible-playbook -i "localhost," admin.yml --ask-become-pass --connection=local

# 子ノード設定
ansible-playbook -i production nodes.yml --ask-become-pass
```

### CUDAとGPUドライバーの互換性

各ノードのGPUとCUDAバージョンは以下のように対応しています：

- GTX 780Ti: CUDA 10.2, ドライバー450以上
- RTX 2080/2080 Super: CUDA 11.x/12.x, ドライバー450以上

### NISグループ情報の問題

`/var/yp/Makefile`内の`MINGID`パラメータは重要です：

```
MINGID=999  # dockerグループ(999)を共有するため
```

### systemd-logindとNISの競合問題

Ubuntu 18以降ではsystemd-logindが通信をブロックすることでNISと競合する場合があります：

```bash
# 解決策: IPAddressDenyの行をコメントアウト
sudo nano /lib/systemd/system/systemd-logind.service
# IPAddressDeny=any の行をコメントアウト
sudo systemctl daemon-reload
```

### 特殊ケース: GPU認識問題の深掘り

GPUが認識されない場合の追加チェック項目：

```bash
# 1. ハードウェア認識確認
lspci | grep -i nvidia

# 2. カーネルモジュール確認
lsmod | grep -i nvidia
lsmod | grep -i nouveau

# 3. NVIDIA永続サービス
sudo systemctl enable nvidia-persistenced
sudo systemctl start nvidia-persistenced

# 4. セキュアブート確認
sudo mokutil --sb-state
```

## 付録: 便利なコマンド集

```bash
# 全ノードに対してコマンドを実行
sudo /root/sbin/do_all "command"

# すべてのノードのシャットダウン
sudo /root/sbin/shutdown_all

# NISデータベースの更新
cd /var/yp && sudo make

# GPUリソース情報の更新（子ノードで実行）
sudo sacctmgr update node set gres=gpu:1 where name=golgi[XX]

# NFSエクスポートの更新
sudo exportfs -ra

# ファイルシステムの状態確認
df -h /home
df -h /usr/local
df -h /research_data
```

## 最終アドバイス

Golgiクラスタは複雑なシステムです。問題が発生した場合は以下の原則に従ってください：

1. **変更の最小化**: 必要最小限の変更のみを行い、大規模なシステム変更は避ける
2. **バックアップ**: 重要な設定ファイルは変更前にバックアップを取る
3. **ログ確認**: エラーが発生した場合は必ず関連ログを確認する
4. **ステップバイステップ**: 複数の変更を同時に行わず、一つずつ変更して効果を確認する
5. **ドキュメント化**: 行った変更や解決策は必ず記録に残す

このマニュアルに記載されていない問題が発生した場合は、より詳細な情報を収集し、生成AIに具体的な症状と実行したコマンド、エラーメッセージを提供してください。
