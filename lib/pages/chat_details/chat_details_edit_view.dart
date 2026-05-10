import 'package:dartz/dartz.dart';
import 'package:fluffychat/app_state/failure.dart';
import 'package:fluffychat/app_state/success.dart';
import 'package:fluffychat/domain/model/room/room_extension.dart';
import 'package:fluffychat/pages/chat_details/chat_details_edit.dart';
import 'package:fluffychat/pages/chat_details/chat_details_edit_option.dart';
import 'package:fluffychat/pages/chat_details/chat_details_edit_view_style.dart';
import 'package:fluffychat/presentation/model/pick_avatar_state.dart';
import 'package:fluffychat/resource/image_paths.dart';
import 'package:fluffychat/utils/matrix_sdk_extensions/matrix_locals.dart';
import 'package:fluffychat/utils/platform_infos.dart';
import 'package:fluffychat/widgets/app_bars/twake_app_bar.dart';
import 'package:fluffychat/widgets/avatar/avatar.dart';
import 'package:fluffychat/widgets/context_menu_builder_ios_paste_without_permission.dart';
import 'package:fluffychat/widgets/mixins/popup_menu_widget_style.dart';
import 'package:fluffychat/widgets/stream_image_view.dart';
import 'package:fluffychat/widgets/twake_components/twake_icon_button.dart';
import 'package:flutter/material.dart';
import 'package:fluffychat/generated/l10n/app_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:matrix/matrix.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

class ChatDetailsEditView extends StatelessWidget {
  final ChatDetailsEditController controller;

  const ChatDetailsEditView(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    if (controller.room == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF131314),
        appBar: AppBar(
          backgroundColor: const Color(0xFF131314),
          title: Text(
            L10n.of(context)!.oopsSomethingWentWrong,
            style: const TextStyle(color: Colors.white),
          ),
        ),
        body: Center(
          child: Text(
            L10n.of(context)!.youAreNoLongerParticipatingInThisChat,
            style: const TextStyle(color: Color(0xFF919191)),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF131314),
      resizeToAvoidBottomInset: false,
      appBar: TwakeAppBar(
        title: L10n.of(context)!.edit,
        leading: TwakeIconButton(
          paddingAll: 8,
          splashColor: Colors.transparent,
          hoverColor: Colors.transparent,
          highlightColor: Colors.transparent,
          iconColor: Colors.white,
          onTap: controller.onBack,
          icon: Icons.arrow_back_ios,
        ),
        enableLeftTitle: true,
        centerTitle: true,
        withDivider: false,
        actions: [
          ValueListenableBuilder(
            valueListenable: controller.isValidGroupNameNotifier,
            builder: (context, isValid, child) {
              return ValueListenableBuilder(
                valueListenable: controller.isEditedGroupInfoNotifier,
                builder: (context, value, child) {
                  if (!value || !isValid) {
                    return const SizedBox.shrink();
                  }
                  return child!;
                },
                child: Padding(
                  padding: ChatDetailEditViewStyle.doneIconPadding,
                  child: IconButton(
                    highlightColor: Colors.transparent,
                    hoverColor: Colors.transparent,
                    splashColor: Colors.transparent,
                    onPressed: () => controller.handleSaveAction(context),
                    icon: const Icon(Icons.done, color: Colors.white),
                  ),
                ),
              );
            },
          ),
        ],
        context: context,
      ),
      body: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            Padding(
              padding: ChatDetailEditViewStyle.editAvatarPadding,
              child: Center(
                child: Stack(
                  children: [
                    Padding(
                      padding: ChatDetailEditViewStyle.avatarPadding,
                      child: SizedBox(
                        width: ChatDetailEditViewStyle.avatarSize(context),
                        height: ChatDetailEditViewStyle.avatarSize(context),
                        child: Hero(
                          tag: 'content_banner',
                          child: _AvatarBuilder(
                            updateGroupAvatarNotifier:
                                controller.pickAvatarUIState,
                            room: controller.room!,
                            onImageLoaded: controller.updateAvatarFilePicker,
                          ),
                        ),
                      ),
                    ),
                    if (controller.room?.canChangeRoomAvatar == true)
                      Positioned(
                        bottom: 14,
                        right: 14,
                        child: ValueListenableBuilder(
                          valueListenable: controller.isEditedGroupInfoNotifier,
                          builder: (context, _, __) {
                            return MenuAnchor(
                              controller: controller.menuController,
                              style: MenuStyle(
                                padding: const WidgetStatePropertyAll(
                                  EdgeInsets.zero,
                                ),
                                backgroundColor: const WidgetStatePropertyAll(
                                  Color(0xFF2A2A2B),
                                ),
                              ),
                              alignmentOffset:
                                  ChatDetailEditViewStyle.contextMenuAlignmentOffset(
                                    context,
                                  ),
                              builder:
                                  (
                                    BuildContext context,
                                    MenuController menuController,
                                    Widget? child,
                                  ) {
                                    return GestureDetector(
                                      onTap: () => menuController.isOpen
                                          ? menuController.close()
                                          : menuController.open(),
                                      child: Container(
                                        width: 22,
                                        height: 22,
                                        color: Colors.white,
                                        child: const Icon(
                                          Icons.edit_outlined,
                                          size: 14,
                                          color: Color(0xFF131314),
                                        ),
                                      ),
                                    );
                                  },
                              menuChildren: controller.listContextMenuBuilder(
                                context,
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(
              height: ChatDetailEditViewStyle.avatarAndTextFieldsGap,
            ),
            Padding(
              padding: ChatDetailEditViewStyle.editAvatarPadding,
              child: Column(
                children: [
                  _GroupNameField(controller: controller),
                  const SizedBox(height: ChatDetailEditViewStyle.textFieldsGap),
                  _DescriptionField(controller: controller),
                  const SizedBox(height: 20),
                  ValueListenableBuilder(
                    valueListenable: controller.isRoomEnabledEncryptionNotifier,
                    builder: (context, isRoomEnabledEncryption, child) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: const BoxDecoration(
                          color: Color(0xFF1C1B1C),
                          border: Border.fromBorderSide(
                            BorderSide(color: Color(0x33474747)),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            SvgPicture.asset(
                              ImagePaths.icShieldLockFill,
                              width: 18,
                              height: 18,
                              colorFilter: const ColorFilter.mode(
                                Color(0xFFB0B0B0),
                                BlendMode.srcIn,
                              ),
                            ),
                            const SizedBox(width: 12),
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
                                  const SizedBox(height: 3),
                                  Text(
                                    L10n.of(context)!
                                        .yourDataIsEncryptedForSecurity,
                                    style: const TextStyle(
                                      color: Color(0xFF919191),
                                      fontSize: 11,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
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
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            if (controller.room?.canAssignRoles == true)
              StreamBuilder(
                stream: controller.room?.powerLevelsChanged,
                builder: (context, snapshot) {
                  return Column(
                    children: [
                      _ZeonSectionHeader(
                        L10n.of(context)!.administration,
                      ),
                      ChatDetailsEditOption(
                        title: L10n.of(context)!.assignRoles,
                        counterText:
                            '${controller.room?.getAssignRolesMember().length}',
                        subtitleColor: const Color(0xFF636363),
                        leading: Icons.admin_panel_settings_outlined,
                        titleColor: const Color(0xFFE5E2E3),
                        leadingIconColor: const Color(0xFFB0B0B0),
                        onTap: controller.openAssignRolesPage,
                      ),
                      if (controller.room?.getExceptionsMember().isNotEmpty ==
                          true)
                        ChatDetailsEditOption(
                          title: L10n.of(context)!.exceptions,
                          counterText:
                              '${controller.room?.getExceptionsMember().length}',
                          subtitleColor: const Color(0xFF636363),
                          leading: Icons.people_outlined,
                          titleColor: const Color(0xFFE5E2E3),
                          leadingIconColor: const Color(0xFFB0B0B0),
                          onTap: controller.openExceptionsPage,
                        ),
                      if (controller.room?.getBannedMembers().isNotEmpty ==
                          true)
                        ChatDetailsEditOption(
                          title: L10n.of(context)!.removedUsers,
                          counterText:
                              '${controller.room?.getBannedMembers().length}',
                          subtitleColor: const Color(0xFF636363),
                          leading: Icons.block,
                          titleColor: const Color(0xFFE5E2E3),
                          leadingIconColor: const Color(0xFFB0B0B0),
                          onTap: controller.openRemovedPage,
                        ),
                    ],
                  );
                },
              ),
            if (!controller.isSupportChat) ...[
              _ZeonSectionHeader(L10n.of(context)!.dangerZone),
              ChatDetailsEditOption(
                title: L10n.of(context)!.commandHint_leave,
                subtitle: L10n.of(context)!.leaveGroupSubtitle,
                leading: Icons.logout_outlined,
                titleColor: const Color(0xFFFFB4AB),
                leadingIconColor: const Color(0xFFFFB4AB),
                subtitleColor: const Color(0xFF636363),
                onTap: () => controller.leaveChat(context, controller.room),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AvatarBuilder extends StatelessWidget {
  final ValueNotifier<Either<Failure, Success>> updateGroupAvatarNotifier;
  final Room room;
  final Function(MatrixFile) onImageLoaded;

  const _AvatarBuilder({
    required this.updateGroupAvatarNotifier,
    required this.room,
    required this.onImageLoaded,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: updateGroupAvatarNotifier,
      builder: (context, value, child) => value.fold(
        (failure) {
          if (failure is GetAvatarBigSizeUIStateFailure ||
              failure is GetAvatarUIStateFailure) {
            return child!;
          }
          return const SizedBox();
        },
        (success) {
          if (PlatformInfos.isMobile) {
            if (success is GetAvatarOnMobileUIStateSuccess) {
              if (success.assetEntity == null) {
                return child!;
              }
              return ClipRRect(
                borderRadius: BorderRadius.zero,
                child: SizedBox.fromSize(
                  size: Size(
                    ChatDetailEditViewStyle.thumbnailSizeWidth.toDouble(),
                    ChatDetailEditViewStyle.thumbnailSizeHeight.toDouble(),
                  ),
                  child: AssetEntityImage(
                    success.assetEntity!,
                    thumbnailSize: const ThumbnailSize(
                      ChatDetailEditViewStyle.thumbnailSizeWidth,
                      ChatDetailEditViewStyle.thumbnailSizeHeight,
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
            }

            if (success is DeleteAvatarUIStateSuccess) {
              return Avatar(
                fontSize: ChatDetailEditViewStyle.avatarFontSize,
                name: room.getLocalizedDisplayname(
                  MatrixLocals(L10n.of(context)!),
                ),
                size: ChatDetailEditViewStyle.avatarSize(context),
              );
            }
          }

          if (PlatformInfos.isWeb) {
            if (success is GetAvatarOnWebUIStateSuccess) {
              if (success.matrixFile == null) {
                return child!;
              }
              return ClipRRect(
                borderRadius: BorderRadius.zero,
                child: SizedBox.fromSize(
                  size: Size(
                    ChatDetailEditViewStyle.avatarRadiusForWeb * 2,
                    ChatDetailEditViewStyle.avatarRadiusForWeb * 2,
                  ),
                  child: StreamImageViewer(
                    matrixFile: success.matrixFile!,
                    onImageLoaded: onImageLoaded,
                  ),
                ),
              );
            }

            if (success is DeleteAvatarUIStateSuccess) {
              return Avatar(
                fontSize: ChatDetailEditViewStyle.avatarFontSize,
                name: room.getLocalizedDisplayname(
                  MatrixLocals(L10n.of(context)!),
                ),
                size: ChatDetailEditViewStyle.avatarSize(context),
              );
            }
          }
          return child!;
        },
      ),
      child: Avatar(
        fontSize: ChatDetailEditViewStyle.avatarFontSize,
        mxContent: room.avatar,
        name: room.getLocalizedDisplayname(MatrixLocals(L10n.of(context)!)),
        size: ChatDetailEditViewStyle.avatarSize(context),
      ),
    );
  }
}

class _ZeonSectionHeader extends StatelessWidget {
  final String label;
  const _ZeonSectionHeader(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0E0E0F),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Text(
        label.toUpperCase(),
        style: ChatDetailEditViewStyle.textChatDetailsEditCategoryStyle(
          context,
        ),
      ),
    );
  }
}

class _GroupNameField extends StatelessWidget {
  const _GroupNameField({required this.controller});

  final ChatDetailsEditController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: controller.isValidGroupNameNotifier,
      builder: (context, value, _) {
        return TextField(
          enabled: controller.room?.canChangeRoomName ?? false,
          style: ChatDetailEditViewStyle.textFieldStyle(context),
          controller: controller.groupNameTextEditingController,
          contextMenuBuilder: mobileTwakeContextMenuBuilder,
          focusNode: controller.groupNameFocusNode,
          onTapOutside: (_) {
            controller.groupNameFocusNode.unfocus();
          },
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
            labelText: L10n.of(context)!.groupName,
            labelStyle: ChatDetailEditViewStyle.textFieldLabelStyle(context),
            hintText: L10n.of(context)!.enterGroupName,
            hintStyle: ChatDetailEditViewStyle.textFieldHintStyle(context),
            contentPadding: ChatDetailEditViewStyle.contentPadding,
            errorText: controller.getErrorMessage(
              controller.groupNameTextEditingController.text,
            ),
            errorStyle: const TextStyle(color: Color(0xFFFFB4AB)),
            suffixIcon: ValueListenableBuilder<bool>(
              valueListenable: controller.groupNameEmptyNotifier,
              builder: (context, isGroupNameEmpty, child) {
                if (controller.room?.canChangeRoomName == false) {
                  return child!;
                }
                if (isGroupNameEmpty) {
                  return child!;
                }
                return IconButton(
                  onPressed: () =>
                      controller.groupNameTextEditingController.clear(),
                  icon: const Icon(
                    Icons.cancel_outlined,
                    size: ChatDetailEditViewStyle.clearIconSize,
                    color: Color(0xFF636363),
                  ),
                );
              },
              child: const SizedBox.shrink(),
            ),
          ),
        );
      },
    );
  }
}

class _DescriptionField extends StatelessWidget {
  const _DescriptionField({required this.controller});

  final ChatDetailsEditController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          enabled: controller.room?.canChangeTopic ?? false,
          style: ChatDetailEditViewStyle.textFieldStyle(context),
          controller: controller.descriptionTextEditingController,
          contextMenuBuilder: mobileTwakeContextMenuBuilder,
          focusNode: controller.descriptionFocusNode,
          onTapOutside: (_) {
            controller.descriptionFocusNode.unfocus();
          },
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
            border: const OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF474747)),
            ),
            labelText: L10n.of(context)!.description,
            labelStyle: ChatDetailEditViewStyle.textFieldLabelStyle(context),
            hintText: L10n.of(context)!.description,
            hintStyle: ChatDetailEditViewStyle.textFieldHintStyle(context),
            contentPadding: ChatDetailEditViewStyle.contentPadding,
            suffixIcon: ValueListenableBuilder<bool>(
              valueListenable: controller.descriptionEmptyNotifier,
              builder: (context, isDescriptionEmpty, child) {
                if (controller.room?.canChangeTopic == false) {
                  return child!;
                }

                if (isDescriptionEmpty) {
                  return child!;
                }

                return IconButton(
                  onPressed: () =>
                      controller.descriptionTextEditingController.clear(),
                  icon: const Icon(
                    Icons.cancel_outlined,
                    size: ChatDetailEditViewStyle.clearIconSize,
                    color: Color(0xFF636363),
                  ),
                );
              },
              child: const SizedBox.shrink(),
            ),
          ),
        ),
        const SizedBox(height: 2.0),
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Text(
            L10n.of(context)!.descriptionHelper,
            style: const TextStyle(
              color: Color(0xFF636363),
              fontSize: 11,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ],
    );
  }
}
