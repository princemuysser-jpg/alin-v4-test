from pathlib import Path

path = Path('flutter_business/lib/widgets/business_brand.dart')
text = path.read_text(encoding='utf-8')
text = text.replace('appBarTheme: const AppBarTheme(', 'appBarTheme: AppBarTheme(')
text = text.replace(
    'floatingActionButtonTheme: const FloatingActionButtonThemeData(',
    'floatingActionButtonTheme: FloatingActionButtonThemeData(',
)
path.write_text(text, encoding='utf-8')
print('Removed const wrappers around runtime-colored theme widgets')
