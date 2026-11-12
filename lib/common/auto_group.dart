import 'package:fl_clash/models/models.dart';

const autoGroupTestUrl = 'https://www.gstatic.com/generate_204';

// Keeps a fastest group from flapping between nodes of similar latency.
const autoGroupTolerance = 100;

const autoGroupInterval = 300;

String _escapeRegex(String text) =>
    text.replaceAllMapped(RegExp(r'[.*+?^$(){}|\[\]\\]'), (m) => '\\${m[0]}');

String autoGroupFilter(AutoGroup group) {
  if (group.proxies.isNotEmpty) {
    return '^(${group.proxies.map(_escapeRegex).join('|')})\$';
  }
  return group.regex ?? '.*';
}

// A filter, not `proxies`: nodes from a proxy provider cannot be listed by name.
Map<String, dynamic> autoGroupDefinition(AutoGroup group) {
  final fastest = group.strategy == AutoGroupStrategy.fastest;
  return {
    'name': group.name,
    'type': fastest ? 'url-test' : 'fallback',
    'include-all': true,
    'filter': autoGroupFilter(group),
    'url': autoGroupTestUrl,
    'interval': autoGroupInterval,
    if (fastest) 'tolerance': autoGroupTolerance,
  };
}

Map<String, dynamic> withAutoGroups(
  Map<String, dynamic> config,
  List<AutoGroup> groups,
) {
  if (groups.isEmpty) return config;
  final existing = config['proxy-groups'] is List
      ? List<Object?>.from(config['proxy-groups'] as List)
      : <Object?>[];
  final names = {
    for (final group in existing)
      if (group is Map) group['name'],
  };
  return {
    ...config,
    'proxy-groups': [
      ...existing,
      for (final group in groups)
        if (!names.contains(group.name)) autoGroupDefinition(group),
    ],
  };
}
