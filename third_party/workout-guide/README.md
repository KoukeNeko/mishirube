# Workout Guide 的動作清單與示範圖

`assets/exercises/` 的動作清單與每個動作三張姿勢圖，來自 Workout Guide。

| 項目 | 內容 |
|---|---|
| 來源 | https://github.com/bryllim/workout-guide |
| 版本 | aac599224bb9780305239607ef98540b7e0ce389（2026-08-27） |
| 程式與 metadata 授權 | MIT（見同目錄 `LICENSE`） |
| 圖片授權 | CC BY-SA 4.0（見同目錄 `LICENSE-ASSETS`） |
| 圖片上游 | Everkinetic（CC BY-SA 4.0），見 `ATTRIBUTION.md` |
| 產生方式 | `tool/build_exercise_catalogue.py` |

## 我們取了什麼、改了什麼

**取了**：`packages/workout-guide/manifest.json` 的動作清單（英文名稱、器材、訓練型態）
與 `assets/*/frame-{1,2,3}.svg` 三張姿勢圖；伸展與活動度動作沒有收錄。

**改了**（CC BY-SA 要求標示變更）：

- 圖片：SVG 轉為 384 × 384 的 WebP（品質 78，保留透明），檔名改為本 App 的動作 id。
  圖形內容沒有修改。
- 資料：中文名稱、別名、主要與次要肌群（本 App 的 19 個肌群）、動作模式、單雙側、
  動作家族與部分器材分類，是本專案自己的整理，寫在建置腳本裡。

**沒取**：Workout Guide 的 TypeScript 套件、網站與文件。

## 授權要求我們做的事

- MIT：保留著作權聲明與授權條款（本目錄 `LICENSE`）。
- CC BY-SA 4.0：標示作者與授權、附授權連結、標示變更（本檔）；示範圖在 App 的
  動作頁標示來源與授權。這些圖的衍生版本以同樣的 CC BY-SA 4.0 釋出；
  App 的程式碼不受影響。
