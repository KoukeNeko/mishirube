# MuscleMap 的肌肉輪廓

`lib/features/trends/muscle_map_paths.dart` 裡的向量路徑不是這個專案畫的。

| 項目 | 內容 |
|---|---|
| 來源 | https://github.com/Jsplice/MuscleMap |
| 檔案 | `packages/assets/src/{male,female}-{front,back}.ts` |
| 取得日期 | 2026-09-20 |
| 授權 | MIT（見同目錄 `LICENSE`） |
| 來源說明 | repo 的 `ASSET_PROVENANCE.md` 記載這些 path 是該專案以 Inkscape 手繪的原創作品，與程式碼同樣以 MIT 釋出 |

## 我們取了什麼、沒取什麼

**取了**：男性與女性、正面與背面共四張圖的人體輪廓（`BODY`）與各肌肉面的
`d` 路徑資料。

**沒取**：該專案的 React/TypeScript 程式、以 AI 生成的示範人體照片（`bodies/*.webp`）、
以及它自己的肌群分類。哪一塊形狀代表哪個肌群，是本專案自己的對應
（見 `muscle_map_paths.dart` 的產生規則）——因為這個 App 只記錄十個肌群，
而那張圖比十個細。內收肌與外展肌沒有對應的肌群，因此永遠不著色。

## MIT 要求我們做的事

保留著作權聲明與授權條款（即同目錄的 `LICENSE`）。已保留。
