import 'package:web/web.dart';

Map<String, String> cookieCache = {};

Future<String?> getCookie(String name) async {
  String? item = window.localStorage.getItem(name);
  if (item != null) {
    cookieCache[name] = item;
  }
  return item;
}

void setCookie(String name, String? value) {
  if (value == null) {
    window.localStorage.removeItem(name);
    cookieCache.remove(name);
  } else {
    window.localStorage.setItem(name, value);
    cookieCache[name] = value;
  }
}