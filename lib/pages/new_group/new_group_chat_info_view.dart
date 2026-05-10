import 'package:dartz/dartz.dart';
import 'package:fluffychat/app_state/failure.dart';
import 'package:fluffychat/app_state/success.dart';
import 'package:fluffychat/pages/new_group/new_group_chat_info.dart';
import 'package:fluffychat/pages/new_group/new_group_chat_info_style.dart';
import 'package:fluffychat/pages/new_group/new_group_info_controller.dart';
import 'package:fluffychat/pages/new_group/widget/expansion_participants_list.dart';
import 'package:fluffychat/presentation/model/pick_avatar_state.dart';
import 'package:fluffychat/resource/image_paths.dart';
import 'package:fluffychat/widgets/app_bars/twake_app_bar.dart';
import 'package:fluffychat/widgets/context_menu_builder_ios_paste_without_permission.dart';
import 'package:fluffychat/widgets/stream_image_view.dart';
import 'package:fluffychat/widgets/twake_components/twake_fab.dart';
import 'package:fluffychat/widgets/twake_components/twake_icon_button.dart';
import 'package:flutter/material.dart';
import 'package:fluffychat/generated/l10n/app_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:matrix/matrix.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

class NewGroupChatInfoView extends StatelessWidget {
  final NewGroupChatInfoController newGroupInfoController;

  const NewGroupChatInfoView(this.newGroupInfoController, {super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF131314),
      appBar: _buildAppBar(context),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverOverlapAbsorber(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
              sliver: SliverToBoxAdapter(
                child: Column(
                  children: [
                    Padding(
                      padding: NewGroupChatInfoStyle.profilePadding,
                      child: _buildChangeProfileWidget(context),
                    ),
                    const SizedBox(height: 24),
                    _buildGroupNameTextField(context),
                    const SizedBox(height: 16),
                    const _ZeonEncryptionBadge(),
                  ],
                ),
              ),
            ),
          ];
        },
        body: Padding(
          padding: NewGroupChatInfoStyle.padding,
          child: ExpansionParticipantsList(
            contactsList: newGroupInfoController.contactsList ?? {},
          ),
        ),
      ),
      floatingActionButton: ValueListenableBuilder<bool>(
        valueListenable: newGroupInfoController.haveGroupNameNotifier,
        builder: (context, value, child) {
          if (!value) {
            return const SizedBox.shrink();
          }
          return child!;
        },
        child: ValueListenableBuilder<Either<Failure, Success>?>(
          valueListenable: newGroupInfoController.createRoomStateNotifier,
          builder: (context, _, __) {
            return ValueListenableBuilder<Either<Failure, Success>?>(
              valueListenable: newGroupInfoController.inviteUserStateNotifier,
              builder: (context, _, ___) {
                if (newGroupInfoController.isCreatingRoom) {
                  return const TwakeFloatingActionButton(
                    customIcon: SizedBox(child: CircularProgressIndicator()),
                  );
                }
                return TwakeFloatingActionButton(
                  icon: Icons.done,
                  onTap: () => newGroupInfoController.moveToGroupChatScreen(),
                );
              },
            );
          },
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(NewGroupChatInfoStyle.toolbarHeight),
      child: TwakeAppBar(
        title: L10n.of(context)!.newGroupChat,
        context: context,
        centerTitle: true,
        withDivider: false,
        enableLeftTitle: true,
        isDialog: true,
        leading: TwakeIconButton(
          paddingAll: 8,
          splashColor: Colors.transparent,
          hoverColor: Colors.transparent,
          highlightColor: Colors.transparent,
          iconColor: Colors.white,
          onTap: () => Navigator.of(context).pop(),
          icon: Icons.arrow_back_ios,
        ),
      ),
    );
  }

  Widget _buildChangeProfileWidget(BuildContext context) {
    final size = NewGroupChatInfoStyle.profileSize(context);
    return GestureDetector(
      onTap: () =>
          newGroupInfoController.showImagesPickerAction(context: context),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            color: const Color(0xFF2A2A2B),
            alignment: Alignment.center,
            child: NewGroupChatInfoStyle.responsive.isMobile(context)
                ? _AvatarForMobileBuilder(
                    avatarMobileNotifier:
                        newGroupInfoController.avatarAssetEntityNotifier,
                  )
                : _AvatarForWebBuilder(
                    avatarWebNotifier: newGroupInfoController.pickAvatarUIState,
                    onImageLoaded: newGroupInfoController.updateAvatarFilePicker,
                  ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                color: Colors.white,
              ),
              child: const Icon(
                Icons.add,
                size: 16,
                color: Color(0xFF131314),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupNameTextField(BuildContext context) {
    return Padding(
      padding: NewGroupChatInfoStyle.groupNameTextFieldPadding,
      child: ValueListenableBuilder(
        valueListenable: newGroupInfoController.createRoomStateNotifier,
        builder: (context, value, child) {
          return ValueListenableBuilder(
            valueListenable:
                newGroupInfoController.groupNameTextEditingController,
            builder: (context, value, _) {
              return TextField(
                controller:
                    newGroupInfoController.groupNameTextEditingController,
                focusNode: newGroupInfoController.groupNameFocusNode,
                enabled: !newGroupInfoController.isCreatingRoom,
                style: const TextStyle(color: Color(0xFFE5E2E3)),
                cursorColor: Colors.white,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF1C1B1C),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: const Color(0xFF474747).withValues(alpha: 0.5),
                    ),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF919191)),
                  ),
                  errorBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFFFB4AB)),
                  ),
                  focusedErrorBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFFFB4AB)),
                  ),
                  border: const OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF474747)),
                  ),
                  errorText: newGroupInfoController.getErrorMessage(
                    newGroupInfoController.groupNameTextEditingController.text,
                  ),
                  errorStyle: const TextStyle(color: Color(0xFFFFB4AB)),
                  labelText: L10n.of(context)!.widgetName,
                  labelStyle: const TextStyle(
                    color: Color(0xFF919191),
                    fontSize: 12,
                    letterSpacing: 0.4,
                  ),
                  hintText: L10n.of(context)!.enterGroupName,
                  hintStyle: const TextStyle(color: Color(0xFF636363)),
                  contentPadding: NewGroupChatInfoStyle.contentPadding,
                ),
                contextMenuBuilder: mobileTwakeContextMenuBuilder,
              );
            },
          );
        },
      ),
    );
  }
}

class _AvatarForMobileBuilder extends StatelessWidget {
  final ValueNotifier<AssetEntity?> avatarMobileNotifier;

  const _AvatarForMobileBuilder({required this.avatarMobileNotifier});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: avatarMobileNotifier,
      builder: (context, value, child) {
        if (value == null) {
          return child!;
        }
        return ClipRRect(
          borderRadius: BorderRadius.zero,
          child: SizedBox.fromSize(
            size: Size(
              NewGroupChatInfoStyle.thumbnailSizeWidth.toDouble(),
              NewGroupChatInfoStyle.thumbnailSizeHeight.toDouble(),
            ),
            child: AssetEntityImage(
              value,
              thumbnailSize: const ThumbnailSize(
                NewGroupChatInfoStyle.thumbnailSizeWidth,
                NewGroupChatInfoStyle.thumbnailSizeHeight,
              ),
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress != null &&
                    loadingProgress.cumulativeBytesLoaded !=
                        loadingProgress.expectedTotalBytes) {
                  return const Center(
                    child: CircularProgressIndicator.adaptive(),
                  );
                }
                return child;
              },
              errorBuilder: (context, error, stackTrace) {
                return const Center(child: Icon(Icons.error_outline));
              },
            ),
          ),
        );
      },
      child: const Icon(
        Icons.camera_alt_outlined,
        color: Color(0xFF919191),
      ),
    );
  }
}

class _AvatarForWebBuilder extends StatelessWidget {
  final ValueNotifier<Either<Failure, Success>> avatarWebNotifier;
  final Function(MatrixFile) onImageLoaded;

  const _AvatarForWebBuilder({
    required this.avatarWebNotifier,
    required this.onImageLoaded,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: avatarWebNotifier,
      builder: (context, uiState, child) => uiState.fold(
        (failure) {
          if (failure is GetAvatarBigSizeUIStateFailure ||
              failure is GetAvatarUIStateFailure) {
            return child!;
          }
          return const SizedBox();
        },
        (success) {
          if (success is GetAvatarOnWebUIStateSuccess) {
            return ClipRRect(
              borderRadius: BorderRadius.zero,
              child: SizedBox.fromSize(
                size: Size(
                  NewGroupChatInfoStyle.avatarRadiusForWeb * 2,
                  NewGroupChatInfoStyle.avatarRadiusForWeb * 2,
                ),
                child: StreamImageViewer(
                  matrixFile: success.matrixFile!,
                  onImageLoaded: onImageLoaded,
                ),
              ),
            );
          }
          return child!;
        },
      ),
      child: const Icon(
        Icons.add_a_photo_outlined,
        color: Color(0xFF919191),
      ),
    );
  }
}

class _ZeonEncryptionBadge extends StatelessWidget {
  const _ZeonEncryptionBadge();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF201F20),
          border: Border.all(color: const Color(0x33474747)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
        child: Row(
          children: [
            SvgPicture.asset(
              ImagePaths.icE2EEncryptionMessageIndicator,
              width: 18,
              height: 18,
              colorFilter: const ColorFilter.mode(
                Color(0xFFB0B0B0),
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: 12.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'END-TO-END ENCRYPTED',
                    style: TextStyle(
                      color: Color(0xFFE5E2E3),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.8,
                    ),
                  ),
                  const SizedBox(height: 3.0),
                  Text(
                    L10n.of(context)!.encryptionMessage,
                    style: const TextStyle(
                      color: Color(0xFF919191),
                      fontSize: 11,
                      letterSpacing: 0.3,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8.0),
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Color(0xFF4CAF50),
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
