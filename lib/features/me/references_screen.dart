import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../shared/widgets/widgets.dart';

/// The studies and official figures the app's calculations rest on,
/// grouped by the feature that uses them. Each says what it is used for;
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
                      detail: reference.url,
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
        citation: 'Mifflin MD, St Jeor ST, Hill LA, Scott BJ, Daugherty SA, Koh YO. A new predictive equation for resting energy expenditure in healthy individuals. Am J Clin Nutr. 1990;51(2):241-7.',
        use: '基礎代謝的估算公式',
        url: 'https://pubmed.ncbi.nlm.nih.gov/2305711/',
      ),
      (
        citation: 'Frankenfield D, Roth-Yousey L, Compher C. Comparison of predictive equations for resting metabolic rate in healthy nonobese and obese adults: a systematic review. J Am Diet Assoc. 2005;105(5):775-89.',
        use: '健康成人以 Mifflin-St Jeor 估算最接近實測',
        url: 'https://pubmed.ncbi.nlm.nih.gov/15883556/',
      ),
      (
        citation: 'FAO/WHO/UNU. Human energy requirements: report of a Joint FAO/WHO/UNU Expert Consultation. Rome: FAO; 2004.',
        use: '活動量（身體活動程度）的分級',
        url: 'https://www.fao.org/4/y5686e/y5686e07.htm',
      ),
      (
        citation: 'Jäger R, Kerksick CM, Campbell BI, Cribb PJ, Wells SD, Skwiat TM, et al. International Society of Sports Nutrition Position Stand: protein and exercise. J Int Soc Sports Nutr. 2017;14:20.',
        use: '蛋白質目標每公斤 1.6 g（建議範圍 1.4–2.0 g）',
        url: 'https://pubmed.ncbi.nlm.nih.gov/28642676/',
      ),
      (
        citation: 'Institute of Medicine. Dietary Reference Intakes for Energy, Carbohydrate, Fiber, Fat, Fatty Acids, Cholesterol, Protein, and Amino Acids. Washington, DC: The National Academies Press; 2005.',
        use: '膳食纖維每 1,000 kcal 14 g、脂肪占熱量 20–35%',
        url: 'https://nap.nationalacademies.org/read/10490',
      ),
      (
        citation: '衛生福利部國民健康署。減鹽秘笈手冊。',
        use: '成人每日鈉攝取上限 2,400 mg',
        url: 'https://www.hpa.gov.tw/Pages/Detail.aspx?nodeid=1161&pid=6648',
      ),
    ],
  ),
  (
    '咖啡因',
    [
      (
        citation: 'Institute of Medicine. Pharmacology of Caffeine. In: Caffeine for the Sustainment of Mental Task Performance: Formulations for Military Operations. Washington, DC: National Academies Press; 2001.',
        use: '殘留咖啡因依半衰期 5 小時推算',
        url: 'https://www.ncbi.nlm.nih.gov/books/NBK223808/',
      ),
      (
        citation: 'Liu X, Xu S. Unraveling the complexities of caffeine: metabolism, genetics, evolution, and health. Hereditas. 2026;163(1):36.',
        use: '半衰期因人而異，推算值不是量測',
        url: 'https://pubmed.ncbi.nlm.nih.gov/41622288/',
      ),
      (
        citation: 'Gardiner CL, Weakley J, Burke LM, Fernandez F, Johnston RD, Leota J, et al. Dose and timing effects of caffeine on subsequent sleep: a randomized clinical crossover trial. Sleep. 2025;48(4):zsae230.',
        use: '不設就寢前的咖啡因門檻',
        url: 'https://pubmed.ncbi.nlm.nih.gov/39377163/',
      ),
    ],
  ),
  (
    '睡眠債',
    [
      (
        citation: 'Consensus Conference Panel, Watson NF, Badr MS, Belenky G, Bliwise DL, Buxton OM, et al. Recommended Amount of Sleep for a Healthy Adult: A Joint Consensus Statement of the American Academy of Sleep Medicine and Sleep Research Society. J Clin Sleep Med. 2015;11(6):591-2.',
        use: '未設定目標時以每晚 8 小時計（共識為 7 小時以上）',
        url: 'https://pubmed.ncbi.nlm.nih.gov/25979105/',
      ),
      (
        citation: 'Van Dongen HP, Maislin G, Mullington JM, Dinges DF. The cumulative cost of additional wakefulness: dose-response effects on neurobehavioral functions and sleep physiology from chronic sleep restriction and total sleep deprivation. Sleep. 2003;26(2):117-26.',
        use: '少睡的影響在 14 天內持續累積',
        url: 'https://pubmed.ncbi.nlm.nih.gov/12683469/',
      ),
      (
        citation: 'Banks S, Van Dongen HP, Maislin G, Dinges DF. Neurobehavioral dynamics following chronic sleep restriction: dose-response effects of one night for recovery. Sleep. 2010;33(8):1013-26.',
        use: '多睡不以一比一抵銷少睡',
        url: 'https://pubmed.ncbi.nlm.nih.gov/20815182/',
      ),
      (
        citation: 'Guzzetti JR, Banks S. Dynamics of recovery sleep from chronic sleep restriction. Sleep Adv. 2023;4(1):zpac044.',
        use: '恢復沒有公認的速率，不設衰減',
        url: 'https://pubmed.ncbi.nlm.nih.gov/37193276/',
      ),
    ],
  ),
  (
    '訓練與趨勢',
    [
      (
        citation: 'Epley B. Poundage Chart. In: Boyd Epley Workout. Lincoln, NE: Body Enterprises; 1985.',
        use: '估計最大重量（1RM），超過 12 下不估計',
        url: null,
      ),
      (
        citation: 'Schoenfeld BJ, Ogborn D, Krieger JW. Dose-response relationship between weekly resistance training volume and increases in muscle mass: a systematic review and meta-analysis. J Sports Sci. 2017;35(11):1073-1082.',
        use: '每肌群每週 10 組以上的組數劑量反應',
        url: 'https://pubmed.ncbi.nlm.nih.gov/27433992/',
      ),
      (
        citation: 'Morton RW, Murphy KT, McKellar SR, Schoenfeld BJ, Henselmans M, Helms E, et al. A systematic review, meta-analysis and meta-regression of the effect of protein supplementation on resistance training-induced gains in muscle mass and strength in healthy adults. Br J Sports Med. 2018;52(6):376-384.',
        use: '蛋白質每公斤 1.6 g 後增益不再明顯',
        url: 'https://pubmed.ncbi.nlm.nih.gov/28698222/',
      ),
    ],
  ),
  (
    '運動心率區間',
    [
      (
        citation: 'Tanaka H, Monahan KD, Seals DR. Age-predicted maximal heart rate revisited. J Am Coll Cardiol. 2001;37(1):153-6.',
        use: '最大心率以 208 − 0.7 × 年齡估算',
        url: 'https://pubmed.ncbi.nlm.nih.gov/11153730/',
      ),
      (
        citation: 'Karvonen MJ, Kentala E, Mustala O. The effects of training on heart rate; a longitudinal study. Ann Med Exp Biol Fenn. 1957;35(3):307-15.',
        use: '有安靜心率時以心率儲備劃分區間',
        url: 'https://pubmed.ncbi.nlm.nih.gov/13470504/',
      ),
    ],
  ),
  (
    '身體',
    [
      (
        citation: '衛生福利部國民健康署。成人健康體位標準。',
        use: 'BMI 過輕、正常、過重、肥胖的分級',
        url: 'https://www.hpa.gov.tw/Pages/Detail.aspx?nodeid=542&pid=9737&sid=710',
      ),
      (
        citation: 'Kouri EM, Pope HG Jr, Katz DL, Oliva P. Fat-free mass index in users and nonusers of anabolic-androgenic steroids. Clin J Sport Med. 1995;5(4):223-8.',
        use: '去脂體重指數（FFMI）的定義',
        url: 'https://pubmed.ncbi.nlm.nih.gov/7496846/',
      ),
    ],
  ),
];
