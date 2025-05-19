以下に、`/srv/ansible`ディレクトリ内に配置する想定の「README.md」サンプルを作成しました。  
本ドキュメントは**GolgiクラスターのAnsible管理**を新たに担当する後輩の方へ向けた、できるだけ分かりやすく丁寧なガイドです。  
読みやすさを意識して、**用途や背景、使い方の手順、運用上の注意点**などを包括的にまとめています。

---

# README.md

## はじめに

本ディレクトリ（`/srv/ansible`）は、**研究室の計算機クラスター「Golgi」** をAnsibleで管理するための一式が置かれています。  
- Golgiクラスターには**親ノード（GolgiAdmin）**と**子ノード（golgi01〜golgiXX）**があり、Ubuntu Linux上で動作するGPU計算環境（CUDA・Gromacs・Slurm・NIS/NFSなど）を構築・管理しています。  
- このAnsibleプロジェクトを用いることで、**ノードの追加や環境アップデート、NIS/NFS設定変更などを効率よく実行**できます。  
- ここにまとめられたPlaybook・ロール・スクリプトを正しく使うことで、複数のノードを一括管理しつつ、**トラブルや再起動リスクを最小限に抑える**ことが可能です。

以下では、ディレクトリ構成や主要ファイル、実行手順、運用上の注意点などを段階的に解説します。


---

## 1. ディレクトリ構成

```
/srv/ansible/
├─ safe_apply.sh
├─ admin.yml
├─ nodes.yml
├─ production            (インベントリファイル)
├─ verify_changes.yml
├─ backup_configs.yml
├─ logs/                (Playbook実行ログが保存される)
├─ roles/               (各種ロールのディレクトリ)
│   ├─ cuda-10.2/
│   ├─ cuda-11.4/
│   ├─ cuda-12.0/
│   ├─ gromacs-2020.3/
│   ├─ gromacs-2022.4/
│   ├─ slurm/
│   ├─ nfs/
│   ├─ nis/
│   ├─ nis-server/
│   ├─ tensorflow/
│   ├─ child-ubuntu/
│   ├─ admin-ubuntu/
│   └─ ... (その他ロールいろいろ)
└─ (その他: iptables-restore, iptables.rulesなども存在)
```

### 主なファイル／フォルダの説明

1. **`safe_apply.sh`**  
   - **対話的にAnsibleを実行できるスクリプト**です。  
   - 「親ノードへの適用」「子ノードへの適用」「特定ノードへの適用」などのメニューがあり、誤操作を防止します。  
   - 実行ログは `logs/ansible_YYYYMMDD_HHMMSS.log` に保存されます。

2. **`admin.yml`**  
   - **親ノード（GolgiAdmin）** をセットアップ・管理するためのメインPlaybook。  
   - NISサーバーやNFSサーバー、Slurmコントローラ等、親ノード固有の処理を含みます。

3. **`nodes.yml`**  
   - **子ノード**（golgi01〜golgiXX）を管理するPlaybook。  
   - 子ノード共通の設定（CUDA、Gromacs、Slurm、NISクライアント、NFSクライアントなど）を一括適用できます。

4. **`production`** (インベントリファイル)  
   - `Ansible` で管理するホスト（golgi01, golgi02...）やグループ（`nodes_gtx780ti`, `nodes_rtx2080` など）の定義が書かれています。  
   - `ansible-playbook` コマンドの `-i production` オプションで利用されます。

5. **`verify_changes.yml`**  
   - Playbook適用後に**ネットワーク・NIS・NFS・NVIDIAドライバ・Slurmなどの動作確認**を行うためのPlaybook。

6. **`backup_configs.yml`**  
   - 各ノードの主要設定ファイル（`/etc/hosts` や `slurm.conf` など）を**バックアップ**するためのPlaybook。

7. **`logs/` ディレクトリ**  
   - `safe_apply.sh` 経由でPlaybookを実行した際のログが、日時付きファイルとして自動的に保存されます。

8. **`roles/` ディレクトリ**  
   - **Ansibleロール**が種類別（CUDA, Gromacs, Slurm, etc.）にまとまっています。  
   - ロールごとに`tasks/main.yml`があり、**インストール手順や設定編集タスク**が定義されています。


---

## 2. `safe_apply.sh` を使った手順

### 2.1 前提条件

- **Ansible** がインストール済みであること（バージョンは 2.13.7 など）。  
- 親ノード（GolgiAdmin）で実行するときは `sudo権限` が必要です。  
- この `/srv/ansible` ディレクトリ内でコマンドを実行してください（`cd /srv/ansible`）。

### 2.2 実行方法

1. `cd /srv/ansible`  
2. `chmod +x safe_apply.sh` （初回のみ、実行権限を与える）  
3. `./safe_apply.sh`  

すると、下記のようなメニューが表示されます（例）:

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

メニュー選択後、「実行するか？ (yes/no/check)」と聞かれますので、

- **yes**: 実際にPlaybookを実行（変更を適用）  
- **check**: チェックモード（--checkオプションを付けて実行。実際には変更しない）  
- **no**: キャンセル  

を選びます。

### 2.3 実行結果のログ

- `/srv/ansible/logs/` に `ansible_YYYYMMDD_HHMMSS.log` が作成され、Playbookの出力がすべて記録されます。  
- **30日以上前のログは自動的に削除**されますが、必要に応じてバックアップを取得しておくとよいでしょう。

### 2.4 補足（メニュー項目の説明）

- **1) 親ノードの設定適用**  
  - `admin.yml` を `localhost` (GolgiAdmin自体) に対して実行し、NISサーバーやNFSサーバー、Slurmコントローラ、AlphaFold共有ディレクトリなどの設定を行います。  

- **2) すべての子ノードに設定適用**  
  - `nodes.yml` を `[nodes]` グループに属する全ノードへ適用。  
  - 全ノード一括でCUDAやGromacs、Slurmノード設定などを更新します。  

- **3) 特定の子ノードのみに設定適用**  
  - `golgi08,golgi09` などカンマ区切り指定すると、そのノードだけに `nodes.yml` を適用可能。  
  - 個別に検証したい場合や、一部ノードのみ再構築したい場合に便利です。

- **4), 5) GPUタイプ別**  
  - `[nodes_gtx780ti]` や `[nodes_rtx2080]` グループ向けに `nodes.yml` を適用。  
  - CUDAバージョンやGromacsバージョンをGPUの世代ごとに変える際に便利。  

- **6) バックアップの作成のみ**  
  - `backup_configs.yml` を実行して、設定ファイルのバックアップを取得するだけです。  
  - 大きな変更をする前などに活用します。  

- **7) システム状態の検証のみ**  
  - `verify_changes.yml` を全ノードに実行し、NIS/NFS/NVIDIAドライバ/Slurmなどの状態をチェック。  
  - 問題があれば「FAILED」などと表示されるため、具体的にログを参照して対処します。

- **8) 接続可能なノードのみに設定適用**  
  - `[nodes_online]` グループに含まれるノード（現在SSHが通るノード）だけに `nodes.yml` を適用します。  
  - 一部ノードが落ちている状況でも、接続可能なノードだけ先に更新したい場合などに使用します。  


---

## 3. Playbookの詳細

### 3.1 `admin.yml`

- 親ノード専用のPlaybookです。  
- **NISサーバー設定** (`nis-server`ロール) や **NFSサーバー設定** (`nfs`ロールのサーバー側)、**Slurmコントローラ** (`slurm`ロール) などを条件付きで適用。  
- すでにサービスが起動している場合は再設定しない仕組みが多く、**必要最小限の変更のみ**行うよう工夫されています。  

### 3.2 `nodes.yml`

- 子ノード用Playbook。  
- 主な流れ：
  1. 前段で`nvidia-smi`結果や現在ジョブが走っているかをチェック  
  2. **各ロール（CUDA, Gromacs, Slurm, Docker, AlphaFoldなど）** を必要に応じて適用  
  3. GPUの種類 (GTX 780Ti / RTX 2080 など) によってインストールする**CUDAのバージョン**や**Gromacsのバージョン**を切り替える。  
  4. スクリプト内で「もしジョブが実行中なら再起動を見送る」などの制御も行う。  

### 3.3 `verify_changes.yml`

- **適用後の確認**に特化したPlaybookです。  
- 全ノードに対して、  
  - GolgiAdminへのping  
  - `ypcat passwd` (NIS動作チェック)  
  - `/home` がマウントされているか (NFSチェック)  
  - `nvidia-smi` (NVIDIAドライバチェック)  
  - `sinfo` (Slurmチェック)  
  - `gmx --version` (Gromacsチェック)  
  - Dockerで `alphafold` イメージがあるか  
  - などを一括テストし、結果を表示します。

### 3.4 `backup_configs.yml`

- 全ホストに対して**主要な設定ファイルをバックアップ**します。  
- `/root/ansible_backups/日付/` ディレクトリにコピーして保存する仕組み。  
- 変更前に安全策として実行しておくと、万が一設定ファイルが壊れた時も復旧しやすくなります。

---

## 4. インベントリ (`production`)

`production` ファイルには、以下のような内容が書かれています。

- `[nodes]`：`golgi01, golgi02, ... golgi14` のリスト  
- `[nodes_online]`：現在SSH可能なノードのみ  
- `[nodes_gtx780ti]`, `[nodes_rtx2080]`：GPU種類による分類  
- `[nodes_cuda102]`, `[nodes_cuda114]`：CUDAバージョンでの分類  
- `ansible_ssh_user=ansible`, `ansible_python_interpreter=/usr/bin/python3` などの共通変数設定

Ansibleがどのノードをどういうグループ名で扱うかがここで決まります。  
**Playbookが参照する変数（`inventory_hostname in groups['nodes_gtx780ti']` など）**もここを見ています。  
GPU構成が変わったら適宜ここを更新してください。

---

## 5. Roles（ロール）概要

`roles/`ディレクトリの下に多数のロールがあります。  
各ロールには `tasks/main.yml` や `defaults/main.yml`、`handlers/main.yml` などが配置されています。

代表的な例を挙げると：

1. **`cuda-10.2`, `cuda-11.4`, `cuda-12.0`**  
   - CUDA各バージョンをインストールするロール。  
   - `/tmp/cuda.deb` を展開して `apt` コマンドでインストールし、バージョンが合わなければ再起動（reboot）をかける、などの処理を行う。  

2. **`gromacs-2020.3`, `gromacs-2022.4`**  
   - ソースコードをダウンロードしてCMakeビルドを行い、Gromacsをインストールするロール。  
   - GPUのCompute Capabilityに合わせて `-DGMX_CUDA_TARGET_SM=35` (780Ti) などオプションを切り替える仕組みが入っています。  

3. **`slurm`**  
   - Slurmをソースからビルドし、`slurm.conf`, `gres.conf`のテンプレートを配置し、`slurmd.service` などをSystemdで起動する。  
   - 親ノードだと `slurmctld.service`、子ノードだと `slurmd.service` を制御します。  

4. **`nfs`**, **`nis`** / **`nis-server`**  
   - NFSクライアントやNFSサーバー設定、NISクライアントやNISサーバーの初期化(`ypinit -m`)などを行うロール。  

5. **`child-ubuntu`, `admin-ubuntu`**  
   - Ubuntuサーバーのタイムゾーンやhosts設定などの**初期セットアップ**をまとめたロール。  
   - 親ノードと子ノードで若干処理が異なるために分かれています。  

6. **`tensorflow`**  
   - DockerやNVIDIA Docker2をインストールし、Tensorflow向けのコンテナ環境を整備。  

7. **`child-alphafold`, `admin-alphafold`**  
   - AlphaFold用ディレクトリのNFS共有を親ノードでセットし、子ノードがマウントするまでの一連の設定。  
   - 必要に応じてAlphaFoldイメージをビルドする処理も含まれます。  

その他にも**各ロールの`tasks/` や `handlers/`**をよく読むと、どのような設定ファイルを書き換えているかが分かるので、トラブル時やカスタマイズ時は必ず参照してください。

---

## 6. 運用上の注意点

1. **必ず事前にバックアップを**  
   - 大きな変更（CUDAバージョンアップ、Slurmバージョンアップなど）を行う前は、  
     - メニュー「6) バックアップの作成のみ」を選んで `backup_configs.yml` を実行しておきましょう。  
   - 万一設定が壊れても `/root/ansible_backups/日付/` から復旧可能です。

2. **ジョブ稼働中のノードには注意**  
   - CUDAドライバやGromacsを再インストールすると**再起動が伴う場合**があります。  
   - `nodes.yml`ではジョブが走っているかをチェックし、走っていればrebootをスキップする仕組みもありますが、**安全のため利用者への周知を行う**など配慮してください。

3. **`--check`モードでテスト可能**  
   - 実際に変更を加える前に、Ansibleの「チェックモード」を使うとどのファイルを変更するか確認できます。  
   - `safe_apply.sh` の実行時、`check` を選択するか、あるいは `ansible-playbook -i production admin.yml --check` などの形で直接実行してもOKです。

4. **インベントリの更新**  
   - 新ノードを追加する際は `production` ファイルの `[nodes]` に新しいホスト名を追加し、SSH接続できるようにします。  
   - GPUの種類が増える場合は `[nodes_gtx780ti]` などに追記。または新たなグループを作るなど自由にアレンジしてください。

5. **ログの確認**  
   - 実行が失敗したときは、`logs/ansible_YYYYMMDD_HHMMSS.log` を参照すれば、どのタスクでエラーになったか詳細が分かります。  
   - 失敗した箇所に応じて**関連するロールのtasks**を調べると原因が見つかるでしょう。

6. **大掛かりな変更後は必ず `verify_changes.yml`**  
   - システム全体が正しく動いているか一括チェックできます。  
   - 修正が必要な箇所があれば「FAILED」など表示されるので、対応しましょう。

---

## 7. トラブルシューティングのヒント

- **NISが機能しない**  
  - `systemctl status nis` でステータスを確認し、`journalctl -xe` でエラーを探す。  
  - `/etc/defaultdomain` が正しいか、`/var/yp/Makefile` の `MINGID=999` が書き換わっていないか確認する。

- **NFSがマウントできない**  
  - `/home`がアクセス拒否される場合は、NAS側(`Synology`など)のエクスポート設定や `/etc/exports` を確認。  
  - もしくは `/srv/ansible/roles/nfs/tasks/main.yml` で設定しているマウント先やIPアドレス指定が誤っていないか確認する。

- **CUDAドライバが衝突・うまく入らない**  
  - Secure Bootの設定（BIOS）をOFFにしているか。  
  - aptの自動アップデートが入っていないか。  
  - `nvidia-smi` がエラーになる場合、バージョン不整合やPCIEスロットの物理的問題も疑う。

- **SlurmでジョブがPendingのまま**  
  - 該当ノードが落ちている、GPU台数が合わない、Slurmバージョンが違うなどの可能性。  
  - `sinfo -l` や `scontrol show node <nodename>` で状態を確認。

- **Docker / NVIDIA Dockerが動かない**  
  - `tensorflow` や `child-alphafold` ロールのタスクがすべて通っているか。  
  - `docker info` でNVIDIA関連のプラグインが認識されているか確認。

---

## 8. 参考コマンド（Playbook直接実行）

`safe_apply.sh` で対話的に実行するのが基本ですが、慣れてきたら以下のように**直接Ansibleコマンド**を叩くこともあります。  
ただし**操作を誤るとシステムに影響**を与えるので、十分注意してください。

```bash
# 親ノードにadmin.ymlを適用
ansible-playbook -i production admin.yml --limit=localhost --ask-become-pass

# 子ノード全台にnodes.ymlを適用
ansible-playbook -i production nodes.yml --ask-become-pass

# 特定ノードだけ
ansible-playbook -i production nodes.yml --limit="golgi08" --ask-become-pass

# チェックモード(実際には変更しない)
ansible-playbook -i production nodes.yml --limit="golgi08" --check --ask-become-pass

# 途中タスクから再開
ansible-playbook -i production nodes.yml --start-at-task="Apply CUDA 10.2 only for GTX 780Ti nodes"
```

---

## 9. 今後の拡張・更新手順

1. **新ノードの追加**  
   - `production` ファイルに新ノードを追記し、`safe_apply.sh` で「2) すべての子ノードに適用」もしくは「3) 特定の子ノード」等でセットアップ。  
   - GPUの種類などに応じて `[nodes_gtx780ti]`, `[nodes_rtx2080]` などのグループを更新。

2. **CUDAやGromacsの新バージョン対応**  
   - 新しいロール例：`cuda-12.2`, `gromacs-2023.1` などを追加して `roles/` に配置し、 `nodes.yml` で条件分岐を加える。  
   - 既存ノードを移行する場合は手動で `production` や `nodes.yml` のロジックを書き換え（あるいは安全策として旧環境は残したまま並行運用）する。

3. **Slurmのアップグレード**  
   - `roles/slurm` 下にある `slurm_version` などの変数を変え、ソースを切り替える。  
   - 大きな変更の場合、念のため手動バックアップ＋チェックモードで段階的にテスト推奨。

4. **トラブル共有**  
   - 新たに見つかった不具合やノウハウは**このリポジトリにドキュメントを追加**し、後輩への引き継ぎを円滑に。

---

## 10. まとめ

本ディレクトリ一式は、**ゴルジクラスター管理の「中核」** です。  
- `safe_apply.sh` を使えば**対話的に**安全に適用できる  
- Playbookを適用する前後に**バックアップ (`backup_configs.yml`)** や**状態確認 (`verify_changes.yml`)** を行い、トラブルを最小化  
- **各ロール**がソフトウェアインストールやサービス設定を自動化  
- **インベントリ (production)** でノードやGPUの種類ごとの管理が可能  

**次に管理を引き継ぐ方へ**：  
- まずは `safe_apply.sh` で「7) システム状態の検証のみ」を試してみて、現在のノード状態がどうなっているかを確認してください。  
- その後、必要に応じて「1) 親ノードへの適用」「2) 子ノードへの適用」などを実行し、ログ（`logs/ansible_...log`）を確認しましょう。  
- わからないことがあれば `roles/` の`tasks/main.yml`を直接読むと、どのファイルをどう変更しているかが見えます。  

**本READMEが参考になり、Golgiクラスターの運用がスムーズに進むことを願っています。**  
不明点があれば遠慮なく過去の管理者や先輩に相談し、**万全の体制でHPC環境を支えていってください。**

---

以上が `/srv/ansible/README.md` のサンプルです。  
このドキュメントを適宜修正・追記しながら、Golgiクラスター管理の知見を継承していってください。  
