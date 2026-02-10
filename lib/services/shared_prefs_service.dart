import 'package:shared_preferences/shared_preferences.dart';

//키 상수로 빼는거
class SharedPrefService {
  static final SharedPrefService _instance = SharedPrefService._internal();

  late SharedPreferences _prefs;

  factory SharedPrefService() {
    return _instance;
  }

  SharedPrefService._internal();

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  SharedPreferences get pref => _prefs;
}
