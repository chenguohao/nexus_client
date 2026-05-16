import 'package:dartz/dartz.dart' as dartz;
import 'package:fluffychat/app_state/failure.dart';
import 'package:fluffychat/app_state/success.dart';
import 'package:fluffychat/config/zeon_colors.dart';
import 'package:fluffychat/data/model/invitation/invitation_status_response.dart';
import 'package:fluffychat/domain/app_state/invitation/get_invitation_status_state.dart';
import 'package:fluffychat/domain/model/contact/contact_status.dart';
import 'package:fluffychat/pages/contacts_tab/contacts_invitation.dart';
import 'package:fluffychat/presentation/mixins/invitation_status_mixin.dart';
import 'package:fluffychat/presentation/model/contact/presentation_contact.dart';
import 'package:fluffychat/pages/new_private_chat/widget/contact_status_widget.dart';
import 'package:fluffychat/utils/adaptive_bottom_sheet.dart';
import 'package:fluffychat/utils/display_name_widget.dart';
import 'package:fluffychat/utils/string_extension.dart';
import 'package:fluffychat/widgets/avatar/avatar.dart';
import 'package:fluffychat/widgets/highlight_text.dart';
import 'package:fluffychat/widgets/matrix.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fluffychat/generated/l10n/app_localizations.dart';
import 'package:matrix/matrix.dart';

typedef OnExpansionListTileTap = void Function();

class ExpansionContactListTile extends StatefulWidget {
  final PresentationContact contact;
  final String highlightKeyword;
  final bool enableInvitation;
  final void Function()? onContactTap;

  /// 外层已包一层 [InkWell]（如建群多选、搜索建议）时设为 true，避免嵌套水波纹抢手势。
  final bool suppressInkWell;

  const ExpansionContactListTile({
    super.key,
    required this.contact,
    this.highlightKeyword = '',
    this.enableInvitation = false,
    this.onContactTap,
    this.suppressInkWell = false,
  });

  @override
  State<ExpansionContactListTile> createState() =>
      _ExpansionContactListTileState();
}

class _ExpansionContactListTileState extends State<ExpansionContactListTile>
    with InvitationStatusMixin {
  @override
  void initState() {
    if (widget.enableInvitation == true) {
      getInvitationStatus(
        userId: client.userID ?? '',
        contactId: widget.contact.id ?? '',
        contact: widget.contact,
      );
    }
    super.initState();
  }

  void _handleMatrixIdNull({
    required BuildContext context,
    required PresentationContact contact,
    InvitationStatusResponse? invitationStatus,
  }) async {
    if (invitationStatus?.invitation != null &&
        invitationStatus!.invitation?.hasMatrixId == true) {
      widget.onContactTap?.call();
      return;
    }
    if (widget.contact.matrixId != null &&
        widget.contact.matrixId!.isNotEmpty) {
      widget.onContactTap?.call();
      return;
    }
    if (client.userID == null && client.userID?.isEmpty == true) return;
    final result = await showAdaptiveBottomSheet<String?>(
      context: context,
      builder: (context) => ContactsInvitation(
        contact: contact,
        userId: client.userID!,
        invitationStatus: invitationStatus,
      ),
    );

    if (result != null) {
      getInvitationNetworkStatus(
        userId: client.userID ?? '',
        contactId: widget.contact.id ?? '',
        invitationId: result,
        contact: widget.contact,
      );
    }
  }

  @override
  void dispose() {
    disposeInvitationStatus();
    super.dispose();
  }

  Client get client => Matrix.of(context).client;

  @override
  Widget build(BuildContext context) {
    final tileBody = Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x1F474747))),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.only(
          start: 8.0,
          top: 8.0,
          bottom: 8.0,
        ),
        child: FutureBuilder<Profile?>(
          key: widget.contact.matrixId != null
              ? Key(widget.contact.matrixId!)
              : null,
          future: widget.contact.status == ContactStatus.active
              ? getProfile(context)
              : null,
          builder: (context, snapshot) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: IgnorePointer(
                    child: Avatar(
                      mxContent: snapshot.data?.avatarUrl,
                      name: widget.contact.displayName,
                      borderRadius: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 8.0),
                Expanded(
                  child: SizedBox(
                    height: 64,
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.max,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              IntrinsicWidth(
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Flexible(
                                            child: _displayNameWidget(
                                              snapshot.data?.displayName,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (widget.contact.matrixId != null &&
                                        widget.contact.matrixId!
                                            .isCurrentMatrixId(context)) ...[
                                      const SizedBox(width: 8.0),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: ZeonColors.surfaceContainer,
                                          border: Border.all(
                                            color: const Color(0x33474747),
                                          ),
                                        ),
                                        child: Text(
                                          L10n.of(context)!.owner,
                                          style: const TextStyle(
                                            color: ZeonColors.outline,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            fontFamily: 'Inter',
                                            letterSpacing: 1.8,
                                          ),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(width: 8.0),
                                    if (widget.contact.status != null &&
                                        widget.contact.status ==
                                            ContactStatus.inactive)
                                      ContactStatusWidget(
                                        status: widget.contact.status!,
                                      ),
                                  ],
                                ),
                              ),
                              if (widget.contact.matrixId != null &&
                                  widget.contact.matrixId!.isNotEmpty) ...[
                                HighlightText(
                                  text: widget.contact.matrixId!,
                                  searchWord: widget.highlightKeyword,
                                  style: const TextStyle(
                                    color: Color(0xFF636363),
                                    fontSize: 12,
                                    letterSpacing: 0.25,
                                    fontFamily: 'Inter',
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (widget.highlightKeyword.isNotEmpty) ...[
                                  if (widget.highlightKeyword
                                      .isPhoneNumberFormatted()) ...[
                                    _displayPhoneNumber(),
                                  ] else ...[
                                    _displayEmail(),
                                  ],
                                ] else ...[
                                  _displayInformationDefault(),
                                ],
                              ] else ...[
                                _displayPhoneNumber(),
                                _displayEmail(),
                              ],
                            ],
                          ),
                        ),
                        if (widget.contact.matrixId == null ||
                            widget.contact.matrixId!.isEmpty)
                          ValueListenableBuilder(
                            valueListenable: getInvitationStatusNotifier,
                            builder: _invitationIconBuilder,
                            child: _displayIconInvitation(),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );

    if (widget.suppressInkWell) {
      return tileBody;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _onContactTapHandler(
          context,
          widget.contact,
          getInvitationStatusNotifier.value
              .getSuccessOrNull<GetInvitationStatusSuccessState>()
              ?.invitationStatusResponse,
        ),
        splashColor: const Color(0x1AFFFFFF),
        highlightColor: const Color(0x0DFFFFFF),
        borderRadius: BorderRadius.zero,
        child: tileBody,
      ),
    );
  }

  BuildDisplayName _displayNameWidget(String? snapshotDisplayName) {
    return BuildDisplayName(
      profileDisplayName: _profileDisplayName(
        widget.contact,
        snapshotDisplayName,
      ),
      contactDisplayName: widget.contact.displayName,
      highlightKeyword: widget.highlightKeyword,
      style: const TextStyle(
        color: ZeonColors.onSurface,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        fontFamily: 'Inter',
      ),
    );
  }

  String? _profileDisplayName(
    PresentationContact contact,
    String? profileName,
  ) {
    return contact.displayName ?? profileName;
  }

  Widget _invitationIconBuilder(
    BuildContext context,
    dartz.Either<Failure, Success> status,
    Widget? child,
  ) {
    if (!widget.enableInvitation) {
      return const SizedBox();
    }

    return status.fold((failure) => child!, (success) {
      if (success is GetInvitationStatusLoadingState) {
        return const Padding(
          padding: EdgeInsets.all(8),
          child: SizedBox(
            width: 16,
            height: 16,
            child: CupertinoActivityIndicator(
              color: ZeonColors.outline,
              radius: 8,
            ),
          ),
        );
      }

      if (success is GetInvitationStatusSuccessState) {
        if (success.invitationStatusResponse.invitation?.hasMatrixId == true) {
          return const SizedBox();
        }
        return _displayIconInvitation(
          isExpired:
              success.invitationStatusResponse.invitation!.expiredTimeToInvite,
        );
      }

      return child!;
    });
  }

  Widget _displayIconInvitation({bool isExpired = true}) {
    return InkWell(
      onTap: () {
        _handleMatrixIdNull(
          context: context,
          contact: widget.contact,
          invitationStatus: getInvitationStatusNotifier.value
              .getSuccessOrNull<GetInvitationStatusSuccessState>()
              ?.invitationStatusResponse,
        );
      },
      hoverColor: Colors.transparent,
      focusColor: Colors.transparent,
      highlightColor: Colors.transparent,
      splashColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          Icons.person_add_alt_rounded,
          color: isExpired ? ZeonColors.outline : const Color(0xFF4CAF50),
        ),
      ),
    );
  }

  Widget _displayInformationDefault() {
    if (widget.contact.primaryPhoneNumber.isNotEmpty) {
      return HighlightText(
        text: widget.contact.primaryPhoneNumber,
        searchWord: widget.highlightKeyword,
        style: const TextStyle(
          color: ZeonColors.outline,
          fontSize: 13,
          fontFamily: 'Inter',
        ),
      );
    } else if (widget.contact.primaryEmail.isNotEmpty) {
      return HighlightText(
        text: widget.contact.primaryEmail,
        searchWord: widget.highlightKeyword,
        style: const TextStyle(
          color: ZeonColors.outline,
          fontSize: 13,
          fontFamily: 'Inter',
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    return const SizedBox();
  }

  Widget _displayPhoneNumber() {
    if (widget.contact.primaryPhoneNumber.isNotEmpty) {
      return HighlightText(
        text: widget.contact.primaryPhoneNumber,
        searchWord: widget.highlightKeyword,
        style: const TextStyle(
          color: ZeonColors.outline,
          fontSize: 13,
          fontFamily: 'Inter',
        ),
      );
    }
    return const SizedBox();
  }

  Widget _displayEmail() {
    if (widget.contact.primaryEmail.isNotEmpty) {
      return HighlightText(
        text: widget.contact.primaryEmail,
        searchWord: widget.highlightKeyword,
        style: const TextStyle(
          color: ZeonColors.outline,
          fontSize: 13,
          fontFamily: 'Inter',
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    return const SizedBox();
  }

  Future<Profile?> getProfile(BuildContext context) async {
    final client = Matrix.of(context).client;
    if (widget.contact.matrixId == null) {
      return Future.error(Exception("MatrixId is null"));
    }
    try {
      final profile = await client.getProfileFromUserId(
        widget.contact.matrixId!,
        getFromRooms: false,
      );
      Logs().d(
        "ExpansionContactListTile()::getProfiles(): ${profile.avatarUrl}",
      );
      return profile;
    } catch (e) {
      return Profile(
        userId: widget.contact.matrixId!,
        displayName: widget.contact.displayName,
        avatarUrl: null,
      );
    }
  }

  dynamic Function()? _onContactTapHandler(
    BuildContext context,
    PresentationContact contact,
    InvitationStatusResponse? invitationStatus,
  ) {
    if (widget.enableInvitation) {
      return () => _handleMatrixIdNull(
        context: context,
        contact: contact,
        invitationStatus: invitationStatus,
      );
    }

    if (widget.onContactTap != null) {
      return () => widget.onContactTap!.call();
    }

    return null;
  }
}
