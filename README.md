# Golgiクラスター管理ガイド

このドキュメントでは、計算機クラスター「Golgi」の管理に使用するAnsible設定について説明します。Ansible（アンシブル）はサーバー設定管理のためのオープンソースツールで、複数のノードに対して一貫した設定を適用するのに最適です。このREADMEではAnsibleの基本から、Golgiクラスター特有の設定、よくあるトラブルシューティングまで説明します。

## 目次

1. [基本情報](#基本情報)
2. [ディレクトリ構造](#ディレクトリ構造)
3. [Ansibleの実行方法](#ansibleの実行方法)
4. [安全な適用手順](#安全な適用手順)
5. [プレイブックの説明](#プレイブックの説明)
6. [主要なロールと機能](#主要なロールと機能)
7. [GPUタイプと対応するCUDA](#gpuタイプと対応するcuda)
8. [よくあるトラブルと対処法](#よくあるトラブルと対処法)
9. [停電後の復旧手順](#停電後の復旧手順)
10. [設定の追加・変更方法](#設定の追加変更方法)
11. [連絡先とサポート](#連絡先とサポート)

## 基本情報

**Golgiクラスターとは**：
Golgiは複数のGPUノードからなる計算機クラスターです。親ノード（GolgiAdmin）と複数の子ノード（golgi01〜golgi14など）で構成されています。各ノードには異なるタイプのGPU（RTX2080, GTX780Tiなど）が搭載されています。

**クラスター構成**：
- **親ノード**: GolgiAdmin (192.168.2.200)
- **子ノード**: golgi01〜golgi14 (192.168.2.1〜192.168.2.14)
- **ファイルサーバー**: GolgiFS (192.168.2.201)
- **GPUタイプ**:
  - RTX 2080 / RTX 2080 SUPER (Compute Capability 7.5)
  - GeForce GTX 780Ti (Compute Capability 3.5)

**使用技術**：
- Ubuntu Linux (16.04〜22.04)
- NVIDIA CUDA (10.2/11.4/12.0)
- Slurm (ジョブスケジューラ)
- NIS (アカウント情報共有)
- NFS (ファイル共有)
- Ansible (自動構成管理)

## ディレクトリ構造

```
/srv/ansible/
├── safe_apply.sh            # 安全なAnsible実行のためのラッパースクリプト
├── admin.yml                # 親ノード(GolgiAdmin)設定用プレイブック
├── nodes.yml                # 子ノード設定用プレイブック
├── production               # インベントリファイル（ノードリスト）
├── backup_configs.yml       # 設定ファイルのバックアップ用プレイブック
├── verify_changes.yml       # 変更後の検証用プレイブック
├── logs/                    # Ansible実行ログが保存されるディレクトリ
└── roles/                   # 各種ロール（機能単位の設定）
    ├── admin-ubuntu/        # 親ノード基本設定
    ├── child-ubuntu/        # 子ノード基本設定
    ├── apt/                 # APTパッケージ管理設定
    ├── cuda-10.2/           # CUDA 10.2設定（GTX 780Ti用）
    ├── cuda-11.4/           # CUDA 11.4設定（RTX 2080用）
    ├── cuda-12.0/           # CUDA 12.0設定
    ├── gromacs-2020.3/      # Gromacs 2020.3（CUDA 10.2と互換性あり）
    ├── gromacs-2022.4/      # Gromacs 2022.4（CUDA 11.4/12.0と互換性あり）
    ├── munge/               # Slurm認証システム
    ├── nis/                 # NISクライアント設定
    ├── nis-server/          # NISサーバー設定（親ノード用）
    ├── nfs/                 # NFSクライアント設定
    ├── slurm/               # Slurmジョブスケジューラ設定
    ├── tensorflow/          # TensorFlow環境設定
    ├── lm-sensors/          # 温度監視ツール
    ├── admin-alphafold/     # AlphaFold親ノード設定
    ├── child-alphafold/     # AlphaFold子ノード設定
    └── gfortran/            # Fortranコンパイラ
```

## Ansibleの実行方法

Golgiクラスターの設定管理には、安全な実行のために作成された`safe_apply.sh`スクリプトを使用します。このスクリプトには、バックアップ作成、変更検証、条件付き実行などの安全機構が組み込まれています。

### basic usage

```bash
cd /srv/ansible
./safe_apply.sh
```

スクリプトを実行すると、以下のようなメニューが表示されます：

```
Golgi クラスター管理ツール
==========================
1) 親ノード（GolgiAdmin）の設定適用
2) すべての子ノードに設定適用
3) 特定の子ノードのみに設定適用
4) GPUタイプ別に設定適用（GTX 780Ti）
5) GPUタイプ別に設定適用（RTX 2080）
6) バックアップの作成のみ
7) システム状態の検証のみ
8) 接続可能なノードのみに設定適用
9) 終了

選択してください>
```

オプションを選択すると、実行前の確認プロンプトが表示されます：

```
実行するPlaybook: admin.yml
対象ホスト: 「全ノード」
追加オプション:
========================================================
続行しますか？ (yes/no/check)
 yes - 実行します
 no - キャンセルします
 check - チェックモードで実行します（変更なし）
>
```

- `yes` - 実際に変更を適用します
- `no` - キャンセルします
- `check` - 変更を適用せずにチェックのみ実行します（安全確認用）

### Ansibleを手動で実行する方法（上級者向け）

`safe_apply.sh`の代わりに直接Ansibleコマンドを実行することもできます：

```bash
# 親ノード設定
ansible-playbook -i production admin.yml --ask-become-pass

# 特定の子ノードのみに設定適用
ansible-playbook -i production nodes.yml --limit=golgi01,golgi02 --ask-become-pass

# チェックモードで実行（変更なし）
ansible-playbook -i production nodes.yml --check --ask-become-pass

# 特定のタスクから開始
ansible-playbook -i production nodes.yml --start-at-task="Check NVIDIA driver status" --ask-become-pass

# ステップバイステップで実行（各タスク実行前に確認）
ansible-playbook -i production nodes.yml --step --ask-become-pass
```

## 安全な適用手順

Ansibleプレイブックの実行は、クラスターの安定性に影響を与える可能性があります。安全に実行するために以下のガイドラインに従ってください。

### 実行前の確認事項

1. **実行中のジョブ確認**:
   ```bash
   squeue
   ```
   重要なジョブが実行中の場合は、完了を待つか、必要に応じてユーザーに連絡してください。

2. **GPUタイプの確認**:
   ```bash
   ansible nodes -i production -m shell -a "hostname && nvidia-smi --query-gpu=name --format=csv,noheader"
   ```
   この結果と`production`ファイルの`nodes_gtx780ti`と`nodes_rtx2080`グループが一致しているか確認してください。

3. **ノードの接続性確認**:
   ```bash
   ansible nodes -i production -m ping
   ```
   接続できないノードがある場合は、電源や物理的な接続を確認してください。

4. **NIS/NFSの状態確認**:
   ```bash
   # NIS
   ypcat passwd

   # NFS
   df -h | grep /home
   ```

### 実行の推奨手順

1. **バックアップ作成**:
   ```bash
   ./safe_apply.sh  # メニューから「6) バックアップの作成のみ」を選択
   ```

2. **システム状態の検証**:
   ```bash
   ./safe_apply.sh  # メニューから「7) システム状態の検証のみ」を選択
   ```

3. **親ノード設定の適用**:
   ```bash
   ./safe_apply.sh  # メニューから「1) 親ノード（GolgiAdmin）の設定適用」を選択
   ```
   最初に`check`モードで実行し、問題がなければ`yes`で実際に適用してください。

4. **子ノードへの段階的適用**:
   少数のノードから始めて、問題がないことを確認してから残りのノードに適用します。
   ```bash
   ./safe_apply.sh  # メニューから「3) 特定の子ノードのみに設定適用」を選択
   ```
   2〜3ノードずつ指定してください（例: `golgi01,golgi02,golgi03`）。

5. **GPUタイプ別の設定適用**（必要な場合）:
   ```bash
   ./safe_apply.sh  # メニューから「4) GPUタイプ別に設定適用（GTX 780Ti）」
                     # または「5) GPUタイプ別に設定適用（RTX 2080）」を選択
   ```

6. **最終検証**:
   ```bash
   ./safe_apply.sh  # メニューから「7) システム状態の検証のみ」を選択
   ```

## プレイブックの説明

Golgiクラスターの設定には、主に2つのプレイブックが使用されます。

### admin.yml（親ノード設定）

`admin.yml`は親ノード（GolgiAdmin）の設定を担当します。主な機能：

1. **基本的な安全対策**:
   - 重要な設定ファイルのバックアップ
   - 重要サービス（rpcbind, nfs-kernel-server, slurmctld）の状態確認

2. **基本的なシステム設定**:
   - APTリポジトリの設定（日本のミラー設定）
   - Ubuntu基本設定（タイムゾーン設定など）
   - 自動アップグレードの無効化

3. **NFSサーバー設定**:
   - `/home`ディレクトリマウント状態の確認
   - NFSエクスポート設定

4. **NISサーバー設定**:
   - NISサーバーの状態確認
   - Makefileの`MINGID=999`設定（dockerグループ共有のため）
   - NISサーバーの適切な構成と起動

5. **開発環境と計算環境**:
   - gfortranコンパイラのインストール
   - Gromacs分子動力学シミュレーションソフトウェアのインストール
   - Slurmジョブスケジューラの設定と起動

6. **AlphaFold環境**:
   - AlphaFold用のディレクトリマウント

### nodes.yml（子ノード設定）

`nodes.yml`は計算ノード（golgi01〜golgi14）の設定を担当します。主な機能：

1. **事前確認と準備**:
   - NVIDIAドライバ状態確認（`nvidia-smi`）
   - 実行中のジョブの確認
   - 設定ファイルのバックアップ

2. **基本設定**:
   - 子ノードのUbuntu基本設定
   - APTリポジトリ設定
   - NISクライアント設定
   - NFSクライアント設定
   - lm-sensors（温度監視）のインストール

3. **GPUタイプに応じた処理**:
   - GPUタイプの検出（`nvidia-smi`で確認）
   - GTX 780Tiノード用CUDA 10.2の適用
   - RTX 2080ノード用CUDA 11.4の適用

4. **科学計算環境**:
   - Gromacs 2020.3（GTX 780Ti用）のインストール
   - Gromacs 2022.4（RTX 2080用）のインストール

5. **機械学習環境**:
   - Tensorflowの環境設定
   - Docker、NVIDIA Docker設定

6. **クラスタージョブ管理**:
   - Slurmクライアント（slurmdデーモン）の設定と起動

7. **AlphaFold実行環境**:
   - AlphaFoldディレクトリマウント
   - AlphaFold Dockerイメージのビルド

### production（インベントリファイル）

`production`はAnsibleのインベントリファイルで、ノードリストとグループ定義を含みます。主なグループ：

- **nodes**: 全ノード（golgi01〜golgi14）
- **nodes_online**: 現在接続可能なノード
- **nodes_gtx780ti**: GTX 780Ti搭載ノード（CUDA 10.2が必要）
- **nodes_rtx2080**: RTX 2080搭載ノード（CUDA 11.4が最適）

**注意**: ノードのGPUが変更された場合は、このファイルのグループ定義を更新する必要があります。

## 主要なロールと機能

各ロールは特定の機能を担当します。主要なロールについて説明します。

### CUDA関連ロール

- **cuda-10.2**: GTX 780Ti用CUDA環境構築
  - CUDA 10.2は古いGPU（Compute Capability 3.5）向け
  - Gromacs 2020.3と互換性あり

- **cuda-11.4**: RTX 2080用CUDA環境構築
  - CUDA 11.4は新しいGPU（Compute Capability 7.5）向け
  - Gromacs 2022.4と互換性あり

- **cuda-12.0**: 最新のGPU向けCUDA環境
  - Ubuntu 22.04との互換性が高い

### Gromacs関連ロール

- **gromacs-2020.3**: CUDA 10.2と互換性のある分子動力学シミュレーションソフトウェア
  - GTX 780Ti用に最適化
  - `-DGMX_CUDA_TARGET_SM=35`を使用

- **gromacs-2022.4**: CUDA 11.4/12.0と互換性のある新バージョン
  - RTX 2080用に最適化
  - `-DGMX_CUDA_TARGET_SM=75`を使用

### システム管理ロール

- **admin-ubuntu** / **child-ubuntu**: 基本的なUbuntu設定
  - タイムゾーン設定（Asia/Tokyo）
  - ホスト名とIPの設定
  - サスペンド機能の無効化

- **apt**: パッケージ管理の設定
  - 自動アップグレードの無効化（NVIDIAドライバとの競合防止）
  - 日本のミラーサーバー設定

- **nis** / **nis-server**: アカウント情報共有
  - NISクライアント設定（子ノード用）
  - NISサーバー設定（親ノード用）
  - `MINGID=999`設定（dockerグループ共有のため）

- **nfs**: ファイル共有設定
  - `/home`ディレクトリのNFSマウント
  - GolgiFS（192.168.2.201）からのマウント

### ジョブ管理ロール

- **slurm**: ジョブスケジューラ
  - Slurm設定ファイル（slurm.conf）の生成
  - GPU数に応じたgres.conf設定
  - Slurmサービス（slurmctld/slurmd）の管理

- **munge**: Slurm認証システム
  - 共有認証キーの配置
  - Mungeサービスの設定と起動

### 機械学習関連ロール

- **tensorflow**: TensorFlow環境
  - Docker環境の設定
  - NVIDIA Docker設定

- **admin-alphafold** / **child-alphafold**: AlphaFold環境
  - 親ノードでのAlphaFoldディレクトリマウント
  - 子ノードでのNFSマウントとDockerイメージ設定

## GPUタイプと対応するCUDA

Golgiクラスターでは、異なるGPUタイプが混在しています。各GPUタイプには最適なCUDAバージョンがあります。

### GPUタイプとCompute Capability

1. **GeForce GTX 780Ti**:
   - Compute Capability: 3.5（Kepler世代）
   - 対応CUDA: 10.2まで
   - Gromacsの最適バージョン: 2020.3

2. **RTX 2080 / RTX 2080 SUPER**:
   - Compute Capability: 7.5（Turing世代）
   - 対応CUDA: 11.x / 12.0
   - Gromacsの最適バージョン: 2022.4

### CUDA / GPUトラブルシューティング

GPUが正しく認識されない場合の確認事項:

1. **Secure Boot確認**:
   ```
   mokutil --sb-state
   ```
   「SecureBoot enabled」と表示される場合、UEFI BIOSでSecure Bootを無効化する必要があります。

2. **CUDA/ドライババージョン確認**:
   ```bash
   nvidia-smi
   /usr/local/cuda/bin/nvcc --version
   ```
   バージョン不一致がある場合は、適切なCUDAロールを適用します。

3. **GPUが搭載されているか確認**:
   ```bash
   lspci | grep -i nvidia
   ```
   物理的に搭載されていない場合や、PCIeスロットの問題の可能性があります。

## よくあるトラブルと対処法

### NVIDIAドライバ関連

1. **nvidia-smiが「No devices found」を返す**:
   - Secure Bootが有効になっている可能性（UEFI BIOSで無効化）
   - カーネルとドライバのバージョン不一致（適切なCUDAロールを再適用）
   - GPUが物理的に認識されていない（物理接続確認）

2. **「driver/library version mismatch」エラー**:
   - カーネル更新後にドライバが再構築されていない
   - 対処: 適切なCUDAロールを再適用
   ```bash
   ./safe_apply.sh  # GPUタイプに応じて4)または5)を選択
   ```

### NIS/NFS関連

1. **「YPBINDPROC_DOMAIN: Domain not bound」エラー**:
   - NISサーバーへの接続問題
   - 対処: NIS設定を再適用
   ```bash
   ansible-playbook -i production nodes.yml --tags=nis --ask-become-pass
   ```

2. **「Permission denied」NFS関連エラー**:
   - NFSエクスポート設定の問題
   - 対処: NFSサーバー設定を確認し、必要に応じて修正
   ```bash
   # GolgiAdminで
   cat /etc/exports
   # /volume1/homes 192.168.2.0/255.255.255.0(rw,sync,no_subtree_check,no_root_squash) のような行があるか確認
   ```

### Slurm関連

1. **「can't stat gres.conf file /dev/nvidia1」エラー**:
   - 物理的なGPU数とslurm.conf/gres.confの設定不一致
   - 対処: gres.confを実際のGPU数に合わせて修正
   ```bash
   sudo vi /opt/slurm/etc/gres.conf
   # 例: NodeName=golgi14 Name=gpu File=/dev/nvidia0
   # 例: NodeName=golgi08 Name=gpu File=/dev/nvidia[0-1]
   ```

2. **ノードがdrain/downのまま**:
   - 状態を手動でリセット
   ```bash
   sudo /opt/slurm/bin/scontrol update node=golgi05 state=idle
   ```

### その他のトラブル

1. **SSH接続問題「Exceeded MaxStartups」**:
   - 並列SSH接続の制限に達した
   - 対処: `/etc/ssh/sshd_config`の`MaxStartups`値を増加

2. **ブレーカー落ち後の復旧**:
   - 「[停電後の復旧手順](#停電後の復旧手順)」セクションを参照

## 停電後の復旧手順

計画停電や突然の電源断の後は、以下の手順でクラスターを復旧します。

### ステップ1: 物理的な確認

1. 全ノードの電源が入っていることを確認
2. ネットワークケーブルが接続されていることを確認
3. ファイルサーバー（GolgiFS）の電源が入っていることを確認

### ステップ2: 親ノードの復旧

1. 親ノード（GolgiAdmin）にログイン
2. 基本サービス確認
   ```bash
   systemctl status rpcbind nfs-kernel-server slurmctld
   ```
3. 必要に応じて親ノード設定を適用
   ```bash
   cd /srv/ansible
   ./safe_apply.sh  # メニューから「1) 親ノード（GolgiAdmin）の設定適用」を選択
   ```

### ステップ3: 子ノードの接続確認

1. 接続可能なノードの確認
   ```bash
   ansible nodes -i production -m ping
   ```
2. 接続できるノードリストを`production`ファイルの`nodes_online`グループに追加
   ```bash
   vi /srv/ansible/production
   ```

### ステップ4: 子ノードの復旧

1. 接続可能なノードに対してAnsibleを適用
   ```bash
   ./safe_apply.sh  # メニューから「8) 接続可能なノードのみに設定適用」を選択
   ```
2. 各ノードの状態を確認
   ```bash
   ./safe_apply.sh  # メニューから「7) システム状態の検証のみ」を選択
   ```

### ステップ5: Slurmノード状態の復旧

1. ノードの状態を確認
   ```bash
   sinfo
   ```
2. down/drainノードをリセット
   ```bash
   sudo /opt/slurm/bin/scontrol update node=golgiXX state=idle
   ```

### ステップ6: 各ノードのGPU確認

全ノードでGPUが正しく認識されていることを確認
```bash
ansible nodes -i production -m shell -a "hostname && nvidia-smi" --ask-become-pass
```

## 設定の追加・変更方法

### インベントリファイルの更新

新しいノードを追加する場合や、GPUタイプが変更された場合は、`production`ファイルを更新します。

```bash
vi /srv/ansible/production
```

例えば、新しいノード「golgi15」をRTX 2080グループに追加する場合：

```
[nodes]
golgi01
...
golgi14
golgi15

[nodes_rtx2080]
...
golgi13
golgi14
golgi15

[nodes_cuda114]
...
golgi13
golgi14
golgi15
```

### 新しいロールの追加

特定の機能を追加したい場合は、新しいロールを作成できます。

1. ロールディレクトリを作成:
   ```bash
   mkdir -p /srv/ansible/roles/new-role/{tasks,handlers,defaults,files,templates,meta}
   ```

2. メインタスクファイルを作成:
   ```bash
   vi /srv/ansible/roles/new-role/tasks/main.yml
   ```

3. 既存のプレイブックにロールを追加:
   ```bash
   vi /srv/ansible/nodes.yml
   # 適切な場所に "- role: new-role" を追加
   ```

### 特定のノードに特定の設定を適用

特定のノードにのみ適用したい設定がある場合：

1. インベントリに専用グループを追加:
   ```
   [special_nodes]
   golgi05
   golgi06
   ```

2. プレイブックで条件付き適用:
   ```yaml
   - hosts: nodes
     tasks:
     - name: Apply special configuration
       include_role:
         name: special-role
       when: inventory_hostname in groups['special_nodes']
   ```

## 連絡先とサポート

* **内部ドキュメント**: `/srv/ansible/docs/` ディレクトリに詳細なドキュメントがあります
* **マニュアル**: より詳細なマニュアルは `/srv/docs/golgi_management_manual.md` を参照してください
* **連絡先**: 問題やサポートが必要な場合は研究室のシステム管理者に連絡してください

---

このREADMEは、Golgiクラスター管理のための基本的な情報を提供します。システムの詳細な理解と管理経験を積むために、定期的にAnsibleプレイブックの内容を確認し、小さな更新から始めることをお勧めします。
