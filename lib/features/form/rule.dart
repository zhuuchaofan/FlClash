library;

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'form_page.dart';
import 'form_row.dart';

const _ruleRowVerticalPadding = 7.0;

/// Rule lists run to thousands of rows, so a rule row is padded tighter than
/// other list rows.
double get ruleItemHeight =>
    globalState.measure.listTitleHeight +
    globalState.measure.listSubtitleHeight +
    2 * _ruleRowVerticalPadding;

class RuleItem extends StatelessWidget {
  static const _targetMaxWidthFactor = 0.5;
  static const _targetMinWidthFactor = 0.3;
  static const _labelTargetGap = 16.0;

  final bool isSelected;
  final bool isEditing;
  final Rule rule;
  final bool hasMatch;
  final void Function() onSelected;
  final void Function(Rule rule) onEdit;
  final String? Function(Rule rule)? invalidMessageOf;

  /// With a callback the row ends in a switch that turns the rule on or off.
  final bool enabled;
  final ValueChanged<bool>? onEnabledChanged;

  const RuleItem({
    super.key,
    required this.isSelected,
    required this.rule,
    required this.onSelected,
    required this.onEdit,
    this.invalidMessageOf,
    this.enabled = true,
    this.onEnabledChanged,
    this.isEditing = false,
    this.hasMatch = false,
  });

  ({bool invalid, Color? color, String? message}) _checkInvalid(
    BuildContext context,
  ) {
    final message = invalidMessageOf?.call(rule);
    if (message == null && rule.ruleAction != RuleAction.SUB_RULE) {
      final ruleTarget = (rule.ruleTarget ?? '').toUpperCase();
      final color = switch (ruleTarget) {
        'DIRECT' || 'COMPATIBLE' => context.colorScheme.success,
        'REJECT' || 'REJECT-DROP' => context.colorScheme.warning,
        'PASS' || 'PASS-RULE' || 'GLOBAL' => context.colorScheme.tertiary,
        'MATCH' when hasMatch => context.colorScheme.tertiary,
        _ => null,
      };
      if (color != null) {
        return (invalid: false, color: color, message: null);
      }
    }
    final invalid = invalidMessageOf == null || message != null;
    return (
      invalid: invalid,
      color: invalid ? context.colorScheme.error : context.colorScheme.tertiary,
      message: message,
    );
  }

  Widget _buildInfoWidget(BuildContext context, String? message) {
    return MinIconButtonTheme(
      child: IconButton(
        tooltip: context.appLocalizations.tip,
        onPressed: () {
          dialogs.showAlert(
            message: TextSpan(
              text:
                  message ??
                  rule.targetErrorTip(
                    context.appLocalizations.invalidSubRule(rule.subRule ?? ''),
                    context.appLocalizations.invalidPolicy(
                      rule.ruleTarget ?? '',
                    ),
                  ),
            ),
          );
        },
        icon: GlyphIcon(
          AppGlyphs.info,
          fill: 1,
          size: 16.ap(context),
          color: context.colorScheme.error,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final checkResult = _checkInvalid(context);
    final invalid = checkResult.invalid;
    return SelectedDecorationListItem(
      minVerticalPadding: 0,
      isSelected: isSelected,
      isEditing: isEditing,
      horizontalTitleGap: 0,
      invalid: invalid,
      onSelected: () {
        onSelected();
      },
      title: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final labelStyle = DefaultTextStyle.of(
              context,
            ).style.toJetBrainsMono;
            final actionWidth = globalState.measure
                .computeTextSize(Text(rule.ruleAction.name, style: labelStyle))
                .width;
            final maxWidth = constraints.maxWidth;
            final targetMaxWidth = (maxWidth - _labelTargetGap - actionWidth)
                .clamp(
                  maxWidth * _targetMinWidthFactor,
                  maxWidth * _targetMaxWidthFactor,
                );
            return Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Opacity(
                    opacity: enabled ? 1 : 0.5,
                    child: _RuleItemLabel(rule: rule, style: labelStyle),
                  ),
                ),
                const SizedBox(width: _labelTargetGap),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: targetMaxWidth),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (invalid)
                        _buildInfoWidget(context, checkResult.message),
                      if (rule.realTarget != null)
                        Flexible(
                          child: TooltipText(
                            text: Text(
                              hasMatch &&
                                      rule.realTarget!.toUpperCase() ==
                                          RuleAction.MATCH.value
                                  ? context.appLocalizations.matchTarget
                                  : rule.realTarget!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyle.subheadline
                                  .of(context)
                                  .toJetBrainsMono
                                  .copyWith(color: checkResult.color),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (onEnabledChanged case final onChanged? when !isEditing) ...[
                  const SizedBox(width: 8),
                  Switch(value: enabled, onChanged: onChanged),
                ],
              ],
            );
          },
        ),
      ),
      onPressed: () {
        onEdit(rule);
      },
    );
  }
}

class _RuleItemLabel extends StatelessWidget {
  const _RuleItemLabel({required this.rule, required this.style});

  final Rule rule;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final content = rule.realContent ?? '';
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          rule.ruleAction.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style,
        ),
        if (content.isNotEmpty)
          Flexible(
            child: TooltipText(
              text: Text(
                content,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.listSubtitleStyle.toJetBrainsMono.copyWith(
                  color: style.color?.opacity60,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class RuleStatusItem extends StatelessWidget {
  final bool status;
  final Rule rule;
  final void Function(bool) onChange;

  const RuleStatusItem({
    super.key,
    required this.status,
    required this.rule,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    return DecorationListItem(
      title: TooltipText(
        text: Text(
          rule.rawValue,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyle.subheadline.of(context).toJetBrainsMono,
        ),
      ),
      trailing: Switch(value: status, onChanged: onChange),
      onPressed: () {
        onChange(!status);
      },
    );
  }
}

enum _RuleField { content, target }

const _simpleRuleActions = [
  RuleAction.DOMAIN_SUFFIX,
  RuleAction.DOMAIN,
  RuleAction.DOMAIN_KEYWORD,
  RuleAction.GEOSITE,
  RuleAction.GEOIP,
  RuleAction.IP_CIDR,
];

const _simpleBaseTargets = ['MATCH', 'DIRECT', 'REJECT'];

/// Group and node names of the running config, groups first; a rule may name
/// either, and only the names the current subscription defines resolve.
List<String> _proxyTargetsOf(List<Group> groups) {
  final names = <String>{};
  for (final group in groups) {
    if (group.name != GroupName.GLOBAL.name) names.add(group.name);
  }
  for (final group in groups) {
    for (final proxy in group.all) {
      names.add(proxy.name);
    }
  }
  names.removeAll([...RuleTarget.ruleTargetNames, RuleAction.MATCH.value]);
  return names.toList();
}

class RuleForm extends ConsumerStatefulWidget {
  final Rule? rule;

  /// Prefills a new rule; unlike [rule], saving it adds instead of editing.
  final Rule? draft;

  const RuleForm({super.key, this.rule, this.draft});

  @override
  ConsumerState<RuleForm> createState() => _RuleFormState();
}

class _RuleFormState extends ConsumerState<RuleForm> {
  late RuleAction _ruleAction;
  late String _ruleTarget;
  late final TextEditingController _contentController;
  late bool _noResolve;
  late bool _src;
  bool _attempted = false;

  @override
  void initState() {
    super.initState();
    final rule = widget.rule ?? widget.draft;
    _ruleAction =
        rule?.ruleAction ??
        (simpleUi
            ? _simpleRuleActions.first
            : RuleAction.addedRuleActions.first);
    _ruleTarget =
        rule?.ruleTarget ??
        (simpleUi ? RuleAction.MATCH.value : RuleTarget.ruleTargetNames.first);
    _contentController = TextEditingController(text: rule?.content);
    _noResolve = rule?.noResolve ?? false;
    _src = rule?.src ?? false;
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  ({_RuleField field, String message})? _issue() {
    final appLocalizations = context.appLocalizations;
    final content = _contentController.text;
    if (content.isEmpty) {
      return (
        field: _RuleField.content,
        message: appLocalizations.emptyTip(appLocalizations.content),
      );
    }
    final payloadError = Rule(
      ruleAction: _ruleAction,
      content: content,
    ).payloadError;
    if (payloadError != null) {
      return (
        field: _RuleField.content,
        message: payloadError.getMessage(context),
      );
    }
    if (_ruleTarget.isEmpty) {
      return (
        field: _RuleField.target,
        message: appLocalizations.splitStrategyNotEmpty,
      );
    }
    return null;
  }

  void _handleSubmit() {
    if (_issue() != null) {
      setState(() {
        _attempted = true;
      });
      return;
    }
    Navigator.of(context).pop(
      (widget.rule ?? widget.draft ?? Rule(id: snowflake.id)).copyWith(
        ruleAction: _ruleAction,
        content: _contentController.text,
        ruleTarget: _ruleTarget,
        noResolve: _noResolve,
        src: _src,
      ),
    );
  }

  String _targetLabel(String target) {
    final appLocalizations = context.appLocalizations;
    if (simpleUi) {
      switch (target) {
        case 'MATCH':
          return appLocalizations.ruleTargetProxy;
        case 'DIRECT':
          return appLocalizations.ruleTargetDirect;
        case 'REJECT':
          return appLocalizations.ruleTargetReject;
      }
    }
    return target == RuleAction.MATCH.value
        ? appLocalizations.matchTarget
        : target;
  }

  String _actionLabel(RuleAction action) {
    if (!simpleUi) return action.value;
    final appLocalizations = context.appLocalizations;
    return switch (action) {
      RuleAction.DOMAIN_SUFFIX => appLocalizations.ruleTypeDomainSuffix,
      RuleAction.DOMAIN => appLocalizations.ruleTypeDomain,
      RuleAction.DOMAIN_KEYWORD => appLocalizations.ruleTypeDomainKeyword,
      RuleAction.GEOSITE => appLocalizations.ruleTypeGeosite,
      RuleAction.GEOIP => appLocalizations.ruleTypeGeoip,
      RuleAction.IP_CIDR => appLocalizations.ruleTypeIpCidr,
      _ => action.value,
    };
  }

  String? _actionHint(RuleAction action) {
    final appLocalizations = context.appLocalizations;
    return switch (action) {
      RuleAction.DOMAIN_SUFFIX => appLocalizations.ruleTypeDomainSuffixHint,
      RuleAction.DOMAIN => appLocalizations.ruleTypeDomainHint,
      RuleAction.DOMAIN_KEYWORD => appLocalizations.ruleTypeDomainKeywordHint,
      RuleAction.GEOSITE => appLocalizations.ruleTypeGeositeHint,
      RuleAction.GEOIP => appLocalizations.ruleTypeGeoipHint,
      RuleAction.IP_CIDR => appLocalizations.ruleTypeIpCidrHint,
      _ => null,
    };
  }

  String? _contentExample(RuleAction action) => switch (action) {
    RuleAction.DOMAIN_SUFFIX => 'google.com',
    RuleAction.DOMAIN => 'www.google.com',
    RuleAction.DOMAIN_KEYWORD => 'google',
    RuleAction.GEOSITE => 'youtube',
    RuleAction.GEOIP => 'JP',
    RuleAction.IP_CIDR => '192.168.0.0/16',
    _ => null,
  };

  Widget _buildSwitchRow({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return FormRow(
      title: title,
      onPressed: () => onChanged(!value),
      trailing: Switch(value: value, onChanged: onChanged),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final issue = _attempted ? _issue() : null;
    final targets = simpleUi
        ? [..._simpleBaseTargets, ..._proxyTargetsOf(ref.watch(groupsProvider))]
        : [...RuleTarget.ruleTargetNames, RuleAction.MATCH.value];
    final actions = simpleUi
        ? [
            if (!_simpleRuleActions.contains(_ruleAction)) _ruleAction,
            ..._simpleRuleActions,
          ]
        : RuleAction.addedRuleActions;
    final actionHint = simpleUi ? _actionHint(_ruleAction) : null;
    return FormPage(
      title: widget.rule != null
          ? appLocalizations.editRule
          : appLocalizations.addRule,
      onSave: _handleSubmit,
      error: issue?.message,
      children: [
        generateSection(
          title: appLocalizations.basicInfo,
          footer: simpleUi
              ? [?actionHint, appLocalizations.ruleTargetHint].join('\n\n')
              : null,
          items: [
            ListItem<RuleAction>.options(
              title: Text(appLocalizations.proxyType),
              options: actions,
              value: _ruleAction,
              textBuilder: _actionLabel,
              onChanged: (action) {
                setState(() {
                  _ruleAction = action;
                });
              },
            ),
            FormRow(
              title: appLocalizations.content,
              invalid: issue?.field == _RuleField.content,
              trailing: FormRowTextField(
                controller: _contentController,
                hintText: simpleUi
                    ? _contentExample(_ruleAction) ??
                          appLocalizations.inputRuleContent
                    : appLocalizations.inputRuleContent,
                autocorrect: false,
                inputFormatters: TextInputLimits.limit(TextInputLimits.rule),
                onChanged: (_) {
                  if (_attempted) {
                    setState(() {});
                  }
                },
                onFieldSubmitted: (_) => _handleSubmit(),
              ),
            ),
            ListItem<String>.options(
              title: Text(appLocalizations.splitStrategy),
              options: [
                if (!targets.contains(_ruleTarget)) _ruleTarget,
                ...targets,
              ],
              value: _ruleTarget,
              textBuilder: _targetLabel,
              onChanged: (target) {
                setState(() {
                  _ruleTarget = target;
                });
              },
            ),
          ],
        ),
        if (_ruleAction.hasParams)
          generateSection(
            title: appLocalizations.additionalParameters,
            items: [
              _buildSwitchRow(
                title: appLocalizations.noResolveHostname,
                value: _noResolve,
                onChanged: (value) {
                  setState(() {
                    _noResolve = value;
                  });
                },
              ),
              _buildSwitchRow(
                title: appLocalizations.matchSourceIp,
                value: _src,
                onChanged: (value) {
                  setState(() {
                    _src = value;
                  });
                },
              ),
            ],
          ),
      ],
    );
  }
}
