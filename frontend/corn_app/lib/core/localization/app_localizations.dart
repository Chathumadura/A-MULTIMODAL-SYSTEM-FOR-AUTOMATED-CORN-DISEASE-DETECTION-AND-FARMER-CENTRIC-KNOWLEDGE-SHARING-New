import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [
    Locale('en', ''),
    Locale('si', ''), // Sinhala
    Locale('ta', ''), // Tamil
  ];

  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'welcome_back': 'Welcome back',
      'plant_health_cockpit': 'Plant health cockpit',
      'corn_yield_assistant': 'Corn yield assistant',
      'description': 'Jump into the yield predictor to see SHAP-based explanations and keep inputs aligned with Plantix-style visuals.',
      'open_predictor': 'Open predictor',
      'whats_inside': "What's inside",
      'features_list': '• Plantix-inspired palette with rounded cards and bold CTA\n• Yield prediction + SHAP explanations\n• Nutrient analysis with crop health insights\n• Clean navigation bar to hop between features',
      'home': 'Home',
      'yield': 'Yield',
      'nutrient': 'Nutrient',
      'corn_yield_prediction': 'Corn Yield Prediction',
      'guided_by': 'Guided by Plantix-style crop health cues',
      'live': 'LIVE',
      'field_snapshot': 'Field snapshot',
      'inputs': 'inputs',
      'district': 'District',
      'variety': 'Variety',
      'farm_size': 'Farm Size',
      'rainfall': 'Rainfall',
      'fertilizer': 'Fertilizer',
      'prev_yield': 'Prev Yield',
      'predict_yield': 'Predict yield',
      'predicting': 'Predicting...',
      'reset': 'Reset',
      'result': 'Result',
      'predicted_yield': 'Predicted yield',
      'main_contributing_factors': 'Main contributing factors',
      'increases_yield': 'increases yield',
      'reduces_yield': 'reduces yield',
      'no_change': 'no change',
      'select': 'Select',
      'acres': 'acres',
      'mm': 'mm',
      'kg_per_acre': 'kg/acre',
      'required': 'Required',
      'enter_number': 'Enter a number',
      'cannot_negative': 'Cannot be negative',
      'language': 'Language',
    },
    'si': {
      'welcome_back': 'නැවත පිළිගනිමු',
      'plant_health_cockpit': 'ශාක සෞඛ්‍ය පාලන මධ්‍යස්ථානය',
      'corn_yield_assistant': 'බඩඉරිඟු අස්වැන්න සහායක',
      'description': 'SHAP මත පදනම් වූ පැහැදිලි කිරීම් දැකීමට අස්වැන්න පුරෝකථනය වෙත පිවිසෙන්න.',
      'open_predictor': 'පුරෝකථනය විවෘත කරන්න',
      'whats_inside': 'ඇතුළත් දේ',
      'features_list': '• Plantix විලාසය සමග සැලසුම්\n• අස්වැන්න පුරෝකථනය + SHAP පැහැදිලි කිරීම්\n• පෝෂක විශ්ලේෂණය\n• පහසු සංචලනය',
      'home': 'මුල් පිටුව',
      'yield': 'අස්වැන්න',
      'nutrient': 'පෝෂක',
      'corn_yield_prediction': 'බඩඉරිඟු අස්වැන්න පුරෝකථනය',
      'guided_by': 'Plantix විලාසයේ බෝග සෞඛ්‍ය ඉඟි මගින් මග පෙන්වයි',
      'live': 'සජීවී',
      'field_snapshot': 'ක්ෂේත්‍ර තොරතුරු',
      'inputs': 'ආදාන',
      'district': 'දිස්ත්‍රික්කය',
      'variety': 'ප්‍රභේදය',
      'farm_size': 'ගොවිපල ප්‍රමාණය',
      'rainfall': 'වර්ෂාපතනය',
      'fertilizer': 'පොහොර',
      'prev_yield': 'පෙර අස්වැන්න',
      'predict_yield': 'අස්වැන්න පුරෝකථනය',
      'predicting': 'පුරෝකථනය කරමින්...',
      'reset': 'යළි සකසන්න',
      'result': 'ප්‍රතිඵලය',
      'predicted_yield': 'පුරෝකථනය කළ අස්වැන්න',
      'main_contributing_factors': 'ප්‍රධාන දායක සාධක',
      'increases_yield': 'අස්වැන්න වැඩි කරයි',
      'reduces_yield': 'අස්වැන්න අඩු කරයි',
      'no_change': 'වෙනසක් නැත',
      'select': 'තෝරන්න',
      'acres': 'අක්කර',
      'mm': 'මි.මී',
      'kg_per_acre': 'කි.ග්‍රෑ/අක්කර',
      'required': 'අවශ්‍යයි',
      'enter_number': 'අංකයක් ඇතුළත් කරන්න',
      'cannot_negative': 'සෘණ විය නොහැක',
      'language': 'භාෂාව',
    },
    'ta': {
      'welcome_back': 'மீண்டும் வரவேற்கிறோம்',
      'plant_health_cockpit': 'தாவர சுகாதார மையம்',
      'corn_yield_assistant': 'சோள விளைச்சல் உதவியாளர்',
      'description': 'SHAP அடிப்படையிலான விளக்கங்களைக் காண விளைச்சல் முன்னறிவிப்பிற்குள் செல்லவும்.',
      'open_predictor': 'முன்னறிவிப்பைத் திறக்கவும்',
      'whats_inside': 'உள்ளே என்ன',
      'features_list': '• Plantix பாணி வடிவமைப்பு\n• விளைச்சல் முன்னறிவிப்பு + SHAP விளக்கங்கள்\n• ஊட்டச்சத்து பகுப்பாய்வு\n• எளிதான வழிசெலுத்தல்',
      'home': 'முகப்பு',
      'yield': 'விளைச்சல்',
      'nutrient': 'ஊட்டச்சத்து',
      'corn_yield_prediction': 'சோள விளைச்சல் முன்னறிவிப்பு',
      'guided_by': 'Plantix பாணி பயிர் சுகாதார குறிப்புகளால் வழிநடத்தப்படுகிறது',
      'live': 'நேரலை',
      'field_snapshot': 'வயல் தகவல்',
      'inputs': 'உள்ளீடுகள்',
      'district': 'மாவட்டம்',
      'variety': 'வகை',
      'farm_size': 'பண்ணை அளவு',
      'rainfall': 'மழை',
      'fertilizer': 'உரம்',
      'prev_yield': 'முந்தைய விளைச்சல்',
      'predict_yield': 'விளைச்சல் முன்னறிவிப்பு',
      'predicting': 'முன்னறிவிக்கிறது...',
      'reset': 'மீட்டமை',
      'result': 'முடிவு',
      'predicted_yield': 'முன்னறிவிக்கப்பட்ட விளைச்சல்',
      'main_contributing_factors': 'முக்கிய பங்களிப்பு காரணிகள்',
      'increases_yield': 'விளைச்சலை அதிகரிக்கிறது',
      'reduces_yield': 'விளைச்சலைக் குறைக்கிறது',
      'no_change': 'மாற்றம் இல்லை',
      'select': 'தேர்ந்தெடு',
      'acres': 'ஏக்கர்',
      'mm': 'மி.மீ',
      'kg_per_acre': 'கி.கி/ஏக்கர்',
      'required': 'தேவை',
      'enter_number': 'எண்ணை உள்ளிடவும்',
      'cannot_negative': 'எதிர்மறையாக இருக்க முடியாது',
      'language': 'மொழி',
    },
  };

  String translate(String key) {
    return _localizedValues[locale.languageCode]?[key] ?? key;
  }

  String get welcomeBack => translate('welcome_back');
  String get plantHealthCockpit => translate('plant_health_cockpit');
  String get cornYieldAssistant => translate('corn_yield_assistant');
  String get description => translate('description');
  String get openPredictor => translate('open_predictor');
  String get whatsInside => translate('whats_inside');
  String get featuresList => translate('features_list');
  String get home => translate('home');
  String get yield => translate('yield');
  String get nutrient => translate('nutrient');
  String get cornYieldPrediction => translate('corn_yield_prediction');
  String get guidedBy => translate('guided_by');
  String get live => translate('live');
  String get fieldSnapshot => translate('field_snapshot');
  String get inputs => translate('inputs');
  String get district => translate('district');
  String get variety => translate('variety');
  String get farmSize => translate('farm_size');
  String get rainfall => translate('rainfall');
  String get fertilizer => translate('fertilizer');
  String get prevYield => translate('prev_yield');
  String get predictYield => translate('predict_yield');
  String get predicting => translate('predicting');
  String get reset => translate('reset');
  String get result => translate('result');
  String get predictedYield => translate('predicted_yield');
  String get mainContributingFactors => translate('main_contributing_factors');
  String get increasesYield => translate('increases_yield');
  String get reducesYield => translate('reduces_yield');
  String get noChange => translate('no_change');
  String get select => translate('select');
  String get acres => translate('acres');
  String get mm => translate('mm');
  String get kgPerAcre => translate('kg_per_acre');
  String get required => translate('required');
  String get enterNumber => translate('enter_number');
  String get cannotNegative => translate('cannot_negative');
  String get language => translate('language');
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'si', 'ta'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
