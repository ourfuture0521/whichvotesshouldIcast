# 地方選舉候選人管理系統｜第一階段重建版

這是依照你提供的 `地方選舉候選人資訊_候選人專屬頁面_完整程式(2).html` 重建的第一階段專案。原始公開頁面另存於 `public/source-original.html`，新公開頁面保留原有版面、篩選流程與候選人專屬詳細資訊頁，並改為從 Supabase 讀取「已發布」資料。

## 專案內容

- `public/index.html`：公開候選人查詢頁。只讀取已發布資料，不會把草稿顯示給一般訪客。
- `public/source-original.html`：你提供的原始 HTML，未修改，供備份。
- `admin/index.html`：管理後台，包含管理員登入、TOTP MFA、AAL2 檢查、草稿新增／編輯／刪除、單筆發布、全部發布、初始資料匯入。
- `supabase/schema.sql`：資料表、RLS 權限、審計紀錄、發布 RPC。
- `data/initial-candidates.json`：從原始 HTML 還原的 1,693 筆候選人資料，匯入後全部是草稿。
- `data/regions.json`：原始頁面使用的地區分類。

## 重要安全提醒

1. 前端只使用 Supabase Project URL 與 Publishable key（或舊版 anon public key）。
2. **絕對不要**把 Secret key、service_role key、資料庫密碼放進 HTML、GitHub 或傳給任何人。
3. 後台固定只允許管理員 UID：`feec62cf-3af7-4315-add9-96b6aeb117ff`。
4. 新增、修改、刪除、發布操作均要求管理員登入且通過 TOTP MFA，JWT 安全等級需為 AAL2。
5. 所有初始 1,693 筆資料匯入後都是草稿；公開網站在發布前不會顯示它們。
6. 這是第一階段重建版，請先以少量測試資料驗證流程，再匯入全部資料、檢查資料後才發布。

## 建議操作順序

### 第 1 步：先不要操作 GitHub，先建立 Supabase 資料庫結構

1. 登入你已建立的 Supabase 專案「公民怎麼投」。
2. 左側選單進入 **SQL Editor**。
3. 開啟本資料夾 `supabase/schema.sql`，完整複製內容。
4. 在 SQL Editor 貼上，按 **Run**。
5. 若出現成功訊息，先截圖回傳確認。若出現錯誤，先不要反覆執行或自行修改，請把錯誤畫面傳回來。

### 第 2 步：確認 Supabase 前端連線資訊

在 Supabase 專案的 **Project Settings → API**（介面也可能顯示 API Keys）找到：
- Project URL
- Publishable key；若專案介面提供舊版 anon public key，也可使用 anon public key。

只需將這兩項填入網站設定。不要提供 Secret key。

### 第 3 步：部署 GitHub Pages

將 ZIP 解壓縮後，將 `public` 資料夾內容放到 GitHub Pages 網站根目錄；`admin` 資料夾與 `data` 資料夾也需一併放在同一個網站根目錄，最後結構應為：
```
/index.html
/source-original.html
/admin/index.html
/data/initial-candidates.json
/data/regions.json
```
將 `public/index.html` 複製成根目錄 `index.html`，`public/source-original.html` 可放根目錄作為備份。管理後台路徑為 `/admin/`。

### 第 4 步：設定公開頁 Supabase 連線

編輯根目錄 `index.html`，找到：
```
const SUPABASE_URL = "請填入_SUPABASE_PROJECT_URL";
const SUPABASE_ANON_KEY = "請填入_SUPABASE_PUBLISHABLE_OR_ANON_KEY";
```
填入你的 Project URL 和 Publishable/anon key。

### 第 5 步：登入管理後台

1. 開啟 `https://你的GitHub帳號.github.io/你的專案/admin/`。
2. 填入同一個 Supabase 管理員帳號 Email 和密碼。
3. 第一次登入按「建立 TOTP 驗證器」，用驗證器 App 掃描 QR Code。
4. 輸入 6 位數代碼並按「驗證並提升安全等級」。
5. 成功顯示 AAL2 後，才可管理資料。

### 第 6 步：匯入 1,693 筆初始資料

在管理後台按「匯入初始 1,693 筆（僅草稿）」。此操作請只執行一次。匯入後先檢查筆數與資料內容，全部資料仍為草稿。

### 第 7 步：公開發布

資料檢查完成後，可逐筆發布或使用「全部發布草稿」。發布後一般訪客才會在公開頁看到資料。

## 目前版本的範圍與注意事項

- 目前資料來源是你提供的 HTML 內嵌資料，成功還原 1,693 筆。
- 原始檔包含的資料分類以原始內容為準；本版沒有自行新增原始檔未提供的鄉鎮市長、鄉鎮市民代表或里長資料。
- 後台匯入採每批 100 筆；若網路中斷可能發生部分匯入。若匯入中斷，先檢查資料庫筆數再決定如何處理，避免重複匯入。
- 這份 ZIP 是重建的第一階段版本，不是原本遺失 ZIP 的逐位元還原。正式對外發布前仍應完成測試、備份與權限檢查。
