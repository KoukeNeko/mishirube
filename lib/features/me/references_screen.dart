import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../shared/widgets/widgets.dart';

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
        title: '開啟連結',
        message: url,
        actions: [
          DialogAction(
            label: '開啟',
            tone: DialogTone.primary,
            onTap: () => Navigator.of(context).pop(true),
          ),
          DialogAction(label: '取消', onTap: () => Navigator.of(context).pop()),
        ],
      ),
    );
    if (isGoing != true) return;
    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      showToast(context, '無法開啟連結', kind: ToastKind.warning);
    }
  }

  @override
  Widget build(BuildContext context) => DetailPage(
    appBar: const PageAppBar(title: '文獻來源'),
    children: [
      for (final (feature, references) in _references)
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

const List<(String, List<_Reference>)> _references = [
  (
    '每日熱量與營養素目標',
    [
      (
        citation: 'Mifflin, M. D., St Jeor, S. T., Hill, L. A., Scott, B. J., Daugherty, S. A., & Koh, Y. O. (1990). A new predictive equation for resting energy expenditure in healthy individuals. The American Journal of Clinical Nutrition, 51(2), 241–247.',
        use: '基礎代謝的估算公式',
        url: 'https://doi.org/10.1093/ajcn/51.2.241',
      ),
      (
        citation: 'Frankenfield, D., Roth-Yousey, L., & Compher, C. (2005). Comparison of predictive equations for resting metabolic rate in healthy nonobese and obese adults: A systematic review. Journal of the American Dietetic Association, 105(5), 775–789.',
        use: '健康成人以 Mifflin-St Jeor 估算最接近實測',
        url: 'https://doi.org/10.1016/j.jada.2005.02.005',
      ),
      (
        citation: 'Food and Agriculture Organization of the United Nations. (2004). Human energy requirements: Report of a joint FAO/WHO/UNU expert consultation (FAO Food and Nutrition Technical Report Series No. 1).',
        use: '活動量（身體活動程度）的分級',
        url: 'https://www.fao.org/4/y5686e/y5686e07.htm',
      ),
      (
        citation: 'Jäger, R., Kerksick, C. M., Campbell, B. I., Cribb, P. J., Wells, S. D., Skwiat, T. M., Purpura, M., Ziegenfuss, T. N., Ferrando, A. A., Arent, S. M., Smith-Ryan, A. E., Stout, J. R., Arciero, P. J., Ormsbee, M. J., Taylor, L. W., Wilborn, C. D., Kalman, D. S., Kreider, R. B., Willoughby, D. S., . . . Antonio, J. (2017). International Society of Sports Nutrition position stand: Protein and exercise. Journal of the International Society of Sports Nutrition, 14, Article 20.',
        use: '蛋白質目標每公斤 1.6 g（建議範圍 1.4–2.0 g）',
        url: 'https://doi.org/10.1186/s12970-017-0177-8',
      ),
      (
        citation: 'Institute of Medicine. (2005). Dietary reference intakes for energy, carbohydrate, fiber, fat, fatty acids, cholesterol, protein, and amino acids. The National Academies Press.',
        use: '膳食纖維每 1,000 kcal 14 g、脂肪占熱量 20–35%',
        url: 'https://doi.org/10.17226/10490',
      ),
      (
        citation: '衛生福利部國民健康署（2026年1月23日）。減鹽秘笈手冊。',
        use: '成人每日鈉攝取上限 2,400 mg',
        url: 'https://www.hpa.gov.tw/Pages/Detail.aspx?nodeid=1161&pid=6648',
      ),
    ],
  ),
  (
    '咖啡因',
    [
      (
        citation: 'Institute of Medicine. (2001). Pharmacology of caffeine. In Caffeine for the sustainment of mental task performance: Formulations for military operations. National Academies Press.',
        use: '殘留咖啡因依半衰期 5 小時推算',
        url: 'https://doi.org/10.17226/10219',
      ),
      (
        citation: 'Liu, X., & Xu, S. (2026). Unraveling the complexities of caffeine: Metabolism, genetics, evolution, and health. Hereditas, 163(1), Article 36.',
        use: '半衰期因人而異，推算值不是量測',
        url: 'https://doi.org/10.1186/s41065-026-00648-z',
      ),
      (
        citation: 'Gardiner, C. L., Weakley, J., Burke, L. M., Fernandez, F., Johnston, R. D., Leota, J., Russell, S., Munteanu, G., Townshend, A., & Halson, S. L. (2025). Dose and timing effects of caffeine on subsequent sleep: A randomized clinical crossover trial. Sleep, 48(4), Article zsae230.',
        use: '不設就寢前的咖啡因門檻',
        url: 'https://doi.org/10.1093/sleep/zsae230',
      ),
    ],
  ),
  (
    '睡眠債',
    [
      (
        citation: 'Watson, N. F., Badr, M. S., Belenky, G., Bliwise, D. L., Buxton, O. M., Buysse, D., Dinges, D. F., Gangwisch, J., Grandner, M. A., Kushida, C., Malhotra, R. K., Martin, J. L., Patel, S. R., Quan, S. F., & Tasali, E. (2015). Recommended amount of sleep for a healthy adult: A joint consensus statement of the American Academy of Sleep Medicine and Sleep Research Society. Journal of Clinical Sleep Medicine, 11(6), 591–592.',
        use: '未設定目標時以每晚 8 小時計（共識為 7 小時以上）',
        url: 'https://doi.org/10.5664/jcsm.4758',
      ),
      (
        citation: 'Van Dongen, H. P. A., Maislin, G., Mullington, J. M., & Dinges, D. F. (2003). The cumulative cost of additional wakefulness: Dose-response effects on neurobehavioral functions and sleep physiology from chronic sleep restriction and total sleep deprivation. Sleep, 26(2), 117–126.',
        use: '少睡的影響在 14 天內持續累積',
        url: 'https://doi.org/10.1093/sleep/26.2.117',
      ),
      (
        citation: 'Banks, S., Van Dongen, H. P. A., Maislin, G., & Dinges, D. F. (2010). Neurobehavioral dynamics following chronic sleep restriction: Dose-response effects of one night for recovery. Sleep, 33(8), 1013–1026.',
        use: '多睡不以一比一抵銷少睡',
        url: 'https://doi.org/10.1093/sleep/33.8.1013',
      ),
      (
        citation: 'Guzzetti, J. R., & Banks, S. (2023). Dynamics of recovery sleep from chronic sleep restriction. Sleep Advances, 4(1), Article zpac044.',
        use: '恢復沒有公認的速率，不設衰減',
        url: 'https://doi.org/10.1093/sleepadvances/zpac044',
      ),
    ],
  ),
  (
    '訓練與趨勢',
    [
      (
        citation: 'Epley, B. (1985). Poundage chart. In Boyd Epley workout. Body Enterprises.',
        use: '估計最大重量（1RM）的公式',
        url: null,
      ),
      (
        citation: 'Reynolds, J. M., Gordon, T. J., & Robergs, R. A. (2006). Prediction of one repetition maximum strength from multiple repetition maximum testing and anthropometry. Journal of Strength and Conditioning Research, 20(3), 584–592.',
        use: '超過 10 下不估計；5 下最準',
        url: 'https://doi.org/10.1519/R-15304.1',
      ),
      (
        citation: 'Mayhew, J. L., Hill, S. P., Thompson, M. D., Johnson, E. C., & Wheeler, L. (2007). Using absolute and relative muscle endurance to estimate maximal strength in young athletes. International Journal of Sports Physiology and Performance, 2(3), 305–314.',
        use: '7–10 下的估計仍準確',
        url: 'https://doi.org/10.1123/ijspp.2.3.305',
      ),
      (
        citation: 'Nuzzo, J. L., Pinto, M. D., Nosaka, K., & Steele, J. (2024). Maximal number of repetitions at percentages of the one repetition maximum: A meta-regression and moderator analysis of sex, age, training status, and exercise. Sports Medicine, 54(2), 303–321.',
        use: '次數越多，個人與動作之間的差異越大',
        url: 'https://doi.org/10.1007/s40279-023-01937-7',
      ),
      (
        citation: 'Schoenfeld, B. J., Ogborn, D., & Krieger, J. W. (2017). Dose-response relationship between weekly resistance training volume and increases in muscle mass: A systematic review and meta-analysis. Journal of Sports Sciences, 35(11), 1073–1082.',
        use: '每肌群每週 10 組以上的組數劑量反應',
        url: 'https://doi.org/10.1080/02640414.2016.1210197',
      ),
      (
        citation: 'Morton, R. W., Murphy, K. T., McKellar, S. R., Schoenfeld, B. J., Henselmans, M., Helms, E., Aragon, A. A., Devries, M. C., Banfield, L., Krieger, J. W., & Phillips, S. M. (2018). A systematic review, meta-analysis and meta-regression of the effect of protein supplementation on resistance training-induced gains in muscle mass and strength in healthy adults. British Journal of Sports Medicine, 52(6), 376–384.',
        use: '蛋白質每公斤 1.6 g 後增益不再明顯',
        url: 'https://doi.org/10.1136/bjsports-2017-097608',
      ),
    ],
  ),
  (
    '運動心率區間',
    [
      (
        citation: 'Tanaka, H., Monahan, K. D., & Seals, D. R. (2001). Age-predicted maximal heart rate revisited. Journal of the American College of Cardiology, 37(1), 153–156.',
        use: '最大心率以 208 − 0.7 × 年齡估算',
        url: 'https://doi.org/10.1016/s0735-1097(00)01054-8',
      ),
      (
        citation: 'Karvonen, M. J., Kentala, E., & Mustala, O. (1957). The effects of training on heart rate; a longitudinal study. Annales Medicinae Experimentalis et Biologiae Fenniae, 35(3), 307–315.',
        use: '有安靜心率時以心率儲備劃分區間',
        url: 'https://pubmed.ncbi.nlm.nih.gov/13470504/',
      ),
    ],
  ),
  (
    '身體',
    [
      (
        citation: '衛生福利部國民健康署（2025年9月11日）。成人健康體位標準。',
        use: 'BMI 過輕、正常、過重、肥胖的分級',
        url: 'https://www.hpa.gov.tw/Pages/Detail.aspx?nodeid=542&pid=9737&sid=710',
      ),
      (
        citation: 'Kouri, E. M., Pope, H. G., Jr., Katz, D. L., & Oliva, P. (1995). Fat-free mass index in users and nonusers of anabolic-androgenic steroids. Clinical Journal of Sport Medicine, 5(4), 223–228.',
        use: '去脂體重指數（FFMI）的定義',
        url: 'https://doi.org/10.1097/00042752-199510000-00003',
      ),
    ],
  ),
];
