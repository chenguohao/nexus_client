import 'dart:async';

import 'package:fluffychat/generated/l10n/app_localizations.dart';
import 'package:fluffychat/pages/chat/events/event_video_player.dart';
import 'package:fluffychat/pages/chat/events/message_content_style.dart';
import 'package:fluffychat/presentation/model/chat/upload_file_ui_state.dart';
import 'package:fluffychat/widgets/mixins/upload_file_mixin.dart';
import 'package:fluffychat/widgets/zeon/zeon_linear_upload_progress.dart';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class MessageVideoUploadContent extends StatefulWidget {
  const MessageVideoUploadContent({
    super.key,
    required this.event,
    required this.width,
    required this.height,
    this.bubbleWidth,
  });

  final Event event;

  final double width;

  final double height;

  final double? bubbleWidth;

  @override
  State<StatefulWidget> createState() => _MessageVideoUploadContentState();
}

class _MessageVideoUploadContentState extends State<MessageVideoUploadContent>
    with UploadFileMixin<MessageVideoUploadContent> {
  static const Color _zeonAccent = Color(0xFFE5E2E3);

  @override
  Event get event => widget.event;

  late Completer<String?> _completer;
  Future<String?> getMobileThumbnail() async {
    final completer = _completer;
    try {
      final uploadFileInfo = await uploadManager.getUploadFileInfo(
        event.eventId,
        room: event.room,
      );
      if (uploadFileInfo == null) {
        if (!completer.isCompleted) completer.complete(null);
        return null;
      }

      final filePath = uploadFileInfo.fileInfo?.filePath;
      if (filePath == null) {
        if (!completer.isCompleted) completer.complete(null);
        return null;
      }

      final thumbnail = await VideoThumbnail.thumbnailFile(video: filePath);
      if (!completer.isCompleted) completer.complete(thumbnail.path);
      return thumbnail.path;
    } catch (e) {
      Logs().e('Error getting thumbnail: $e');
      if (!completer.isCompleted) completer.complete(null);
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _completer = Completer<String?>();
    getMobileThumbnail();
  }

  @override
  void didUpdateWidget(covariant MessageVideoUploadContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.event != widget.event) {
      _completer = Completer<String?>();
      getMobileThumbnail();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;

    return ValueListenableBuilder(
      valueListenable: uploadFileStateNotifier,
      builder: ((context, uploadState, child) {
        double? progress;
        final hasError = uploadState is UploadFileFailedUIState;

        final indeterminate = !hasError &&
            (uploadState is UploadProcessingUIState ||
                uploadState is UploadFileUISateInitial ||
                (uploadState is UploadingFileUIState &&
                    (uploadState.total == null ||
                        uploadState.receive == null ||
                        uploadState.total! <= 0)));

        if (!hasError &&
            uploadState is UploadingFileUIState &&
            uploadState.total != null &&
            uploadState.receive != null &&
            uploadState.receive! > 0 &&
            uploadState.total! > 0) {
          progress = uploadState.receive! / uploadState.total!;
        }

        return FutureBuilder(
          future: _completer.future,
          builder: (context, asyncSnapshot) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                EventVideoPlayer(
                  widget.event,
                  width: widget.width,
                  height: widget.height,
                  bubbleWidth: widget.bubbleWidth,
                  thumbnailPath: asyncSnapshot.data,
                  onVideoTapped: () {
                    if (uploadState is UploadFileSuccessUIState) {
                      return;
                    }
                    if (hasError) {
                      uploadManager.retryUpload(event);
                    } else {
                      uploadManager.cancelUpload(event);
                    }
                  },
                  centerWidget: Stack(
                    alignment: Alignment.center,
                    children: [
                      const SizedBox(
                        width: MessageContentStyle.videoCenterButtonSize,
                        height: MessageContentStyle.videoCenterButtonSize,
                      ),
                      if (uploadState is UploadFileSuccessUIState) ...[
                        const SizedBox.shrink(),
                      ] else if (hasError)
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Color(0xFF2A2A2B),
                          ),
                          child: const Icon(
                            Icons.refresh,
                            color: _zeonAccent,
                            size: 24,
                          ),
                        )
                      else
                        const CenterVideoButton(
                          icon: Icons.close,
                          iconSize: MessageContentStyle.cancelButtonSize,
                        ),
                      if (!hasError)
                        SizedBox(
                          width: MessageContentStyle.iconInsideVideoButtonSize,
                          height: MessageContentStyle.iconInsideVideoButtonSize,
                          child: CircularProgressIndicator(
                            value: indeterminate ? null : progress,
                            color: _zeonAccent,
                            strokeWidth: MessageContentStyle.strokeVideoWidth,
                          ),
                        ),
                    ],
                  ),
                ),
                if (hasError)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Color(0xFFCF6679),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.tapToRetry,
                            style: const TextStyle(
                              color: Color(0xFF919191),
                              fontSize: 12,
                            ),
                          ),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF131314),
                            backgroundColor: Colors.white,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.zero,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                          ),
                          onPressed: () => uploadManager.retryUpload(event),
                          child: Text(l10n.tapToRetry),
                        ),
                      ],
                    ),
                  )
                else if (uploadState is! UploadFileSuccessUIState)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: ZeonLinearUploadProgress(
                      value: indeterminate ? null : progress,
                    ),
                  ),
              ],
            );
          },
        );
      }),
    );
  }
}
