
<h1 align="center">guacamole-docker 🥑</h1>
<p align="center">
  <img alt="Ubuntu" src="https://img.shields.io/badge/OS-Ubuntu%2024.04-E95420?logo=ubuntu&logoColor=white">
  <img alt="Docker Compose" src="https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker&logoColor=white">
  <img alt="Apache Guacamole" src="https://img.shields.io/badge/Guacamole-1.6.x-00a86b">
  <img alt="Made with Bash" src="https://img.shields.io/badge/Made%20with-Bash-4EAA25?logo=gnubash&logoColor=white">
</p>

<p align="center">用5–10 分鐘最少的步驟，把 Apache Guacamole 在 <b>Ubuntu 24.04 </b>跑起來。</p>

👉 **有用的話，幫這個 repo 點個 Star ⭐️ 收藏起來！**

[![GitHub Stars](https://img.shields.io/github/stars/lhlaib/guacamole-docker.svg?style=social)](https://github.com/lhlaib/guacamole-docker)   [![GitHub Follow](https://img.shields.io/github/followers/lhlaib?label=Follow&style=social)](https://github.com/lhlaib)

## 前言
這份 repo 把常見的坑都填好、腳本也幫你寫好了；照著做，十分鐘能看到畫面。  
包含 RDP / VNC / SSH、錄影回放、LDAP、IP 封鎖、品牌化登入頁。
中文教學真的不多，所以我把重點都整理在這裡。

為什麼微軟內建的「遠端桌面軟體」無法滿足「安全」設計環境？

❌ 缺乏集中管理：老師、助教、管理員無法看到誰正在連線、做什麼
❌ 沒有完整稽核：多數僅有系統日誌，缺少「螢幕側錄」與「鍵盤事件」等可視化證據
❌ 權限控管薄弱：難以精準「只允許這些帳號連到這幾台主機，僅開這些功能」
❌ 沒有完整紀錄：一旦有異常行為（例如外流資料、誤刪檔案），難以追溯

沒有集中、沒有稽核、沒有留痕 → 難以達到高資安標準

---

## Guacamole 是什麼？
**Apache Guacamole** = 用瀏覽器直接連 **RDP / VNC / SSH**。  
透過開源的解決方案來架設免費的 VDI 環境，無授權成本，高掌握度。

無需安裝客戶端、集中管理帳號與連線、還能錄影、支援 LDAP、2FA、IP 封鎖與品牌化登入頁。

官方網站：https://guacamole.apache.org/
官方手冊：https://guacamole.apache.org/doc/gug/

**為什麼用這個專案？**
- 一鍵裝好 Docker / Compose
- 一鍵初始化資料庫與錄影目錄
- 常用功能（錄影 / LDAP / BAN / RESTRICT）開關都幫你放好
- 提供一份可直接改的 **品牌化登入頁**（含打包腳本）

---

## 系統需求
- **Ubuntu 24.04 LTS**
- `sudo` 權限
- 對外安裝 Docker 的網路
- 預設使用 **80/tcp** 對外（可在 `docker-compose.yml` 改）

---

## 快速安裝（一步一步）
> 所有指令都在專案根目錄執行

1) 讓腳本可執行
```bash
chmod +rx *.sh
```

2.  安裝 Docker / Compose

```bash
./00_install_docker.sh
```

3.  一鍵初始化（建 DB、設錄影目錄權限、整套帶起來）

```bash
./01_manager.sh init-all
```

> （可放圖）  

4.  重啟（改設定或更新時）

```bash
./02_restart.sh
```

5.  看服務狀態（都要是 Up）

```bash
./03_check.sh
```

> （可放圖）  

6.  追 log（出問題先看這裡）

```bash
./04_log.sh
```

> （可放圖）  

打完收工 → 開瀏覽器到 `http://<你的主機>`。

預設登入帳號：`guacadmin` / 密碼：`guacadmin`
**強烈建議**：馬上登入後→**改密碼**→
立刻建立第二管理員（具備同等權限），確認能登入後→停用 guacadmin。
理由：預設帳號是攻擊者掃描的第一目標。

* * *

錄影放哪？
-----

*   錄影原始檔會落在主機的 `./recordings/`（已掛進容器 `/var/lib/guacamole/recordings`）。
*   Web 介面內建播放器就能回放。
*   真的要影片檔（m4v/mp4）再轉就好（避免一開始就吃硬碟）。

* * *

關鍵設定
----

### `docker-compose.yml`（功能開關）

這些環境變數在 `guacamole` 服務內，改成 `"true"` 就啟用：

```yaml
# --- Web 附加功能啟用 ---
RECORDING_ENABLED: "true"  # 🎥 會話錄影與回放
LDAP_ENABLED: "true"       # 🔐 LDAP 登入（請在 guacamole.properties 設參數）
TOTP_ENABLED: "false"      # 🔑 二階段驗證（TOTP）
BAN_ENABLED: "true"        # 🚫 失敗登入 IP 封鎖
RESTRICT_ENABLED: "true"   # 🕘 來源/時段限制
JSON_ENABLED: "false"      # 🔗 JSON 認證（自家入口/SSO）
```

**怎麼選？**

*   只想先跑起來：`RECORDING_ENABLED`、`BAN_ENABLED` 開著就好。
*   要 LDAP 登入：把 `LDAP_ENABLED` 設為 `true`，再填下面的 `guacamole.properties`。
*   要更硬的安全：開 `TOTP_ENABLED`、`RESTRICT_ENABLED`，限制來源與時段。

> 改完記得 `./02_restart.sh`。

* * *

### `guacamole.properties`

位置：專案根目錄 `./guacamole.properties`（已掛到容器 `/etc/guacamole/guacamole.properties`）

```properties
# ===== LDAP（依你的環境改）=====
ldap-hostname: ldap.school.edu.tw
ldap-user-base-dn: dc=school,dc=edu,dc=tw
ldap-group-base-dn: cn=groups,dc=school,dc=edu,dc=tw
ldap-search-bind-dn: uid=root,cn=users,dc=school,dc=edu,dc=tw
ldap-search-bind-password: your_password
ldap-group-name-attribute: cn
ldap-member-attribute: memberUid
ldap-member-attribute-type: uid

# ===== 錄影 =====
recording-search-path=/var/lib/guacamole/recordings

# ===== 語系 =====
allowed-languages: en

# ===== Session 時間（分鐘）=====
api-session-timeout: 120

# ===== BAN（若有開 BAN 擴充）=====
#ban-max-invalid-attempts: 5
#ban-address-duration: 300

# ===== 除錯日誌 =====
#log-level: trace
```

**小抄：**

*   `ldap-*`LDAP 的 DN 要跟你的樹狀一致；測不準就用 `ldapsearch` 先打一次。
*   `recording-search-path`：一定要跟 compose 掛載的路徑一樣（預設 `/var/lib/guacamole/recordings`）。
*   `api-session-timeout`：太短會一直被登出；常見 60～120。
*   要用 BAN：把註解打開，先用「錯 5 次 → 封 5 分」試試。

* * *

第一次新增 RDP 連線（示例）
----------------

1.  用管理者登入 `http://<你的主機>`
2.  **Settings → Connections → New Connection**
3.  Protocol 選 **RDP**，填：
    *   Hostname：`10.0.0.10` or `server.school.edu.tw` (你的 遠端桌面 主機 IP/主機名)
    *   Username / Password：可用 `${GUAC_USERNAME}` / `${GUAC_PASSWORD}`（登入 Guacamole 的帳密）這樣就能直接登入不需再輸一次。
    *   重要設定：請務必勾選 忽略證書錯誤（否則連不上）
    *   Display：可挑整解析度，或用 自動調整大小
    *   Recording：勾選；路徑用 `${HISTORY_PATH}/${HISTORY_UUID}` 最乾淨 https://guacamole.apache.org/doc/gug/recording-playback.html
4.  Save → 回首頁點卡片就能進桌面

* * *

客製化登入頁（Branding）
----------------

位置：`extensions/guacamole-branding-example/`  
你可以改標題、登入 HTML、Logo 圖，然後一鍵打包套用。

**我能改什麼？**

*   標題/文字：`translations/en.json`
*   登入頁內容：`html/warning.html`
*   圖片（檔名別改）：`resources/images/saturn/saturn.png`

**怎麼套用？**

```bash
cd extensions/guacamole-branding-example
chmod +x 01_pack_branding.sh    # 只需第一次

./01_pack_branding.sh           # 每次更改都需要重新打包 會產生 ../guacamole-branding-example.jar

cd ../../
./02_restart.sh                 # 重啟 web
# 瀏覽器強制重新載入（Ctrl+F5 / Cmd+Shift+R）
```

* * *

專案結構
------------

```
├── 00_install_docker.sh          # 安裝 Docker / Compose
├── 01_manager.sh                 # init-all / status / logs 等
├── 02_restart.sh                 # 重啟整套服務
├── 03_check.sh                   # 檢查 compose ps/健康狀態
├── 04_log.sh                     # 跟隨/存檔 logs（輸出到 ./log）
├── docker-compose.yml            # 服務定義（guacd / web / db）
├── guacamole.properties          # LDAP / 錄影 / 語系 / Session 等
├── recordings/                   # 會話錄影（持久化）
├── log/                          # 日誌檔案
└── extensions/
    └── guacamole-branding-example/
        ├── 01_pack_branding.sh
        ├── guac-manifest.json
        ├── html/warning.html
        ├── translations/en.json
        └── resources/images/saturn/saturn.png
```

* * *

常見問題（先這樣排一下雷）
-------------

*   **網頁開不起來？**  
    多半是 80 埠被佔用。把 compose 的 `80:8080` 改成 `8080:8080`，用 `http://<host>:8080` 開。
*   **LDAP 登入失敗？**  
    先用 `ldapsearch` 確認帳密與 DN；再看 `./04_log.sh` 的 `guacamole` 容器 log。
*   **推薦好用的 LDAP GUI 工具**  
    Apache Directory AD Browser 7.8
    https://www.ldapsoft.com/adbrowserfree.html

*   **錄影沒出現？**  
    看 `recordings/` 權限是否正確（`01_manager.sh init-all` 會設好），以及連線有勾錄影。
*   **Logo 改了沒變？**  
    重新打包 + 重啟，再做瀏覽器強制重新載入。

* * *

最後的小建議 💡
---------

*   放在反向代理後面上 **HTTPS**
*   開 **BAN** / **RESTRICT**，減少暴力嘗試與越權
*   如果要整合 AD/LDAP，建議先做測試 OU，再逐步放大
*   錄影先保留原始檔，需要時再轉影片，省空間

有用的話，幫這個 repo 點個 ⭐️。有問題就開 Issue，我看得到就回 🙌

---

## 👥 貢獻者名單（Contributors）

感謝以下夥伴協助本教學系統的撰寫與維護 🙌

- 賴林鴻（[@lhlaib](https://github.com/lhlaib)）



[![Contributors](https://contrib.rocks/image?repo=lhlaib/guacamole-docker)](https://github.com/lhlaib/guacamole-docker/graphs/contributors)


