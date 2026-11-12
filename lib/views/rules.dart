import 'package:collection/collection.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/views/connection/requests.dart';
import 'package:fl_clash/views/profiles/extend/extend.dart';
import 'package:fl_clash/views/profiles/extend/standard.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The current profile's own rules and auto groups, applied as they change,
/// for users who never open a profile's extension page.
class RulesView extends ConsumerWidget {
  const RulesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final profile = ref.watch(currentProfileProvider);
    final editable =
        profile != null &&
        profile.type != ProfileType.custom &&
        profile.extendType == ExtendType.standard;
    return Scaffold(
      title: PageLabel.rules.label,
      body: NullStatusSwitcher(
        isEmpty: !editable,
        nullStatus: NullStatus(
          label: profile == null
              ? appLocalizations.nullTip(appLocalizations.profiles)
              : appLocalizations.rulesEditedInProfile,
          illustration: NullStatusIllustration.rules,
          action: profile == null || profile.type == ProfileType.custom
              ? null
              : TonalButton(
                  size: TonalButtonSize.bar,
                  label: appLocalizations.extend,
                  onPressed: () => BaseNavigator.push(
                    context,
                    ExtendView(profileId: profile.id),
                  ),
                ),
        ),
        child: editable
            ? _RulesContent(key: ValueKey(profile.id), profileId: profile.id)
            : const SizedBox(),
      ),
    );
  }
}

class _RulesContent extends ConsumerStatefulWidget {
  final int profileId;

  const _RulesContent({super.key, required this.profileId});

  @override
  ConsumerState<_RulesContent> createState() => _RulesContentState();
}

class _RulesContentState extends ConsumerState<_RulesContent> {
  @override
  void initState() {
    super.initState();
    final profileId = widget.profileId;
    ref.listenManual(
      profileProvider(
        profileId,
      ).select((state) => (state?.matchTarget, state?.disabledRules)),
      (previous, next) => _apply(),
    );
    for (final provider in <ProviderListenable<AsyncValue<Object?>>>[
      profileRulesProvider(profileId),
      profileDisabledRuleIdsProvider(profileId),
      proxyGroupsProvider(profileId),
    ]) {
      ref.listenManual(provider, (previous, next) {
        if (previous?.hasValue == true &&
            next.hasValue &&
            !const DeepCollectionEquality().equals(
              previous!.value,
              next.value,
            )) {
          _apply();
        }
      });
    }
  }

  // The page has no apply button: what the user changes here is what they
  // expect the proxy to do next.
  void _apply() {
    ref.read(setupActionProvider.notifier).applyProfileDebounce(silence: true);
  }

  @override
  Widget build(BuildContext context) {
    return ProfileIdProvider(
      profileId: widget.profileId,
      child: ScrollConfiguration(
        behavior: const ShowBarScrollBehavior(),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: SizedBox(height: context.sectionsTopPadding),
            ),
            const StandardContent(),
            SliverToBoxAdapter(
              child: MoreActionButton(
                label: PageLabel.requests.label,
                onPressed: () =>
                    BaseNavigator.push(context, const RequestsView()),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(height: 16 + context.bottomInset),
            ),
          ],
        ),
      ),
    );
  }
}
