# Golgi クラスター Ansible 構成ガイド

このドキュメントは、計算機クラスター「Golgi」の自動化管理に使用されるAnsible構成について説明します。Golgiの管理を引き継ぐ方は、このドキュメントを通じて各Ansible Playbookの機能、実行方法、およびクラスター管理の効率化についての理解を深めることができます。

## 目次

1. [はじめに](#はじめに)
2. [ディレクトリ構造](#ディレクトリ構造)
3. [実行方法](#実行方法)
4. [メインPlaybook](#メインplaybook)
5. [インベントリファイル](#インベントリファイル)
6. [ロール詳細](#ロール詳細)
7. [一般的な管理タスク](#一般的な管理タスク)
8. [トラブルシューティング](#トラブルシューティング)
9. [設定ファイル例](#設定ファイル例)

## はじめに

Golgiクラスターは親ノード（GolgiAdmin）と複数の子ノード（golgi01〜golgi14）で構成される計算機クラスターです。このクラスターを効率的に管理するために、Ansibleを用いた自動化システムが構築されています。

Ansibleは複数のサーバーに対して同時に設定変更やソフトウェアインストールを行うことができるIT自動化ツールです。GolgiクラスターではAnsibleを使用して以下の作業を自動化しています：

- OSの基本設定
- NIS/NFSを用いたアカウントとファイル共有
- Slurmジョブスケジューラの構成
- CUDA/GPUドライバのインストールと設定
- Gromacs等の科学計算ソフトウェアのインストール
- AlphaFold環境の構築
- 監視ツールの設定

このAnsible構成は、計画停電後の復旧作業や新規ノードの追加、ソフトウェアアップデートなど、様々な管理作業を効率化するために設計されています。

## ディレクトリ構造

`/srv/ansible` ディレクトリには以下のファイルが含まれています：

```
/srv/ansible/
├── admin.yml           # 親ノード設定用Playbook
├── backup_configs.yml  # 設定ファイルバックアップ用Playbook
├── logs/               # Ansible実行ログディレクトリ
├── nodes.yml           # 子ノード設定用Playbook
├── production          # インベントリファイル（ノード一覧）
├── roles/              # 各種ロール（機能単位）ディレクトリ
│   ├── admin-alphafold/    # AlphaFold親ノード設定
│   ├── admin-ubuntu/       # Ubuntu親ノード基本設定
│   ├── apt/                # APTリポジトリ設定
│   ├── child-alphafold/    # AlphaFold子ノード設定
│   ├── child-ubuntu/       # Ubuntu子ノード基本設定
│   ├── cuda-10.2/          # CUDA 10.2インストール（GTX780Ti用）
│   ├── cuda-11.4/          # CUDA 11.4インストール（RTX2080用）
│   ├── cuda-12.0/          # CUDA 12.0インストール
│   ├── gfortran/           # gfortranコンパイラインストール
│   ├── gromacs-2019.4/     # Gromacs 2019.4インストール
│   ├── gromacs-2020.3/     # Gromacs 2020.3インストール（GTX780Ti向け）
│   ├── gromacs-2022.4/     # Gromacs 2022.4インストール（親ノード用）
│   ├── gromacs-2022.4-child/ # Gromacs 2022.4インストール（RTX2080向け）
│   ├── lm-sensors/         # 温度監視ツールインストール
│   ├── munge/              # Slurm認証システム設定
│   ├── nfs/                # NFSクライアント設定
│   ├── nis/                # NISクライアント設定
│   ├── nis-server/         # NISサーバー設定
│   ├── slurm/              # Slurmジョブスケジューラ設定
│   └── tensorflow/         # TensorFlow/Docker環境設定
├── safe_apply.sh       # 安全なAnsible適用スクリプト
└── verify_changes.yml  # 変更検証用Playbook
```

## 実行方法

Ansible Playbookの実行には `/srv/ansible/safe_apply.sh` スクリプトを使用します。このスクリプトは設定変更を安全に適用するためのメニューインターフェースを提供します。

```bash
cd /srv/ansible
./safe_apply.sh
```

実行すると以下のようなメニューが表示されます：

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
```

各メニュー項目の機能：

1. **親ノード設定適用**: `admin.yml` を実行して親ノード（GolgiAdmin）を設定します
2. **全子ノード設定適用**: `nodes.yml` を実行してすべての子ノードを設定します
3. **特定ノード設定適用**: 指定した子ノードのみに設定を適用します
4. **GTX 780Ti向け設定**: GTX 780Ti GPUを搭載したノードに適した設定を適用します
5. **RTX 2080向け設定**: RTX 2080 GPUを搭載したノードに適した設定を適用します
6. **バックアップ作成**: 設定ファイルのバックアップのみを作成します
7. **状態検証**: システム状態の検証のみを行います
8. **接続可能ノード設定**: 現在接続可能なノードのみに設定を適用します

スクリプトは選択に応じてAnsible Playbookを実行し、「yes」（実行）、「no」（キャンセル）、「check」（チェックモードで実行）のいずれかを選択できます。

## メインPlaybook

### admin.yml

`admin.yml` は親ノード（GolgiAdmin）の設定を行うPlaybookです。主な機能：

1. **バックアップ作成**: 重要な設定ファイルのバックアップを作成
2. **基本設定適用**: `apt` と `admin-ubuntu` ロールを適用して基本設定を行う
3. **条件付き設定**:
   - `/home` マウント状態を確認し、必要な場合は `nfs` ロールを適用
   - NISサーバー状態を確認し、必要な場合は `nis-server` ロールを適用
   - gfortranの有無を確認し、必要な場合は `gfortran` ロールを適用
   - Gromacsのインストール状態を確認し、必要な場合は `gromacs-2022.4` ロールを適用
   - Slurmの状態を確認し、必要な場合は `slurm` ロールを適用
   - AlphaFoldのマウント状態を確認し、必要な場合は `admin-alphafold` ロールを適用

このPlaybookは実行前に現在の状態をチェックし、必要な設定のみを適用する「冪等性（べきとうせい）」を備えています。既に設定済みの項目は再適用されません。

### nodes.yml

`nodes.yml` は子ノードの設定を行うPlaybookです。主な機能：

1. **ノード状態確認**: 各ノードの状態（NVIDIAドライバ、実行中のジョブ）を確認
2. **バックアップ作成**: 重要な設定ファイルのバックアップを作成
3. **基本設定適用**: 全ノードに `child-ubuntu`、`apt`、`nis`、`nfs`、`lm-sensors` ロールを適用
4. **GPUタイプ検出**: ノードのGPUタイプを検出し、適切なCUDAバージョンを選択
   - GTX 780Ti → CUDA 10.2
   - RTX 2080/2080 SUPER → CUDA 11.4
5. **Gromacs設定**: GPUタイプに応じて適切なGromacsバージョンをインストール
   - GTX 780Ti → Gromacs 2020.3
   - RTX 2080/2080 SUPER → Gromacs 2022.4
6. **TensorFlow/Docker設定**: Docker環境を設定（必要な場合のみ）
7. **Slurm設定**: Slurmクライアントを設定（必要な場合のみ）
8. **AlphaFold設定**: AlphaFold環境を設定（必要な場合のみ）

このPlaybookもGPUタイプや既存の設定状態を検出し、必要な設定のみを適用する設計になっています。

## インベントリファイル

`production` ファイルはAnsibleのインベントリファイルで、管理対象ノードと各種グループを定義しています：

```
[nodes]          # 全ノードグループ
golgi01
golgi02
...
golgi14

[nodes_online]   # 接続可能なノードグループ
golgi06
golgi07
...
golgi14

[nodes_gtx780ti] # GeForce GTX 780Ti搭載ノード
golgi14

[nodes_rtx2080]  # RTX 2080/2080 SUPER搭載ノード
golgi08
golgi09
...
golgi13

[nodes_cuda102]  # CUDA 10.2適用ノード
golgi14

[nodes_cuda114]  # CUDA 11.4適用ノード
golgi08
golgi09
...
golgi13
```

各グループは特定の設定を適用する際のターゲットとして使用されます。例えば、GTX 780Ti搭載ノードのみにCUDA 10.2を適用する場合は `nodes_gtx780ti` グループを指定します。

## ロール詳細

各ロールは特定の機能を担当し、タスクファイル（`tasks/main.yml`）に具体的な処理が定義されています。主要なロールについて説明します：

### OSベース設定

- **apt**: APTリポジトリをJapan向けに変更し、自動アップグレードを無効化して意図しないカーネルアップデートを防止します。
- **admin-ubuntu**: 親ノード向けの基本設定を行います（タイムゾーン設定、ホスト名設定、サスペンド無効化、IPフォワーディング設定など）。
- **child-ubuntu**: 子ノード向けの基本設定を行います（タイムゾーン設定、ホスト名設定、サスペンド無効化など）。

### ネットワーク・共有設定

- **nis-server**: 親ノードにNISサーバーを設定し、ユーザーアカウント・グループ情報の共有を可能にします。特に重要なのは「MINGID=999」の設定で、dockerグループ（ID=999）を共有できるようにします。
- **nis**: 子ノードにNISクライアントを設定し、親ノードからユーザー情報を取得できるようにします。
- **nfs**: NFSクライアント設定を行い、共有ファイルシステム（GolgiFS:/volume1/homes）を各ノードの/homeにマウントします。
- **admin-alphafold**: AlphaFold用のNFSエクスポートを親ノードに設定します。
- **child-alphafold**: AlphaFold用のNFSマウントを子ノードに設定します。

### CUDA・GPU関連

- **cuda-10.2**: CUDA 10.2をインストールします（GTX 780Ti向け）。パッチも適用し、実行中のジョブがある場合は再起動を回避します。
- **cuda-11.4**: CUDA 11.4をインストールします（RTX 2080/2080 SUPER向け）。
- **cuda-12.0**: CUDA 12.0をインストールします（対応GPUを搭載した新型ノード向け）。

### 計算ソフトウェア

- **gromacs-2020.3**: Gromacs 2020.3をインストールします（GTX 780Ti向け、CUDA 10.2依存）。
- **gromacs-2022.4**: Gromacs 2022.4をインストールします（親ノード向け、CUDA 12.0依存）。
- **gromacs-2022.4-child**: Gromacs 2022.4をインストールします（RTX 2080向け、CUDA 11.4依存）。
- **tensorflow**: TensorFlow実行環境としてDocker/NVIDIA Dockerをインストールします。

### ジョブ管理

- **munge**: Slurmの認証システムであるMungeをインストールし、共有鍵を設定します。
- **slurm**: Slurmジョブスケジューラをインストールし、必要な設定ファイル（slurm.conf、gres.conf）を配置します。親ノードにはslurmctld、子ノードにはslurmdを設定します。

### 監視・その他

- **lm-sensors**: CPU温度など、ハードウェア状態を監視するためのツールをインストールします。
- **gfortran**: GromacesビルドなどでFortranコンパイラが必要な場合にインストールします。

## 一般的な管理タスク

以下に一般的な管理タスクの実行方法を示します：

### 1. 計画停電後の復旧手順

```bash
cd /srv/ansible
./safe_apply.sh
# メニューから「8) 接続可能なノードのみに設定適用」を選択
# 確認画面で「yes」を入力
```

これにより、現在接続可能なノードのみに必要な設定が適用されます。すべてのノードを復旧させるには、次に「2) すべての子ノードに設定適用」を選択します。

### 2. 新規ノードの追加

1. インベントリファイル（`production`）に新しいノードを追加します：
```bash
vi /srv/ansible/production
# [nodes]セクションに新ノードを追加
# 適切なGPUタイプグループにも追加
```

2. 新規ノードの基本設定を適用します：
```bash
cd /srv/ansible
./safe_apply.sh
# メニューから「3) 特定の子ノードのみに設定適用」を選択
# ノード名（例：golgi15）を入力
```

### 3. CUDAバージョンのアップデート

CUDAドライバの更新が必要な場合は以下のようにします：

1. 新しいCUDAドライバファイルを適切なロールディレクトリに配置：
```bash
# 例：CUDA 11.4アップデート
cp cuda-repo-ubuntu2004-11-4-local_11.4.2-xyz.deb /srv/ansible/roles/cuda-11.4/files/
```

2. 必要に応じてroles/cuda-11.4/defaults/main.ymlのバージョン情報を更新

3. 対象ノードに適用：
```bash
cd /srv/ansible
./safe_apply.sh
# メニューから「5) GPUタイプ別に設定適用（RTX 2080）」を選択
```

### 4. NISグループ設定の修正

dockerグループなどのNIS共有に問題がある場合：

```bash
cd /srv/ansible
./safe_apply.sh
# メニューから「1) 親ノード（GolgiAdmin）の設定適用」を選択
```

### 5. システム全体の状態検証

```bash
cd /srv/ansible
./safe_apply.sh
# メニューから「7) システム状態の検証のみ」を選択
```

この操作はすべてのノードの状態（ネットワーク、NIS、NFS、NVIDIA、Slurm）を検証し、問題があればレポートします。

## トラブルシューティング

Ansible構成に関する一般的な問題と解決策：

### 1. Playbookの実行に失敗する場合

特定のタスクから実行を再開する方法：
```bash
cd /srv/ansible
ansible-playbook -i production nodes.yml --limit=golgi01 --start-at-task="タスク名" --ask-become-pass
```

ステップバイステップで実行する方法：
```bash
cd /srv/ansible
ansible-playbook -i production nodes.yml --limit=golgi01 --step --ask-become-pass
```

### 2. GPUに関する問題

CUDA/ドライバの問題が発生した場合、適切なロールを適用します：
```bash
# 例：GTX 780Ti搭載ノードでnvidia-smiが動作しない場合
cd /srv/ansible
./safe_apply.sh
# 「4) GPUタイプ別に設定適用（GTX 780Ti）」を選択
```

### 3. Slurmの問題

Slurmの設定に問題がある場合、slurm.confやgres.confの問題が考えられます。検証と修正方法：

```bash
# Slurm設定のみを再適用
cd /srv/ansible
ansible-playbook -i production nodes.yml --limit=problematic_node --tags="slurm" --ask-become-pass
```

### 4. NIS/NFSの問題

NISやNFSの問題が発生した場合、以下のコマンドで設定を再適用します：

```bash
# NFS設定のみを再適用
cd /srv/ansible
ansible-playbook -i production nodes.yml --limit=problematic_node --tags="nfs" --ask-become-pass
```

### 5. Ansibleログの確認

Ansible実行ログは `/srv/ansible/logs/` ディレクトリに保存されます。問題調査のために確認してください：

```bash
ls -lt /srv/ansible/logs/
# 最新のログファイルを確認
cat /srv/ansible/logs/ansible_yyyymmdd_HHMMSS.log | less
```

## 設定ファイル例

### slurm.conf テンプレート

Slurmの設定は `/opt/slurm/etc/slurm.conf` に保存されます。この設定はAnsibleのテンプレート（`roles/slurm/templates/slurm2.conf.j2`）から生成されます。

### gres.conf

GPUリソース設定は `/opt/slurm/etc/gres.conf` に保存されます：

```
# GTX 780Ti搭載ノード（GPU 1枚）
NodeName=golgi14 Name=gpu File=/dev/nvidia0

# RTX 2080搭載ノード（GPU 2枚）
NodeName=golgi[08-13] Name=gpu File=/dev/nvidia[0-1]
```

### NIS設定

NISサーバー設定で重要なのは `/var/yp/Makefile` の `MINGID=999` の設定です。これによりdockerグループ（ID=999）が正しく共有されます。

## まとめ

このAnsible構成はGolgiクラスターの管理を自動化するための包括的なフレームワークを提供します。計画停電後の復旧や新規ノードの追加などの作業を効率化することができます。

適切なPlaybookやロールを選択し、必要に応じてインベントリを更新することで、クラスター全体の一貫した設定を維持できます。問題が発生した場合は、`verify_changes.yml` を使って状態を検証し、特定のロールを再適用することで解決できることが多いです。

モジュール化された設計により、将来的な拡張やカスタマイズも容易です。例えば、新しいGPUタイプや科学計算ソフトウェアのサポートを追加する場合は、既存のロールをテンプレートとして新しいロールを作成できます。

Golgiクラスターの安定運用のために、設定変更前には必ず `safe_apply.sh` のチェックモードを使用して影響を確認することをお勧めします。





# Golgi クラスター Ansible 構成ガイド（続き）

## Ansibleロールの詳細解説

各ロールの具体的な機能と重要なポイントをより詳しく説明します。

### CUDA関連ロールの詳細

#### cuda-10.2

このロールはGTX 780Ti（Compute Capability 3.5）向けに最適化されています。主な特徴：

- インストール前に既存のCUDA/GPUドライバの動作チェック
- 実行中のジョブを検出し、再起動が必要な場合は安全に処理
- パッチ（10.2.1、10.2.2）の適用による安定性向上
- gcc-8を使用したコンパイルによる互換性確保

重要な部分のコード：

```yaml
# GPUドライバの動作確認
- name: Check if GPU drivers are already working
  command: nvidia-smi
  register: nvidia_smi_check
  ignore_errors: yes
  changed_when: false

# 実行中ジョブの確認
- name: Check for running jobs
  command: squeue -h -o "%i" -t running -w {{ ansible_hostname }}
  register: running_jobs
  ignore_errors: yes
  changed_when: false

# 安全な再起動処理
- name: Notify reboot only if CUDA was installed/upgraded and no jobs are running
  command: echo "Reboot is needed"
  notify: reboot the machine
  when:
    - (cuda_installed is defined and cuda_installed.changed) or (cuda_upgraded is defined and cuda_upgraded.changed)
    - running_jobs.stdout_lines | length == 0
    - process_count.stdout | int < 5
```

#### cuda-11.4

RTX 2080/2080 SUPER（Compute Capability 7.5）向けに最適化されています。cuda-10.2と比較した主な違い：

- より新しいNVIDIA GPUアーキテクチャのサポート
- 異なるGPGキーとリポジトリ構成
- Ubuntu 20.04との互換性に特化

### Gromacs関連ロールの違い

各Gromacsロールの最適化の違いを理解することが重要です：

#### gromacs-2020.3（GTX 780Ti向け）

```yaml
- name: Set GPU architecture for GTX 780Ti
  set_fact:
    cuda_target: "-DGMX_CUDA_TARGET_SM=35"
  when: gpu_type.stdout is defined and 'GTX 780Ti' in gpu_type.stdout

# gcc-8を使用してCUDA 10.2との互換性を確保
- name: configure
  command: >
    cmake {{ source_directory }}/gromacs-{{ version }}
    -DCMAKE_C_COMPILER=gcc-8
    -DCMAKE_CXX_COMPILER=g++-8
    -DGMX_SIMD=AVX2_256
    -DGMX_GPU=ON
    {{ cuda_target }}
    -DCUDA_TOOLKIT_ROOT_DIR=/usr/local/cuda
```

#### gromacs-2022.4-child（RTX 2080向け）

```yaml
- name: configure
  command: "cmake {{ source_directory }}/gromacs-{{ version }} -DGMX_SIMD=AVX2_256 -DGMX_GPU=CUDA -DCUDA_TOOLKIT_ROOT_DIR=/usr/local/cuda -DREGRESSIONTEST_DOWNLOAD=ON -DCMAKE_INSTALL_PREFIX={{ install_prefix }}-{{ version }}"
```

主な違いは：
- コンパイラ指定（2020.3はgcc-8を明示的に使用）
- ターゲットGPUアーキテクチャ設定
- テスト方法（2022.4は`REGRESSIONTEST_DOWNLOAD=ON`を使用）

## カスタマイズとベストプラクティス

### インベントリファイルのカスタマイズ

新規ノード追加時のベストプラクティス：

1. ノードの基本情報（IPアドレス、ホスト名）を`/etc/hosts`に追加
2. `production`ファイルの適切なセクションに追加
3. ノードのハードウェア特性に基づいて、適切なグループに割り当て

例えば、新しいRTX 3090搭載ノードを追加する場合：

```ini
# productionファイルに新しいノードとグループを追加
[nodes]
golgi01
...
golgi15  # 新規ノード

# 新しいGPUタイプのグループを作成
[nodes_rtx3090]
golgi15

# CUDA 11.4グループに追加（RTX 3090はCUDA 11.4と互換性がある）
[nodes_cuda114]
golgi08
...
golgi15
```

### 新しいロールの追加

新しいソフトウェアやハードウェアをサポートするためのロール追加手順：

1. 既存の類似ロールをテンプレートとしてコピー
2. `defaults/main.yml`でデフォルト変数を定義
3. `tasks/main.yml`で実行タスクを定義
4. 依存関係を`meta/main.yml`で指定
5. 必要に応じて`handlers/main.yml`でイベントハンドラを定義

例えば、Gromacs 2023向けの新しいロールを作成する場合：

```bash
# ディレクトリ構造をコピー
cp -r /srv/ansible/roles/gromacs-2022.4 /srv/ansible/roles/gromacs-2023.0

# 設定を編集
vi /srv/ansible/roles/gromacs-2023.0/defaults/main.yml
# version: 2023.0 に変更

# タスクを必要に応じて編集
vi /srv/ansible/roles/gromacs-2023.0/tasks/main.yml
```

### 複雑な依存関係の管理

Ansible Galaxyを使用したロール管理を検討することも有効です：

```bash
# 依存関係の定義をrequirements.ymlに記述
cat > /srv/ansible/requirements.yml <<EOF
---
roles:
  - name: cuda-11.4
    src: /srv/ansible/roles/cuda-11.4
    version: master
  - name: gromacs-2022.4
    src: /srv/ansible/roles/gromacs-2022.4
    version: master
EOF

# 依存関係をインストール
ansible-galaxy install -r requirements.yml
```

## セキュリティ考慮事項

### SSH鍵による認証

現在の構成では`ansible_ssh_user=ansible`と`ansible_ssh_pass=ansible`を使用していますが、本番環境ではSSH鍵による認証を推奨します：

```bash
# Ansible用のSSH鍵を生成
ssh-keygen -t ed25519 -f /home/ansible/.ssh/id_ed25519 -C "ansible@golgiadmin"

# 各ノードに公開鍵を配布
for node in golgi{01..14}; do
  ssh-copy-id -i /home/ansible/.ssh/id_ed25519.pub ansible@$node
done

# productionファイルを更新
vi /srv/ansible/production
# [nodes:vars]セクションを変更:
# ansible_ssh_user=ansible
# ansible_ssh_private_key_file=/home/ansible/.ssh/id_ed25519
# ansible_python_interpreter=/usr/bin/python3
```

### 権限の最小化

Ansible実行ユーザーには必要最小限の権限だけを付与することが重要です：

```bash
# sudoersファイルを編集
visudo -f /etc/sudoers.d/ansible

# 以下の内容を追加（特定のコマンドのみ許可）
ansible ALL=(ALL) NOPASSWD: /usr/bin/apt-get, /usr/bin/systemctl, /usr/sbin/service
```

### シークレット管理

パスワードやAPIキーなどの機密情報はAnsible Vaultを使用して暗号化します：

```bash
# 新しいVaultファイルを作成
ansible-vault create /srv/ansible/group_vars/all/vault.yml

# 既存ファイルを暗号化
ansible-vault encrypt /srv/ansible/group_vars/all/secrets.yml

# Vaultパスワードをファイルに保存（安全な場所に置くこと）
echo "your-secure-password" > ~/.ansible_vault_pass
chmod 600 ~/.ansible_vault_pass

# ansible.cfgを設定
echo "vault_password_file = ~/.ansible_vault_pass" >> /srv/ansible/ansible.cfg
```

## パフォーマンスチューニング

### Slurmの最適化

クラスターのパフォーマンスを最大化するためのSlurm設定：

```ini
# /opt/slurm/etc/slurm.conf

# CPU/メモリ割り当ての最適化
SelectType=select/cons_tres
SelectTypeParameters=CR_Core_Memory

# GPUスケジューリングの最適化
GresTypes=gpu
NodeName=golgi[08-13] Gres=gpu:2
NodeName=golgi14 Gres=gpu:1

# 公平なスケジューリングポリシー
PriorityType=priority/multifactor
PriorityWeightAge=1000
PriorityWeightFairshare=10000
PriorityWeightJobSize=1000
PriorityWeightPartition=1000
PriorityWeightQOS=1000
```

### NFSパフォーマンス最適化

高速なファイルアクセスのためのNFS最適化：

```bash
# /etc/fstab のNFSマウントオプションを最適化
GolgiFS:/volume1/homes /home nfs rw,hard,intr,noatime,nodiratime,rsize=32768,wsize=32768 0 0
```

### CUDA関連最適化

GPUパフォーマンスを最大化するための設定：

```bash
# NVIDIA永続的モードを有効化
cat > /etc/systemd/system/nvidia-persistenced.service <<EOF
[Unit]
Description=NVIDIA Persistence Daemon
Wants=syslog.target

[Service]
Type=forking
ExecStart=/usr/bin/nvidia-persistenced --user ansible
ExecStopPost=/bin/rm -rf /var/run/nvidia-persistenced

[Install]
WantedBy=multi-user.target
EOF

systemctl enable nvidia-persistenced.service
systemctl start nvidia-persistenced.service

# この設定をAnsibleロールに追加することも可能
```

## 定期メンテナンス手順

### 毎週のメンテナンスタスク

```bash
# 以下のタスクを週次で実行するcronジョブを設定

# システム状態の検証
cd /srv/ansible && ./safe_apply.sh < <(echo "7" && echo "n")

# 設定バックアップの作成
cd /srv/ansible && ./safe_apply.sh < <(echo "6" && echo "n")

# ログローテーション
find /srv/ansible/logs -name "ansible_*.log" -type f -mtime +30 -delete
```

### 月次メンテナンスタスク

```bash
# 以下のタスクを月次で実行

# 親ノード設定の更新
cd /srv/ansible && ./safe_apply.sh < <(echo "1" && echo "yes")

# 接続可能なノードのみに設定適用
cd /srv/ansible && ./safe_apply.sh < <(echo "8" && echo "yes")
```

### 緊急時の復旧手順

停電や予期せぬシャットダウン後の迅速な復旧手順：

1. ハードウェア確認
```bash
# 各ノードの電源とネットワーク接続を確認
for node in golgi{01..14}; do
  ping -c 1 $node &>/dev/null && echo "$node: online" || echo "$node: offline"
done
```

2. ファイルシステム復旧
```bash
# NFSサーバーの状態確認と復旧
ssh GolgiFS "sudo reboot"  # 必要な場合のみ
systemctl restart nfs-kernel-server
```

3. Ansible適用
```bash
cd /srv/ansible
./safe_apply.sh  # オプション8、1、2の順に実行
```

## 高度なAnsible機能

### 動的インベントリ

オンラインノードを動的に検出するスクリプトの作成：

```python
#!/usr/bin/env python3
# /srv/ansible/inventory/dynamic_nodes.py

import json
import subprocess
import sys

def ping_node(node):
    result = subprocess.run(["ping", "-c", "1", "-W", "1", node],
                            stdout=subprocess.DEVNULL,
                            stderr=subprocess.DEVNULL)
    return result.returncode == 0

def get_inventory():
    # 全ノードリスト
    all_nodes = [f"golgi{i:02d}" for i in range(1, 15)]

    # オンラインノードを検出
    online_nodes = [node for node in all_nodes if ping_node(node)]

    # インベントリ作成
    inventory = {
        "_meta": {
            "hostvars": {}
        },
        "all": {
            "children": ["nodes", "nodes_online"]
        },
        "nodes": {
            "hosts": all_nodes
        },
        "nodes_online": {
            "hosts": online_nodes
        }
    }

    return inventory

if __name__ == '__main__':
    if len(sys.argv) == 2 and sys.argv[1] == '--list':
        print(json.dumps(get_inventory()))
    else:
        print("{}")
```

このスクリプトを使用してオンラインノードのみにタスクを実行：

```bash
chmod +x /srv/ansible/inventory/dynamic_nodes.py
ansible-playbook -i /srv/ansible/inventory/dynamic_nodes.py nodes.yml --limit=nodes_online
```

### Ansibleタグの活用

特定のタスクのみを実行するためのタグ活用例：

```yaml
# nodes.ymlに以下のようなタグを追加
tasks:
  - name: Check NVIDIA driver status
    command: nvidia-smi
    register: nvidia_smi_result
    ignore_errors: yes
    changed_when: false
    tags: check

# タグを指定して実行
ansible-playbook -i production nodes.yml --tags=check
```

タグを活用した共通シナリオ：

1. 状態確認のみ実行
```bash
ansible-playbook -i production nodes.yml --tags=check
```

2. NFSマウントのみ修正
```bash
ansible-playbook -i production nodes.yml --tags=nfs
```

3. 特定のアプリケーションのみ更新
```bash
ansible-playbook -i production nodes.yml --tags=gromacs
```

## Golgiクラスター特有の最適化

### 多様なGPU環境の最大活用

Golgiクラスターは異なるGPUタイプ（GTX 780Ti、RTX 2080/2080 SUPER）を搭載しており、それぞれに最適化した環境を提供する必要があります。

Slurmジョブ投入時のGPUタイプ指定例：

```bash
# GTX 780Ti搭載ノードでのみ実行するジョブ
sbatch --constraint="GTX780Ti" job_script.sh

# RTX 2080搭載ノードでのみ実行するジョブ
sbatch --constraint="RTX2080" job_script.sh
```

これを可能にするための`gres.conf`設定：

```
NodeName=golgi14 Name=gpu Type=GTX780Ti File=/dev/nvidia0
NodeName=golgi08 Name=gpu Type=RTX2080 File=/dev/nvidia[0-1]
NodeName=golgi09 Name=gpu Type=RTX2080 File=/dev/nvidia[0-1]
# ...
```

### Gromacsパフォーマンスの最大化

GPUタイプごとに最適なGromacsパラメータを設定するバッチスクリプト：

```bash
#!/bin/bash
# /home/shared/bin/run_gromacs.sh

# 実行するノード名を取得
NODE=$(hostname)

# GPUタイプに基づいてパラメータを設定
if [[ "$NODE" == "golgi14" ]]; then
    # GTX 780Ti向け最適化
    PARAMS="-nb gpu -bonded cpu -pme cpu -npme 1"
else
    # RTX 2080向け最適化
    PARAMS="-nb gpu -bonded gpu -pme gpu -npme 0"
fi

# Gromacsコマンド実行
gmx mdrun $PARAMS "$@"
```

この最適化スクリプトをクラスター全体で共有：

```yaml
# AnsibleでGromacsパフォーマンス最適化スクリプトを配備
- name: Deploy Gromacs optimization script
  copy:
    src: files/run_gromacs.sh
    dest: /home/shared/bin/run_gromacs.sh
    mode: '0755'
    owner: root
    group: root
```

## まとめと今後の展望

このGolgi Ansible構成は、単なる設定管理ツールではなく、HPCクラスターの効率的な運用と最適化のための包括的なフレームワークです。以下の点に注目することで、クラスターの管理・運用・拡張性がさらに向上します：

1. **変更管理**: 重要な変更を行う前には必ずバックアップを取り、事前にチェックモードで安全性を確認してください。

2. **環境の標準化**: 新しいノードを追加する際は、既存のノードと同様の環境を確保するために、Ansible Playbookを使用した標準化された手順に従ってください。

3. **継続的改善**: ユーザーからのフィードバックや新しいハードウェア・ソフトウェア要件に基づいて、定期的にAnsible構成を見直し、更新してください。

4. **ドキュメント維持**: このREADMEを最新の状態に保ち、変更を行う際にはドキュメントも更新してください。

5. **知識共有**: Golgiクラスター管理の知識を共有し、複数の管理者がシステムを理解できるようにすることで、人的リスクを低減させます。

今後のGolgiクラスター発展のための検討事項：

- **コンテナ化**: Singularityなどのコンテナ技術を導入し、科学計算環境の互換性と再現性を向上
- **モニタリング強化**: Prometheus/Grafanaなどを用いた詳細なパフォーマンスモニタリングの実装
- **自動化拡張**: CIパイプラインとの統合による構成管理の自動化
- **クラウド連携**: 必要に応じてクラウドリソースと連携できるハイブリッドインフラの検討

Golgiクラスターのすべての面を管理するこのAnsible構成は、次世代の管理者にとって強力な基盤となります。常に改善と最適化を意識しながら、研究者の計算ニーズを効率的にサポートしていきましょう。
