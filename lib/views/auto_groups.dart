import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/features.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef _Region = ({String label, String regex});

List<_Region> _regionsOf(AppLocalizations l) {
  final names = {
    'Hong Kong': l.regionHongKong,
    'Taiwan': l.regionTaiwan,
    'Japan': l.regionJapan,
    'Singapore': l.regionSingapore,
    'United States': l.regionUnitedStates,
    'South Korea': l.regionSouthKorea,
    'United Kingdom': l.regionUnitedKingdom,
  };
  return [
    for (final filter in defaultFilters)
      if (names[filter.label] case final name?)
        (label: name, regex: filter.regex),
  ];
}

String? _regionLabel(AppLocalizations l, String? regex) {
  for (final region in _regionsOf(l)) {
    if (region.regex == regex) return region.label;
  }
  return null;
}

List<String> _nodeNamesOf(List<Group> groups) {
  final groupNames = {for (final group in groups) group.name};
  final names = <String>{};
  for (final group in groups) {
    for (final proxy in group.all) {
      if (!groupNames.contains(proxy.name) &&
          !RuleTarget.ruleTargets.contains(proxy.name)) {
        names.add(proxy.name);
      }
    }
  }
  return names.toList();
}

class AutoGroupsView extends ConsumerWidget {
  const AutoGroupsView({super.key});

  void _save(WidgetRef ref, List<AutoGroup> groups) {
    ref
        .read(appSettingProvider.notifier)
        .update((state) => state.copyWith(autoGroups: groups));
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, [int? index]) async {
    final groups = ref.read(
      appSettingProvider.select((state) => state.autoGroups),
    );
    final res = await showFormSheet<_FormResult>(
      context: context,
      builder: (_) => _AutoGroupForm(
        group: index == null ? null : groups[index],
        takenNames: {
          for (final (i, group) in groups.indexed)
            if (i != index) group.name,
        },
      ),
    );
    if (res == null) return;
    final next = List<AutoGroup>.from(groups);
    if (res.group == null) {
      if (index != null) next.removeAt(index);
    } else if (index == null) {
      next.add(res.group!);
    } else {
      next[index] = res.group!;
    }
    _save(ref, next);
  }

  String _subtitle(AppLocalizations l, AutoGroup group, Group? running) {
    final source = group.proxies.isNotEmpty
        ? l.autoGroupManualCount(group.proxies.length)
        : _regionLabel(l, group.regex) ?? l.autoGroupByRegion;
    final strategy = group.strategy == AutoGroupStrategy.fastest
        ? l.autoGroupFastest
        : l.autoGroupFailover;
    final parts = [source, strategy];
    if (running != null) {
      parts.add(
        running.all.isEmpty || running.now == 'COMPATIBLE'
            ? l.autoGroupNoMatch
            : l.autoGroupNow(running.now ?? '-', running.all.length),
      );
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.appLocalizations;
    final groups = ref.watch(
      appSettingProvider.select((state) => state.autoGroups),
    );
    final running = {
      for (final group in ref.watch(groupsProvider)) group.name: group,
    };
    return Scaffold(
      title: l.autoGroups,
      actions: [
        IconButton(
          tooltip: l.add,
          onPressed: () => _edit(context, ref),
          icon: const GlyphIcon(AppGlyphs.addCircle),
        ),
      ],
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.info,
          onPressed: () => dialogs.showAlert(
            title: l.autoGroups,
            message: TextSpan(text: l.autoGroupsHelp),
          ),
          tooltip: l.tip,
        ),
      ],
      body: groups.isEmpty
          ? NullStatus(
              label: l.autoGroupsEmptyTip,
              illustration: NullStatusIllustration.proxies,
            )
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16).copyWith(
                top: context.contentTopPadding,
                bottom: 16 + context.bottomInset,
              ),
              children: [
                generateSection(
                  footer: l.autoGroupsFooter,
                  items: [
                    for (final (index, group) in groups.indexed)
                      ListItem(
                        leading: const GlyphIcon(AppGlyphs.proxies),
                        title: Text(group.name),
                        subtitle: Text(
                          _subtitle(l, group, running[group.name]),
                        ),
                        onTap: () => _edit(context, ref, index),
                      ),
                  ],
                ),
              ],
            ),
    );
  }
}

/// A null [group] deletes the edited group.
typedef _FormResult = ({AutoGroup? group});

class _AutoGroupForm extends ConsumerStatefulWidget {
  final AutoGroup? group;
  final Set<String> takenNames;

  const _AutoGroupForm({this.group, required this.takenNames});

  @override
  ConsumerState<_AutoGroupForm> createState() => _AutoGroupFormState();
}

class _AutoGroupFormState extends ConsumerState<_AutoGroupForm> {
  late final TextEditingController _nameController;
  late bool _manual;
  String? _regex;
  late Set<String> _proxies;
  late AutoGroupStrategy _strategy;
  bool _nameEdited = false;
  bool _attempted = false;

  @override
  void initState() {
    super.initState();
    final group = widget.group;
    _manual = group?.proxies.isNotEmpty ?? false;
    _regex = group?.regex;
    _proxies = {...?group?.proxies};
    _strategy = group?.strategy ?? AutoGroupStrategy.fastest;
    _nameController = TextEditingController(text: group?.name);
    _nameEdited = group != null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.group == null && _regex == null && !_manual) {
      final region = _regionsOf(context.appLocalizations).first;
      _setRegion(region);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _setRegion(_Region region) {
    _regex = region.regex;
    if (!_nameEdited) {
      _nameController.text = context.appLocalizations.autoGroupDefaultName(
        region.label,
      );
    }
  }

  String? _issue() {
    final l = context.appLocalizations;
    final name = _nameController.text.trim();
    if (name.isEmpty) return l.emptyTip(l.name);
    if (widget.takenNames.contains(name)) return l.autoGroupNameExists;
    if (_manual && _proxies.isEmpty) return l.autoGroupNodesEmpty;
    return null;
  }

  void _submit() {
    if (_issue() != null) {
      setState(() => _attempted = true);
      return;
    }
    Navigator.of(context).pop<_FormResult>((
      group: AutoGroup(
        name: _nameController.text.trim(),
        regex: _manual ? null : _regex,
        proxies: _manual ? _proxies.toList() : const [],
        strategy: _strategy,
      ),
    ));
  }

  Future<void> _delete() async {
    final l = context.appLocalizations;
    final res = await dialogs.showMessage(
      title: l.tip,
      message: TextSpan(text: l.deleteTip(widget.group!.name)),
      destructive: true,
      confirmText: l.delete,
    );
    if (res == true && mounted) {
      Navigator.of(context).pop<_FormResult>((group: null));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final regions = _regionsOf(l);
    final region = regions.where((item) => item.regex == _regex).firstOrNull;
    final nodes = _manual
        ? _nodeNamesOf(ref.watch(groupsProvider))
        : const <String>[];
    final selectedMissing = _proxies.where((name) => !nodes.contains(name));
    return FormPage(
      title: widget.group == null ? l.addAutoGroup : l.editAutoGroup,
      onSave: _submit,
      error: _attempted ? _issue() : null,
      actions: [
        if (widget.group != null)
          IconButtonData(
            glyph: AppGlyphs.delete,
            onPressed: _delete,
            tooltip: l.delete,
          ),
      ],
      children: [
        generateSection(
          title: l.basicInfo,
          items: [
            FormRow(
              title: l.name,
              trailing: FormRowTextField(
                controller: _nameController,
                hintText: l.autoGroupDefaultName(l.regionJapan),
                onChanged: (_) {
                  _nameEdited = true;
                  if (_attempted) setState(() {});
                },
              ),
            ),
            ListItem<bool>.options(
              title: Text(l.autoGroupSource),
              options: const [false, true],
              value: _manual,
              textBuilder: (manual) =>
                  manual ? l.autoGroupManual : l.autoGroupByRegion,
              onChanged: (manual) => setState(() => _manual = manual),
            ),
            if (!_manual)
              ListItem<_Region>.options(
                title: Text(l.autoGroupRegion),
                options: regions,
                value: region ?? regions.first,
                textBuilder: (item) => item.label,
                onChanged: (item) => setState(() => _setRegion(item)),
              ),
            ListItem<AutoGroupStrategy>.options(
              title: Text(l.autoGroupStrategy),
              options: AutoGroupStrategy.values,
              value: _strategy,
              textBuilder: (strategy) => strategy == AutoGroupStrategy.fastest
                  ? l.autoGroupFastest
                  : l.autoGroupFailover,
              onChanged: (strategy) => setState(() => _strategy = strategy),
            ),
          ],
          footer: [
            if (!_manual) l.autoGroupRegionHint,
            _strategy == AutoGroupStrategy.fastest
                ? l.autoGroupFastestHint
                : l.autoGroupFailoverHint,
          ].join('\n\n'),
        ),
        if (_manual)
          generateSection(
            title: l.autoGroupNodes,
            footer: nodes.isEmpty ? l.autoGroupNoNodesTip : null,
            items: [
              for (final name in [...selectedMissing, ...nodes])
                FormRow(
                  title: name,
                  onPressed: () => setState(() => _proxies.addOrRemove(name)),
                  trailing: Switch(
                    value: _proxies.contains(name),
                    onChanged: (_) =>
                        setState(() => _proxies.addOrRemove(name)),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
