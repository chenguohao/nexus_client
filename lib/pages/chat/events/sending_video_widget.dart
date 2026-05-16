import 'package:fluffychat/di/global/get_it_initializer.dart';
import 'package:fluffychat/generated/l10n/app_localizations.dart';
import 'package:fluffychat/pages/chat/events/message/message_style.dart';
import 'package:fluffychat/pages/chat/events/message_content_style.dart';
import 'package:fluffychat/presentation/mixins/play_video_action_mixin.dart';
import 'package:fluffychat/presentation/model/chat/upload_file_ui_state.dart';
import 'package:fluffychat/presentation/model/file/display_image_info.dart';
import 'package:fluffychat/utils/manager/upload_manager/upload_manager.dart';
import 'package:fluffychat/utils/matrix_sdk_extensions/event_extension.dart';
import 'package:fluffychat/widgets/mixins/upload_file_mixin.dart';
import 'package:fluffychat/widgets/zeon/zeon_linear_upload_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';
import 'package:matrix/matrix.dart';

class SendingVideoWidget extends StatefulWidget {
  final Event event;

  final DisplayImageInfo displayImageInfo;

  final double? bubbleWidth;

  const SendingVideoWidget({
    super.key,
    required this.event,
    required this.displayImageInfo,
    this.bubbleWidth,
  });

  @override
  State<SendingVideoWidget> createState() => _SendingVideoWidgetState();
}

class _SendingVideoWidgetState extends State<SendingVideoWidget>
    with PlayVideoActionMixin, UploadFileMixin {
  @override
  Event get event => widget.event;

  late final VideoWidget videoWidget;

  @override
  void initState() {
    super.initState();
    videoWidget = VideoWidget(
      imageHeight: widget.displayImageInfo.size.height,
      imageWidth: widget.displayImageInfo.size.width,
      event: event,
    );
  }

  static const Color _zeonAccent = Color(0xFFE5E2E3);
  static const Color _zeonChipBg = Color(0xFF2A2A2B);

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    return ClipRRect(
      borderRadius: MessageContentStyle.borderRadiusBubble,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: MessageStyle.mediaContentWidth(
              context: context,
              event: event,
              calculatedWidth:
                  MessageContentStyle.combinedBubbleImageWidthWithBubbleMaxWidget(
                    bubbleImageWidget: widget.displayImageInfo.size.width,
                    bubbleMaxWidth: widget.bubbleWidth ?? 0,
                  ),
            ),
            height: MessageContentStyle.imageBubbleHeight(
              widget.displayImageInfo.size.height,
            ),
            child: const BlurHash(hash: MessageContentStyle.defaultBlurHash),
          ),
          videoWidget,
          ValueListenableBuilder<UploadFileUIState>(
            valueListenable: uploadFileStateNotifier,
            builder: (context, uploadState, _) {
              final failed = uploadState is UploadFileFailedUIState ||
                  event.status == EventStatus.error;

              if (failed) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: l10n.tapToRetry,
                      onPressed: () => uploadManager.retryUpload(event),
                      icon: const Icon(Icons.refresh, color: _zeonAccent, size: 28),
                      style: IconButton.styleFrom(
                        backgroundColor: _zeonChipBg,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        l10n.tapToRetry,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF919191),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                );
              }

              double? progress;
              final indeterminate =
                  uploadState is UploadProcessingUIState ||
                  uploadState is UploadFileUISateInitial ||
                  (uploadState is UploadingFileUIState &&
                      (uploadState.receive == null ||
                          uploadState.total == null ||
                          uploadState.total! <= 0));

              if (!indeterminate && uploadState is UploadingFileUIState) {
                progress =
                    uploadState.receive! / uploadState.total!;
              }

              return Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: MessageContentStyle.videoCenterButtonSize,
                    height: MessageContentStyle.videoCenterButtonSize,
                    decoration: const BoxDecoration(
                      color: Colors.black38,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.close,
                      color: _zeonAccent,
                      size: MessageContentStyle.iconInsideVideoButtonSize,
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      if (uploadState is UploadFileSuccessUIState) {
                        return;
                      }
                      uploadManager.cancelUpload(event);
                    },
                    child: SizedBox(
                      width: MessageContentStyle.videoCenterButtonSize,
                      height: MessageContentStyle.videoCenterButtonSize,
                      child: CircularProgressIndicator(
                        strokeWidth: MessageContentStyle.strokeVideoWidth,
                        color: _zeonAccent,
                        value: indeterminate ? null : progress,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          ValueListenableBuilder<UploadFileUIState>(
            valueListenable: uploadFileStateNotifier,
            builder: (context, uploadState, _) {
              if (uploadState is UploadFileFailedUIState ||
                  event.status == EventStatus.error ||
                  uploadState is UploadFileSuccessUIState) {
                return const SizedBox.shrink();
              }
              double? frac;
              final indeterminate =
                  uploadState is UploadProcessingUIState ||
                  uploadState is UploadFileUISateInitial ||
                  (uploadState is UploadingFileUIState &&
                      (uploadState.receive == null ||
                          uploadState.total == null ||
                          uploadState.total! <= 0));
              if (!indeterminate && uploadState is UploadingFileUIState) {
                frac = uploadState.receive! / uploadState.total!;
              }
              return Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ZeonLinearUploadProgress(value: indeterminate ? null : frac),
              );
            },
          ),
        ],
      ),
    );
  }
}

class VideoWidget extends StatefulWidget {
  const VideoWidget({
    super.key,
    required this.imageHeight,
    required this.imageWidth,
    required this.event,
  });

  final double imageHeight;
  final double imageWidth;
  final Event event;

  @override
  State<VideoWidget> createState() => _VideoWidgetState();
}

class _VideoWidgetState extends State<VideoWidget> {
  late final Future<MatrixImageFile?> _thumbnailFuture;

  @override
  void initState() {
    super.initState();
    _thumbnailFuture = widget.event.getPlaceholderMatrixImageFile(
      getIt.get<UploadManager>(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final placeholder = SizedBox(
      width: widget.imageWidth,
      height: widget.imageHeight,
    );

    return FutureBuilder(
      future: _thumbnailFuture,
      builder: (context, snapshot) {
        if (snapshot.data == null) return placeholder;

        return Image.memory(
          snapshot.data!.bytes,
          width: widget.imageWidth,
          height: widget.imageHeight,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
        );
      },
    );
  }
}

enum SendingVideoStatus { sending, sent, error }
