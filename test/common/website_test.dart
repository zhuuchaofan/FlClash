import 'package:fl_clash/common/website.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a pasted URL comes down to its host', () {
    expect(
      normalizeWebsite(' https://user@Www.GitHub.com:443/a/b?c=d#e '),
      'www.github.com',
    );
  });

  test('a wildcard or a leading dot is dropped', () {
    expect(normalizeWebsite('*.openai.com'), 'openai.com');
    expect(normalizeWebsite('.google.com.'), 'google.com');
  });

  test('nothing but a scheme leaves nothing', () {
    expect(normalizeWebsite('https://'), isEmpty);
  });
}
