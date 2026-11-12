import 'package:fl_clash/common/user_groups.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/clash_config.dart';
import 'package:flutter_test/flutter_test.dart';

ProxyGroup _group(String name, List<String> proxies, {List<String>? use}) =>
    ProxyGroup(
      id: name.hashCode,
      name: name,
      type: GroupType.URLTest,
      proxies: proxies,
      use: use,
    );

void main() {
  test('a group whose members all remain is left as it is', () {
    final group = _group('jp', ['a', 'DIRECT']);

    final result = pruneUserGroups([group], ['a', 'b']);

    expect(result.groups.single, same(group));
    expect(result.missing, isEmpty);
  });

  test('members the subscription dropped are taken out and reported', () {
    final result = pruneUserGroups(
      [
        _group('jp', ['a', 'gone']),
        _group('backup', ['jp']),
      ],
      ['a'],
    );

    expect(result.groups.first.proxies, ['a']);
    expect(result.groups.last.proxies, ['jp']);
    expect(result.missing, {
      'jp': ['gone'],
    });
  });

  test('a group left empty rejects rather than going direct', () {
    final result = pruneUserGroups(
      [
        _group('us', ['gone']),
      ],
      ['a'],
    );

    expect(result.groups.single.proxies, ['REJECT']);
  });

  test('a group drawing from providers may lose every listed member', () {
    final result = pruneUserGroups(
      [
        _group('us', ['gone'], use: ['sub']),
      ],
      ['a'],
    );

    expect(result.groups.single.proxies, isEmpty);
  });
}
