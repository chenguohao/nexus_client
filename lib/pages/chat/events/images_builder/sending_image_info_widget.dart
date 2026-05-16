import 'package:fluffychat/config/app_config.dart';
import 'package:fluffychat/pages/chat/events/message_content_style.dart';
import 'package:fluffychat/pages/image_viewer/image_viewer.dart';
import 'package:fluffychat/presentation/model/chat/upload_file_ui_state.dart';
import 'package:fluffychat/presentation/model/file/display_image_info.dart';
import 'package:fluffychat/utils/extension/build_context_extension.dart';
import 'package:fluffychat/utils/interactive_viewer_gallery.dart';
import 'package:fluffychat/utils/matrix_sdk_extensions/event_extension.dart';
import 'package:fluffychat/utils/platform_infos.dart';
import 'package:fluffychat/widgets/hero_page_route.dart';
import 'package:fluffychat/widgets/mixins/upload_file_mixin.dart';
import 'package:fluffychat/widgets/zeon/zeon_linear_upload_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';
import 'package:matrix/matrix.dart' hide Visibility;

import 'package:fluffychat/generated/l10n/app_localizations.dart';

class SendingImageInfoWidget extends StatefulWidget {
  const SendingImageInfoWidget({
    super.key,
    required this.matrixFile,
    required this.event,
    required this.displayImageInfo,
    this.onTapPreview,
    this.bubbleWidth,
  });

  final MatrixImageFile matrixFile;

  final Event event;

  final void Function()? onTapPreview;

  final DisplayImageInfo displayImageInfo;

  final double? bubbleWidth;

  @override
  State<SendingImageInfoWidget> createState() => _SendingImageInfoWidgetState();
}

class _SendingImageInfoWidgetState extends State<SendingImageInfoWidget>
    with UploadFileMixin {
  static const Color _progressStroke = Color(0xFFE5E2E3);

  @override
  Event get event => widget.event;

  Future<void> _onTap(BuildContext context) async {
    if (widget.onTapPreview != null) {
      await Navigator.of(context, rootNavigator: PlatformInfos.isWeb).push(
        HeroPageRoute(
          builder: (context) {
            return InteractiveViewerGallery(
              itemBuilder: ImageViewer(event: widget.event),
            );
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;

    return Hero(
      tag: widget.event.eventId,
      child: ValueListenableBuilder<UploadFileUIState>(
        valueListenable: uploadFileStateNotifier,
        builder: (context, uploadState, child) {
          final hasError = uploadState is UploadFileFailedUIState;
          final done =
              widget.event.status == EventStatus.sent ||
              widget.event.status == EventStatus.synced;

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

          final hideOverlay =
              (done || uploadState is UploadFileSuccessUIState) && !hasError;
          final showOverlay = !hideOverlay;

          return Stack(
            alignment: Alignment.center,
            children: [
              child!,
              if (showOverlay)
                Positioned.fill(
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.35),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (hasError)
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                tooltip: l10n.tapToRetry,
                                onPressed: () =>
                                    uploadManager.retryUpload(widget.event),
                                icon: const Icon(
                                  Icons.refresh,
                                  color: _progressStroke,
                                  size: 32,
                                ),
                                style: IconButton.styleFrom(
                                  backgroundColor: const Color(0xFF2A2A2B),
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.zero,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
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
                          )
                        else ...[
                          SizedBox(
                            width: 44,
                            height: 44,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: _progressStroke,
                              value: indeterminate ? null : frac,
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () =>
                                    uploadManager.cancelUpload(widget.event),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  color: const Color(0xFF2A2A2B),
                                  child: const Icon(
                                    Icons.close,
                                    color: _progressStroke,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              if (!hasError && showOverlay)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: ZeonLinearUploadProgress(value: indeterminate ? null : frac),
                ),
            ],
          );
        },
        child: Material(
          borderRadius: MessageContentStyle.borderRadiusBubble,
          child: InkWell(
            onTap: () => _onTap(context),
            child: ClipRRect(
              borderRadius: MessageContentStyle.borderRadiusBubble,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (widget.matrixFile.bytes.isEmpty)
                    SizedBox(
                      width: MessageContentStyle.imageBubbleWidth(
                        widget.displayImageInfo.size.width <
                                (widget.bubbleWidth ?? 0)
                            ? widget.bubbleWidth ?? 0
                            : widget.displayImageInfo.size.width,
                      ),
                      height: MessageContentStyle.imageBubbleHeight(
                        widget.displayImageInfo.size.height,
                      ),
                      child: BlurHash(
                        hash:
                            widget.event.blurHash ??
                            AppConfig.defaultImageBlurHash,
                      ),
                    )
                  else
                    Image.memory(
                      widget.matrixFile.bytes,
                      width: widget.displayImageInfo.size.width,
                      height: widget.displayImageInfo.size.height,
                      cacheHeight: context.getCacheSize(
                        widget.displayImageInfo.size.height,
                      ),
                      cacheWidth: context.getCacheSize(
                        widget.displayImageInfo.size.width,
                      ),
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.none,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
