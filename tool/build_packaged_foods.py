#!/usr/bin/env python3
"""Builds the packaged-food data that ships with the app.

    python3 tool/build_packaged_foods.py tfda <188_*.json or its .zip>
    python3 tool/build_packaged_foods.py off-fetch <directory for the pages>
    python3 tool/build_packaged_foods.py off <directory of fetched pages>
    python3 tool/build_packaged_foods.py off-csv <products.csv.gz> [directory for the fetched products]

The three `off` commands take `--market jp` (default `tw`) and write
`assets/packaged/openfoodfacts-<market>.json`, and `--max-requests N` to stop
calling the public API after N requests (retries included).

Writes `assets/packaged/tfda-tw.json`, `assets/packaged/openfoodfacts-tw.json`
and `assets/packaged/openfoodfacts-jp.json`. All are read by
`lib/backend/seed/packaged_foods.dart`; see
`research/76-taiwan-food-labels.md` and `research/83-japan-food-labels.md`
for the sources, licences and what is dropped.

  tfda       Taiwan FDA's 食品追溯追蹤系統消費者查詢資料集, dataset 33575 on
             data.gov.tw (政府資料開放授權條款－第1版). Download the JSON from
             https://data.fda.gov.tw/data/opendata/export/188/json
  off-fetch  Products Open Food Facts lists as sold in the market, through its
             public search API, slowly (ODbL 1.0).
  off        The same, turned into the app's format.
  off-csv    The whole set, from Open Food Facts' daily CSV export
             (https://world.openfoodfacts.org/data), streamed; the way to
             get every product of a market. Writes the same file as `off`.

Only a product whose label gives energy, protein, fat, carbohydrate and
sodium survives, and only if those figures agree with each other.
"""

import collections
import csv
import gzip
import hashlib
import json
import pathlib
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import zipfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / 'assets' / 'packaged'

RETRIEVED = time.strftime('%Y-%m-%d')
COLUMNS = [
    'id', 'brand', 'name', 'amount', 'unit', 'kcal', 'proteinG', 'fatG',
    'carbG', 'saturatedFatG', 'transFatG', 'sugarG', 'sodiumMg', 'beverage',
    'barcode',
]


class Dropped(collections.Counter):
    """Why a product was left out, counted for the research note."""

    def __call__(self, reason):
        self[reason] += 1
        return None


def number(value, unit):
    """`12.5公克` as 12.5; None for anything else, including `5＊`."""
    match = re.fullmatch(r'\s*(\d+(?:\.\d+)?)\s*' + unit + r'\s*', value or '')
    return float(match.group(1)) if match else None


def tidy(value):
    value = round(value, 2)
    return int(value) if value == int(value) else value


def check_figures(amount, kcal, protein, fat, carb, sodium_mg,
                  saturated=None, trans=None, sugar=None):
    """Why these figures cannot be one label's, or None when they can.

    Energy is checked against 4/4/9 with room for fibre, sugar alcohols
    and rounding; everything is per `amount` g or mL.
    """
    if not 1 <= amount <= 2000:
        return 'serving outside 1-2000 g/mL'
    figures = [kcal, protein, fat, carb, sodium_mg]
    if any(figure < 0 for figure in figures):
        return 'negative figure'
    # A serving cannot hold more macronutrient than it weighs.
    if protein + fat + carb > amount * 1.02 + 0.5:
        return 'macronutrients outweigh the serving'
    # Table salt is 39.3% sodium; nothing on a shelf has more.
    if sodium_mg > amount * 400 * 1.02 + 5:
        return 'sodium above pure salt'
    # Soy sauce is 6-7 g per 100 g. Past 12 g it is nearly always a typed
    # error (grams entered as milligrams, or the reverse), which also costs
    # the few seasonings and bouillons that really are that salty.
    if sodium_mg * 100 / amount > 12000:
        return 'sodium above 12 g per 100 g'
    if kcal > amount * 9.2 + 5:
        return 'energy above pure fat'
    calculated = 4 * protein + 4 * carb + 9 * fat
    if not (0.75 * calculated - 10 <= kcal <= 1.3 * calculated + 10):
        return 'energy disagrees with 4/4/9'
    if sugar is not None and sugar > carb + 0.5:
        return 'sugar above carbohydrate'
    if saturated is not None and saturated > fat + 0.5:
        return 'saturated fat above fat'
    if saturated is not None and trans is not None and saturated + trans > fat + 0.5:
        return 'saturated and trans fat above fat'
    return None


def write(name, header, rows):
    OUT.mkdir(parents=True, exist_ok=True)
    rows.sort(key=lambda row: row[0])
    columns = [
        column for index, column in enumerate(COLUMNS)
        if any(row[index] is not None for row in rows)
    ]
    keep = [COLUMNS.index(column) for column in columns]
    document = {**header, 'columns': columns,
                'foods': [[row[i] for i in keep] for row in rows]}
    text = json.dumps(document, ensure_ascii=False, separators=(',', ':'))
    # One product per line, so a diff of a new release reads.
    text = text.replace('"foods":[[', '"foods":[\n[').replace('],[', '],\n[')
    (OUT / name).write_text(text + '\n', encoding='utf-8')
    print(f'{name}: {len(rows)} products, {len(text) / 1e6:.2f} MB')


# --- Taiwan FDA ---------------------------------------------------------

# Food additives and detergents are not eaten as food.
TFDA_SKIPPED_CATEGORIES = {'食品添加物', '食品用洗潔劑'}
# Samples, tests and trade ingredients the dataset also carries.
TFDA_SKIPPED_NAMES = re.compile(r'樣品|測試|試用|無販售|供食品用途|\btest\b', re.I)
TFDA_DRINK_CATEGORIES = {'非酒精飲料製品', '製茶類製品', '乳類製品'}


def tfda(path):
    path = pathlib.Path(path)
    if path.suffix == '.zip':
        with zipfile.ZipFile(path) as archive:
            name = next(n for n in archive.namelist() if n.endswith('.json'))
            records = json.loads(archive.read(name).decode('utf-8-sig'))
    else:
        records = json.loads(path.read_text(encoding='utf-8-sig'))

    dropped = Dropped()
    rows, seen = [], set()
    for record in records:
        category = record['產品分類'] or ''
        name = re.sub(r'\s+', ' ', (record['產品名稱'] or '').replace('\xa0', ' ')).strip()
        brand = (record['公司名稱'] or '').strip()
        if category in TFDA_SKIPPED_CATEGORIES:
            dropped('category is not food')
            continue
        if not name or not brand or TFDA_SKIPPED_NAMES.search(name):
            dropped('no name, no company, or a sample/test')
            continue
        serving = record['每一份量']
        amount, unit = number(serving, '公克'), 'g'
        if amount is None:
            amount, unit = number(serving, '毫升'), 'ml'
        figures = [
            number(record['每份熱量'], '大卡'),
            number(record['每份蛋白質'], '公克'),
            number(record['每份脂肪'], '公克'),
            number(record['每份碳水化合物'], '公克'),
            number(record['每份鈉'], '毫克'),
        ]
        if amount is None or None in figures:
            dropped('label incomplete or not per g/mL serving')
            continue
        kcal, protein, fat, carb, sodium = figures
        saturated = number(record['每份飽和脂肪'], '公克')
        trans = number(record['每份反式脂肪'], '公克')
        sugar = number(record['每份糖'], '公克')
        reason = check_figures(amount, kcal, protein, fat, carb, sodium,
                               saturated, trans, sugar)
        if reason:
            dropped(reason)
            continue
        # The label also prints per 100 g; it has to agree with the serving.
        per_100g = number(record['每100公克熱量'], '大卡')
        if unit == 'g' and per_100g is not None:
            if abs(kcal * 100 / amount - per_100g) > max(5, 0.1 * per_100g):
                dropped('per-serving and per-100 g energy disagree')
                continue
        key = (brand, name, amount, unit, kcal, protein, fat, carb, sodium)
        if key in seen:
            dropped('duplicate of another package size')
            continue
        seen.add(key)
        code = record['產品追溯系統串接碼']
        rows.append([
            'tfda-' + hashlib.sha1(code.encode()).hexdigest()[:10],
            brand, name, tidy(amount), unit, tidy(kcal), tidy(protein),
            tidy(fat), tidy(carb),
            None if saturated is None else tidy(saturated),
            None if trans is None else tidy(trans),
            None if sugar is None else tidy(sugar),
            tidy(sodium),
            1 if unit == 'ml' and category in TFDA_DRINK_CATEGORIES else 0,
            None,
        ])
    ids = [row[0] for row in rows]
    assert len(ids) == len(set(ids)), 'id collision'
    write('tfda-tw.json', {
        'source': 'tfda',
        'market': 'tw',
        'checkedAt': RETRIEVED,
        'sourceUrl': 'https://data.gov.tw/dataset/33575',
        'licence': '政府資料開放授權條款－第1版',
        'attribution': '衛生福利部食品藥物管理署「食品追溯追蹤系統消費者查詢資料集」',
    }, rows)
    report(len(records), rows, dropped)


# --- Open Food Facts ----------------------------------------------------

OFF_FIELDS = ','.join([
    'code', 'product_name', 'product_name_zh', 'product_name_ja', 'brands',
    'quantity', 'serving_size', 'serving_quantity', 'nutriments',
    'countries_tags', 'states_tags',
])
OFF_AGENT = 'MISHIRUBE-catalogue-import/1.0 (open-source nutrition logger)'

# What differs between the markets Open Food Facts files are built for.
#   country   the `countries_tags` entry and the search API's country name
#   names     the product-name fields to try, in order
#   salt      grams of salt equivalent per gram of sodium
#   salt_first
#             whether the label's salt figure outranks a sodium figure.
#             Japanese labels (食品表示基準) print 食塩相当量 and only
#             optionally sodium, so Open Food Facts' sodium there is nearly
#             always its own salt / 2.5; the label's factor is 2.54.
MARKETS = {
    'tw': {'country': 'taiwan', 'names': ('product_name_zh', 'product_name'),
           'salt': 2.5, 'salt_first': False},
    'jp': {'country': 'japan', 'names': ('product_name_ja', 'product_name'),
           'salt': 2.54, 'salt_first': True},
}

# Every call to the public API, retries included, counted against a cap
# the caller may set so a run cannot go on asking.
api_requests = 0
api_request_cap = None
# Refusals (429, 5xx, timeouts) in a row; five stop a run.
refusals = 0
MAX_REFUSALS = 5


def off_get(url):
    """A JSON reply, asked for again a few times: the service is shared and
    answers 503 (and sometimes 401) while it is busy. None when it stays
    unavailable."""
    global api_requests, refusals
    request = urllib.request.Request(url, headers={'User-Agent': OFF_AGENT})
    for attempt in range(6):
        if refusals >= MAX_REFUSALS or (
                api_request_cap is not None and api_requests >= api_request_cap):
            return None
        api_requests += 1
        try:
            reply = json.load(urllib.request.urlopen(request, timeout=90))
            refusals = 0
            return reply
        except urllib.error.HTTPError as error:
            if error.code == 404:
                # A product the service does not have; asking again is no use.
                refusals = 0
                return {'status': 0}
            refusals += 1
            print('retry', url[-60:], error, flush=True)
            time.sleep(15 * (attempt + 1))
        except Exception as error:
            refusals += 1
            print('retry', url[-60:], error, flush=True)
            time.sleep(15 * (attempt + 1))
    return None


def off_fetch(directory, market='tw'):
    """Everything the public API will give about the market's products.

    1. The search API's pages, 100 products each and 8 s apart (it allows 10
       calls a minute), for as far as it answers; it refuses deep pages
       now and then. A page already in the directory is kept, so a run
       resumes.
    2. The products that search-a-licious lists for the market and the pages
       did not bring, one product call each (limit 100 a minute).
    The daily CSV export is the full list of products, but it leaves out
    the figures of those entered under Open Food Facts' newer nutrition
    format; `off-csv` takes those from here.
    """
    directory = pathlib.Path(directory)
    directory.mkdir(parents=True, exist_ok=True)
    page = 1
    while True:
        target = directory / f'p{page:03d}.json'
        if not target.exists():
            body = off_get(
                'https://world.openfoodfacts.org/api/v2/search?'
                + urllib.parse.urlencode({
                    'countries_tags_en': MARKETS[market]['country'], 'fields': OFF_FIELDS,
                    'page_size': 100, 'page': page}))
            if body is None:
                print(f'page {page} would not load; going on without it')
                break
            target.write_text(json.dumps(body, ensure_ascii=False),
                              encoding='utf-8')
            time.sleep(8)
        else:
            body = json.loads(target.read_text(encoding='utf-8'))
        print(page, len(body['products']), body['count'], flush=True)
        if not body['products'] or page * 100 >= body['count']:
            break
        page += 1

    have = {
        product['code']
        for file in directory.glob('*.json')
        for product in json.loads(file.read_text(encoding='utf-8'))['products']
    }
    listed = []
    for number in range(1, 100):
        reply = off_get(
            'https://search.openfoodfacts.org/search?'
            + urllib.parse.urlencode({
                'q': f'countries_tags:"en:{MARKETS[market]["country"]}"',
                'fields': 'code',
                'page_size': 100, 'page': number}))
        if reply is None or not reply['hits']:
            break
        listed += [hit['code'] for hit in reply['hits']]
        time.sleep(1)
    fetch_by_code(directory, listed)


def fetch_by_code(directory, codes):
    """One product call for each code the directory does not have yet,
    kept in `extra.json` (limit 100 a minute, so one a second). A run
    resumes; it gives up when the service keeps refusing."""
    directory = pathlib.Path(directory)
    directory.mkdir(parents=True, exist_ok=True)
    target = directory / 'extra.json'
    extra = (json.loads(target.read_text(encoding='utf-8'))['products']
             if target.exists() else [])
    have = {
        product['code']
        for file in directory.glob('*.json')
        for product in json.loads(file.read_text(encoding='utf-8'))['products']
    }

    def save():
        target.write_text(json.dumps({'products': extra}, ensure_ascii=False),
                          encoding='utf-8')

    pending = [code for code in codes if code not in have]
    for done, code in enumerate(pending):
        if api_request_cap is not None and api_requests >= api_request_cap:
            print(f'request cap of {api_request_cap} reached; '
                  f'{len(pending) - done} products left unfetched')
            break
        reply = off_get(
            f'https://world.openfoodfacts.org/api/v2/product/{code}?'
            + urllib.parse.urlencode({'fields': OFF_FIELDS}, safe=','))
        if reply is None:
            if refusals >= MAX_REFUSALS:
                print('the service keeps refusing; stopping')
                break
        else:
            if reply.get('status') == 1:
                extra.append(reply['product'])
            have.add(code)
        if len(extra) % 50 == 0:
            save()
        time.sleep(1)
    save()
    print(f'{len(extra)} products fetched by code', flush=True)


def ean_is_valid(code):
    """GS1 check digit, for EAN-8, UPC-A, EAN-13 and GTIN-14."""
    if not code.isdigit() or len(code) not in (8, 12, 13, 14):
        return False
    digits = [int(d) for d in code]
    total = sum(d * (3 if i % 2 == 0 else 1)
                for i, d in enumerate(reversed(digits[:-1])))
    return (10 - total % 10) % 10 == digits[-1]


def serving_of(product):
    """The serving as amount and unit, or a hundred of what it is sold by."""
    for text in (product.get('serving_size'), product.get('quantity')):
        match = re.fullmatch(
            r'\s*(\d+(?:[.,]\d+)?)\s*(g|gr|ml|mL|ML|cl|l|L)\b.*',
            text or '', re.S)
        if not match:
            continue
        amount = float(match.group(1).replace(',', '.'))
        unit = match.group(2).lower()
        amount *= {'cl': 10, 'l': 1000}.get(unit, 1)
        unit = 'ml' if unit in ('ml', 'cl', 'l') else 'g'
        # Only a serving is a portion; a package's weight is not.
        if text is product.get('serving_size'):
            return amount, unit
        return 100, unit
    return 100, 'g'


def salt_to_sodium(salt_g, sodium_g, salt_per_sodium, salt_first):
    """Sodium in grams from a label's salt and sodium figures, None when it
    has neither. Salt is sodium times `salt_per_sodium` (2.5, or 2.54 where
    the label states it so, as Japan's does)."""
    if salt_first and salt_g is not None:
        return salt_g / salt_per_sodium
    if sodium_g is not None:
        return sodium_g
    return None if salt_g is None else salt_g / salt_per_sodium


def off(directory, market='tw'):
    products = []
    for page in sorted(pathlib.Path(directory).glob('*.json')):
        products += json.loads(page.read_text(encoding='utf-8'))['products']
    build_off(products, market)


# The export's columns that carry what OFF_FIELDS asks the API for.
OFF_CSV_TEXT_COLUMNS = ['code', 'product_name', 'brands', 'quantity',
                        'serving_size', 'countries_tags', 'states_tags',
                        'completeness', 'nutriscore_grade']
OFF_CSV_NUTRIMENTS = ['energy-kcal', 'proteins', 'fat', 'carbohydrates',
                      'sodium', 'salt', 'saturated-fat', 'trans-fat', 'sugars']


def off_csv(path, directory=None, market='tw'):
    """The export's rows for the market, in the shape the API gives them.

    The file is 1.3 GB gzipped and about 4 million rows, so it is read one
    row at a time. The export is tab-separated with no quoting.

    It has no figures for the products entered under Open Food Facts' newer
    nutrition format. With a directory, those whose nutrition facts are
    marked completed are fetched by code into it (as `off-fetch` does) and
    the API's product replaces the export's.
    """
    csv.field_size_limit(2 ** 24)
    opener = gzip.open if str(path).endswith('.gz') else open
    products = []
    with opener(path, 'rt', encoding='utf-8', newline='') as stream:
        rows = csv.reader(stream, delimiter='\t', quoting=csv.QUOTE_NONE)
        header = {name: index for index, name in enumerate(next(rows))}
        tag = 'en:' + MARKETS[market]['country']
        tags = header['countries_tags']
        text = {name: header[name] for name in OFF_CSV_TEXT_COLUMNS}
        figures = {key: header[key + '_100g'] for key in OFF_CSV_NUTRIMENTS}
        for row in rows:
            if len(row) <= tags or tag not in row[tags].split(','):
                continue
            product = {name: row[index] for name, index in text.items()
                       if index < len(row)}
            product['countries_tags'] = row[tags].split(',')
            product['states_tags'] = product.get('states_tags', '').split(',')
            product['nutriments'] = {}
            for key, index in figures.items():
                try:
                    product['nutriments'][key + '_100g'] = float(row[index])
                except (IndexError, ValueError):
                    pass
            products.append(product)
    print(f'{len(products)} {market} products in the export', flush=True)
    if directory:
        wanted = [
            p for p in products
            if 'energy-kcal_100g' not in p['nutriments']
            and 'en:nutrition-facts-completed' in p['states_tags']
            and p.get('product_name')
            and ean_is_valid(p['code'])]
        # A run may be capped (--max-requests), so ask first for the products
        # most likely to have a usable label: those Open Food Facts could
        # score (a-e needs sugar, fat, salt and protein), then the better
        # filled-in pages.
        wanted.sort(key=lambda p: (
            p.get('nutriscore_grade') in ('a', 'b', 'c', 'd', 'e'),
            float(p.get('completeness') or 0),
            bool(p.get('serving_size'))), reverse=True)
        fetch_by_code(directory, [p['code'] for p in wanted])
        fetched = {}
        for file in sorted(pathlib.Path(directory).glob('*.json')):
            for product in json.loads(file.read_text(encoding='utf-8'))['products']:
                fetched[product['code']] = product
        products = [fetched.get(p['code'], p) for p in products]
    build_off(products, market)


def build_off(products, market='tw'):
    config = MARKETS[market]
    tag = 'en:' + config['country']
    # Pages fetched in different runs can overlap.
    products = list({p['code']: p for p in products}.values())

    # A product sold in two markets is in the file built first: the app
    # keys foods by id, so the same barcode may not be in two files.
    listed_elsewhere = set()
    for other in OUT.glob('openfoodfacts-*.json'):
        if other.name != f'openfoodfacts-{market}.json':
            file = json.loads(other.read_text(encoding='utf-8'))
            column = file['columns'].index('barcode')
            listed_elsewhere |= {row[column].lstrip('0') for row in file['foods']}

    dropped = Dropped()
    rows, seen = [], set(listed_elsewhere)
    for product in products:
        code = product.get('code') or ''
        if tag not in product.get('countries_tags', []):
            dropped(f'not sold in {config["country"].title()}')
            continue
        name = re.sub(
            r'\s+', ' ',
            next((product[key] for key in config['names'] if product.get(key)),
                 ''),
        ).strip()
        brand = (product.get('brands') or '').split(',')[0].strip()
        if not name:
            dropped('no name')
            continue
        if not ean_is_valid(code):
            dropped('barcode fails its check digit')
            continue
        if code.lstrip('0') in listed_elsewhere:
            dropped('already in another market\'s file')
            continue
        if code.lstrip('0') in seen:
            dropped('duplicate barcode')
            continue
        nutriments = product.get('nutriments') or {}

        def per_100(key):
            value = nutriments.get(key + '_100g')
            return float(value) if isinstance(value, (int, float)) else None

        kcal = per_100('energy-kcal')
        protein, fat, carb = per_100('proteins'), per_100('fat'), per_100('carbohydrates')
        salt_g, sodium_g = per_100('salt'), per_100('sodium')
        # Open Food Facts derives each from the other (salt = sodium * 2.5),
        # so a pair that disagrees is a typing error in one of them.
        if (salt_g is not None and sodium_g is not None
                and abs(salt_g / 2.5 - sodium_g) > max(0.1 * sodium_g, 0.005)):
            dropped('salt and sodium disagree')
            continue
        sodium_g = salt_to_sodium(salt_g, sodium_g, config['salt'],
                                  config['salt_first'])
        if None in (kcal, protein, fat, carb, sodium_g):
            dropped('label incomplete')
            continue
        amount, unit = serving_of(product)
        scale = amount / 100
        figures = [kcal * scale, protein * scale, fat * scale, carb * scale,
                   sodium_g * 1000 * scale]
        saturated, trans, sugar = (
            None if per_100(key) is None else per_100(key) * scale
            for key in ('saturated-fat', 'trans-fat', 'sugars'))
        reason = check_figures(amount, *figures, saturated, trans, sugar)
        if reason:
            dropped(reason)
            continue
        seen.add(code.lstrip('0'))
        rows.append([
            'off-' + code, brand, name, tidy(amount), unit,
            *(tidy(f) for f in figures[:4]),
            *(None if f is None else tidy(f) for f in (saturated, trans, sugar)),
            tidy(figures[4]), 0, code,
        ])
    write(f'openfoodfacts-{market}.json', {
        'source': 'openfoodfacts',
        'market': market,
        'checkedAt': RETRIEVED,
        'sourceUrl': 'https://world.openfoodfacts.org/',
        'productUrl': 'https://world.openfoodfacts.org/product/{barcode}',
        'licence': 'Open Database License 1.0 (ODbL); contents under the '
                   'Database Contents License 1.0',
        'attribution': 'Open Food Facts contributors, openfoodfacts.org',
    }, rows)
    report(len(products), rows, dropped)


def report(total, rows, dropped):
    print(f'read {total}, kept {len(rows)}')
    for reason, count in dropped.most_common():
        print(f'  {count:6}  {reason}')


def option(name, default):
    """`--name value` taken out of the arguments, or [default]."""
    if name in sys.argv:
        index = sys.argv.index(name)
        value = sys.argv[index + 1]
        del sys.argv[index:index + 2]
        return value
    return default


if __name__ == '__main__':
    commands = {'tfda': tfda, 'off': off, 'off-fetch': off_fetch,
                'off-csv': off_csv}
    market = option('--market', 'tw')
    cap = option('--max-requests', None)
    api_request_cap = None if cap is None else int(cap)
    if (not 3 <= len(sys.argv) <= 4 or sys.argv[1] not in commands
            or market not in MARKETS):
        sys.exit(__doc__)
    commands[sys.argv[1]](*sys.argv[2:],
                          **({} if sys.argv[1] == 'tfda' else {'market': market}))
