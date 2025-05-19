# 生成AI用 Golgi管理マニュアル  ChatGPT o1 pro
以下に示すのは、**計算機クラスター「Golgi」の管理全般**を将来担当する方が、ChatGPTやClaudeなどの生成AIに与えることで、ハードウェア・ソフトウェア・ネットワーク・管理ツールなどの観点で生じるあらゆる問題をスムーズに解決できるようにするための**包括的な「生成AI用Golgi管理マニュアルテキスト」**です。  

このマニュアルには、過去の管理・修理ログで扱われた情報・注意点・トラブル事例を整理し、今後類似の問題に直面したときに参照すべきポイントをできるだけ網羅的かつ体系的にまとめています。**このマニュアルそのもの**をChatGPTやClaudeなどの生成AIに投げ込むことで、トラブルシューティングや運用上の改善策をAIに質問・提案してもらうことを想定しています。  

----
## 本マニュアルの用途

- 新たにGolgi管理を担当する人が、\#golgi運用に関わるあらゆる問題（ハードウェア構成、ドライバ、Slurm設定、NFS/NIS、ジョブ管理、計算ノードの追加・修理など）を効率的に解決する際のベースとなる知識を提供する。  
- 過去ログに散逸していたノウハウを**1つの大きなテキスト**としてまとめることで、生成AI（ChatGPT・Claude等）に対して直接読み込ませ、過去の知見を踏まえた回答や提案を得られるようにする。  
- Golgiの運用だけでなく、Ubuntu系Linuxを用いたHPCクラスター構築・管理の一般的な知見としても活用できる。  

----
## マニュアル構成

このドキュメントでは、以下の主要セクションに分けて内容を整理します。

1. **Golgiクラスターの概要**
   - 構成ノード一覧
   - 親ノード(Admin)・子ノードの概念
   - GPU構成やネットワーク構成、ファイルサーバー（GolgiFS）などの概要

2. **ハードウェア関連**
   - 主な計算ノードとGPU（RTX2080, 780Tiなど）の構成
   - マザーボード・電源・メモリ構成トラブルの事例
   - Secure Bootの問題とUEFI設定
   - 故障対応（ノードが反応しない、ブレーカーが落ちるなど）

3. **OS・ドライバ・CUDA関連**
   - Ubuntuのバージョン(16.04,18.04,20.04,22.04)アップグレードや注意点
   - CUDAのバージョン問題 (10.2, 11.x, 12.0) と対応ドライバ
   - 古いGPU(Compute Capability 3.0系など)に対するサポート問題
   - NVIDIAドライバインストールの典型エラーや対処法

4. **Slurmジョブ管理**
   - slurm.conf / gres.confの設定例
   - GPU台数の不一致（GPUが1枚ノード/2枚ノード混在）の注意点
   - ノードの状態(down, drain, idleなど)を変更するコマンド
   - Slurmバージョン差異 (18.x, 21.x, 22.x) や削除されたパラメータ (AccountingStorageLoc 等)

5. **NISとアカウント情報共有**
   - /var/yp/Makefile での MINGID設定
   - ypbind / nis-server roleの設定と典型的なエラー
   - アカウントとパスワードの同期方法
   - dockerグループをNISで共有する際のトラブル

6. **NFSとファイルサーバー (GolgiFS)**
   - Synology NASを用いた新GolgiFSの導入
   - /etc/exports によるアクセス制限
   - /home ディレクトリのNFSマウント、管理の注意点
   - 旧GolgiFS（故障したNAS）からのデータ移行事例

7. **クラスターモニタリング・温度監視・ClusterUsage**
   - lm-sensorsによるCPU温度検出
   - clusterusageアカウントによる並列ssh (GNU parallel) とMaxStartups問題
   - jobcount.pyとsqueueパース
   - parse_temperature.pyスクリプトでのCSV→JSON変換
   - ssh_exchange_identification: Exceeded MaxStartups の原因と対処

8. **トラブルシューティング事例一覧**
   - GPUを認識しない / nvidia-smiがエラーになる / CUDAとのミスマッチ
   - ノードがPending状態から動かない (SlurmのResources不足/ノード電源断)
   - aptの自動アップグレードに伴うカーネルアップデートでドライバが壊れる
   - ufwによるポートブロック・sshが異様に遅くなるなど

9. **管理スクリプト・Ansible活用**
   - /srv/ansibleに格納されたPlaybookの構成
   - admin.yml / nodes.yml / roles など各ファイルの概要
   - Ansible実行時の--ask-become-pass、--start-at-task、--stepオプション
   - Adminノード自身をAnsibleで管理する場合の留意点

10. **補足情報：ログ取得場所・参考リンク**
   - /var/log/slurm/ や /var/log/apt/ の利用
   - dmesg / journalctl -xe の読み方
   - NVIDIA公式リリースノート / Gromacs公式ドキュメント / Slurm公式


----

以下、**各セクションの詳細**をまとめて記述します。生成AIへの質問時には、気になるセクション付近の記述を参考にしながら「原因・対策」「操作手順」などを聞いてみてください。

---

## 1. Golgiクラスターの概要

1. Golgiには**親ノード(Adminノード)**があり、`GolgiAdmin` と呼ばれる。  
   - 内向きIP: `192.168.2.200`  
   - 外向きIP: `10.1.1.226`  

2. **子ノード(golgi01〜golgiXX)** が複数台存在し、GPUを2枚積んだノードや1枚だけのノードが混在している。  
   - 例: golgi08,09,10... → GPUが2枚  
   - golgi14 → GPUが1枚  

3. **ファイルサーバー(GolgiFS)**  
   - 旧GolgiFSはSynology製NASで、ハード故障により新NASに置き換え (本マニュアル末尾参照)。  
   - 新NASもSynologyで `/volume1/homes` を `/home` にNFSマウント。IPは `192.168.2.201` 。  

4. **ネットワーク構成**  
   - 親ノードは内向きネットワーク(192.168.2.0/24)および外向き(10.1.1.0/24)を担う。  
   - 子ノードは内向きネットワークを介してのみ通信する。  
   - NAT/マスカレード設定により外部通信を可能にする場合がある。  

5. **計算資源の状況**  
   - GPUカードとしてRTX2080やRTX2080SUPER、古いGK110(GeForce GTX780Ti)などが混在。
   - CPU数はノードごとに異なる(12コア、20コアなど)。

---

## 2. ハードウェア関連

### 2.1 主なトラブル傾向
- **電源ブレーカーが落ちる**：GPU増設で消費電力が跳ね上がり、20A超えでゴソッとノードが落ちた事例あり。  
- **マザーボードの不具合**：Secure Bootが有効だとNVIDIAドライバを正常にロードできない問題。  
- **DIMMスロット不良**：メモリを認識しないなど(X99マザーなどで発生)。  

### 2.2 Secure Boot無効化
UEFI BIOS設定で Secure Boot を無効化しないと、新しいNVIDIAドライバが正しくロードされず、`nvidia-smi` で `No devices found` になりがち。  
- BIOS画面で`OS Type → [Other OS]`に変更または`Secure Boot key`をクリアする。

### 2.3 故障ノードの修理方針
- 物理的にGPU/マザボ/メモリを別ノードへ移植することも多い。  
- 旧Golgi04のマザボ故障→新パーツで再組み立て→ホスト名をgolgi04として流用。  

---

## 3. OS・ドライバ・CUDA関連

### 3.1 Ubuntuのバージョン
- かつては16.04/18.04がメインで、GromacsがCUDA10.2までしか対応していない関係で一度20.04/22.04へのアップグレードを諦めたこともある。  
- 現在一部ノードで20.04/22.04を使う事例があるが、CUDA・ドライバとの整合性に注意。

### 3.2 CUDAバージョン
- **CUDA10.2** → Ubuntu18.04が公式サポート。GeForce GTX 780Ti などCompute 3.5世代を利用する場合に必要。  
- **CUDA11.x** → RTX20系以降の新しいGPU向け(Compute 7.0〜)。  
- **CUDA12.0** → Ubuntu22向け。ただし一部GPUで非対応。  

### 3.3 インストール注意点
- aptの自動アップグレードで、カーネルが勝手に更新され、NVIDIAドライバとのバージョン不整合が起こる → `driver/library version mismatch`  
- 対策: `/etc/apt/apt.conf.d/20auto-upgrades` で無効化する / バージョンピン止めする。  
- Secure Bootがenableなままだと、インストール後に`nvidia-smi`が`No devices found`のまま。  

### 3.4 古いGPUとコンパイラ不整合
- GromacsのCUDAコンパイル時に `Unsupported gpu architecture 'compute_30'` などのエラーが出る。  
- `-DGMX_CUDA_TARGET_COMPUTE=52;60;75` のようにCMakeオプションで対応GPUアーキを限定する。  
- CUDA10.2以前でないとCompute 3.0,3.5 (Kepler/Maxwell) はサポートされない。  

---

## 4. Slurmジョブ管理

### 4.1 設定ファイル
- `slurm.conf` にクラスター名やノード一覧、GresTypes、PartitionNameなどを設定。  
- GPUを複数積んでいるノードは `Gres=gpu:2`、1枚なら `gpu:1` といった記述が必要。  
- **Slurmバージョン差異**：  
  - slurm-18.x までは `AccountingStorageLoc=xxxx` のように書けたが、 slurm-22.x では削除され`The AccountingStorageLoc option has been removed.` というエラーが出る。  
  - その場合、 `AccountingStorageType=none` または `slurmdbd` を指定する。  

### 4.2 gres.conf
- GPU数がノードごとに違う場合、`gres.conf` で  
  ```
  NodeName=golgi[01-08] Name=gpu File=/dev/nvidia[0-1]
  NodeName=golgi14 Name=gpu File=/dev/nvidia0
  ```
  のように個別設定をする。  
- あるいはノードが2GPU構成だけの場合は2行書くなど適当な対処。  

### 4.3 ノード状態変更
- ノードがdown, drain, idleになった場合は管理者権限で  
  ```
  sudo /opt/slurm/bin/scontrol update node=golgi05 state=idle
  ```
  等で状態変更。  

### 4.4 Pendingジョブ
- ノードが落ちていてもSlurmがノードを認識していると、`(Resources)` や `(Priority)` でジョブがPendingのままになる。  
- 実際にはノード電源断やブレーカー落ちでping通らないのにSlurm上でdownになっていない → 物理的に起動して `/opt/slurm/bin/scontrol update node=xxx state=idle`。  

---

## 5. NISとアカウント情報共有

### 5.1 簡単な仕組み
- GolgiではNISを用いてパスワード・グループ情報を共有している。  
  - 親ノードにnis-server (ypserv, yppasswdd) が入っており、子ノードは `nis-client(ypbind)` で参照。  

### 5.2 /var/yp/Makefileの設定
- **MINGID=999** のように設定しないとdockerグループ(ID=999)などを共有してくれない。  
- たまに `MINGID=9999999999` に書き換わってしまうバグが生じる (Ansibleのreplaceタスクが原因の場合あり)。  

### 5.3 ypbind / ypcatでエラー
- `YPBINDPROC_DOMAIN: Domain not bound` / `Can't bind to server which serves this domain`  
- /etc/yp.conf で NISサーバーのアドレスやdomainが未設定→ `domain GolgiAdmin.golgi server 192.168.2.200` のように指定。  
- `systemctl start ypbind.service` → `No NIS server and no -broadcast option specified.` → 同様に /etc/yp.conf や /var/yp/ypservers 設定が足りない。  

### 5.4 dockerグループ共有
- NISでdockerグループを共有しないと、各ノードで `docker: Error response from daemon: Got permission denied while trying to connect to the Docker daemon...` というエラーが出がち。  
- アカウントをdockerグループに入れる → /var/yp/make → 子ノードにも反映。  
- 反映されてもslurm経由だとdocker.sock に書き込み不可になる事例あり → slurm起動時のユーザー環境等を要確認。  

---

## 6. NFSとファイルサーバー(GolgiFS)

### 6.1 旧GolgiFS
- Synology製NASだが、故障して電源が入らなくなったため、データ復旧にはmdadm等でRAIDを再構成する必要があった。  

### 6.2 新GolgiFSの導入手順(例)
1. SynologyNASを用意（SHR構成、IP設定）。  
2. `NFSサービスを有効化` → `/volume1/homes` をNFSエクスポート。  
3. Export設定で `rootユーザーにadmin権限` or `全ユーザーrw`などを必要に応じて設定。  
4. GolgiAdmin上で `sudo mount -t nfs 192.168.2.201:/volume1/homes /home`  

### 6.3 /etc/exports の編集
- Synology上でGUIからNFSエクスポート設定を行うか、あるいは `/etc/exports` を直接編集して `exportfs -ra`  
- Golgiの子ノード全てのIPアドレス(`192.168.2.2,3,...,15`など)を許可しないと `access denied by server while mounting` が発生。  

### 6.4 ディレクトリのパーミッション
- SynologyNAS側でNFS map設定をどうするか(`no_root_squash`, `map all to admin`など)。  
- root以外でも書き込みできるようにするには `anonuid=xxxx, anongid=xxxx` や `insecure_locks` 等を指定。  

---

## 7. クラスターモニタリング・温度監視・ClusterUsage

### 7.1 clusterusageによる並列ssh
- mocaサーバーがcronで `/var/www/cluster/data/get_usage.sh` を実行し、Golgiにsshしてjobcountや温度取得を行う。  
- 大量のsshが並列に実行されると `ssh_exchange_identification: Exceeded MaxStartups` となり、一時的にssh全拒否状態になることがある。  
  - `/etc/ssh/sshd_config` の `MaxStartups` 値を増やす or clusterusage側で確実にssh接続を切るなどが必要。  

### 7.2 lm-sensorsによる温度取得
- Golgi子ノードに `lm-sensors` パッケージをインストール後、 `sensors` でCPUコア温度を出力。  
- clusterusageユーザーが並列sshして `sensors` の結果をログに落とし、parse_temperature.pyでHighcharts用JSONに変換している。  
- parallelが遅い/ locale設定がない / division by zero等で温度取得がこけることあり。  

### 7.3 jobcount.py (Slurm版)
- `slurm_output = squeue -o '%u %D %t' | tail -n +2`  
- 実行ユーザー数×ノード数をカウントしてCSV出力→ parse script → Web表示  

---

## 8. トラブルシューティング事例一覧

このセクションは過去ログで多発したトラブルを簡潔にまとめたリストです。

1. **GPU認識不良 (nvidia-smiが`No devices found`、`Failed to initialize NVML`)**  
   - Secure BootがON  
   - aptの自動アップデートでカーネル更新→ドライババージョン不整合  
   - GPUが物理的に抜けている/PCIEスロットが壊れている  

2. **Slurm起動失敗 (`fatal: can't stat gres.conf file /dev/nvidia1` など)**  
   - 物理的に2枚目のGPUが刺さっていないのに `Gres=gpu:2` と設定している  
   - slurmバージョンが合わずに `AccountingStorageLoc` が削除済み  

3. **Pendingジョブが実行されない (Resources / Priority)**  
   - 該当ノードの電源が落ちてping不可 → Slurmはdownと認識できず  
   - GPU数などリソースが足りない / ジョブのcuda compute capabilityが不一致  

4. **NIS関連 (`YPBINDPROC_DOMAIN: Domain not bound`)**  
   - /etc/yp.conf, /var/yp/ypservers 等の設定不備  
   - MINGID設定誤り → dockerグループ共有がされない  
   - ypbind / rpcbind / yppasswd / ypserv いずれかが起動していない  

5. **NFS関連 (`access denied by server while mounting`, `permission denied`)**  
   - /etc/exportsで特定ノードのIPが許可されていない  
   - SynologyNASのGUI設定でroot権限のマッピングが不十分  
   - mount.nfs: requested NFS version or transport protocol is not supported → nfsバージョン不一致  

6. **MaxStartupsエラーでssh拒否**  
   - clusterusageの並列sshが多重に積み重なり、sshデーモンが新規受付を拒否  
   - sshd_configのMaxStartups、LoginGraceTimeを調整 or cronスクリプト修正  

7. **ブレーカー落ち**  
   - GPU多数による電力超過  
   - ノードが一斉にOFFになり復帰後slurm上でdown/drain→idle手動変更  

8. **GUIが起動しない/画面が真っ暗**  
   - lightdmで`Failed to get D-Bus connection`  
   - カーネルパラメータor aptでX関連ドライバ崩壊  
   - HPC用途ならCUI運用で放置でも可  

---

## 9. 管理スクリプト・Ansible活用

### 9.1 Ansibleディレクトリ構成例
- `/srv/ansible/` に `production, admin.yml, nodes.yml, roles/child-alphafold, roles/cuda, roles/slurm, ...`  
- `roles/xxx/tasks/main.yml` で各種インストール手順・設定ファイル修正を記述。  

### 9.2 実行例
```bash
# 親ノードで
cd /srv/ansible
ansible-playbook -i production admin.yml --ask-become-pass
ansible-playbook -i production nodes.yml --ask-become-pass --step
```
- `--start-at-task "xxxxx"` で途中タスクのみ再実行  
- GPUドライバを切り替え、cudaを再インストール等を半自動化できる。

### 9.3 Ansibleでの再起動処理
- 一部のroleでGPUドライバを入れ替えた後に`reboot: yes` が走る → その後のタスクがエラーになるので、`wait_for_connection`や手動再実行が必要。  

### 9.4 NIS Makefile書き換え
- replaceモジュールだと文字列が重複書き込みされる等のバグが出がち  
- lineinfileモジュール推奨  

---

## 10. 補足情報：ログ取得場所・参考リンク

### 10.1 ログ
- **aptの履歴** → `/var/log/apt/history.log`  
- **Slurmログ** → `/var/log/slurm/slurmd.log` / `slurmctld.log`  
- **カーネルログ** → `dmesg` / `journalctl -xe`  
- **NIS関連** → `/var/yp/Makefile`, `ypbind.service` のjournalなど  

### 10.2 ハードウェアメーカー・ドライバ関連リンク
- [NVIDIA公式ダウンロード](https://www.nvidia.com/Download/index.aspx?lang=en-us)  
- [CUDA Toolkit Documentation](https://docs.nvidia.com/cuda/index.html)  
- [Gromacs公式サイト](https://www.gromacs.org/)  

### 10.3 Slurm関連
- [Slurm official docs](https://slurm.schedmd.com/documentation.html)  
- [Configurator](https://slurm.schedmd.com/configurator.html) でslurm.conf生成  

### 10.4 SynologyNAS
- [Synology KB: NFS設定方法](https://kb.synology.com/ja-jp)  

---

## まとめ・使い方

- 本マニュアルを**そっくり生成AIに投げる**ことで、将来的なGolgi運用の難題（ノード増設・CUDAのバージョン問題・Slurm設定不整合・NIS/NFSトラブルなど）について、過去の事例を踏まえたアドバイスを出してもらうことが可能となる。  
- 具体的な問い合わせ例：  
  - 「Ubuntu22にアップグレードしたゴルジ子ノードでnvidia-smiが動かない時の原因と対策は？」  
  - 「NISでdockerグループを共有しているはずなのにdockerが動かない時に確認すべき項目は？」  
  - 「slurm-22.xでAccountingStorageLocが削除された後の代替設定方法は？」  
  - 「SynologyNASでNFSをマウントする際、`access denied` になった時の設定確認箇所は？」  
  - などなど  

これらの質問に対し、ChatGPTやClaudeなどは**このマニュアルの内容**を下敷きに回答を生成し、過去ログの知見を踏まえた具体的な指示を行ってくれるはずです。

以上が、**「生成AI用 Golgi管理マニュアルテキスト」**の全体像です。  
このドキュメントを**丸ごと**AIに貼り付け、「これを踏まえて問題解決の手順・考えられる原因を教えてほしい」と尋ねれば、過去に遭遇した事例を含む幅広いトラブルへの解決策を提案してくれるでしょう。  
