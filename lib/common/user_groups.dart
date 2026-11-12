import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/clash_config.dart';

typedef PrunedGroups = ({
  List<ProxyGroup> groups,
  Map<String, List<String>> missing,
});

/// A subscription update can drop a proxy a user's group names by hand, and
/// mihomo refuses the whole config for one unknown member. A group left with
/// nothing to pick from rejects instead of leaking its traffic direct.
PrunedGroups pruneUserGroups(
  List<ProxyGroup> groups,
  Iterable<String> outbounds,
) {
  final known = {
    ...outbounds,
    ...RuleTarget.baseTargets,
    for (final group in groups) group.name,
  };
  final missing = <String, List<String>>{};
  final pruned = [
    for (final group in groups)
      () {
        final proxies = group.proxies ?? const <String>[];
        final kept = [
          for (final name in proxies)
            if (known.contains(name)) name,
        ];
        if (kept.length == proxies.length) {
          return group;
        }
        missing[group.name] = [
          for (final name in proxies)
            if (!known.contains(name)) name,
        ];
        final drawsElsewhere =
            group.use?.isNotEmpty == true ||
            group.includeAllProxies == true ||
            group.includeAllProviders == true;
        return group.copyWith(
          proxies: kept.isEmpty && !drawsElsewhere ? const ['REJECT'] : kept,
        );
      }(),
  ];
  return (groups: pruned, missing: missing);
}
