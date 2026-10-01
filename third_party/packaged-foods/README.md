# Packaged food data

`assets/packaged/` holds packaged foods sold in Taiwan and Japan, read from
their labels. Each file keeps its own licence. They are built by
`tool/build_packaged_foods.py`; `research/76-taiwan-food-labels.md` and
`research/83-japan-food-labels.md` have the counts, the validation rules
and what was left out.

## tfda-tw.json

衛生福利部食品藥物管理署「食品追溯追蹤系統消費者查詢資料集」
(https://data.gov.tw/dataset/33575), published under the
[政府資料開放授權條款－第1版](https://data.gov.tw/license). The licence asks
only that the provider is named; the files are not a statement by the
agency. The labels are entered by the manufacturers, and the agency
does not vouch for them.

## openfoodfacts-tw.json and openfoodfacts-jp.json

Contains information from [Open Food Facts](https://world.openfoodfacts.org/),
made available under the
[Open Database License 1.0](https://opendatacommons.org/licenses/odbl/1-0/);
individual contents are under the
[Database Contents License 1.0](https://opendatacommons.org/licenses/dbcl/1-0/).
Each file is a derived database, so it stays under the ODbL, and it is the
machine-readable copy the licence asks to be offered: it is kept as a
separate file and is not merged with the app's own data. The Japanese file
holds products Open Food Facts lists as sold in Japan.

Both notices also appear on the open-source licences page in the app
(`registerPackagedFoodLicences`).
