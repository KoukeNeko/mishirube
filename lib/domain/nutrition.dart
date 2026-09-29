import '../shared/format.dart';
import 'body.dart';

class FoodComponent {
  const FoodComponent({
    required this.name,
    required this.amountLabel,
    required this.source,
  });

  final String name;
  final String amountLabel;
  final String source;
}

class DishEntry {
  const DishEntry({
    required this.name,
    required this.quantityLabel,
    required this.subtitle,
    this.components = const [],
  });

  final String name;
  final String quantityLabel;
  final String subtitle;
  final List<FoodComponent> components;

  bool get isComposite => components.isNotEmpty;
}

/// How the water shortcut marks what it writes, so a glass of water can
/// be told from any other drink — including a saved food someone named
/// 「水」, which comes through a portion instead.
// l10n-ignore: stored with the meal; shown through qualityTagLabel.
const waterQualityTag = '水';

// The other marks a meal is stored with, shown through qualityTagLabel.
// l10n-ignore: stored.
const confirmedQualityTag = '已確認';
// l10n-ignore: stored.
const estimatedPortionQualityTag = '份量為估計';
// l10n-ignore: stored.
const customFoodQualityTag = '自訂食物';
// l10n-ignore: stored.
const quickLogQualityTag = '快速記錄';

class MealEvent {
  const MealEvent({
    required this.id,
    required this.name,
    required this.timeLabel,
    required this.qualityTag,
    required this.dishes,
    this.kcal,
    this.proteinGrams,
    this.carbGrams,
    this.fatGrams,
    this.fibreGrams,
    this.isEstimated = false,
    this.isFavorite = false,
    this.nutrients = const {},
    this.millilitres,
    this.kind = ConsumptionKind.unknown,
    this.mealType,
    this.valueType = NutrientValueType.declared,
    this.foodId,
    this.servings,
    this.groupId,
    this.labelCountry = '',
    this.brand = '',
    this.amount = '',
  });

  final String id;
  final String name;

  /// How much was eaten, in words, when that is not a food's servings:
  /// an AI draft's `180 g`. Empty when nobody said.
  final String amount;
  final String timeLabel;

  /// The saved food this was logged from, and how many of its servings,
  /// when it came from one. Only for remembering what the user usually
  /// has: the numbers above were copied and never follow the food.
  final String? foodId;
  final double? servings;

  /// The group this is one item of, when several things were eaten as
  /// one meal: each keeps its own record and figures, and the meal is
  /// their sum. Null for something eaten on its own.
  final String? groupId;

  /// Whose rules the label its figures came from follows (`TW`, `JP`,
  /// `EU`), copied from the food when it was logged; empty when not
  /// known. It decides how the label's salt reads as sodium.
  final String labelCountry;

  /// Who made it, copied from the food when it was logged and editable
  /// on the record; empty when nobody said.
  final String brand;

  /// Plain water from the water shortcut, as opposed to any other drink.
  bool get isWater =>
      qualityTag == waterQualityTag && dishes.isEmpty && foodId == null;

  /// Some amount in the meal is a guess, so its totals read as `~`.
  final bool isEstimated;

  /// What was eaten, where it is known. Null is not zero: a meal logged
  /// from a food whose label was never read has no calorie figure, and
  /// the day's total has to say so rather than quietly add nothing.
  final double? kcal;
  final String qualityTag;
  final List<DishEntry> dishes;
  final double? proteinGrams;
  final double? carbGrams;
  final double? fatGrams;

  /// Fibre, which is part of the carbohydrate already counted above and
  /// is tracked separately because it is what people actually watch.
  final double? fibreGrams;

  /// Starred to log again without going looking for it.
  final bool isFavorite;

  /// Everything else known about what was eaten. Absent means unknown,
  /// so a day's total for a nutrient has to say how much of the day it
  /// could not see.
  final Nutrients nutrients;

  /// Whether this was eaten or drunk, as the food said when it was
  /// logged. Copied, not looked up, like everything else here.
  final ConsumptionKind kind;

  /// Which sitting the user called it, if they said. Null is not a
  /// failure to record: plenty of eating does not belong to a sitting.
  final MealType? mealType;

  /// What kind of numbers these are, copied from the food when it was
  /// logged. A day adding up ceilings has a ceiling for a total.
  final NutrientValueType valueType;

  /// How much liquid this was, when it was logged by volume.
  ///
  /// It is what was drunk, not the water in it: 250 ml of milk is 250 ml
  /// of drink. The app applies no hydration factor, because the numbers
  /// other apps use for that are not something anyone can show the
  /// working for.
  final int? millilitres;

  MealEvent copyWith({
    String? id,
    String? name,
    String? timeLabel,
    List<DishEntry>? dishes,
    bool? isFavorite,
    double? kcal,
    double? proteinGrams,
    double? carbGrams,
    double? fatGrams,
    double? fibreGrams,
    bool? isEstimated,
    String? qualityTag,
    Nutrients? nutrients,
    int? millilitres,
    ConsumptionKind? kind,
    MealType? mealType,
    NutrientValueType? valueType,
    String? Function()? groupId,
    String? brand,
    String? amount,
  }) => MealEvent(
    foodId: foodId,
    servings: servings,
    groupId: groupId == null ? this.groupId : groupId(),
    labelCountry: labelCountry,
    brand: brand ?? this.brand,
    amount: amount ?? this.amount,
    id: id ?? this.id,
    name: name ?? this.name,
    timeLabel: timeLabel ?? this.timeLabel,
    kcal: kcal ?? this.kcal,
    qualityTag: qualityTag ?? this.qualityTag,
    dishes: dishes ?? this.dishes,
    proteinGrams: proteinGrams ?? this.proteinGrams,
    carbGrams: carbGrams ?? this.carbGrams,
    fatGrams: fatGrams ?? this.fatGrams,
    fibreGrams: fibreGrams ?? this.fibreGrams,
    isFavorite: isFavorite ?? this.isFavorite,
    isEstimated: isEstimated ?? this.isEstimated,
    nutrients: nutrients ?? this.nutrients,
    millilitres: millilitres ?? this.millilitres,
    kind: kind ?? this.kind,
    mealType: mealType ?? this.mealType,
    valueType: valueType ?? this.valueType,
  );
}

/// What kind of number a food's figures are.
///
/// The same 257 mg means different things depending on where it came
/// from. Taiwan requires chains to publish a *maximum* caffeine figure
/// per cup, not the amount in the cup you are holding; the FDA gives
/// brewed coffee as a range of 113–247 mg per 355 ml; and one study
/// sampling the same drink at the same shop on six days found 259 to
/// 564 mg. Printing all of those as a bare number would be inventing a
/// precision nobody has.
enum NutrientValueType {
  /// A figure the maker declares: a packet label, a brand's own table.
  declared,

  /// A ceiling, not a measurement — what Taiwanese chains are required
  /// to publish. The number is shown as it is and the pages that show it
  /// say it is a maximum, the way the chains' own tables do.
  max,

  /// Not this thing's own label: a general figure for its kind, or one
  /// borrowed from the same recipe in another size.
  estimate,
}

/// Which sitting a record belongs to, when the user says so.
///
/// Optional everywhere, and never guessed from the clock. The time is
/// the fact; which meal that was is what the person calls it, and the
/// two disagree more than you would think — asking people to name the
/// sitting and classifying the same records by time only agree at an
/// ICC of about 0.37. The American Heart Association says outright that
/// meal and snack have no agreed definition and that letting people
/// judge for themselves travels better between cultures.
///
/// These five are the values Health Connect defines, so a record can be
/// handed over without inventing a mapping. HealthKit has no meal type
/// at all; syncing there simply loses the note.
enum MealType { breakfast, lunch, dinner, snack }

/// Whether something is eaten or drunk.
///
/// This is not the same question as how it is measured. Soup and sauces
/// are poured by the millilitre and no food authority calls them drinks;
/// drink powders and syrups are weighed in grams and become drinks. USDA,
/// Codex and the TFDA all classify by how something is consumed, not by
/// the unit on the packet — so the app asks rather than guesses.
///
/// [unknown] is where the genuinely arguable ones sit. It is not a
/// failure to categorise: nobody has a definition of "beverage" that
/// settles soup, so the app does not pretend to have one.
enum ConsumptionKind { food, beverage, unknown }

/// Which column of the label the figures were typed from: per 100 g or
/// ml, or one serving. Named for caffeine, the first figure typed this
/// way; it covers the whole label now. The food keeps every figure per
/// serving either way; this is only so the form can show them back as
/// they were typed.
enum CaffeineBasis { serving, per100 }

/// What kind of quantity a unit measures.
///
/// Mass and volume never convert into each other: that needs the food's
/// density, which the app does not know. A teaspoon of oil is 5 g and a
/// teaspoon of mayonnaise is 8 g, so treating 100 ml as 100 g is not a
/// rounding error, it is a wrong answer.
enum ServingDimension { mass, volume, count }

/// How much one serving of a food is.
///
/// Only units with an exact, official conversion are here. Household
/// measures are deliberately absent: a cup is 240 ml to Taiwan's health
/// authority, 236.6 ml in the US and 250 ml metric, and an Australian
/// tablespoon is 20 ml against everyone else's 15. A unit that means
/// three different things is not a unit.
///
/// [ServingDimension.count] means the size is not a measurement at all:
/// one 便當 is one 便當, and the app must not pretend it knows the grams.
enum ServingUnit {
  gram(ServingDimension.mass, 1),
  kilogram(ServingDimension.mass, 1000),
  ounce(ServingDimension.mass, 28.349523125),
  pound(ServingDimension.mass, 453.59237),

  /// Taiwan's tael and catty, fixed by the Bureau of Standards at
  /// 37.5 g and 600 g.
  tael(ServingDimension.mass, 37.5),
  catty(ServingDimension.mass, 600),

  millilitre(ServingDimension.volume, 1),
  litre(ServingDimension.volume, 1000),

  serving(ServingDimension.count, 1);

  const ServingUnit(this.dimension, this.inBaseUnit);
  final ServingDimension dimension;

  /// How many of the dimension's base unit — grams or millilitres — one
  /// of these is.
  final double inBaseUnit;

  /// Whether a portion can be entered as a raw amount in this unit.
  bool get isMeasured => dimension != ServingDimension.count;

  /// The units a portion of this one can also be written in. Converting
  /// outside this list would need a density the app does not have.
  Iterable<ServingUnit> get comparable =>
      values.where((unit) => unit.dimension == dimension);

  /// [amount] of this unit, written in [target]. Both must measure the
  /// same kind of quantity.
  double convert(double amount, ServingUnit target) {
    assert(target.dimension == dimension, 'no density to convert with');
    return amount * inBaseUnit / target.inBaseUnit;
  }
}

/// A food the user saved so they do not have to type it in again.
///
/// This is the private layer of the food catalogue: it lives on this
/// device, it is never shared, and every value in it was entered by the
/// person who will read it back. Nothing here claims to be authoritative.
class FoodItem {
  const FoodItem({
    required this.id,
    required this.name,
    this.kcal,
    this.proteinGrams,
    this.carbGrams,
    this.fatGrams,
    this.fibreGrams,
    this.brand = '',
    this.servingLabel = '',
    this.servingAmount = 1,
    this.servingUnit = ServingUnit.serving,
    this.nutrients = const {},
    this.parentId,
    this.sizeName = '',
    this.kind = ConsumptionKind.unknown,
    this.valueType = NutrientValueType.declared,
    this.sourceUrl = '',
    this.checkedAt,
    this.isBuiltIn = false,
    this.searchTerms = '',
    this.isCupCapacity = false,
    this.series = '',
    this.note = '',
    this.country = '',
    this.caffeineBasis = CaffeineBasis.serving,
    this.allergens,
    this.barcode,
  });

  final String id;

  final String name;

  /// The maker, when the food has one; empty for anything homemade.
  final String brand;

  /// The maker's own line the food belongs to, when it names one:
  /// 7-ELEVEN sells CITY CAFE and CITY TEA, and both have a 拿鐵.
  final String series;

  /// What the maker says about it beside its name, which is not part of
  /// the name: `一部店舗限定`, `首都圏のみ`. Empty when nothing.
  final String note;

  /// Where the maker sells it, as an ISO 3166-1 code (`TW`, `JP`): the
  /// same chain prints different figures for the same drink in each
  /// country. Empty for a food the user made.
  final String country;

  /// What the user calls one serving: `一碗`, `一片`, `一罐`. Optional,
  /// and separate from how much that is — what you call it and how much
  /// it weighs are two different things.
  final String servingLabel;

  /// How much one serving is, in [servingUnit]. Always positive.
  final double servingAmount;

  final ServingUnit servingUnit;

  /// Per serving, as the user entered them, decimals included: a label
  /// prints 6.7 g. Null is a figure nobody wrote down — a food whose
  /// label was never read is not a food with no calories in it. A meal
  /// logged from the food rounds once, when it is logged.
  final double? kcal;
  final double? proteinGrams;
  final double? carbGrams;
  final double? fatGrams;

  /// Fibre, part of the carbohydrate above; see [MealEvent.fibreGrams].
  final double? fibreGrams;

  /// Everything else known about one serving. Absent means unknown.
  final Nutrients nutrients;

  /// Whether this is eaten or drunk.
  final ConsumptionKind kind;

  /// What kind of numbers the figures above are.
  final NutrientValueType valueType;

  /// Where they came from, when they came from somewhere citable.
  /// Empty for a food somebody typed off the packet in front of them.
  final String sourceUrl;

  /// When that source was last read. A brand's table changes; a figure
  /// with no date is a figure nobody can check.
  final DateTime? checkedAt;

  /// Its volume is the cup it comes in, not the drink.
  ///
  /// Chains publish cup sizes — 7-ELEVEN's 480 mL is a 16 oz cup, ice
  /// included when iced — and say so. Such a volume names the size; it
  /// is never counted as fluid drunk.
  final bool isCupCapacity;

  /// Other words it answers to in search, space separated: a brand's
  /// other spellings (`Starbucks STARBUCKS` for 星巴克). Not shown.
  final String searchTerms;

  /// Which label column the figures were typed from.
  final CaffeineBasis caffeineBasis;

  /// The allergens the maker declares it contains; empty when it
  /// declares none, null when nobody said — not the same as none.
  final Set<Allergen>? allergens;

  /// The number under the package's barcode (EAN-13 in Taiwan and
  /// Japan); null when it is not known or the food has no package.
  final String? barcode;

  /// Shipped with the app, and read-only.
  ///
  /// The app replaces this data wholesale when it updates, which is only
  /// safe while nobody has edited it: an edit would be silently undone by
  /// the next release. Anyone wanting their own version makes their own
  /// food.
  final bool isBuiltIn;

  /// The food this is a size of, when it is one.
  final String? parentId;

  /// What the size is called: `Tall`, `大杯`. Empty for a food that is
  /// not a size of something else.
  final String sizeName;

  bool get isSize => parentId != null;

  /// Its name and, for a cup size, which size: `美式咖啡 Tall`. What a
  /// food is called where its maker is shown apart from it.
  String get nameWithSize => sizeName.isEmpty ? name : '$name $sizeName';

  /// `統一 雞胸肉` when it has a maker, otherwise just the name. A size
  /// says which one it is: `星巴克 美式咖啡 Tall`, and a line which it
  /// belongs to: `7-ELEVEN CITY CAFE 拿鐵咖啡`.
  String get displayName {
    final named = [
      brand,
      series,
      name,
    ].where((part) => part.isNotEmpty).join(' ');
    return sizeName.isEmpty ? named : '$named $sizeName';
  }

  FoodItem copyWith({
    String? id,
    String? name,
    String? brand,
    String? servingLabel,
    double? servingAmount,
    ServingUnit? servingUnit,
    double? kcal,
    double? proteinGrams,
    double? carbGrams,
    double? fatGrams,
    double? fibreGrams,
    Nutrients? nutrients,
    String? parentId,
    String? sizeName,
    ConsumptionKind? kind,
    NutrientValueType? valueType,
    String? sourceUrl,
    DateTime? checkedAt,
    bool? isBuiltIn,
    String? searchTerms,
    bool? isCupCapacity,
    String? series,
    String? note,
    String? country,
    CaffeineBasis? caffeineBasis,
    Set<Allergen>? allergens,
    String? barcode,
  }) => FoodItem(
    allergens: allergens ?? this.allergens,
    barcode: barcode ?? this.barcode,
    series: series ?? this.series,
    note: note ?? this.note,
    country: country ?? this.country,
    caffeineBasis: caffeineBasis ?? this.caffeineBasis,
    searchTerms: searchTerms ?? this.searchTerms,
    isCupCapacity: isCupCapacity ?? this.isCupCapacity,
    id: id ?? this.id,
    name: name ?? this.name,
    brand: brand ?? this.brand,
    servingLabel: servingLabel ?? this.servingLabel,
    servingAmount: servingAmount ?? this.servingAmount,
    servingUnit: servingUnit ?? this.servingUnit,
    kcal: kcal ?? this.kcal,
    proteinGrams: proteinGrams ?? this.proteinGrams,
    carbGrams: carbGrams ?? this.carbGrams,
    fatGrams: fatGrams ?? this.fatGrams,
    fibreGrams: fibreGrams ?? this.fibreGrams,
    nutrients: nutrients ?? this.nutrients,
    parentId: parentId ?? this.parentId,
    sizeName: sizeName ?? this.sizeName,
    kind: kind ?? this.kind,
    valueType: valueType ?? this.valueType,
    sourceUrl: sourceUrl ?? this.sourceUrl,
    checkedAt: checkedAt ?? this.checkedAt,
    isBuiltIn: isBuiltIn ?? this.isBuiltIn,
  );
}

/// What Taiwan's food allergen labelling rule (食品過敏原標示規定) has a
/// food declare it contains, in the order the rule lists them.
enum Allergen {
  crustacean,
  mango,
  peanut,
  milk,
  egg,
  treeNut,
  sesame,
  gluten,
  soy,
  fish,
  sulphite,
}

/// The unit a nutrient is counted in.
enum NutrientUnit {
  gram('g'),
  milligram('mg'),
  microgram('µg');

  const NutrientUnit(this.label);

  final String label;
}

/// Whose way of reading a label the day's totals and limits follow: a
/// user's own, apart from the language of the app and from the label
/// each food was printed with, which its own page keeps.
///
/// Each reads salt the way its labels print it and holds it to its own
/// health authority's limit for adults, not to a label's reference value.
enum NutritionConvention {
  /// Sodium in mg, under the Health Promotion Administration's 2,400 mg.
  taiwan({'TW'}),

  /// Salt equivalent in g, under Japan's DRIs (2025) by sex.
  japan({'JP'}),

  /// Sodium in mg, under the NASEM's 2,300 mg (2019).
  unitedStates({'US'}),

  /// Salt in g, under EFSA's 2.0 g of sodium (2019), 5 g of the EU's
  /// salt.
  europeanUnion({'EU'}),

  /// Sodium in mg, under the NHMRC's suggested dietary target of
  /// 2,000 mg (2017), for both countries under one food code.
  australiaNewZealand({'AU', 'NZ'}),

  /// Sodium in mg, under the 2020 KDRIs' 2,300 mg.
  korea({'KR'}),

  /// Salt in g, under the Chinese Dietary Guidelines' (2022) 5 g.
  china({'CN'}),

  /// Sodium in mg, under the NASEM's 2,300 mg (2019), as Health Canada
  /// uses it.
  canada({'CA'});

  const NutritionConvention(this.labelCountries);

  /// The countries whose labels this convention reads, as a food's
  /// [FoodItem.country] names them.
  final Set<String> labelCountries;

  /// The convention a label from [country] follows; null for a country
  /// none of them covers, or none at all.
  static NutritionConvention? ofLabel(String country) {
    for (final convention in values) {
      if (convention.labelCountries.contains(country)) return convention;
    }
    return null;
  }

  /// What salt is counted as: sodium, or the salt it makes.
  Nutrient get saltMeasure => switch (this) {
    japan || europeanUnion || china => Nutrient.saltEquivalent,
    _ => Nutrient.sodium,
  };

  /// The other measure, folded into [saltMeasure] rather than listed.
  Nutrient get otherSaltMeasure => saltMeasure == Nutrient.sodium
      ? Nutrient.saltEquivalent
      : Nutrient.sodium;

  /// Salt a day, at most, in [saltMeasure]'s unit, for an adult of [sex];
  /// Japan's differs by sex and takes the lower one when it is not known.
  double saltLimit(Sex? sex) => switch (this) {
    taiwan => 2400,
    japan => sex == Sex.male ? 7.5 : 6.5,
    unitedStates || korea || canada => 2300,
    europeanUnion || china => 5,
    australiaNewZealand => 2000,
  };

  /// Whether this convention's carbohydrate leaves out the fibre, as the
  /// EU's and Australia's and New Zealand's do; the app's own
  /// carbohydrate holds it.
  bool get countsAvailableCarb =>
      this == europeanUnion || this == australiaNewZealand;

  /// What a list of totals leaves out because another figure already
  /// holds it: the other measure of salt, and the carbohydrate less its
  /// fibre where that is the carbohydrate itself.
  Set<Nutrient> get foldedAway => {
    otherSaltMeasure,
    if (countsAvailableCarb) Nutrient.netCarb,
  };

  /// Whether the day works out the carbohydrate less its fibre: as 糖質
  /// the Japanese way, or as the carbohydrate itself where it leaves the
  /// fibre out.
  bool get readsAvailableCarb => this == japan || countsAvailableCarb;

  /// The part of the carbohydrate the day is read by: sugar, or, the
  /// Japanese way, 糖質, the carbohydrate less its fibre.
  Nutrient get carbPart => this == japan ? Nutrient.netCarb : Nutrient.sugar;
}

/// The nutrients this app can hold beyond the five it counts everywhere.
///
/// Energy, protein, carbohydrate, fat and fibre are not here: they are
/// fields on every food and every meal, because every record has them.
/// Everything below is held only when it is actually known, so a nutrient
/// missing from a food means nobody wrote it down — not zero.
///
/// The order is the order the label prints them in, then the DRI groups.
enum Nutrient {
  // What Taiwan's packaging law requires beyond the five above.
  saturatedFat(NutrientUnit.gram),
  transFat(NutrientUnit.gram),
  sugar(NutrientUnit.gram),
  sodium(NutrientUnit.milligram),

  // What a Japanese label prints instead, kept as printed: 糖質 is
  // carbohydrate less fibre, not sugar, and salt is not converted to
  // sodium.
  netCarb(NutrientUnit.gram),
  saltEquivalent(NutrientUnit.gram),

  // Energy the three macronutrients leave out: the sugar alcohols a
  // label may list inside its carbohydrate, and a drink's alcohol.
  polyols(NutrientUnit.gram),
  alcohol(NutrientUnit.gram),

  // Commonly declared voluntarily.
  cholesterol(NutrientUnit.milligram),
  caffeine(NutrientUnit.milligram),

  // The amino acids a protein drink's label lists under its protein:
  // the essential ones' total, the branched-chain ones' total and each
  // of the three, and glutamine.
  essentialAminoAcids(NutrientUnit.milligram),
  bcaa(NutrientUnit.milligram),
  leucine(NutrientUnit.milligram),
  isoleucine(NutrientUnit.milligram),
  valine(NutrientUnit.milligram),
  glutamine(NutrientUnit.milligram),

  // Minerals in the DRIs.
  calcium(NutrientUnit.milligram),
  phosphorus(NutrientUnit.milligram),
  magnesium(NutrientUnit.milligram),
  iron(NutrientUnit.milligram),
  zinc(NutrientUnit.milligram),
  potassium(NutrientUnit.milligram),
  iodine(NutrientUnit.microgram),
  selenium(NutrientUnit.microgram),

  // Vitamins in the DRIs.
  vitaminA(NutrientUnit.microgram),
  vitaminD(NutrientUnit.microgram),
  vitaminE(NutrientUnit.milligram),
  vitaminK(NutrientUnit.microgram),
  vitaminC(NutrientUnit.milligram),
  vitaminB1(NutrientUnit.milligram),
  vitaminB2(NutrientUnit.milligram),
  niacin(NutrientUnit.milligram),
  vitaminB6(NutrientUnit.milligram),
  vitaminB12(NutrientUnit.microgram),
  folate(NutrientUnit.microgram),
  pantothenicAcid(NutrientUnit.milligram),
  biotin(NutrientUnit.microgram);

  const Nutrient(this.unit);
  final NutrientUnit unit;

  /// Written as `12.4 mg`.
  String format(double amount) => '${formatAmount(amount)} ${unit.label}';
}

/// The key a model's answer gives [nutrient] under: its name in
/// snake_case and its unit, `saturated_fat_g`, `sodium_mg`,
/// `vitamin_d_ug`, the way the label's own keys read, so the unit is
/// never a guess.
String nutrientAnswerKey(Nutrient nutrient) =>
    '${nutrient.name.replaceAllMapped(RegExp('[A-Z]'), (match) => '_${match[0]!.toLowerCase()}')}_${switch (nutrient.unit) {
      NutrientUnit.gram => 'g',
      NutrientUnit.milligram => 'mg',
      NutrientUnit.microgram => 'ug',
    }}';

/// What is known about a food's nutrients, per serving.
///
/// A nutrient absent from the map is one nobody recorded. It is never
/// read as zero: a label that prints `0 g` of fat only means under half a
/// gram, and a label that prints nothing at all means nothing at all.
typedef Nutrients = Map<Nutrient, double>;
