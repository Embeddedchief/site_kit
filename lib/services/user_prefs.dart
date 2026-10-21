import 'package:shared_preferences/shared_preferences.dart';

class UserPrefs {
  static const _nameKey = 'user_name';
  static const _emailKey = 'user_email';

  static Future<void> save({
    required String name,
    required String email,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nameKey, name);
    await prefs.setString(_emailKey, email);
  }

  static Future<String?> name() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_nameKey);
  }

  static Future<bool> isRegistered() async => (await name()) != null;

  static const _favouritesKey = 'favourite_tools';

  static Future<Set<String>> favourites() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_favouritesKey) ?? const []).toSet();
  }

  static Future<void> saveFavourites(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favouritesKey, ids.toList());
  }
}
