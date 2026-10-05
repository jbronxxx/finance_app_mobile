import os, re, json

with open("pubspec.yaml", "r") as f:
    pub = f.read()
if "generate: true" not in pub:
    pub = pub.replace("uses-material-design: true", "uses-material-design: true\n  generate: true")
    with open("pubspec.yaml", "w") as f:
        f.write(pub)

with open("l10n.yaml", "w") as f:
    f.write("arb-dir: lib/l10n\ntemplate-arb-file: app_en.arb\noutput-localization-file: app_localizations.dart\n")

# Extract arb
with open("lib/utils/language_manager.dart", "r") as f:
    content = f.read()

start_idx = content.find("static final Map<String, Map<AppLanguage, String>> _localizedValues = {")
pattern = re.compile(r"'([^']+)'\s*:\s*\{([^\}]+)\}")
matches = pattern.findall(content[start_idx:])
ru_dict, en_dict, uz_dict = {}, {}, {}
lang_pattern = re.compile(r"AppLanguage\.(ru|en|uz)\s*:\s*('|\")(.+?)(?<!\\)\2")
for key, block in matches:
    for lang, _, val in lang_pattern.findall(block):
        val = val.replace("\\'", "'").replace('\\"', '"')
        if lang == 'ru': ru_dict[key] = val
        elif lang == 'en': en_dict[key] = val
        elif lang == 'uz': uz_dict[key] = val

os.makedirs("lib/l10n", exist_ok=True)
with open("lib/l10n/app_ru.arb", "w") as f: json.dump(ru_dict, f, ensure_ascii=False, indent=2)
with open("lib/l10n/app_en.arb", "w") as f: json.dump(en_dict, f, ensure_ascii=False, indent=2)
with open("lib/l10n/app_uz.arb", "w") as f: json.dump(uz_dict, f, ensure_ascii=False, indent=2)

# Update LanguageManager
new_lm = content[:start_idx]
new_lm = new_lm.replace(
    "class LanguageManager {",
    "import 'package:flutter_gen/gen_l10n/app_localizations.dart';\nexport 'package:flutter_gen/gen_l10n/app_localizations.dart';\n\nclass LanguageManager {"
)
new_lm = new_lm.replace(
    "static AppLanguage _currentLanguage = AppLanguage.ru;",
    "static AppLanguage _currentLanguage = AppLanguage.ru;\n  static late AppLocalizations l10n;"
)
new_lm = new_lm.replace(
    "languageNotifier.value = language;",
    "l10n = lookupAppLocalizations(Locale(language.code));\n    languageNotifier.value = language;"
)
new_lm = new_lm.replace(
    "languageNotifier.value = saved;",
    "l10n = lookupAppLocalizations(Locale(saved.code));\n        languageNotifier.value = saved;"
)
new_lm = new_lm.replace(
    "static AppLanguage get currentLanguage => _currentLanguage;",
    "static AppLanguage get currentLanguage => _currentLanguage;\n  static void initFallback() { try { l10n.balance; } catch(e) { l10n = lookupAppLocalizations(Locale(_currentLanguage.code)); } }"
)
new_lm += "}\n\nextension L10nExtension on BuildContext {\n  AppLocalizations get l10n => AppLocalizations.of(this)!;\n}\n"
with open("lib/utils/language_manager.dart", "w") as f:
    f.write(new_lm)

# Update main.dart to call initFallback
with open("lib/main.dart", "r") as f:
    main_dart = f.read()
main_dart = main_dart.replace(
    "await LanguageManager.loadSavedLanguage();",
    "await LanguageManager.loadSavedLanguage();\n  LanguageManager.initFallback();"
)
with open("lib/main.dart", "w") as f:
    f.write(main_dart)

# Refactor all dart files
for root, dirs, files in os.walk("."):
    if '.dart_tool' in root or '.git' in root: continue
    for file in files:
        if file.endswith('.dart') and file != 'language_manager.dart':
            filepath = os.path.join(root, file)
            with open(filepath, 'r') as f:
                code = f.read()
            
            # fix dynamic cases
            if file == 'currency_formatter.dart':
                code = code.replace("LanguageManager.t('${code.toLowerCase()}_name')", "LanguageManager.l10n.uzs_name /* fixme */")
                code = code.replace(
                    "LanguageManager.l10n.uzs_name /* fixme */",
                    "this == Currency.uzs ? LanguageManager.l10n.uzs_name : this == Currency.kzt ? LanguageManager.l10n.kzt_name : this == Currency.rub ? LanguageManager.l10n.rub_name : this == Currency.eur ? LanguageManager.l10n.eur_name : LanguageManager.l10n.usd_name"
                )
            if file == 'dashboard_screen.dart':
                code = code.replace("LanguageManager.t('month_${date.month}')", "LanguageManager.l10n.month_1 /* fixme */")
            
            is_widget = "BuildContext context" in code or "context" in code
            if is_widget and 'test/' not in filepath and not file.startswith('local_db_models'):
                # use context.l10n for normal strings
                code = re.sub(r"LanguageManager\.t\(['\"]([^'\"]+)['\"]\)", r"context.l10n.\1", code)
            else:
                code = re.sub(r"LanguageManager\.t\(['\"]([^'\"]+)['\"]\)", r"LanguageManager.l10n.\1", code)
                
            with open(filepath, 'w') as f:
                f.write(code)
