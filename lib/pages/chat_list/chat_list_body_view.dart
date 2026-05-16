import 'package:animations/animations.dart';
import 'package:dartz/dartz.dart' hide State;
import 'package:fluffychat/app_state/failure.dart';
import 'package:fluffychat/app_state/success.dart';
import 'package:fluffychat/config/themes.dart';
import 'package:fluffychat/di/global/get_it_initializer.dart';
import 'package:fluffychat/domain/contact_manager/contacts_manager.dart';
import 'package:fluffychat/pages/chat_list/chat_list.dart';
import 'package:fluffychat/pages/chat_list/chat_list_body_view_style.dart';
import 'package:fluffychat/pages/chat_list/chat_list_skeletonizer_widget.dart';
import 'package:fluffychat/pages/chat_list/chat_list_view_builder.dart';
import 'package:fluffychat/pages/chat_list/space_view.dart';
import 'package:fluffychat/presentation/enum/chat_list/chat_list_enum.dart';
import 'package:fluffychat/resource/image_paths.dart';
import 'package:fluffychat/utils/stream_extension.dart';
import 'package:fluffychat/widgets/connection_status_header.dart';
import 'package:flutter/material.dart';
import 'package:fluffychat/generated/l10n/app_localizations.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:linagora_design_flutter/linagora_design_flutter.dart';
import 'package:matrix/matrix.dart';

/// 首屏空列表欢迎区：个人资料请求只发起一次，避免外层 Stream / 通讯录重建时
/// [FutureBuilder] 拿到新 Future、回到 waiting 状态导致欢迎文案一闪一闪。
class _WelcomeEmptyView extends StatefulWidget {
  final Client client;

  const _WelcomeEmptyView({super.key, required this.client});

  @override
  State<_WelcomeEmptyView> createState() => _WelcomeEmptyViewState();
}

class _WelcomeEmptyViewState extends State<_WelcomeEmptyView> {
  late final Future<Profile?> _profileFuture = widget.client
      .fetchOwnProfile(getFromRooms: false);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Padding(
          padding: ChatListBodyViewStyle.paddingIconSkeletons,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [SvgPicture.asset(ImagePaths.icSkeletons)],
          ),
        ),
        Padding(
          padding: ChatListBodyViewStyle.paddingOwnProfile,
          child: FutureBuilder<Profile?>(
            future: _profileFuture,
            builder: (context, snapshotProfile) {
              if (snapshotProfile.connectionState != ConnectionState.done) {
                // 占位高度，避免完成后突然出现一大块文案造成抖动
                return const SizedBox(height: 80);
              }
              final name = snapshotProfile.data?.displayName ?? '👋';
              return Column(
                children: [
                  Text(
                    L10n.of(context)!.welcomeToTwake(name),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  Padding(
                    padding: ChatListBodyViewStyle.paddingTextStartNewChatMessage,
                    child: Text(
                      L10n.of(context)!.startNewChatMessage,
                      style: const TextStyle(
                        color: Color(0xFFC6C6C6),
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class ChatListBodyView extends StatelessWidget {
  final ChatListController controller;

  const ChatListBodyView(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: FocusManager.instance.primaryFocus?.unfocus,
      excludeFromSemantics: true,
      behavior: HitTestBehavior.translucent,
      child: PageTransitionSwitcher(
        transitionBuilder:
            (
              Widget child,
              Animation<double> primaryAnimation,
              Animation<double> secondaryAnimation,
            ) {
              return SharedAxisTransition(
                animation: primaryAnimation,
                secondaryAnimation: secondaryAnimation,
                transitionType: SharedAxisTransitionType.vertical,
                fillColor: const Color(0xFF131314),
                child: child,
              );
            },
        child: SlidableAutoCloseBehavior(
          child: StreamBuilder(
            key: ValueKey(
              controller.activeClient.userID.toString() +
                  controller.activeFilter.toString() +
                  controller.activeSpaceId.toString(),
            ),
            // Rebuild on any sync (rate-limited), not only `hasRoomUpdate`.
            // New accounts can complete first /sync with no rooms / account_data /
            // to_device in the parsed update; `prevBatch` still advances. Filtering
            // only `hasRoomUpdate` can then strand the list on the skeleton until restart.
            stream: controller.activeClient.onSync.stream
                .rateLimit(const Duration(seconds: 1)),
            builder: (context, _) {
              return ValueListenableBuilder<Either<Failure, Success>>(
                valueListenable:
                    getIt.get<ContactsManager>().getContactsNotifier(),
                builder: (context, _, __) {
                  final pb = controller.activeClient.prevBatch;
              final wfs = controller.matrixState.waitForFirstSync;
              String branch;
              if (controller.activeFilter == ActiveFilter.spaces) {
                branch = 'spaces';
              } else if (pb != null) {
                branch = controller.chatListShowsOnboardingWelcome
                    ? 'empty_welcome'
                    : 'room_list';
              } else if (wfs) {
                branch = 'skeleton';
              } else {
                branch = 'shrink';
              }
              Logs().i(
                '[ZeonDiag][ChatListBody] $branch '
                'prevBatch=${pb != null} waitFS=$wfs '
                'user=${controller.activeClient.userID}',
              );
              if (controller.activeFilter == ActiveFilter.spaces) {
                return SpaceView(
                  controller,
                  scrollController: controller.scrollController,
                  key: Key(controller.activeSpaceId ?? 'Spaces'),
                );
              }
              if (controller.activeClient.prevBatch != null) {
                if (controller.chatListShowsOnboardingWelcome) {
                  return _WelcomeEmptyView(
                    key: ValueKey(
                      controller.activeClient.userID ?? 'no_user',
                    ),
                    client: controller.activeClient,
                  );
                }
                return CustomScrollView(
                  controller: controller.scrollController,
                  slivers: [
                    SliverToBoxAdapter(
                      child: ConnectionStatusHeader(controller: controller),
                    ),
                    SliverToBoxAdapter(
                      child: AnimatedContainer(
                        height: ChatListBodyViewStyle.heightIsTorBrowser(
                          controller.isTorBrowser,
                        ),
                        duration: TwakeThemes.animationDuration,
                        curve: TwakeThemes.animationCurve,
                        clipBehavior: Clip.hardEdge,
                        decoration: const BoxDecoration(),
                        child: Material(
                          color: Theme.of(context).colorScheme.surface,
                          child: ListTile(
                            leading: const Icon(Icons.vpn_key),
                            title: Text(L10n.of(context)!.dehydrateTor),
                            subtitle: Text(L10n.of(context)!.dehydrateTorLong),
                            trailing: const Icon(Icons.chevron_right_outlined),
                            onTap: controller.dehydrate,
                          ),
                        ),
                      ),
                    ),
                    if (!controller.filteredRoomsForPinIsEmpty)
                      ValueListenableBuilder(
                        valueListenable: controller.expandRoomsForPinNotifier,
                        builder: (context, isExpanded, child) {
                          return child!;
                        },
                        child: ChatListViewBuilder(
                          controller: controller,
                          rooms: controller.filteredRoomsForPin,
                        ),
                      ),
                    if (!controller.filteredRoomsForAllIsEmpty)
                      ChatListViewBuilder(
                        controller: controller,
                        rooms: controller.filteredRoomsForAll,
                      ),
                  ],
                );
              }
              if (controller.matrixState.waitForFirstSync) {
                return const ChatListSkeletonizerWidget();
              }
              return const SizedBox.shrink();
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class ExpandableTitleBuilder extends StatelessWidget {
  final String title;
  final bool isExpanded;
  final VoidCallback? onTap;

  const ExpandableTitleBuilder({
    super.key,
    required this.title,
    this.isExpanded = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: ChatListBodyViewStyle.paddingHorizontalExpandableTitleBuilder,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: LinagoraRefColors.material().neutral[40],
              ),
            ),
            Padding(
              padding: ChatListBodyViewStyle.paddingIconExpand,
              child: Icon(
                isExpanded ? Icons.expand_less : Icons.expand_more,
                size: ChatListBodyViewStyle.sizeIconExpand,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
