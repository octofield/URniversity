# 驗證信設定（網域 → Resend → SMTP → 速率上限）

> 這份文件說明「給同學用」之前必須完成的信件管道設定。
> 信件範本存在 [`supabase/email-templates/`](../supabase/email-templates/)，因為 Supabase
> Dashboard 的範本欄位**不進版控**，改了就會跟程式碼脫節。

## 為什麼非做不可

發布前實測到**兩個獨立的封鎖點**，任何一個沒解決，同學都收不到驗證信：

| 封鎖點 | 症狀 | 為什麼 |
|---|---|---|
| **Resend 沙箱網域** | 寄給自己以外的地址回 403 | `onboarding@resend.dev` 是測試位址，Resend 要求**驗證自有網域**才能寄給任意收件人 |
| **Supabase 速率上限 2/hr** | 超過額度後靜默失敗，API 仍回 200 | 內建信件服務的預設上限。⚠️ **Send Email Hook 不會繞過它**——[supabase#45743](https://github.com/supabase/supabase/issues/45743) 是同樣處境，目前仍 open |

> ⚠️ 先前的做法是 Send Email Hook（`supabase/functions/send-auth-email/`）呼叫 Resend。
> 那條路**解不開速率上限**。改用 custom SMTP 之後上限預設升到 30/hr 且在 Dashboard 可調。

## 設定步驟

### 1. 買一個網域

任何註冊商都可以，重點是**你要能自己編輯 DNS 記錄**（Resend 驗證需要加 TXT/CNAME）。
Netlify 的 `*.netlify.app` 子網域**不行**，那不能加自訂 DNS 記錄。

### 2. 在 Resend 驗證網域

Resend Dashboard → Domains → Add Domain → 依畫面指示到註冊商加上：

- **SPF**（TXT）
- **DKIM**（CNAME 或 TXT，Resend 會給）
- **DMARC**（TXT，選用但建議加，可降低進垃圾桶的機率）

DNS 生效通常幾分鐘到數小時。Resend 顯示 Verified 才算完成。

### 3. 在 Resend 取得 SMTP 憑證

Resend Dashboard → SMTP，會給：

```
Host: smtp.resend.com
Port: 465（SSL）或 587（TLS）
User: resend
Pass: <你的 Resend API key>
```

### 4. 在 Supabase 設定 custom SMTP

Dashboard → Project Settings → Authentication → SMTP Settings → Enable Custom SMTP

- Sender email：`noreply@<你的網域>`（**必須是已驗證網域底下的位址**）
- Sender name：`URniversity`
- 其餘填上一步的 Host / Port / User / Pass

### 5. ⚠️ 調高速率上限（**最容易漏掉的一步**）

Dashboard → Authentication → Rate Limits → **Rate limit for sending emails**

設好 custom SMTP 後這個欄位才可調，預設會變成 30/hr。
依同學人數往上調——**只設 SMTP 而沒調這裡，仍然會卡住**。

### 6. 貼上信件範本

Dashboard → Authentication → Emails，把 [`supabase/email-templates/`](../supabase/email-templates/)
底下的檔案內容貼進對應的 Message body：

| 檔案 | 對應範本 | Subject heading |
|---|---|---|
| `confirm-signup.html` | Confirm signup | `URniversity 帳號驗證 / Confirm your account` |
| `reset-password.html` | Reset password | `重設 URniversity 密碼 / Reset your password` |
| `change-email.html` | Change email address | `確認新的電子郵件 / Confirm your new email` |

⚠️ **Subject heading 是獨立欄位，不在 HTML 裡**。只貼 Message body 的話，標題會維持
Supabase 的英文預設值（`Confirm Your Signup`）。兩個欄位都要改。

範本用 `{{ .ConfirmationURL }}`，由 Supabase 自行組出正確的驗證網址，不需要手動拼。

> **改範本的規則**：先改 `supabase/email-templates/` 的檔案，再貼到 Dashboard。
> 不要只改 Dashboard——那樣版控裡的內容就過時了。

### 7. 停用舊的 Send Email Hook

Dashboard → Authentication → Hooks → 關閉 Send Email Hook。

Hook 一旦啟用會**取代** SMTP 發信，等於前面幾步都白做。
`supabase/functions/send-auth-email/` 可以留著備查，但不再被呼叫。

## 驗收

1. 用**不是你自己的** email 註冊一個帳號 → 收得到驗證信（先前會 403）
2. 信件的寄件人是 `noreply@<你的網域>`，不是 `onboarding@resend.dev`
3. 點驗證連結 → 正確跳回 App／網站
4. **連續註冊 3 個帳號** → 都收得到（先前第 3 個會被 2/hr 上限靜默擋掉）
5. 忘記密碼流程 → 收得到重設信 → 能設定新密碼
6. 信件不在垃圾郵件匣（DMARC 有設的話機率較低）

## 已知限制

- Supabase 的信件範本**不支援依使用者語言切換**，所以範本做成中英並列。
- Resend 免費方案有每日／每月寄送額度，同學規模的用量不會碰到，但要上線給更多人前要確認。
