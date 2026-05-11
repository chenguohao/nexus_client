import 'package:fluffychat/config/default_power_level_member.dart';
import 'package:fluffychat/pages/chat_details/assign_roles_role_picker/assign_roles_role_picker.dart';
import 'package:fluffychat/pages/chat_details/assign_roles_role_picker/assign_roles_role_picker_style.dart';
import 'package:fluffychat/resource/image_paths.dart';
import 'package:fluffychat/widgets/app_bars/twake_app_bar.dart';
import 'package:fluffychat/widgets/avatar/avatar.dart';
import 'package:fluffychat/widgets/expandable_widget.dart';
import 'package:fluffychat/widgets/twake_components/twake_icon_button.dart';
import 'package:fluffychat/widgets/twake_components/twake_text_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fluffychat/generated/l10n/app_localizations.dart';

class AssignRolesRolePickerView extends StatelessWidget {
  final AssignRolesEditorController controller;
  final bool isDialog;

  const AssignRolesRolePickerView({
    super.key,
    required this.controller,
    this.isDialog = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF131314),
      resizeToAvoidBottomInset: false,
      appBar: TwakeAppBar(
        title: L10n.of(context)!.assignRoles,
        centerTitle: true,
        withDivider: false,
        context: context,
        enableLeftTitle: true,
        isDialog: isDialog,
        backgroundColor: const Color(0xFF131314),
        leading: TwakeIconButton(
          paddingAll: 8,
          splashColor: Colors.transparent,
          hoverColor: Colors.transparent,
          highlightColor: Colors.transparent,
          iconColor: Colors.white,
          onTap: () => Navigator.of(context).pop(),
          icon: Icons.arrow_back_ios,
        ),
        actions: isDialog
            ? [
                TwakeIconButton(
                  paddingAll: 8,
                  splashColor: Colors.transparent,
                  hoverColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  iconColor: Colors.white,
                  onTap: () =>
                      Navigator.of(context).popUntil((route) => route.isFirst),
                  icon: Icons.close,
                ),
              ]
            : null,
      ),
      body: SizedBox(
        height: double.infinity,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 56),
                child: Column(
                  children: [
                    selectedUsersList(context),
                    // "Select role" section header
                    Container(
                      color: const Color(0xFF1C1B1C),
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      margin: isDialog
                          ? const EdgeInsets.symmetric(horizontal: 16)
                          : null,
                      child: Text(
                        L10n.of(context)!.selectRole,
                        style: const TextStyle(
                          color: Color(0xFF919191),
                          fontSize: 12,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      itemBuilder: (context, index) {
                        return ValueListenableBuilder(
                          valueListenable: controller.roleSelectedNotifier,
                          builder: (context, isSelected, child) {
                            return _expandableItemWidget(
                              context: context,
                              index: index,
                              isSelected: isSelected,
                            );
                          },
                        );
                      },
                      itemCount:
                          controller.widget.rolePickerType.assignRoles.length,
                    ),
                  ],
                ),
              ),
            ),
            // Bottom action buttons
            ValueListenableBuilder(
              valueListenable: controller.roleSelectedNotifier,
              builder: (context, roleSelected, child) {
                if (roleSelected == null) return const SizedBox.shrink();
                return Container(
                  padding: EdgeInsets.only(
                    bottom: 24,
                    left: 16,
                    right: isDialog ? 36 : 16,
                    top: isDialog ? 36 : 16,
                  ),
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Color(0x1F474747)),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: TwakeTextButton(
                          onTap: () => Navigator.of(context).pop(),
                          message: L10n.of(context)!.cancel,
                          borderHover: 0,
                          buttonDecoration: BoxDecoration(
                            border: Border.all(
                              color: const Color(0x33474747),
                            ),
                          ),
                          styleMessage: const TextStyle(
                            color: Color(0xFF919191),
                            fontSize: 14,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      TwakeTextButton(
                        message: L10n.of(context)!.done,
                        onTap: controller.onTapToDoneButton,
                        borderHover: 0,
                        buttonDecoration: BoxDecoration(
                          color: const Color(0xFF2A2A2B),
                          border: Border.all(
                            color: const Color(0x33474747),
                          ),
                        ),
                        styleMessage: const TextStyle(
                          color: Color(0xFFE5E2E3),
                          fontSize: 14,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _expandableItemWidget({
    required BuildContext context,
    required int index,
    DefaultPowerLevelMember? isSelected,
  }) {
    final role = controller.widget.rolePickerType.assignRoles[index];
    final checked = isSelected == role;

    return ExpandableWidget(
      dividerPadding: isDialog
          ? const EdgeInsets.symmetric(horizontal: 16)
          : null,
      isExpanded: checked,
      parentWidget: Row(
        children: [
          // Role icon in dark square
          Container(
            width: AssignRolesRolePickerStyle.assignRoleIconSize,
            height: AssignRolesRolePickerStyle.assignRoleIconSize,
            decoration: const BoxDecoration(
              color: Color(0xFF2A2A2B),
            ),
            child: Center(child: controller.iconForRoles(role)),
          ),
          const SizedBox(width: 8.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  role.displayName(context),
                  style: const TextStyle(
                    color: Color(0xFFE5E2E3),
                    fontSize: 15,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w400,
                  ),
                ),
                Text(
                  controller.subtitleForRoles(role),
                  style: const TextStyle(
                    color: Color(0xFF636363),
                    fontSize: 12,
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
          ),
          // Radio indicator
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            switchOutCurve: Curves.easeInOut,
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: SizedBox(
              key: ValueKey(checked),
              width: 24,
              height: 24,
              child: SvgPicture.asset(
                checked
                    ? ImagePaths.icRadioChecked
                    : ImagePaths.icRadioUnchecked,
                colorFilter: ColorFilter.mode(
                  checked
                      ? const Color(0xFFE5E2E3)
                      : const Color(0xFF636363),
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
        ],
      ),
      childWidget: controller.permissionsWidgetForRoles(role),
      onTap: () => controller.onSelectedRole(role),
    );
  }

  Widget selectedUsersList(BuildContext context) {
    final users = controller.widget.assignedUsers;

    if (users.isEmpty) return const SizedBox.shrink();

    if (users.length == 1) {
      return Container(
        padding: const EdgeInsets.all(12),
        margin: EdgeInsets.only(
          left: isDialog ? 16 : 0,
          right: isDialog ? 16 : 0,
          bottom: 4,
        ),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0x1F474747)),
          ),
        ),
        child: Row(
          children: [
            Avatar(
              mxContent: users.first.avatarUrl,
              name: users.first.calcDisplayname(),
            ),
            const SizedBox(width: 8.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    users.first.calcDisplayname(),
                    style: const TextStyle(
                      color: Color(0xFFE5E2E3),
                      fontSize: 14,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  Text(
                    users.first.id,
                    style: const TextStyle(
                      color: Color(0xFF636363),
                      fontSize: 12,
                      fontFamily: 'Inter',
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Multiple users: chip list
    return AnimatedSize(
      curve: Curves.easeIn,
      alignment: Alignment.bottomCenter,
      duration: const Duration(milliseconds: 250),
      child: SizedBox(
        width: MediaQuery.sizeOf(context).width,
        child: Padding(
          padding: EdgeInsets.only(
            left: isDialog ? 16 : 8,
            bottom: 8,
            right: isDialog ? 16 : 8,
          ),
          child: Wrap(
            spacing: 8.0,
            children: users.map((member) {
              return Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2B),
                  border: Border.all(color: const Color(0x33474747)),
                  borderRadius: BorderRadius.circular(
                    AssignRolesRolePickerStyle.avatarChipSize,
                  ),
                ),
                margin: AssignRolesRolePickerStyle.chipMargin,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Avatar(
                      mxContent: member.avatarUrl,
                      name: member.calcDisplayname(),
                      size: AssignRolesRolePickerStyle.avatarChipSize,
                    ),
                    const SizedBox(width: 4.0),
                    Flexible(
                      child: Padding(
                        padding: AssignRolesRolePickerStyle.textChipPadding,
                        child: Text(
                          member.calcDisplayname(),
                          style: const TextStyle(
                            color: Color(0xFFE5E2E3),
                            fontSize: 13,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
