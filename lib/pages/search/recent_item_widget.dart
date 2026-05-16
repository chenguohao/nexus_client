import 'package:fluffychat/pages/search/recent_item_widget_style.dart';
import 'package:fluffychat/presentation/extensions/room_summary_extension.dart';
import 'package:fluffychat/presentation/extensions/search/presentation_search_extensions.dart';
import 'package:fluffychat/presentation/model/search/presentation_search.dart';
import 'package:fluffychat/config/zeon_colors.dart';
import 'package:fluffychat/utils/string_extension.dart';
import 'package:fluffychat/widgets/avatar/avatar.dart';
import 'package:fluffychat/widgets/highlight_text.dart';
import 'package:flutter/material.dart' hide SearchController;
import 'package:fluffychat/generated/l10n/app_localizations.dart';
import 'package:matrix/matrix.dart';

class RecentItemWidget extends StatelessWidget {
  final PresentationSearch presentationSearch;
  final String highlightKeyword;
  final Client client;
  final void Function()? onTap;
  final double? avatarSize;

  const RecentItemWidget({
    required this.presentationSearch,
    required this.highlightKeyword,
    this.onTap,
    super.key,
    required this.client,
    this.avatarSize,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: const Color(0x1AFFFFFF),
        highlightColor: const Color(0x0DFFFFFF),
        borderRadius: BorderRadius.zero,
        child: Container(
          height: RecentItemStyle.recentItemHeight,
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Color(0x1F474747)),
            ),
          ),
          padding: RecentItemStyle.paddingRecentItem,
          alignment: Alignment.centerLeft,
          child: _buildInformationWidget(context),
        ),
      ),
    );
  }

  Widget _buildInformationWidget(BuildContext context) {
    if (presentationSearch is ContactPresentationSearch) {
      return _ContactInformation(
        client: client,
        contactPresentationSearch:
            presentationSearch as ContactPresentationSearch,
        searchKeyword: highlightKeyword,
        avatarSize: avatarSize,
      );
    } else {
      final recentChatPresentationSearch =
          presentationSearch as RecentChatPresentationSearch;
      if (recentChatPresentationSearch.directChatMatrixID == null) {
        return _GroupChatInformation(
          client: client,
          recentChatPresentationSearch: recentChatPresentationSearch,
          searchKeyword: highlightKeyword,
          avatarSize: avatarSize,
        );
      } else {
        return _DirectChatInformation(
          client: client,
          recentChatPresentationSearch: recentChatPresentationSearch,
          searchKeyword: highlightKeyword,
          avatarSize: avatarSize,
        );
      }
    }
  }
}

class _GroupChatInformation extends StatelessWidget {
  final RecentChatPresentationSearch recentChatPresentationSearch;
  final Client client;
  final String? searchKeyword;
  final double? avatarSize;

  const _GroupChatInformation({
    required this.recentChatPresentationSearch,
    this.searchKeyword,
    required this.client,
    this.avatarSize,
  });

  @override
  Widget build(BuildContext context) {
    final actualMembersCount =
        recentChatPresentationSearch.roomSummary?.actualMembersCount ?? 0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: RecentItemStyle.avatarSize,
          child: Avatar(
            name: recentChatPresentationSearch.displayName,
            mxContent: recentChatPresentationSearch.getAvatarUriByMatrixId(
              client: client,
            ),
            size: avatarSize ?? RecentItemStyle.avatarSize,
            borderRadius: 0,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SearchHighlightText(
                text: recentChatPresentationSearch.displayName ?? "",
                style: RecentItemStyle.titleZeon,
                searchWord: searchKeyword,
              ),
              Text(
                L10n.of(context)!.countMembers(actualMembersCount),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                softWrap: false,
                style: RecentItemStyle.subtitleZeon,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SearchHighlightText extends StatelessWidget {
  final String text;
  final String? searchWord;
  final TextStyle? style;

  const _SearchHighlightText({required this.text, this.searchWord, this.style});

  @override
  Widget build(BuildContext context) {
    return HighlightText(
      text: text,
      style: style,
      searchWord: searchWord,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
    );
  }
}

class _DirectChatInformation extends StatelessWidget {
  final RecentChatPresentationSearch recentChatPresentationSearch;
  final Client client;
  final String? searchKeyword;
  final double? avatarSize;

  const _DirectChatInformation({
    required this.recentChatPresentationSearch,
    this.searchKeyword,
    required this.client,
    this.avatarSize,
  });

  /// 当 displayName 缺失或等于 Matrix ID（room member 事件没有携带 displayname
  /// 字段时 SDK 的降级行为）时，从 Matrix 补查对方的真实 Profile。
  Future<Profile?> _tryFetchProfile(String matrixId) async {
    try {
      return await client.getProfileFromUserId(matrixId, getFromRooms: true);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final matrixId = recentChatPresentationSearch.directChatMatrixID;
    final rawName = recentChatPresentationSearch.displayName;
    // displayName 缺失或等于 Matrix ID，说明 room member 事件里没有 displayname，
    // 需要通过 Profile API 补查真实昵称。
    final needsLookup =
        matrixId != null && (rawName == null || rawName.isEmpty || rawName == matrixId);

    return FutureBuilder<Profile?>(
      future: needsLookup ? _tryFetchProfile(matrixId) : Future.value(null),
      builder: (context, snapshot) {
        final resolvedName = snapshot.data?.displayName ?? rawName;
        final resolvedAvatar =
            snapshot.data?.avatarUrl ??
            recentChatPresentationSearch.getAvatarUriByMatrixId(client: client);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Avatar(
              name: resolvedName,
              mxContent: resolvedAvatar,
              size: avatarSize ?? RecentItemStyle.avatarSize,
              borderRadius: 0,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SearchHighlightText(
                    text: resolvedName ?? matrixId ?? "",
                    style: RecentItemStyle.titleZeon,
                    searchWord: searchKeyword,
                  ),
                  _SearchHighlightText(
                    text: matrixId ?? "",
                    style: RecentItemStyle.subtitleZeon,
                    searchWord: searchKeyword,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ContactInformation extends StatelessWidget {
  final ContactPresentationSearch contactPresentationSearch;
  final String? searchKeyword;
  final Client client;
  final double? avatarSize;

  const _ContactInformation({
    required this.contactPresentationSearch,
    this.searchKeyword,
    required this.client,
    this.avatarSize,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FutureBuilder<Profile?>(
          future: contactPresentationSearch.getProfile(client),
          builder: (context, snapshot) {
            return Avatar(
              mxContent: snapshot.data?.avatarUrl,
              name: contactPresentationSearch.displayName,
              size: avatarSize ?? RecentItemStyle.avatarSize,
              borderRadius: 0,
            );
          },
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _SearchHighlightText(
                      text: contactPresentationSearch.displayName ?? "",
                      style: RecentItemStyle.titleZeon,
                      searchWord: searchKeyword,
                    ),
                  ),
                  if (contactPresentationSearch.matrixId != null &&
                      contactPresentationSearch.matrixId!.isCurrentMatrixId(
                        context,
                      )) ...[
                    const SizedBox(width: 8.0),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: ZeonColors.surfaceContainer,
                        border: Border.all(color: const Color(0x33474747)),
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
                ],
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (contactPresentationSearch.matrixId != null)
                      _SearchHighlightText(
                        text: contactPresentationSearch.matrixId ?? "",
                        style: RecentItemStyle.subtitleZeon,
                        searchWord: searchKeyword,
                      ),
                    if (searchKeyword?.isNotEmpty == true) ...[
                      if (searchKeyword?.isPhoneNumberFormatted() == true) ...[
                        Flexible(child: _displayPrimaryPhoneNumber()),
                      ] else ...[
                        Flexible(child: _displayPrimaryEmail()),
                      ],
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _displayPrimaryEmail() {
    if (contactPresentationSearch.primaryEmail.isEmpty) {
      return const SizedBox();
    }
    return _SearchHighlightText(
      text: contactPresentationSearch.primaryEmail,
      style: RecentItemStyle.subtitleZeon,
      searchWord: searchKeyword,
    );
  }

  Widget _displayPrimaryPhoneNumber() {
    if (contactPresentationSearch.primaryPhoneNumber.isEmpty) {
      return const SizedBox();
    }
    return _SearchHighlightText(
      text: contactPresentationSearch.primaryPhoneNumber,
      style: RecentItemStyle.subtitleZeon,
      searchWord: searchKeyword,
    );
  }
}
