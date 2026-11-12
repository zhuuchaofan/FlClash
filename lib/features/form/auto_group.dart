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

const autoGroupInterval = 180;
const autoGroupTolerance = 50;

/// Name patterns for the regions subscriptions name their nodes after.
const autoGroupRegions = {
  'HK': '(?i)港|HK|Hong ?Kong',
  'TW': '(?i)台|TW|Taiwan',
  'JP': '(?i)日本|JP|Japan|东京|大阪',
  'KR': '(?i)韩|KR|Korea',
  'SG': '(?i)新加坡|狮城|SG|Singapore',
  'US': '(?i)美|US|United States|America',
};

enum _Source { name, pick }

enum _Field { name, nodes }

/// Whether the members of [group] are picked by hand rather than matched by
/// a name pattern, which follows the subscription as it changes.
bool isPickedGroup(ProxyGroup group) => group.includeAllProxies != true;

/// Which of [proxies] a name pattern takes in, as mihomo's case-insensitive
/// `(?i)` prefix reads.
Iterable<String> matchingProxies(String filter, Iterable<String> proxies) {
  final caseless = filter.startsWith('(?i)');
  final RegExp pattern;
  try {
    pattern = RegExp(
      caseless ? filter.substring(4) : filter,
      caseSensitive: !caseless,
    );
  } on FormatException {
    return const [];
  }
  return proxies.where(pattern.hasMatch);
}

/// A url-test or fallback group for a subscription profile, built from the
/// few choices that matter: a name, a mode, and which nodes it may use.
class AutoGroupForm extends ConsumerStatefulWidget {
  final int profileId;
  final ProxyGroup? group;
  final VoidCallback? onDelete;

  const AutoGroupForm({
    super.key,
    required this.profileId,
    this.group,
    this.onDelete,
  });

  @override
  ConsumerState<AutoGroupForm> createState() => _AutoGroupFormState();
}

class _AutoGroupFormState extends ConsumerState<AutoGroupForm> {
  late final TextEditingController _nameController;
  late final TextEditingController _filterController;
  late final TextEditingController _intervalController;
  late final TextEditingController _toleranceController;
  late GroupType _type;
  late _Source _source;
  late List<String> _picked;
  bool _attempted = false;

  @override
  void initState() {
    super.initState();
    final group = widget.group;
    _nameController = TextEditingController(text: group?.name);
    _filterController = TextEditingController(text: group?.filter);
    _intervalController = TextEditingController(
      text: '${group?.interval ?? autoGroupInterval}',
    );
    _toleranceController = TextEditingController(
      text: '${group?.tolerance ?? autoGroupTolerance}',
    );
    _type = group?.type == GroupType.Fallback
        ? GroupType.Fallback
        : GroupType.URLTest;
    _source = group == null || isPickedGroup(group)
        ? _Source.pick
        : _Source.name;
    _picked = [...?group?.proxies];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _filterController.dispose();
    _intervalController.dispose();
    _toleranceController.dispose();
    super.dispose();
  }

  List<String> get _proxyNames => [
    for (final proxy
        in ref.read(clashConfigProvider(widget.profileId)).value?.proxies ??
            const <Proxy>[])
      proxy.name,
  ];

  ({_Field field, String message})? _issue() {
    final appLocalizations = context.appLocalizations;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      return (
        field: _Field.name,
        message: appLocalizations.emptyTip(appLocalizations.name),
      );
    }
    final clashConfig = ref.read(clashConfigProvider(widget.profileId)).value;
    final userGroups =
        ref.read(proxyGroupsProvider(widget.profileId)).value ?? const [];
    final taken = {
      ...RuleTarget.ruleTargets,
      ...?clashConfig?.proxyGroups.map((group) => group.name),
      ...?clashConfig?.proxies.map((proxy) => proxy.name),
      for (final group in userGroups)
        if (group.id != widget.group?.id) group.name,
    };
    if (taken.contains(name)) {
      return (field: _Field.name, message: appLocalizations.existsTip(name));
    }
    final noNodes = switch (_source) {
      _Source.pick => _picked.isEmpty,
      _Source.name => _filterController.text.trim().isEmpty,
    };
    if (noNodes) {
      return (
        field: _Field.nodes,
        message: appLocalizations.emptyTip(appLocalizations.candidateNodes),
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
    final byName = _source == _Source.name;
    final previous =
        widget.group ??
        ProxyGroup(
          id: snowflake.id,
          name: '',
          type: _type,
          url: defaultTestUrl,
          lazy: true,
        );
    Navigator.of(context).pop(
      previous.copyWith(
        name: _nameController.text.trim(),
        type: _type,
        proxies: byName ? null : _picked,
        filter: byName ? _filterController.text.trim() : null,
        includeAllProxies: byName ? true : null,
        includeAllProviders: byName ? true : null,
        interval: int.tryParse(_intervalController.text) ?? autoGroupInterval,
        tolerance: _type == GroupType.URLTest
            ? int.tryParse(_toleranceController.text) ?? autoGroupTolerance
            : null,
      ),
    );
  }

  void _handleAddNodes() {
    final appLocalizations = context.appLocalizations;
    final remaining = [
      for (final name in _proxyNames)
        if (!_picked.contains(name)) name,
    ];
    Navigator.of(context).push(
      PagedSheetRoute(
        builder: (_) => SelectionSheet<String>(
          title: appLocalizations.addNode,
          sections: [SelectionSection(items: remaining)],
          labelBuilder: (name) => name,
          selectedOf: (_) => null,
          removeOnSelect: true,
          onSelected: (name) {
            if (mounted) {
              setState(() {
                _picked = [..._picked, name];
              });
            }
          },
        ),
      ),
    );
  }

  Widget _buildNumberRow(String title, TextEditingController controller) {
    return FormRow(
      title: title,
      trailing: FormRowTextField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: TextInputLimits.digitsOnly(TextInputLimits.number),
      ),
    );
  }

  List<Widget> _buildNameSource(bool invalid) {
    final appLocalizations = context.appLocalizations;
    final filter = _filterController.text.trim();
    final region = autoGroupRegions.entries
        .where((entry) => entry.value == filter)
        .firstOrNull
        ?.key;
    final matched = filter.isEmpty
        ? 0
        : matchingProxies(filter, _proxyNames).length;
    return [
      ListItem<String>.options(
        title: Text(appLocalizations.region),
        options: ['', ...autoGroupRegions.keys],
        value: region ?? '',
        textBuilder: (code) => code.isEmpty ? '-' : code,
        onChanged: (code) => setState(() {
          _filterController.text = autoGroupRegions[code] ?? '';
        }),
      ),
      FormRow(
        title: appLocalizations.nameContains,
        invalid: invalid,
        trailing: FormRowTextField(
          controller: _filterController,
          hintText: autoGroupRegions['JP'],
          autocorrect: false,
          onChanged: (_) => setState(() {}),
        ),
      ),
      FormRow(
        title: appLocalizations.candidateNodes,
        trailing: Text('$matched'),
      ),
    ];
  }

  List<Widget> _buildPickedSource(bool invalid) {
    final appLocalizations = context.appLocalizations;
    final available = _proxyNames.toSet();
    return [
      for (final (index, name) in _picked.indexed)
        FormRow(
          title: _type == GroupType.Fallback ? '${index + 1}. $name' : name,
          invalid: available.isNotEmpty && !available.contains(name),
          trailing: IconButton(
            tooltip: appLocalizations.delete,
            onPressed: () => setState(() {
              _picked = [..._picked]..removeAt(index);
            }),
            icon: const GlyphIcon(AppGlyphs.removeCircle),
          ),
        ),
      FormRow(
        title: appLocalizations.addNode,
        invalid: invalid,
        onPressed: _handleAddNodes,
        trailing: const GlyphIcon(AppGlyphs.addCircle),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    ref.watch(clashConfigProvider(widget.profileId));
    final issue = _attempted ? _issue() : null;
    final nodesInvalid = issue?.field == _Field.nodes;
    return FormPage(
      title: widget.group == null
          ? appLocalizations.addAutoGroup
          : appLocalizations.editAutoGroup,
      onSave: _handleSubmit,
      error: issue?.message,
      actions: [
        if (widget.onDelete case final onDelete?)
          IconButtonData(
            glyph: AppGlyphs.delete,
            tooltip: appLocalizations.delete,
            onPressed: () {
              Navigator.of(context).pop();
              onDelete();
            },
          ),
      ],
      children: [
        generateSection(
          items: [
            FormRow(
              title: appLocalizations.name,
              invalid: issue?.field == _Field.name,
              trailing: FormRowTextField(
                controller: _nameController,
                autocorrect: false,
                onChanged: (_) {
                  if (_attempted) {
                    setState(() {});
                  }
                },
              ),
            ),
            ListItem<GroupType>.options(
              title: Text(appLocalizations.mode),
              options: const [GroupType.URLTest, GroupType.Fallback],
              value: _type,
              textBuilder: (type) => type == GroupType.Fallback
                  ? appLocalizations.failover
                  : appLocalizations.lowestDelay,
              onChanged: (type) => setState(() {
                _type = type;
              }),
            ),
            ListItem<_Source>.options(
              title: Text(appLocalizations.candidateNodes),
              options: _Source.values,
              value: _source,
              textBuilder: (source) => source == _Source.name
                  ? appLocalizations.matchByName
                  : appLocalizations.pickNodes,
              onChanged: (source) => setState(() {
                _source = source;
              }),
            ),
          ],
        ),
        generateSection(
          title: _type == GroupType.Fallback && _source == _Source.pick
              ? appLocalizations.failoverOrderTip
              : null,
          items: _source == _Source.name
              ? _buildNameSource(nodesInvalid)
              : _buildPickedSource(nodesInvalid),
        ),
        generateSection(
          items: [
            _buildNumberRow(
              '${appLocalizations.interval} (s)',
              _intervalController,
            ),
            if (_type == GroupType.URLTest)
              _buildNumberRow(
                '${appLocalizations.tolerance} (ms)',
                _toleranceController,
              ),
          ],
        ),
      ],
    );
  }
}
