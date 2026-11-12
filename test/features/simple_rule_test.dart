import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/form/form.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

Future<Rule? Function()> _open(WidgetTester tester, {Rule? rule}) async {
  Rule? result;
  await tester.pumpWidget(
    TestApp(
      wrapInProviderScope: true,
      overrides: [
        viewSizeProvider.overrideWithBuild((_, _) => const Size(1200, 800)),
      ],
      child: Builder(
        builder: (context) => FilledButton(
          onPressed: () async {
            result = await showFormSheet<Rule>(
              context: context,
              builder: (_) => SimpleRuleForm(profileId: 1, rule: rule),
            );
          },
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return () => result;
}

void main() {
  testWidgets('a pasted URL saves as a rule for the site and its subdomains '
      'sent to the default proxy', (tester) async {
    final result = await _open(tester);
    final l10n = AppLocalizations.current;

    await tester.enterText(
      find.byType(TextFormField),
      'https://www.github.com/x',
    );
    await tester.tap(find.widgetWithText(TextButton, l10n.save));
    await tester.pumpAndSettle();

    final rule = result()!;
    expect(rule.ruleAction, RuleAction.DOMAIN_SUFFIX);
    expect(rule.content, 'www.github.com');
    expect(rule.ruleTarget, RuleAction.MATCH.value);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('turning subdomains off saves an exact domain rule', (
    tester,
  ) async {
    final result = await _open(
      tester,
      rule: const Rule(
        ruleAction: RuleAction.DOMAIN_SUFFIX,
        content: 'bilibili.com',
        ruleTarget: 'DIRECT',
      ),
    );
    final l10n = AppLocalizations.current;

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, l10n.save));
    await tester.pumpAndSettle();

    expect(result()!.ruleAction, RuleAction.DOMAIN);
    expect(result()!.ruleTarget, 'DIRECT');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('an empty domain is refused', (tester) async {
    final result = await _open(tester);
    final l10n = AppLocalizations.current;

    await tester.tap(find.widgetWithText(TextButton, l10n.save));
    await tester.pumpAndSettle();

    expect(result(), isNull);
    expect(find.text(l10n.emptyTip(l10n.domain)), findsWidgets);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('only plain domain rules open in the simple form', () {
    expect(
      SimpleRuleForm.canEdit(
        const Rule(ruleAction: RuleAction.DOMAIN, content: 'a.test'),
      ),
      isTrue,
    );
    expect(
      SimpleRuleForm.canEdit(
        const Rule(ruleAction: RuleAction.IP_CIDR, content: '1.1.1.1/32'),
      ),
      isFalse,
    );
  });

  test('a name pattern matches as mihomo reads its caseless prefix', () {
    expect(
      matchingProxies(autoGroupRegions['JP']!, [
        '日本 01',
        'jp-tokyo',
        'US 1',
      ]).toList(),
      ['日本 01', 'jp-tokyo'],
    );
    expect(matchingProxies('(', ['a']), isEmpty);
  });
}
