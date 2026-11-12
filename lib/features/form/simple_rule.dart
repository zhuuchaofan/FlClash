import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/clash_config.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'form_page.dart';
import 'form_row.dart';
import 'selection_sheet.dart';

/// The label a rule target reads as in the simple rule views, where the MATCH
/// placeholder stands for the profile's default proxy.
String ruleTargetLabel(BuildContext context, String target) {
  final appLocalizations = context.appLocalizations;
  return switch (target) {
    'MATCH' => appLocalizations.defaultProxy,
    'DIRECT' => appLocalizations.direct,
    'REJECT' => appLocalizations.block,
    _ => target,
  };
}

/// Every name a rule of [profileId] can send traffic to: the basic actions,
/// the user's own groups, then the subscription's groups and proxies.
Future<String?> pickRuleTarget(
  BuildContext context, {
  required int profileId,
  String? selected,
}) {
  return Navigator.of(context).push<String>(
    PagedSheetRoute(
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final appLocalizations = context.appLocalizations;
          final clashConfig = ref.watch(clashConfigProvider(profileId)).value;
          final userGroups =
              ref.watch(proxyGroupsProvider(profileId)).value ??
              const <ProxyGroup>[];
          final groupTypes = {
            for (final group in [...userGroups, ...?clashConfig?.proxyGroups])
              group.name: group.type.value,
          };
          final userNames = {for (final group in userGroups) group.name};
          return SelectionSheet<String>(
            title: appLocalizations.accessMethod,
            sections: [
              const SelectionSection(items: ['MATCH', 'DIRECT', 'REJECT']),
              SelectionSection(
                label: appLocalizations.autoGroups,
                items: userNames.toList(),
                subtitleBuilder: (_, name) => groupTypes[name],
              ),
              SelectionSection(
                label: appLocalizations.subscriptionGroups,
                items: [
                  for (final group in clashConfig?.proxyGroups ?? const [])
                    if (!userNames.contains(group.name)) group.name,
                ],
                subtitleBuilder: (_, name) => groupTypes[name],
              ),
              SelectionSection(
                label: appLocalizations.proxies,
                items: [
                  for (final proxy in clashConfig?.proxies ?? const [])
                    proxy.name,
                ],
              ),
            ],
            labelBuilder: (target) => ruleTargetLabel(context, target),
            selectedOf: (_) => selected,
            onSelected: (target) => Navigator.of(context).pop(target),
          );
        },
      ),
    ),
  );
}

/// A rule for one website, for users who never write a Clash rule: a domain,
/// whether its subdomains count, and where its traffic goes.
class SimpleRuleForm extends StatefulWidget {
  final int profileId;
  final Rule? rule;
  final String? website;

  /// Opens the full rule form instead, for a match this form cannot express.
  final VoidCallback? onAdvanced;

  const SimpleRuleForm({
    super.key,
    required this.profileId,
    this.rule,
    this.website,
    this.onAdvanced,
  });

  /// Whether [rule] is one this form can edit without losing anything.
  static bool canEdit(Rule rule) =>
      (rule.ruleAction == RuleAction.DOMAIN ||
          rule.ruleAction == RuleAction.DOMAIN_SUFFIX) &&
      !rule.src &&
      !rule.noResolve;

  @override
  State<SimpleRuleForm> createState() => _SimpleRuleFormState();
}

class _SimpleRuleFormState extends State<SimpleRuleForm> {
  late final TextEditingController _websiteController;
  late bool _includeSubdomains;
  late String _target;
  bool _attempted = false;

  @override
  void initState() {
    super.initState();
    final rule = widget.rule;
    _websiteController = TextEditingController(
      text: rule?.content ?? widget.website ?? '',
    );
    _includeSubdomains = rule?.ruleAction != RuleAction.DOMAIN;
    _target = rule?.ruleTarget ?? RuleAction.MATCH.value;
  }

  @override
  void dispose() {
    _websiteController.dispose();
    super.dispose();
  }

  RuleAction get _ruleAction =>
      _includeSubdomains ? RuleAction.DOMAIN_SUFFIX : RuleAction.DOMAIN;

  String? _issue() {
    final appLocalizations = context.appLocalizations;
    final website = normalizeWebsite(_websiteController.text);
    if (website.isEmpty) {
      return appLocalizations.emptyTip(appLocalizations.domain);
    }
    return Rule(
      ruleAction: _ruleAction,
      content: website,
    ).payloadError?.getMessage(context);
  }

  void _handleSubmit() {
    if (_issue() != null) {
      setState(() {
        _attempted = true;
      });
      return;
    }
    Navigator.of(context).pop(
      (widget.rule ?? Rule(id: snowflake.id)).copyWith(
        ruleAction: _ruleAction,
        content: normalizeWebsite(_websiteController.text),
        ruleTarget: _target,
      ),
    );
  }

  Future<void> _handlePickTarget() async {
    final target = await pickRuleTarget(
      context,
      profileId: widget.profileId,
      selected: _target,
    );
    if (target != null && mounted) {
      setState(() {
        _target = target;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final issue = _attempted ? _issue() : null;
    return FormPage(
      title: widget.rule != null
          ? appLocalizations.editRule
          : appLocalizations.addWebsiteRule,
      onSave: _handleSubmit,
      error: issue,
      actions: [
        if (widget.onAdvanced case final onAdvanced?)
          IconButtonData(
            glyph: AppGlyphs.code,
            tooltip: appLocalizations.advancedConfig,
            onPressed: () {
              Navigator.of(context).pop();
              onAdvanced();
            },
          ),
      ],
      children: [
        generateSection(
          items: [
            FormRow(
              title: appLocalizations.domain,
              invalid: issue != null,
              trailing: FormRowTextField(
                controller: _websiteController,
                hintText: 'example.com',
                autocorrect: false,
                keyboardType: TextInputType.url,
                inputFormatters: TextInputLimits.limit(TextInputLimits.rule),
                onChanged: (_) {
                  if (_attempted) {
                    setState(() {});
                  }
                },
                onFieldSubmitted: (_) => _handleSubmit(),
              ),
            ),
            FormRow(
              title: appLocalizations.includeSubdomains,
              onPressed: () => setState(() {
                _includeSubdomains = !_includeSubdomains;
              }),
              trailing: Switch(
                value: _includeSubdomains,
                onChanged: (value) => setState(() {
                  _includeSubdomains = value;
                }),
              ),
            ),
            FormRow(
              title: appLocalizations.accessMethod,
              onPressed: _handlePickTarget,
              trailing: Text(ruleTargetLabel(context, _target)),
            ),
          ],
        ),
      ],
    );
  }
}
