class LanguageOption {
  final String code;
  final String name;
  final String searchHint;

  LanguageOption(this.code, this.name, this.searchHint);
}

class LanguageService {
  static final List<LanguageOption> supportedLanguages = [
    LanguageOption('en', 'English', 'Search location...'),
    LanguageOption('es', 'Español', 'Buscar ubicación...'),
    LanguageOption('fr', 'Français', 'Rechercher un lieu...'),
    LanguageOption('de', 'Deutsch', 'Ort suchen...'),
    LanguageOption('it', 'Italiano', 'Cerca posizione...'),
    LanguageOption('ja', '日本語', '場所を検索...'),
    LanguageOption('ko', '한국어', '위치 검색...'),
    LanguageOption('zh', '中文', '搜索位置...'),
    LanguageOption('ar', 'العربية', '...البحث عن موقع'),
    LanguageOption('ru', 'Русский', 'Поиск места...'),
  ];
} 