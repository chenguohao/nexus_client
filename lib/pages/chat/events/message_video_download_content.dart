import 'dart:async';
import 'dart:io';

import 'package:fluffychat/di/global/get_it_initializer.dart';
import 'package:fluffychat/pages/chat/events/event_video_player.dart';
import 'package:fluffychat/pages/chat/events/message_content_style.dart';
import 'package:fluffychat/pages/media_viewer/media_viewer.dart';
import 'package:fluffychat/presentation/extensions/media_thumbnail_extension.dart';
import 'package:fluffychat/presentation/mixins/play_video_action_mixin.dart';
import 'package:fluffychat/presentation/model/chat/downloading_state_presentation_model.dart';
import 'package:fluffychat/utils/interactive_viewer_gallery.dart';
import 'package:fluffychat/utils/manager/storage_directory_manager.dart';
import 'package:fluffychat/utils/manager/upload_manager/upload_manager.dart';
import 'package:fluffychat/utils/matrix_sdk_extensions/event_extension.dart';
import 'package:fluffychat/widgets/hero_page_route.dart';
import 'package:fluffychat/widgets/mixins/download_file_on_mobile_mixin.dart';
import 'package:flutter/material.dart';
import 'package:linagora_design_flutter/colors/linagora_ref_colors.dart';
import 'package:matrix/matrix.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class MessageVideoDownloadContent extends StatefulWidget {
  const MessageVideoDownloadContent({
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
  State<StatefulWidget> createState() => _MessageVideoDownloadContentState();
}

class _MessageVideoDownloadContentState
    extends State<MessageVideoDownloadContent>
    with
        DownloadFileOnMobileMixin<MessageVideoDownloadContent>,
        PlayVideoActionMixin {
  final UploadManager _uploadManager = getIt.get<UploadManager>();

  @override
  Event get event => widget.event;

  String? _thumbnailPath;
  int _thumbResolveGeneration = 0;

  @override
  void initState() {
    super.initState();
    _startThumbnailResolution();
  }

  @override
  void didUpdateWidget(MessageVideoDownloadContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.event.eventId != widget.event.eventId) {
      _thumbnailPath = null;
      checkDownloadFileState();
      _startThumbnailResolution();
    }
  }

  Future<String?> _localMainVideoPath(Event ev) async {
    final filePath = ev.room.encrypted
        ? await StorageDirectoryManager.instance.getDecryptedFilePath(
            eventId: ev.eventId,
            fileName: ev.filename,
          )
        : await StorageDirectoryManager.instance.getFilePathInAppDownloads(
            eventId: ev.eventId,
            fileName: ev.filename,
          );
    final file = File(filePath);
    return await file.exists() ? filePath : null;
  }

  Future<String?> _thumbnailFromVideoPath(String videoPath) async {
    final thumbnail = await VideoThumbnail.thumbnailFile(video: videoPath);
    return thumbnail.path;
  }

  Future<String?> _tryResolveThumbnailOnce(Event ev) async {
    try {
      final localVideo = await _localMainVideoPath(ev);
      if (localVideo != null) {
        return await _thumbnailFromVideoPath(localVideo);
      }

      final uploadFileInfo = await _uploadManager.getUploadFileInfo(
        ev.eventId,
        room: ev.room,
      );
      final fp = uploadFileInfo?.fileInfo?.filePath;
      if (fp != null) {
        return await _thumbnailFromVideoPath(fp);
      }

      final placeholder = ev.getMatrixFile();
      if (placeholder is MatrixVideoFile) {
        final img = await ev.room.generateVideoThumbnail(placeholder);
        if (img != null && img.bytes.isNotEmpty) {
          final dir = await getTemporaryDirectory();
          final f = File(
            '${dir.path}/zeon_vid_thumb_${ev.eventId.hashCode.abs()}.jpg',
          );
          await f.writeAsBytes(img.bytes);
          return f.path;
        }
      }
    } catch (e) {
      Logs().e('MessageVideoDownloadContent::_tryResolveThumbnailOnce: $e');
    }
    return null;
  }

  /// Matches [_pollUntilLocalAttachmentAppears]: timeline updates before disk copy finishes.
  Future<void> _startThumbnailResolution() async {
    final gen = ++_thumbResolveGeneration;
    const attempts = 22;
    const gap = Duration(milliseconds: 70);
    for (var i = 0; i < attempts; i++) {
      if (!mounted || gen != _thumbResolveGeneration) return;
      if (i > 0) await Future.delayed(gap);
      if (!mounted || gen != _thumbResolveGeneration) return;

      final path = await _tryResolveThumbnailOnce(widget.event);
      if (path != null && mounted && gen == _thumbResolveGeneration) {
        setState(() => _thumbnailPath = path);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return EventVideoPlayer(
      widget.event,
      width: widget.width,
      height: widget.height,
      bubbleWidth: widget.bubbleWidth,
      thumbnailPath: _thumbnailPath,
      centerWidget: ValueListenableBuilder<DownloadPresentationState>(
        valueListenable: downloadFileStateNotifier,
        builder: (context, downloadState, child) {
          if (downloadState is DownloadingPresentationState) {
            double? progress;
            if (downloadState.total != null &&
                downloadState.receive != null &&
                downloadState.total! > 0) {
              progress = downloadState.receive! / downloadState.total!;
            }
            return Stack(
              alignment: Alignment.center,
              children: [
                const SizedBox(
                  width: MessageContentStyle.videoCenterButtonSize,
                  height: MessageContentStyle.videoCenterButtonSize,
                ),
                const CenterVideoButton(
                  icon: Icons.close,
                  iconSize: MessageContentStyle.cancelButtonSize,
                ),
                SizedBox(
                  width: MessageContentStyle.iconInsideVideoButtonSize,
                  height: MessageContentStyle.iconInsideVideoButtonSize,
                  child: CircularProgressIndicator(
                    value: progress,
                    color: LinagoraRefColors.material().primary[100],
                    strokeWidth: MessageContentStyle.strokeVideoWidth,
                  ),
                ),
              ],
            );
          } else if (downloadState is NotDownloadPresentationState) {
            return const CenterVideoButton(
              icon: Icons.arrow_downward,
              iconSize: MessageContentStyle.downloadButtonSize,
            );
          }
          return const CenterVideoButton(icon: Icons.play_arrow);
        },
      ),
      onVideoTapped: () async {
        await Navigator.of(context).push(
          HeroPageRoute(
            builder: (context) {
              return InteractiveViewerGallery(
                itemBuilder: MediaViewer(event: event),
              );
            },
          ),
        );
        if (!mounted) return;
        checkDownloadFileState();
      },
    );
  }
}
