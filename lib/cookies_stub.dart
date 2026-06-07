String serverURL = 'STUB';

/// A cache of cookies that have been saved for use synchronously. This is updated by [getCookie] and [setCookie], and possibly other things too.
Map<String, String> cookieCache = {};

/// Gets the cookie associated with [name] from the cookie store and add it to [cookieCache]. This does not mean an actual cookie, but something somehow stored on the local machine.
Future<String?> getCookie(String name) async {
  return cookieCache[name];
}

/// Sets the cookie associated with [name] to [value] and add it to [cookieCache]. This does not mean an actual cookie, but something somehow stored on the local machine.
void setCookie(String name, String? value) {
  if (value == null) {
    cookieCache.remove(name);
  } else {
    cookieCache[name] = value;
  }
}
