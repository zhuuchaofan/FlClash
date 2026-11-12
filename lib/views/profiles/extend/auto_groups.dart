import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/form/form.dart';
import 'package:fl_clash/models/clash_config.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The url-test and fallback groups a user adds to a subscription profile.
class AutoGroupsSection extends ConsumerWidget {
  final int profileId;

  const AutoGroupsSection({super.key, required this.profileId});

  Future<void> _handleEdit(
    BuildContext context,
    WidgetRef ref, [
    ProxyGroup? group,
  ]) async {
    final res = await showFormSheet<ProxyGroup>(
      context: context,
      builder: (_) => AutoGroupForm(
        profileId: profileId,
        group: group,
        onDelete: group == null
            ? null
            : () => _handleDelete(context, ref, group),
      ),
    );
    if (res == null) {
      return;
    }
    ref.read(proxyGroupsProvider(profileId).notifier).put(res);
  }

  Future<void> _handleDelete(
    BuildContext context,
    WidgetRef ref,
    ProxyGroup group,
  ) async {
    final rules = ref.read(profileRulesProvider(profileId)).value ?? const [];
    if (rules.any((rule) => rule.ruleTarget == group.name)) {
      final appLocalizations = context.appLocalizations;
      final res = await dialogs.showMessage(
        title: appLocalizations.tip,
        message: TextSpan(text: appLocalizations.proxyGroupInUse(group.name)),
        destructive: true,
        confirmText: appLocalizations.delete,
      );
      if (res != true) {
        return;
      }
    }
    ref.read(proxyGroupsProvider(profileId).notifier).delAll([group.id]);
  }

  String _subtitle(
    BuildContext context,
    ProxyGroup group, {
    required Set<String> proxies,
    required bool targeted,
  }) {
    final appLocalizations = context.appLocalizations;
    final mode = group.type == GroupType.Fallback
        ? appLocalizations.failover
        : appLocalizations.lowestDelay;
    final members = isPickedGroup(group)
        ? group.proxies ?? const <String>[]
        : matchingProxies(group.filter ?? '', proxies).toList();
    final gone = isPickedGroup(group) && proxies.isNotEmpty
        ? members.where((name) => !proxies.contains(name)).length
        : 0;
    return [
      mode,
      '${members.length - gone}',
      if (gone > 0) appLocalizations.nodesGone(gone),
      if (!targeted) appLocalizations.noRuleSendsHere,
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final groups =
        ref.watch(proxyGroupsProvider(profileId)).value ?? const <ProxyGroup>[];
    final rules = ref.watch(profileRulesProvider(profileId)).value ?? const [];
    final matchTarget = ref.watch(
      profileProvider(profileId).select((state) => state?.matchTarget),
    );
    final proxies = {
      for (final proxy
          in ref.watch(clashConfigProvider(profileId)).value?.proxies ??
              const <Proxy>[])
        proxy.name,
    };
    final targets = {
      for (final rule in rules) ?rule.ruleTarget,
      ?matchTarget,
      for (final group in groups) ...?group.proxies,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          ListHeader(
            title: appLocalizations.autoGroups,
            actions: [
              IconButtonData(
                glyph: AppGlyphs.addCircle,
                tooltip: appLocalizations.addAutoGroup,
                onPressed: () => _handleEdit(context, ref),
              ),
            ],
          ),
          generateGroup([
            for (final group in groups)
              ListItem(
                title: Text(group.name),
                subtitle: Text(
                  _subtitle(
                    context,
                    group,
                    proxies: proxies,
                    targeted: targets.contains(group.name),
                  ),
                ),
                onTap: () => _handleEdit(context, ref, group),
              ),
          ]),
        ],
      ),
    );
  }
}
