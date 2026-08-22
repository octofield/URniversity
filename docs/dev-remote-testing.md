# 遠端實機測試環境（Tailscale + 無線 ADB）

本文件記錄「在外出時用手機即時測試 URniversity」的環境建置方式，以及建置過程中踩到的三個坑
與其根因。撰寫日期 2026-08-10。

---

## 結論先講

| 目標 | 可行方案 |
|---|---|
| 遠端手機測試 **且要 hot reload** | **只能走無線 ADB（方案 B）** |
| 只是想快速看畫面、不需要 hot reload | web + release 模式（方案 A） |
| 給別人看成果 / 交作業 | 推 git 讓 Netlify 部署 |

**「Tailscale + Flutter web 開發伺服器」無法達成「遠端 + hot reload」**，這是架構限制而非設定
錯誤，原因見下方坑 3。

---

## 環境資訊

| 項目 | 值 |
|---|---|
| 電腦 Tailscale IP | `100.72.60.53` |
| 電腦 MagicDNS 名稱 | `desktop.tail0fe147.ts.net` |
| 手機（s25plus）Tailscale IP | `100.103.94.14` |
| MagicDNS | 已啟用 |
| `adb` 路徑 | `C:\Users\USER\AppData\Local\Android\sdk\platform-tools\adb.exe` |
| 電腦對外（公網）IP | `59.102.131.41` ⚠️ 見坑 3 的安全提醒 |

---

## 建置過程踩到的三個坑

三個坑彼此獨立，且症狀都不會直接指向真正的原因，因此逐一記錄證據。

### 坑 1：自建的 `web_dev_config.yaml` 完全不會被讀取

為了固定 port，曾建立 `src/web_dev_config.yaml`：

```yaml
server:
  host: "127.0.0.1"
  port: 5555
```

**Flutter 沒有任何讀取此類設定檔的機制**，內容再正確也不生效。而且就算生效，
`host: 127.0.0.1` 只綁本機迴路，手機永遠連不到。

網頁伺服器的位址與 port **只能**透過指令參數指定：

```bash
flutter run -d web-server --web-hostname=<位址> --web-port=<port>
```

該檔案已刪除。

### 坑 2：Cloudflare WAF 封鎖「指向私有 IP 的 redirect_to」

**症狀**：按下 Google 登入後出現
`Sorry, you have been blocked — You are unable to access supabase.co`。
已把該網址加入 Supabase 的 Redirect URLs 仍然無效。

**原因**：那是 Cloudflare 的封鎖頁（Supabase 架在 Cloudflare 後面），請求**根本沒到達
Supabase**，所以改 Supabase 的允許清單不可能有效。

**證據**：對 `/auth/v1/authorize` 實測四種 `redirect_to`：

| `redirect_to` | 結果 |
|---|---|
| `http://100.72.60.53:5555`（裸私有 IP） | **HTTP 403**　`Attention Required! \| Cloudflare` |
| `http://desktop.tail0fe147.ts.net:5555`（MagicDNS 主機名） | HTTP 302 正常導向 Google |
| `https://desktop.tail0fe147.ts.net` | HTTP 302 正常 |
| `https://urniversity.netlify.app`（對照組） | HTTP 302 正常 |

WAF 將「redirect 參數指向 `100.64.0.0/10` 私有位址」判定為開放重導向／SSRF 攻擊。
**改用主機名稱即可通過**。這是平台層防護，免費方案無法關閉。

**同時排除的可能**：本機 IP 未被封鎖（`/auth/v1/health` 回 401、`/rest/v1/tasks` 回 200，
皆為正常回應）；Tailscale 未設定 exit node，手機連 Supabase 走自己的網路。

> 因此：若日後仍要用 web 版測試登入，**網址一律使用 MagicDNS 主機名稱，不要用裸 IP**，
> 並把 `http://desktop.tail0fe147.ts.net:5555/**` 加進 Supabase 的 Redirect URLs
> （結尾 `/**` 是因為該清單為 glob 比對，OAuth 繞回時網址會多出路徑或 fragment）。

### 坑 3（致命）：debug 版 web 注入的偵錯連線寫死 `127.0.0.1`

**症狀**：頁面全白、畫面上沒有任何錯誤訊息，網址列仍停在正確網址。主控台顯示：

```
Failed to create WebSocket debug connection: DartDevelopmentServiceException:
WebSocketChannelException: WebSocketException: Connection to
'http://127.0.0.1:59577/p4Ryr8QgmxA=/ws#' was not upgraded to websocket
```

**原因**：debug 模式會在網頁中注入 DWDS 客戶端，要求**瀏覽器主動連回**偵錯服務，而位址是
`127.0.0.1`。在手機上 `127.0.0.1` 指的是手機自己，這條連線必然失敗，app 因此卡在啟動階段。
在電腦瀏覽器上正常，只是因為那裡的 `127.0.0.1` 剛好就是對的機器。

**這是架構限制，無法用設定繞過**：

| 模式 | 手機能否開啟 | hot reload |
|---|---|---|
| debug | ❌ 必然失敗 | ✅ |
| profile / release | ✅ | ❌ |

兩者無法兼得，所以 web 路線走不到「遠端 + hot reload」。

---

## 方案 B：無線 ADB（建議，可 hot reload）

### 原理

關鍵在於**連線方向與 web 相反**：

- **Web**：手機瀏覽器必須「主動連出」到偵錯服務。中間沒有隧道，只能用被告知的位址
  （`127.0.0.1`），因此失敗。
- **Android**：Flutter 執行
  ```
  adb -s <device> forward tcp:<hostPort> tcp:<devicePort>
  ```
  （見 Flutter SDK `flutter_tools/lib/src/android/android_device.dart` 的
  `AndroidDevicePortForwarder.forward()`），**由電腦端主動連進 adb 隧道**去找手機上 app 的
  Dart VM service。手機端不需要解析或連回任何位址，因此沒有 `127.0.0.1` 的問題。

而 adb 本身可以跑在 TCP 上（無線偵錯），這條 TCP 連線走 Tailscale，整條鏈路即成立：

```
電腦 flutter run
   └─ adb forward（TCP）
        └─ Tailscale 加密隧道
             └─ 手機 adb daemon
                  └─ app 的 Dart VM service   →  hot reload
```

**附帶好處：跑的是真正的 Android app**，能測到 web 版測不到的東西：

- Android 專屬問題——例如先前 `AndroidManifest.xml` 缺 `INTERNET` 權限，網頁版與桌面版
  完全正常、只有實機會壞
- 觸控行為——`today_screen.dart` 的任務拖曳是用 `kIsWeb` 分成 `Draggable`（滑鼠）與
  `LongPressDraggable`（觸控）兩條路徑，**web 版走的是滑鼠那條，等於沒測到手機實際會用的邏輯**

### 步驟

#### 0. 前置（各做一次）

- 電腦與手機都安裝 Tailscale 並以**同一個帳號**登入，兩邊都保持連線
- 手機開啟開發者選項：設定 → 關於手機 → 連點「版本號碼」7 次

> **連線本身不需要同一個 WiFi。** 一般的無線 ADB 要求同區網，但 Tailscale 建立的是跨網路的
> 虛擬私有網路——只要兩邊 Tailscale 都連著，手機在行動網路或任何其他網路都連得到電腦。
> 這也是指令中一律使用 `100.x.y.z`（Tailscale 位址）而非 `192.168.x.x`（區網位址）的原因。
>
> ⚠️ **但 Android 的「無線偵錯」開關本身需要手機連著 Wi-Fi 才能啟用**（OS 限制）。
> 若手機當下沒有 Wi-Fi，請改走下方的「USB 一次性設定」，可完全跳過這個開關。

#### 建議路線：USB 一次性設定（不需要 Wi-Fi，也不需要配對碼）

「無線偵錯」（配對碼那套）與 `adb tcpip 5555`（舊的 adb over TCP）是**兩套不同的機制**：

| | 無線偵錯開關 | `adb tcpip 5555` |
|---|---|---|
| 啟用時需要 Wi-Fi | ✅ 需要 | ❌ 不需要 |
| 啟用方式 | 手機 UI + 配對碼 | 電腦下指令（需先有一條既存 adb 連線） |
| 監聽介面 | 綁 Wi-Fi | 綁所有介面（含 Tailscale） |
| port | 每次隨機 | 固定 5555 |

> **`adb` 預設不在 PATH**，直接輸入 `adb` 會得到
> `The term 'adb' is not recognized as a name of a cmdlet`。
> 用完整路徑，或先把它加進當前 PowerShell 視窗：
> ```powershell
> $env:Path += ";$env:LOCALAPPDATA\Android\sdk\platform-tools"
> ```
> 要永久加入（僅使用者層級，改完需重開終端機）：
> ```powershell
> [Environment]::SetEnvironmentVariable('Path',
>   [Environment]::GetEnvironmentVariable('Path','User') + ";$env:LOCALAPPDATA\Android\sdk\platform-tools",
>   'User')
> ```

因此最省事的作法是用 USB 接一次：

```bash
# 1. USB 線接上手機（手機會跳出「允許 USB 偵錯」→ 允許）
adb devices              # 確認看得到手機

# 2. 切換成 TCP 模式，綁在所有網路介面上
adb tcpip 5555

# 3. 拔掉 USB 線

# 4. 之後走 Tailscale 連線
adb connect 100.103.94.14:5555
```

設定維持到**手機重新開機**為止，重開機後重跑一次即可。

> ⚠️ **需實測確認**：`adb tcpip` 之後 adbd 綁在所有介面上，理論上離開 Wi-Fi、改走行動網路時
> 仍能透過 Tailscale 連上，但部分廠商（Samsung 尤其）對此有額外限制。
> 驗證方式：手機關閉 Wi-Fi 只留行動網路，在電腦執行 `adb connect 100.103.94.14:5555`，
> 連得上即成立。

以下的步驟 1～3 是**替代路線**，適用於手邊沒有 USB 線、且手機當下連著 Wi-Fi 的情況。

#### 1. 手機開啟無線偵錯（替代路線）

設定 → 開發者選項 → **無線偵錯** → 開啟 → 點「**使用配對碼配對裝置**」。
畫面會顯示一組 `IP:port` 與 6 位數配對碼。

> Android 11 以上支援，完全不需要 USB 線（S25+ 適用）。
> Android 10 以下只有 USB 偵錯，需先用線接一次執行 `adb tcpip 5555`。

#### 2. 配對（僅首次）

```bash
adb pair 100.103.94.14:<配對port>
```
接著輸入手機上顯示的配對碼。

> ⚠️ **手機畫面顯示的 IP 不能直接照抄。** 它顯示的通常是手機的區網 IP（例如
> `192.168.1.50:37021`），但我們要走 Tailscale。作法是**保留 port、把 IP 換成 Tailscale 的**：
>
> | 手機畫面顯示 | 實際要輸入 |
> |---|---|
> | `192.168.1.50:37021` | `adb pair 100.103.94.14:37021` |

#### 3. 連線

```bash
adb connect 100.103.94.14:<連線port>
adb devices          # 應該看到手機
```

> ⚠️ **配對用的 port 與連線用的 port 不同**。連線 port 顯示在「無線偵錯」主畫面上，
> 配對 port 只在配對對話框裡出現。

#### 4. 把 port 釘死（解決「port 會變動」的關鍵）

Android 每次重開無線偵錯都會隨機換 port。連上之後執行：

```bash
adb tcpip 5555
```

之後就固定用這一行，不必再看手機畫面：

```bash
adb connect 100.103.94.14:5555
```

此設定**維持到手機重新開機為止**；關螢幕、切換網路、Tailscale 斷線重連都不受影響。

#### 5. 執行

```bash
cd d:\Desktop\URniversity\src
flutter run
```

- 按 `r` → hot reload（改一行文字，手機數秒內更新）
- 按 `R` → 完整重啟
- 按 `q` → 結束

#### 6. 手機重開機後的復原

`adb tcpip 5555` 需要一條既有的 adb 連線才能下達，所以重開機後有兩種做法：

- **純無線**：重複步驟 1～4（要再看一次隨機 port 與配對碼）
- **用 USB 接一下**（較快）：接上線後直接 `adb tcpip 5555`，然後拔線，完全跳過隨機 port

---

## 方案 A：web + release（備案，無 hot reload）

只想快速在手機上看畫面時使用：

```bash
cd d:\Desktop\URniversity\src
flutter run -d web-server --release --web-hostname=100.72.60.53 --web-port=5555
```

手機開啟：`http://desktop.tail0fe147.ts.net:5555`

- release 模式不會注入偵錯 websocket 客戶端，所以手機打得開
- **網址必須用主機名稱**，用裸 IP 會讓 Google 登入被 Cloudflare 擋（坑 2）
- **綁定位址不要改成 `0.0.0.0`** ——本機乙太網路是公網 IP `59.102.131.41`，
  綁 `0.0.0.0` 會把開發伺服器連同偵錯服務公開到整個網際網路

**限制**：沒有 hot reload；測不到 Android 專屬問題；觸控拖曳走的是滑鼠程式碼路徑。

---

## 常見問題排查

| 症狀 | 可能原因 | 對策 |
|---|---|---|
| 手機開網址一片空白、無錯誤訊息 | debug 模式的 `127.0.0.1` 偵錯連線（坑 3） | 改用方案 B，或 web 加 `--release` |
| Google 登入出現 Cloudflare 封鎖頁 | 網址用了裸私有 IP（坑 2） | 改用 `desktop.tail0fe147.ts.net` |
| 登入後跑到 `urniversity.netlify.app` | Supabase 允許清單沒比對到 | 加入 `http://desktop.tail0fe147.ts.net:5555/**`（含 `/**`） |
| 手機顯示「找不到網站 / DNS 錯誤」 | MagicDNS 沒生效 | 檢查 Tailscale app 的 DNS 開關；Android「私人 DNS」設為關閉或自動 |
| adb 每次 port 都不一樣 | Android 無線偵錯的預設行為 | `adb tcpip 5555` 釘死 |
| `adb pair` 找不到裝置 | 用錯 IP 或用了配對以外的 port | 確認用 Tailscale IP `100.103.94.14`，且配對 port 取自配對對話框 |
| hot reload 後出現 `Library not defined ... Failed to initialize` | 新增 import／改動 model 欄位／改動 `AppStrings` 抽象類別，熱重載無法套用 | 按 `R` 完整重啟；仍不行則 `q` 後重跑 |
| 連線被防火牆擋 | Windows 防火牆 | 只放行在 **Tailscale 網路介面**，不要放行「公用網路」設定檔 |

---

## 相關文件

- 測試方法與測試類型定義：[testing.md](./testing.md)
- 待執行的測試計畫：[test-plans/](./test-plans/)
