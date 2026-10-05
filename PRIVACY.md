# Privacy Policy

Effective 2026-10-05. 繁體中文版在[下方](#隱私權政策)。

MISHIRUBE is a personal log of training, food, drinks, body measurements,
activity and sleep. It has no account system, no server of its own and no
analytics, advertising or tracking SDKs. The developer, KoukeNeko, does not
receive, store or sell any of your data.

[SECURITY.md](SECURITY.md) describes the same behavior from the technical side.

## Data the app holds

Everything you record, and an audit trail of every change, is kept in a
database inside the app's own storage on your device. Deleted records stay in
that database so a deletion can be undone. Uninstalling the app removes all of
it.

API keys and sign-in tokens for AI providers are kept in the Android Keystore
or the iOS Keychain, not in the database, and are left out of exports.

## Health Connect and Apple Health

When you connect Health Connect (Android) or Apple Health (iOS), the app reads
only the data types you allow and writes back what you log in the app: weight,
body composition, height, sleep, workouts, meals, water and similar records.
Records the app wrote are updated or removed on the platform when you edit or
delete them in the app. Records imported from the platform are never written
back.

Health data stays on your device. It is not sent to any server, not given to
any AI provider and not used for advertising. Disconnecting stops further
reads; records already read stay in the app until you delete them. You can
withdraw each permission at any time in Health Connect or Apple Health.

What the platform does with its own data is governed by Google's and Apple's
terms.

## AI features

AI is optional and drafts entries that you confirm before anything is recorded.

- **Apple Intelligence** runs on the device. Nothing it is given leaves the
  device.
- **A cloud provider** (Ollama Cloud, Google AI Studio, Anthropic, Azure AI
  Foundry, an OpenAI-compatible address you enter, or Microsoft 365 Copilot) is
  off until you choose one. The app asks for your consent before the first text
  is sent and again before the first photo. Only the text or photo of that
  request is sent, to the provider you chose, straight from your device. Photos
  are sent without location or capture metadata and are not kept by the app.
  The provider's own terms apply to what it does with the request. Under Google
  AI Studio's free tier, content may be used to improve Google's products and
  reviewed by people.
- Some providers can search the public web for nutrition data (Anthropic,
  Google AI Studio) based on the text of the request.
- Other photos, other records and health data are never sent. You can withdraw
  consent in *Me → AI*.

## Camera and photos

The camera is opened only while scanning a barcode or label. Photos of a body
scale or of body measurements are read on the device and not sent anywhere. The
photo picker reads the most recent photo as a thumbnail.

## Maps

A workout route is drawn on map tiles fetched from MapKit (iOS) or OpenFreeMap
through MapLibre (Android) when you open it. The route itself is not sent, but
the tiles requested reveal the area it covers to the map service.

## Notifications

Notifications such as the rest timer are generated on the device. The app has
no push server.

## Exports

An export writes a file to a place you choose. The file is not encrypted and is
as private as where you keep it. API keys are never included.

## Children

The app is not directed at children and collects nothing from anyone.

## Changes

A change to this policy is made in this file and shown by its effective date.
The history is in the repository.

## Contact

Open a [private security advisory](https://github.com/KoukeNeko/mishirube/security/advisories/new)
or an [issue](https://github.com/KoukeNeko/mishirube/issues) on the repository.
Please do not post personal data in a public issue.

---

# 隱私權政策

生效日期 2026-10-05。

MISHIRUBE 是記錄訓練、飲食、飲品、身體數據、活動與睡眠的個人紀錄工具。它沒有帳號系統、
沒有自己的伺服器，也沒有分析、廣告或追蹤 SDK。開發者 KoukeNeko 不會收到、儲存或出售你的任何資料。

## App 儲存的資料

你記錄的所有內容，以及每次變更的稽核紀錄，都存在這台裝置上 App 自己的儲存空間內的資料庫。
刪除的紀錄會保留在資料庫中，以便復原。解除安裝 App 會清除全部資料。

AI 供應商的 API 金鑰與登入權杖存放在 Android Keystore 或 iOS Keychain，不進資料庫，也不包含在匯出檔中。

## Health Connect 與 Apple 健康

連接 Health Connect（Android）或 Apple 健康（iOS）後，App 只讀取你允許的資料類別，並把你在
App 中記錄的體重、身體組成、身高、睡眠、運動、餐點、飲水等寫回平台。App 寫入的紀錄在 App 內
編輯或刪除時，會在平台上一併更新或移除；從平台讀入的紀錄不會寫回。

健康資料只留在你的裝置上，不會送到任何伺服器，不提供給 AI 供應商，也不用於廣告。中斷連接後
不再讀取，已讀入的紀錄會保留在 App 中，直到你刪除。你可以隨時在 Health Connect 或 Apple 健康
撤回各項權限。

平台如何處理自己的資料，依 Google 與 Apple 的條款。

## AI 功能

AI 是選用功能，只產生草稿，確認後才會記錄。

- **Apple Intelligence** 在裝置上執行，收到的內容不會離開裝置。
- **雲端供應商**（Ollama Cloud、Google AI Studio、Anthropic、Azure AI Foundry、你輸入的
  OpenAI 相容位址，或 Microsoft 365 Copilot）預設不啟用。第一次送出文字前，以及第一次送出照片前，
  App 會分別徵求你的同意。只會送出該次請求的文字或照片，直接從你的裝置送到你選的供應商。照片會先移除
  位置與拍攝資訊，App 不保存。供應商如何處理請求，依其自己的條款；Google AI Studio 免費額度的內容
  可能用於改進 Google 的產品並經人工審閱。
- 部分供應商（Anthropic、Google AI Studio）會依請求內容搜尋公開的營養資料。
- 其他照片、其他紀錄與健康資料不會送出。可在「我的 > AI」撤回同意。

## 相機與照片

相機只在掃描條碼或標籤時開啟。體脂計與圍度的照片在裝置上讀取數字，不送出。選取照片時會讀取
最新一張做為縮圖。

## 地圖

開啟運動路線時，會從 MapKit（iOS）或 OpenFreeMap（Android 以 MapLibre 取用）取得地圖圖磚。
路線本身不會送出，但請求的圖磚會讓地圖服務知道路線涵蓋的區域。

## 通知

休息計時等通知在裝置上產生，App 沒有推播伺服器。

## 匯出

匯出會把檔案寫到你選的位置。檔案未加密，隱私程度取決於你存放的地方。API 金鑰一律不包含在內。

## 兒童

App 不以兒童為對象，也不向任何人收集資料。

## 變更

政策變更會直接修改本檔案，並更新生效日期，歷史紀錄在儲存庫中。

## 聯絡

請在儲存庫開啟[私人安全公告](https://github.com/KoukeNeko/mishirube/security/advisories/new)或
[Issue](https://github.com/KoukeNeko/mishirube/issues)。請勿在公開 Issue 中貼出個人資料。
