# ExerciseDB 的動作動畫

動作頁的動畫是 ExerciseDB 免費版的 GIF（180 × 180），由 AscendAPI 提供。

| 項目 | 內容 |
|---|---|
| 來源 | https://exercisedb.dev（免費版 API：https://oss.exercisedb.dev） |
| 清單 | 免費版的 1,500 個動作，取自 https://github.com/bootstrapping-lab/exercisedb-api 的 `src/data/exercises.json`（2026-10-05） |
| 動畫位址 | `https://static.exercisedb.dev/media/<id>.gif` |
| 授權 | 免費版：僅限非商業使用，並須標示 AscendAPI |
| 使用方式 | 不隨 App 發佈；顯示該動作時下載，存在裝置的快取資料夾（`lib/backend/application/exercise_gifs.dart`） |

授權條件取自 ExerciseDB 免費版的公開說明與第三方整理；沒有讀到 AscendAPI 的完整條款
原文。**App 若要上架販售或有任何收費，這些動畫不能用**，要改用付費授權
（ExerciseDB 商業版）或移除；移除是把 `assets/exercises/gifs.json` 改成 `{}`，
App 就回到姿勢圖。

## 我們取了什麼

只取每個動畫的 id 與名稱：`tool/match_exercisedb.py` 逐一比對本 App 的動作與 ExerciseDB
的動作，結果在 `tool/exercise_data/exercisedb.json`（我們的動作 id → ExerciseDB 的 id
與名稱），再由 `tool/merge_exercise_catalogue.py` 寫成 `assets/exercises/gifs.json`。
ExerciseDB 的步驟說明、肌群與器材資料沒有使用。

比對只收同一個動作、同一種器材：名稱去掉器材字之後字詞相同，並逐一讀過結果，
剔除別的變化式（加重伏地挺身不是徒手伏地挺身），補上字詞找不到的。沒有把握的
不收，所以 1,504 個動作裡有 350 個有動畫，其餘仍是原有的三張姿勢圖或沒有示範。

## 網路

動畫的請求只送出動畫檔名，連線本身讓 `static.exercisedb.dev` 看得到裝置的位址。
這一點寫在隱私頁（`privacyExerciseGifs`）。離線時動作維持原有的姿勢圖。
