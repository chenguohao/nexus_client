import 'package:fluffychat/config/app_config.dart';
import 'package:fluffychat/pages/chat/events/message_content_style.dart';
import 'package:fluffychat/presentation/model/chat/upload_file_ui_state.dart';
import 'package:fluffychat/utils/extension/mime_type_extension.dart';
import 'package:fluffychat/utils/matrix_sdk_extensions/event_extension.dart';
import 'package:fluffychat/utils/matrix_sdk_extensions/int_extension.dart';
import 'package:fluffychat/widgets/file_widget/base_file_tile_widget.dart';
import 'package:fluffychat/widgets/file_widget/message_file_tile_style.dart';
import 'package:fluffychat/widgets/mixins/upload_file_mixin.dart';
import 'package:fluffychat/widgets/twake_components/twake_preview_link/twake_link_preview.dart';
import 'package:fluffychat/widgets/zeon/zeon_linear_upload_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:matrix/matrix.dart';

import 'package:fluffychat/generated/l10n/app_localizations.dart';

class MessageUploadingContent extends StatefulWidget {
  final Event event;
  final MessageFileTileStyle style;

  const MessageUploadingContent({
    super.key,
    required this.event,
    required this.style,
  });

  @override
  State<MessageUploadingContent> createState() =>
      _MessageUploadingContentState();
}

class _MessageUploadingContentState extends State<MessageUploadingContent>
    with UploadFileMixin<MessageUploadingContent> {
  static const Color _zeonIconBg = Color(0xFF2A2A2B);
  static const Color _zeonPrimaryText = Color(0xFFE5E2E3);
  static const Color _zeonDanger = Color(0xFFCF6679);

  double _leadingReservedWidth() =>
      widget.style.iconSize +
      widget.style.marginDownloadIcon.horizontal +
      4.0;

  Widget _leadingIcon(UploadFileUIState uploadState) {
    final ok = uploadState is UploadFileSuccessUIState;
    final failed = uploadState is UploadFileFailedUIState;

    if (ok) {
      return SvgPicture.asset(
        widget.event.mimeType.getIcon(fileType: widget.event.fileType),
        width: widget.style.iconSize,
        height: widget.style.iconSize,
      );
    }

    if (failed) {
      return IconButton(
        tooltip: L10n.of(context)!.tapToRetry,
        onPressed: () => uploadManager.retryUpload(widget.event),
        icon: const Icon(Icons.refresh, color: _zeonPrimaryText, size: 24),
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          backgroundColor: _zeonIconBg,
          fixedSize: Size.square(widget.style.iconSize + 8),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),
      );
    }

    return SizedBox(
      width: widget.style.iconSize + widget.style.marginDownloadIcon.horizontal,
      height: widget.style.iconSize + widget.style.marginDownloadIcon.vertical,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          SvgPicture.asset(
            widget.event.mimeType.getIcon(fileType: widget.event.fileType),
            width: widget.style.iconSize,
            height: widget.style.iconSize,
          ),
          Positioned(
            top: -4,
            right: -4,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => uploadManager.cancelUpload(widget.event),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  color: _zeonIconBg,
                  child: Icon(
                    Icons.close,
                    size: widget.style.downloadIconSize * 0.65,
                    color: _zeonPrimaryText,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _progressAndRetry(BuildContext context, UploadFileUIState state) {
    final l10n = L10n.of(context)!;

    if (state is UploadFileSuccessUIState) {
      return const SizedBox.shrink();
    }

    if (state is UploadFileFailedUIState) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: _zeonDanger, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.tapToRetry,
                style: widget.style.textInformationStyle(context),
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF131314),
                backgroundColor: Colors.white,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              onPressed: () => uploadManager.retryUpload(widget.event),
              child: Text(l10n.tapToRetry),
            ),
          ],
        ),
      );
    }

    double? frac;
    final indeterminate = state is UploadProcessingUIState ||
        state is UploadFileUISateInitial ||
        (state is UploadingFileUIState &&
            (state.receive == null ||
                state.total == null ||
                state.total! <= 0));

    if (!indeterminate && state is UploadingFileUIState) {
      frac = state.receive! / state.total!;
    }

    String? phaseLabel;
    if (state is UploadProcessingUIState || state is UploadFileUISateInitial) {
      phaseLabel = state is UploadFileUISateInitial
          ? '准备上传…'
          : '处理中…';
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ZeonLinearUploadProgress(value: indeterminate ? null : frac),
          if (phaseLabel != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                phaseLabel,
                style: widget.style.textInformationStyle(context),
              ),
            ),
          if (!indeterminate &&
              state is UploadingFileUIState &&
              state.total != null &&
              state.receive != null &&
              state.total! >= IntExtension.oneKB)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${state.receive!.bytesToMB(placeDecimal: 2)} MB / ${state.total!.bytesToMB(placeDecimal: 2)} MB',
                style: widget.style.textInformationStyle(context),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: widget.style.paddingFileTileAll,
          decoration: ShapeDecoration(
            color: widget.style.backgroundColor(
              context,
              ownMessage: event.isOwnMessage,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: widget.style.borderRadius,
            ),
          ),
          child: ValueListenableBuilder<UploadFileUIState>(
            valueListenable: uploadFileStateNotifier,
            builder: (context, uploadState, _) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: widget.style.crossAxisAlignment,
                    children: [
                      _leadingIcon(uploadState),
                      widget.style.paddingRightIcon,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            const SizedBox(height: 4),
                            FileNameText(
                              filename: widget.event.filename,
                              style: widget.style,
                            ),
                            Row(
                              children: [
                                if (widget.event.sizeString != null &&
                                    !(uploadState is UploadingFileUIState &&
                                        uploadState.receive != null &&
                                        uploadState.total != null &&
                                        uploadState.total! >=
                                            IntExtension.oneKB)) ...[
                                  Text(
                                    widget.event.sizeString!,
                                    style: widget.style.textInformationStyle(
                                      context,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    ' · ',
                                    style: widget.style.textInformationStyle(
                                      context,
                                    ),
                                  ),
                                ],
                                Flexible(
                                  child: Text(
                                    widget.event.mimeType.getFileType(
                                      context,
                                      fileType: widget.event.fileType,
                                    ),
                                    style: widget.style.textInformationStyle(
                                      context,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            widget.style.paddingBottomText,
                          ],
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: EdgeInsets.only(left: _leadingReservedWidth()),
                    child: _progressAndRetry(context, uploadState),
                  ),
                ],
              );
            },
          ),
        ),
        if (event.isCaptionModeOrReply() &&
            event.isBodyDiffersFromFilename()) ...[
          const SizedBox(height: 8.0),
          MouseRegion(
            cursor: SystemMouseCursors.copy,
            child: TwakeLinkPreview(
              key: ValueKey('TwakeLinkPreview%${event.eventId}%'),
              event: event,
              localizedBody: event.body,
              ownMessage: event.isOwnMessage,
              fontSize: AppConfig.messageFontSize * AppConfig.fontSizeFactor,
              linkStyle: MessageContentStyle.linkStyleMessageContent(context),
              richTextStyle: event.getMessageTextStyle(context),
              isCaption: event.isCaptionModeOrReply(),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Event get event => widget.event;
}
