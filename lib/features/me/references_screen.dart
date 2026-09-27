import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../shared/widgets/widgets.dart';
import '../../l10n/l10n.dart';

/// The studies and official figures the app's calculations rest on,
/// grouped by the feature that uses them, cited in APA (7th edition)
/// style; the link is kept for tapping, not printed. Each says what it is used for;
/// tapping one offers to open its link.
///
/// Only what the code actually applies is listed here: add a reference
/// with the rule that uses it, and remove it with the rule.
class ReferencesScreen extends StatelessWidget {
  const ReferencesScreen({super.key});

  /// Leaving the app is the user's call: the link is shown first, then
  /// opened in the default browser.
  Future<void> _open(BuildContext context, String url) async {
    final isGoing = await showAppDialog<bool>(
      context,
      AppDialog(
        title: context.l10n.openLink,
        message: url,
        actions: [
          DialogAction(
            label: context.l10n.openAction,
            tone: DialogTone.primary,
            onTap: () => Navigator.of(context).pop(true),
          ),
          DialogAction(
            label: context.l10n.commonCancel,
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
    if (isGoing != true) return;
    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      showToast(context, context.l10n.cannotOpenLink, kind: ToastKind.warning);
    }
  }

  @override
  Widget build(BuildContext context) => DetailPage(
    appBar: PageAppBar(title: context.l10n.referencesTitle),
    children: [
      for (final (feature, references) in _references(context.l10n))
        PageSection(
          label: feature,
          children: [
            Gutter(
              child: GroupedCard(
                children: [
                  for (final reference in references)
                    NavRow(
                      title: reference.citation,
                      subtitle: reference.use,
                      showChevron: false,
                      onTap: switch (reference.url) {
                        final url? => () => _open(context, url),
                        null => null,
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
    ],
  );
}

typedef _Reference = ({String citation, String use, String? url});

List<(String, List<_Reference>)> _references(AppLocalizations l10n) => [
  (
    l10n.refSectionTargets,
    [
      (
        citation: 'Mifflin, M. D., St Jeor, S. T., Hill, L. A., Scott, B. J., Daugherty, S. A., & Koh, Y. O. (1990). A new predictive equation for resting energy expenditure in healthy individuals. The American Journal of Clinical Nutrition, 51(2), 241–247.',
        use: l10n.refUse01,
        url: 'https://doi.org/10.1093/ajcn/51.2.241',
      ),
      (
        citation: 'Frankenfield, D., Roth-Yousey, L., & Compher, C. (2005). Comparison of predictive equations for resting metabolic rate in healthy nonobese and obese adults: A systematic review. Journal of the American Dietetic Association, 105(5), 775–789.',
        use: l10n.refUse02,
        url: 'https://doi.org/10.1016/j.jada.2005.02.005',
      ),
      (
        citation: 'Food and Agriculture Organization of the United Nations. (2004). Human energy requirements: Report of a joint FAO/WHO/UNU expert consultation (FAO Food and Nutrition Technical Report Series No. 1).',
        use: l10n.refUse03,
        url: 'https://www.fao.org/4/y5686e/y5686e07.htm',
      ),
      (
        citation: 'Jäger, R., Kerksick, C. M., Campbell, B. I., Cribb, P. J., Wells, S. D., Skwiat, T. M., Purpura, M., Ziegenfuss, T. N., Ferrando, A. A., Arent, S. M., Smith-Ryan, A. E., Stout, J. R., Arciero, P. J., Ormsbee, M. J., Taylor, L. W., Wilborn, C. D., Kalman, D. S., Kreider, R. B., Willoughby, D. S., . . . Antonio, J. (2017). International Society of Sports Nutrition position stand: Protein and exercise. Journal of the International Society of Sports Nutrition, 14, Article 20.',
        use: l10n.refUse04,
        url: 'https://doi.org/10.1186/s12970-017-0177-8',
      ),
      (
        citation: 'Helms, E. R., Aragon, A. A., & Fitschen, P. J. (2014). Evidence-based recommendations for natural bodybuilding contest preparation: Nutrition and supplementation. Journal of the International Society of Sports Nutrition, 11, Article 20.',
        use: l10n.refUse05,
        url: 'https://doi.org/10.1186/1550-2783-11-20',
      ),
      (
        citation: 'Longland, T. M., Oikawa, S. Y., Mitchell, C. J., Devries, M. C., & Phillips, S. M. (2016). Higher compared with lower dietary protein during an energy deficit combined with intense exercise promotes greater lean mass gain and fat mass loss: A randomized trial. The American Journal of Clinical Nutrition, 103(3), 738–746.',
        use: l10n.refUse06,
        url: 'https://doi.org/10.3945/ajcn.115.119339',
      ),
      (
        citation: 'Garthe, I., Raastad, T., Refsnes, P. E., Koivisto, A., & Sundgot-Borgen, J. (2011). Effect of two different weight-loss rates on body composition and strength and power-related performance in elite athletes. International Journal of Sport Nutrition and Exercise Metabolism, 21(2), 97–104.',
        use: l10n.refUse07,
        url: 'https://doi.org/10.1123/ijsnem.21.2.97',
      ),
      (
        citation: 'Helms, E. R., Spence, A.-J., Sousa, C., Kreiger, J., Taylor, S., Oranchuk, D. J., Dieter, B. P., & Watkins, C. M. (2023). Effect of small and large energy surpluses on strength, muscle, and skinfold thickness in resistance-trained individuals: A parallel groups design. Sports Medicine – Open, 9(1), Article 102.',
        use: l10n.refUse08,
        url: 'https://doi.org/10.1186/s40798-023-00651-y',
      ),
      (
        citation: 'Hall, K. D. (2008). What is the required energy deficit per unit weight loss? International Journal of Obesity, 32(3), 573–576.',
        use: l10n.refUse09,
        url: 'https://doi.org/10.1038/sj.ijo.0803720',
      ),
      (
        citation: 'Institute of Medicine. (2005). Dietary reference intakes for energy, carbohydrate, fiber, fat, fatty acids, cholesterol, protein, and amino acids. The National Academies Press.',
        use: l10n.refUse10,
        url: 'https://doi.org/10.17226/10490',
      ),
    ],
  ),
  (
    l10n.refSectionLabels,
    [
      (
        // l10n-ignore: cited in its own language.
        citation: '衛生福利部國民健康署（2026年1月23日）。減鹽秘笈手冊。',
        use: l10n.refUse11,
        url: 'https://www.hpa.gov.tw/Pages/Detail.aspx?nodeid=1161&pid=6648',
      ),
      (
        // l10n-ignore: cited in its own language.
        citation: '厚生労働省（2024）。「日本人の食事摂取基準（2025年版）」策定検討会報告書。',
        use: l10n.refUse12,
        url: 'https://www.mhlw.go.jp/stf/newpage_44138.html',
      ),
      (
        // l10n-ignore: cited in its own language.
        citation: '食品表示基準（平成27年内閣府令第10号）。',
        use: l10n.refUse13,
        url: 'https://laws.e-gov.go.jp/law/427M60000002010/',
      ),
      (
        citation: 'National Academies of Sciences, Engineering, and Medicine. (2019). Dietary reference intakes for sodium and potassium. The National Academies Press.',
        use: l10n.refUse14,
        url: 'https://doi.org/10.17226/25353',
      ),
      (
        citation: 'EFSA Panel on Nutrition, Novel Foods and Food Allergens. (2019). Dietary reference values for sodium. EFSA Journal, 17(9), Article 5778.',
        use: l10n.refUse15,
        url: 'https://doi.org/10.2903/j.efsa.2019.5778',
      ),
      (
        citation: 'Regulation (EU) No 1169/2011 of the European Parliament and of the Council of 25 October 2011 on the provision of food information to consumers. Official Journal of the European Union, L 304, 18–63.',
        use: l10n.refUse16,
        url: 'https://eur-lex.europa.eu/eli/reg/2011/1169/oj',
      ),
      (
        citation: 'National Health and Medical Research Council. (2017). Australian and New Zealand nutrient reference values for sodium.',
        use: l10n.refUse17,
        url: 'https://www.eatforhealth.gov.au/nutrient-reference-values/nutrients/sodium',
      ),
      (
        citation: 'Food Standards Australia New Zealand. (2015). Australia New Zealand Food Standards Code – Standard 1.2.8 – Nutrition information requirements.',
        use: l10n.refUse18,
        url: 'https://www.legislation.gov.au/F2015L00395/latest/text',
      ),
      (
        // l10n-ignore: cited in its own language.
        citation: '보건복지부, 한국영양학회. (2020). 2020 한국인 영양소 섭취기준.',
        use: l10n.refUse19,
        url: 'https://www.kns.or.kr/FileRoom/FileRoom_view.asp?idx=108&BoardID=Kdr',
      ),
      (
        // l10n-ignore: cited in its own language.
        citation: '中国营养学会（2022）。中国居民膳食指南（2022）。人民卫生出版社。',
        use: l10n.refUse20,
        url: 'http://dg.cnsoc.org/article/04/ApX3_ozGTmSoqQaFFh5z_Q.html',
      ),
    ],
  ),
  (
    l10n.refSectionCaffeine,
    [
      (
        citation: 'Institute of Medicine. (2001). Pharmacology of caffeine. In Caffeine for the sustainment of mental task performance: Formulations for military operations. National Academies Press.',
        use: l10n.refUse21,
        url: 'https://doi.org/10.17226/10219',
      ),
      (
        citation: 'Liu, X., & Xu, S. (2026). Unraveling the complexities of caffeine: Metabolism, genetics, evolution, and health. Hereditas, 163(1), Article 36.',
        use: l10n.refUse22,
        url: 'https://doi.org/10.1186/s41065-026-00648-z',
      ),
      (
        citation: 'Gardiner, C. L., Weakley, J., Burke, L. M., Fernandez, F., Johnston, R. D., Leota, J., Russell, S., Munteanu, G., Townshend, A., & Halson, S. L. (2025). Dose and timing effects of caffeine on subsequent sleep: A randomized clinical crossover trial. Sleep, 48(4), Article zsae230.',
        use: l10n.refUse23,
        url: 'https://doi.org/10.1093/sleep/zsae230',
      ),
    ],
  ),
  (
    l10n.refSectionSleepDebt,
    [
      (
        citation: 'Watson, N. F., Badr, M. S., Belenky, G., Bliwise, D. L., Buxton, O. M., Buysse, D., Dinges, D. F., Gangwisch, J., Grandner, M. A., Kushida, C., Malhotra, R. K., Martin, J. L., Patel, S. R., Quan, S. F., & Tasali, E. (2015). Recommended amount of sleep for a healthy adult: A joint consensus statement of the American Academy of Sleep Medicine and Sleep Research Society. Journal of Clinical Sleep Medicine, 11(6), 591–592.',
        use: l10n.refUse24,
        url: 'https://doi.org/10.5664/jcsm.4758',
      ),
      (
        citation: 'Van Dongen, H. P. A., Maislin, G., Mullington, J. M., & Dinges, D. F. (2003). The cumulative cost of additional wakefulness: Dose-response effects on neurobehavioral functions and sleep physiology from chronic sleep restriction and total sleep deprivation. Sleep, 26(2), 117–126.',
        use: l10n.refUse25,
        url: 'https://doi.org/10.1093/sleep/26.2.117',
      ),
      (
        citation: 'Banks, S., Van Dongen, H. P. A., Maislin, G., & Dinges, D. F. (2010). Neurobehavioral dynamics following chronic sleep restriction: Dose-response effects of one night for recovery. Sleep, 33(8), 1013–1026.',
        use: l10n.refUse26,
        url: 'https://doi.org/10.1093/sleep/33.8.1013',
      ),
      (
        citation: 'Guzzetti, J. R., & Banks, S. (2023). Dynamics of recovery sleep from chronic sleep restriction. Sleep Advances, 4(1), Article zpac044.',
        use: l10n.refUse27,
        url: 'https://doi.org/10.1093/sleepadvances/zpac044',
      ),
    ],
  ),
  (
    l10n.refSectionTraining,
    [
      (
        citation: 'Epley, B. (1985). Poundage chart. In Boyd Epley workout. Body Enterprises.',
        use: l10n.refUse28,
        url: null,
      ),
      (
        citation: 'Reynolds, J. M., Gordon, T. J., & Robergs, R. A. (2006). Prediction of one repetition maximum strength from multiple repetition maximum testing and anthropometry. Journal of Strength and Conditioning Research, 20(3), 584–592.',
        use: l10n.refUse29,
        url: 'https://doi.org/10.1519/R-15304.1',
      ),
      (
        citation: 'Mayhew, J. L., Hill, S. P., Thompson, M. D., Johnson, E. C., & Wheeler, L. (2007). Using absolute and relative muscle endurance to estimate maximal strength in young athletes. International Journal of Sports Physiology and Performance, 2(3), 305–314.',
        use: l10n.refUse30,
        url: 'https://doi.org/10.1123/ijspp.2.3.305',
      ),
      (
        citation: 'Nuzzo, J. L., Pinto, M. D., Nosaka, K., & Steele, J. (2024). Maximal number of repetitions at percentages of the one repetition maximum: A meta-regression and moderator analysis of sex, age, training status, and exercise. Sports Medicine, 54(2), 303–321.',
        use: l10n.refUse31,
        url: 'https://doi.org/10.1007/s40279-023-01937-7',
      ),
      (
        citation: 'Schoenfeld, B. J., Ogborn, D., & Krieger, J. W. (2017). Dose-response relationship between weekly resistance training volume and increases in muscle mass: A systematic review and meta-analysis. Journal of Sports Sciences, 35(11), 1073–1082.',
        use: l10n.refUse32,
        url: 'https://doi.org/10.1080/02640414.2016.1210197',
      ),
      (
        citation: 'Morton, R. W., Murphy, K. T., McKellar, S. R., Schoenfeld, B. J., Henselmans, M., Helms, E., Aragon, A. A., Devries, M. C., Banfield, L., Krieger, J. W., & Phillips, S. M. (2018). A systematic review, meta-analysis and meta-regression of the effect of protein supplementation on resistance training-induced gains in muscle mass and strength in healthy adults. British Journal of Sports Medicine, 52(6), 376–384.',
        use: l10n.refUse33,
        url: 'https://doi.org/10.1136/bjsports-2017-097608',
      ),
    ],
  ),
  (
    l10n.refSectionHeartZones,
    [
      (
        citation: 'Tanaka, H., Monahan, K. D., & Seals, D. R. (2001). Age-predicted maximal heart rate revisited. Journal of the American College of Cardiology, 37(1), 153–156.',
        use: l10n.refUse34,
        url: 'https://doi.org/10.1016/s0735-1097(00)01054-8',
      ),
      (
        citation: 'Karvonen, M. J., Kentala, E., & Mustala, O. (1957). The effects of training on heart rate; a longitudinal study. Annales Medicinae Experimentalis et Biologiae Fenniae, 35(3), 307–315.',
        use: l10n.refUse35,
        url: 'https://pubmed.ncbi.nlm.nih.gov/13470504/',
      ),
    ],
  ),
  (
    l10n.refSectionBody,
    [
      (
        // l10n-ignore: cited in its own language.
        citation: '衛生福利部國民健康署（2025年9月11日）。成人健康體位標準。',
        use: l10n.refUse36,
        url: 'https://www.hpa.gov.tw/Pages/Detail.aspx?nodeid=542&pid=9737&sid=710',
      ),
      (
        citation: 'Kouri, E. M., Pope, H. G., Jr., Katz, D. L., & Oliva, P. (1995). Fat-free mass index in users and nonusers of anabolic-androgenic steroids. Clinical Journal of Sport Medicine, 5(4), 223–228.',
        use: l10n.refUse37,
        url: 'https://doi.org/10.1097/00042752-199510000-00003',
      ),
    ],
  ),
];
