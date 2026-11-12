/// What a user pastes as a website, a URL or a wildcard, reduced to the host
/// a domain rule matches.
String normalizeWebsite(String input) {
  var host = input.trim().toLowerCase();
  final scheme = host.indexOf('://');
  if (scheme != -1) {
    host = host.substring(scheme + 3);
  }
  host = host.split(RegExp('[/?#]')).first;
  final at = host.lastIndexOf('@');
  if (at != -1) {
    host = host.substring(at + 1);
  }
  host = host.replaceFirst(RegExp(r':\d+$'), '');
  host = host.replaceFirst(RegExp(r'^(\*?\.)+'), '');
  return host.replaceFirst(RegExp(r'\.$'), '');
}
