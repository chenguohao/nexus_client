import 'dart:io';
import 'package:fluffychat/data/local/mxc_disk_image_cache.dart';
import 'package:fluffychat/data/memory/mxc_image_cache_manager.dart';
import 'package:fluffychat/pages/image_viewer/image_viewer.dart';
import 'package:fluffychat/pages/media_viewer/media_viewer.dart';
import 'package:fluffychat/presentation/enum/chat/media_viewer_popup_result_enum.dart';
import 'package:fluffychat/presentation/extensions/media_thumbnail_extension.dart';
import 'package:fluffychat/utils/extension/build_context_extension.dart';
import 'package:fluffychat/utils/extension/mime_type_extension.dart';
import 'package:fluffychat/utils/interactive_viewer_gallery.dart';
import 'package:fluffychat/utils/matrix_sdk_extensions/download_file_extension.dart';
import 'package:fluffychat/utils/matrix_sdk_extensions/event_extension.dart';
import 'package:fluffychat/utils/matrix_sdk_extensions/matrix_file_extension.dart';
import 'package:fluffychat/utils/platform_infos.dart';
import 'package:fluffychat/widgets/hero_page_route.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_avif/flutter_avif.dart';
import 'package:http/http.dart' as http;
import 'package:matrix/matrix.dart';
import 'package:fluffychat/config/themes.dart';
import 'package:fluffychat/widgets/matrix.dart';

typedef EventId = String;
typedef ImageData = Uint8List;

/// 解析 `mxc://{serverName}/{mediaId}`，供 [Client.getContent] / [Client.getContentThumbnail] 使用。
(String serverName, String mediaId)? _parseMxcAuthority(Uri uri) {
  if (!uri.isScheme('mxc')) return null;
  final host = uri.host;
  if (host.isEmpty) return null;
  var mediaPath = uri.path;
  if (mediaPath.startsWith('/')) {
    mediaPath = mediaPath.substring(1);
  }
  if (mediaPath.isEmpty) return null;
  final serverName = uri.hasPort ? '$host:${uri.port}' : host;
  return (serverName, mediaPath);
}

class MxcImage extends StatefulWidget {
  /// 可选：显式指定 Matrix [Client]，用于部分 Overlay / 路由子树里
  /// `Matrix.of(context)` 查不到 [MatrixState] 的场景（见 `FlutterEasyLoading` 双层 Overlay）。
  /// 传入后 [MxcImage] 不再调用 [Matrix.of]。
  final Client? matrixClient;

  final Uri? uri;
  final Event? event;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final bool isThumbnail;
  final bool animated;
  final Duration retryDuration;
  final Duration animationDuration;
  final Curve animationCurve;
  final ThumbnailMethod thumbnailMethod;
  final Widget Function(BuildContext context)? placeholder;
  final String? cacheKey;
  final bool rounded;
  final void Function()? onTapPreview;
  final void Function()? onTapSelectMode;
  final ImageData? imageData;
  final bool isPreview;
  final bool enableHeroAnimation;

  /// Enable it if the image is stretched, and you don't want to resize it
  final bool noResize;

  /// Cache for screen locally, if null, use global cache
  final Map<EventId, ImageData>? cacheMap;

  final VoidCallback? closeRightColumn;

  final int? cacheWidth;

  final int? cacheHeight;

  final bool keepAlive;

  const MxcImage({
    this.matrixClient,
    this.uri,
    this.event,
    this.width,
    this.height,
    this.fit,
    this.placeholder,
    this.isThumbnail = true,
    this.animated = false,
    this.animationDuration = const Duration(milliseconds: 500),
    this.retryDuration = const Duration(seconds: 2),
    this.animationCurve = TwakeThemes.animationCurve,
    this.thumbnailMethod = ThumbnailMethod.scale,
    this.cacheKey,
    this.rounded = false,
    this.onTapPreview,
    this.onTapSelectMode,
    this.imageData,
    this.isPreview = false,
    this.cacheMap,
    this.noResize = false,
    this.closeRightColumn,
    this.cacheWidth,
    this.cacheHeight,
    this.enableHeroAnimation = true,
    this.keepAlive = false,
    super.key,
  });

  @override
  State<MxcImage> createState() => _MxcImageState();
}

class _MxcImageState extends State<MxcImage>
    with AutomaticKeepAliveClientMixin {
  static const String placeholderKey = 'placeholder';
  ImageData? _imageDataNoCache;
  bool isLoadDone = false;
  String? filePath;
  // True when both load attempts failed (e.g. server returned 404 / expired).
  bool _mediaExpired = false;

  ImageData? get _imageData {
    final cacheKey = widget.cacheKey;
    final image = cacheKey == null
        ? _imageDataNoCache
        : widget.cacheMap != null
        ? _imageDataFromLocalCache
        : _imageDataFromGlobalCache;
    return image;
  }

  ImageData? get _imageDataFromLocalCache =>
      widget.cacheKey != null && widget.cacheMap != null
      ? widget.cacheMap![widget.cacheKey]
      : null;

  ImageData? get _imageDataFromGlobalCache => widget.cacheKey != null
      ? MxcImageCacheManager.instance.getImage(widget.cacheKey!)
      : null;

  set _imageData(ImageData? data) {
    if (data == null) return;
    final cacheKey = widget.cacheKey;
    if (cacheKey == null) {
      _imageDataNoCache = data;
    } else if (widget.cacheMap != null) {
      widget.cacheMap![cacheKey] = data;
    } else {
      MxcImageCacheManager.instance.cacheImage(cacheKey, data);
    }
  }

  bool? _isCached;

  Client _matrixClient(BuildContext context) {
    final explicit = widget.matrixClient;
    if (explicit != null) return explicit;
    return Matrix.of(context).client;
  }

  /// 同一 mxc 在不同「缩略图尺寸 / 是否缩略图 / 动画」下对应不同二进制，全部纳入键避免错图。
  String _mxcDiskLogicalKey(Uri mxcUri, int? rw, int? rh) {
    final w = rw ?? 0;
    final h = rh ?? 0;
    return '$mxcUri|thumb:${widget.isThumbnail}|${w}x$h|'
        'anim:${widget.animated}|meth:${widget.thumbnailMethod.name}';
  }

  Future<({Uint8List? imageData, String? filePath})> _load(
    BuildContext context,
  ) async {
    if (!context.mounted) return (imageData: null, filePath: null);
    final client = _matrixClient(context);
    final uri = widget.uri;
    final event = widget.event;

    if (uri != null) {
      final width = widget.width;
      final realWidth = width == null ? null : context.getCacheSize(width);
      final height = widget.height;
      final realHeight = height == null ? null : context.getCacheSize(height);

      // ── MXC：必须用 [Client.getContent] / [Client.getContentThumbnail] ─────────
      // 与 Matrix SDK 内部同步、附件下载共用同一套 endpoint + Bearer + HttpClient，
      // 避免手写 GET 与 MSC3916 / Matrix 1.11 媒体路由不一致。
      if (uri.isScheme('mxc')) {
        final parsed = _parseMxcAuthority(uri);
        if (parsed == null) {
          debugPrint('[MxcImage] invalid mxc (need host + path): $uri');
          return (imageData: null, filePath: null);
        }
        final serverName = parsed.$1;
        final mediaId = parsed.$2;

        final Uri httpUri;
        try {
          httpUri = widget.isThumbnail
              ? await uri.getThumbnailUri(
                  client,
                  width: realWidth,
                  height: realHeight,
                  animated: widget.animated,
                  method: widget.thumbnailMethod,
                )
              : await uri.getDownloadUri(client);
        } catch (e, st) {
          debugPrint('[MxcImage] resolve URL failed: $e\n$st');
          Logs().w('MxcImage::_load: failed to resolve media URL: $e\n$st');
          return (imageData: null, filePath: null);
        }

        if (httpUri.host.isEmpty) {
          debugPrint('[MxcImage] empty host after resolve: $uri');
          return (imageData: null, filePath: null);
        }

        final diskKey = _mxcDiskLogicalKey(uri, realWidth, realHeight);
        final diskBytes = await MxcDiskImageCache.instance.get(diskKey);
        if (diskBytes != null) {
          final ck = widget.cacheKey;
          if (ck != null && widget.cacheMap == null) {
            MxcImageCacheManager.instance.cacheImage(ck, diskBytes);
          }
          return (imageData: diskBytes, filePath: null);
        }

        if (_isCached == null && widget.event != null) {
          final cachedData = await client.database.getFile(httpUri);
          if (cachedData != null) {
            _isCached = true;
            return (imageData: cachedData, filePath: null);
          }
          _isCached = false;
        }

        try {
          final fr = widget.isThumbnail
              ? await client.getContentThumbnail(
                  serverName,
                  mediaId,
                  (realWidth ?? context.getCacheSize(512)).clamp(32, 4096),
                  (realHeight ?? context.getCacheSize(512)).clamp(32, 4096),
                  method: widget.thumbnailMethod == ThumbnailMethod.scale
                      ? Method.scale
                      : Method.crop,
                  animated: widget.animated,
                  allowRemote: true,
                )
              : await client.getContent(
                  serverName,
                  mediaId,
                  allowRemote: true,
                );

          await MxcDiskImageCache.instance.put(diskKey, fr.data);
          if (widget.event != null) {
            await client.database.storeFile(httpUri, fr.data, 0);
          }
          return (imageData: fr.data, filePath: null);
        } catch (e, st) {
          debugPrint('[MxcImage] SDK getContent failed mxc=$uri: $e\n$st');
          Logs().w('MxcImage::_load: SDK getContent failed: $e\n$st');
          rethrow;
        }
      }

      // ── 普通 https 头像（极少见）：仍走 Matrix 配置的 httpClient ────────────────
      if (!uri.isScheme('http') && !uri.isScheme('https')) {
        debugPrint('[MxcImage] unsupported scheme: ${uri.scheme} ($uri)');
        return (imageData: null, filePath: null);
      }

      final httpsDiskKey = uri.toString();
      final httpsCached = await MxcDiskImageCache.instance.get(httpsDiskKey);
      if (httpsCached != null) {
        final ck = widget.cacheKey;
        if (ck != null && widget.cacheMap == null) {
          MxcImageCacheManager.instance.cacheImage(ck, httpsCached);
        }
        return (imageData: httpsCached, filePath: null);
      }

      final req = http.Request('GET', uri);
      final token = client.accessToken;
      if (token != null && token.isNotEmpty) {
        req.headers['Authorization'] = 'Bearer $token';
      }
      final streamed = await client.httpClient.send(req);
      final remoteData = await streamed.stream.toBytes();
      if (streamed.statusCode != 200) {
        if (streamed.statusCode == 404) {
          _mediaExpired = true;
          return (imageData: null, filePath: null);
        }
        debugPrint(
          '[MxcImage] GET ${streamed.statusCode} len=${remoteData.length} $uri',
        );
        Logs().w(
          'MxcImage::_load: media GET ${streamed.statusCode} '
          '(${remoteData.length}b) $uri',
        );
        throw Exception('MxcImage: HTTP ${streamed.statusCode}');
      }
      await MxcDiskImageCache.instance.put(httpsDiskKey, remoteData);
      return (imageData: remoteData, filePath: null);
    }

    if (event != null) {
      try {
        if (!PlatformInfos.isWeb) {
          final fileInfo = await event.getFileInfo(
            getThumbnail: widget.isThumbnail,
          );
          Logs().d('MxcImage::Downloaded get file info = $fileInfo');
          if (fileInfo != null) {
            return (imageData: fileInfo.bytes, filePath: fileInfo.filePath);
          }
        }

        final matrixFile = await event.downloadAndDecryptAttachment(
          getThumbnail: widget.isThumbnail,
        );
        Logs().d(
          'MxcImage::Downloaded attachment name = ${matrixFile.name} - mimeType = ${matrixFile.mimeType} - bytes = ${matrixFile.bytes.length}',
        );
        if (_notImageOrVideo(matrixFile, event)) {
          return (imageData: null, filePath: null);
        }
        return (imageData: matrixFile.bytes, filePath: null);
      } catch (e) {
        Logs().e('MxcImage::Error while downloading image: $e');
        rethrow;
      }
    }

    return (imageData: null, filePath: null);
  }

  bool _notImageOrVideo(MatrixFile matrixFile, Event event) =>
      !matrixFile.isImage() && !event.isVideoOrImage;

  Future<void> _tryLoad(BuildContext context, {int attempt = 0}) async {
    if (widget.imageData != null) {
      _imageData = widget.imageData;
      isLoadDone = true;
      filePath = null;
      if (mounted) setState(() {});
      return;
    }

    final ck = widget.cacheKey;
    if (ck != null &&
        widget.cacheMap == null &&
        MxcImageCacheManager.instance.getImage(ck) != null) {
      isLoadDone = true;
      filePath = null;
      if (mounted) setState(() {});
      return;
    }

    try {
      final loadResult = await _load(context);
      if (!mounted) return;
      isLoadDone = true;
      _imageData = loadResult.imageData;
      filePath = loadResult.filePath;
      setState(() {});
    } catch (e, st) {
      // 历史上这里在「首次失败」时先设 isLoadDone=true 再递归 _tryLoad，
      // 导致内层第一次 catch 必走「已过期」分支（误杀 TLS/瞬时网络错误）。
      debugPrint('[MxcImage] _tryLoad#$attempt uri=${widget.uri} err=$e');
      debugPrint('$st');
      if (!mounted) return;
      if (attempt < 1) {
        await Future<void>.delayed(widget.retryDuration);
        if (mounted) await _tryLoad(context, attempt: attempt + 1);
      } else {
        _mediaExpired = true;
        isLoadDone = true;
        setState(() {});
      }
    }
  }

  void _onTap(BuildContext context) async {
    if (widget.onTapPreview != null) {
      widget.onTapPreview!();
      final result =
          await Navigator.of(context, rootNavigator: PlatformInfos.isWeb).push(
            HeroPageRoute(
              builder: (context) {
                return InteractiveViewerGallery(
                  itemBuilder: PlatformInfos.isMobile
                      ? MediaViewer(event: widget.event!)
                      : ImageViewer(event: widget.event!),
                );
              },
            ),
          );
      if (result == MediaViewerPopupResultEnum.closeRightColumnFlag) {
        widget.closeRightColumn?.call();
      }
    } else if (widget.onTapSelectMode != null) {
      widget.onTapSelectMode!();
      return;
    } else {
      return;
    }
  }

  Widget placeholder(BuildContext context) =>
      widget.placeholder?.call(context) ??
      const Center(
        key: Key(placeholderKey),
        child: CupertinoActivityIndicator(),
      );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _tryLoad(context);
      }
    });
  }

  @override
  void didUpdateWidget(covariant MxcImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Retry loading when the event changes (e.g. local echo → confirmed event)
    // or when the URI/cacheKey changes. This ensures forwarded images reload
    // when the sending event is replaced by the server-confirmed event.
    if (oldWidget.event?.eventId != widget.event?.eventId ||
        oldWidget.uri != widget.uri ||
        oldWidget.cacheKey != widget.cacheKey ||
        oldWidget.matrixClient != widget.matrixClient) {
      isLoadDone = false;
      _mediaExpired = false;
      _imageDataNoCache = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _tryLoad(context);
      });
    }
  }

  @override
  void dispose() {
    _imageDataNoCache = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    Widget imageWidget = widget.animated
        ? AnimatedSwitcher(
            duration: widget.animationDuration,
            child: _buildImageWidget(context),
          )
        : _buildImageWidget(context);

    if (widget.event?.eventId != null && widget.enableHeroAnimation) {
      imageWidget = Hero(tag: widget.event!.eventId, child: imageWidget);
    }

    if (widget.isPreview) {
      return Material(
        child: InkWell(
          mouseCursor: SystemMouseCursors.click,
          borderRadius: widget.rounded
              ? BorderRadius.circular(12.0)
              : BorderRadius.zero,
          onTap: widget.onTapPreview != null || widget.onTapSelectMode != null
              ? () => _onTap(context)
              : null,
          child: imageWidget,
        ),
      );
    } else {
      return imageWidget;
    }
  }

  Widget _expiredPlaceholder() => Container(
        color: const Color(0xFF1C1B1C),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.schedule_outlined,
                color: Color(0xFF636363),
                size: 24,
              ),
              SizedBox(height: 4),
              Text(
                '已过期',
                style: TextStyle(
                  color: Color(0xFF636363),
                  fontSize: 10,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildImageWidget(BuildContext context) {
    final needResize = widget.event != null && !widget.noResize;
    if (_imageData == null && filePath == null) {
      return _mediaExpired ? _expiredPlaceholder() : placeholder(context);
    }
    return ClipRRect(
      key: Key('${_imageData.hashCode}'),
      borderRadius: widget.rounded
          ? BorderRadius.circular(12.0)
          : BorderRadius.zero,
      child: _ImageWidget(
        filePath: filePath,
        event: widget.event,
        data: _imageData,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        needResize: needResize,
        cacheWidth: widget.cacheWidth,
        cacheHeight: widget.cacheHeight,
        isThumbnail: widget.isThumbnail,
        imageErrorWidgetBuilder: (context, error, ___) {
          _isCached = false;
          _imageData = null;
          return placeholder(context);
        },
        placeholder: placeholder(context),
      ),
    );
  }

  @override
  bool get wantKeepAlive => widget.keepAlive;
}

class _ImageWidget extends StatelessWidget {
  final String? filePath;
  final Uint8List? data;
  final double? width;
  final Event? event;
  final double? height;
  final bool needResize;
  final BoxFit? fit;
  final ImageErrorWidgetBuilder imageErrorWidgetBuilder;
  final int? cacheWidth;
  final int? cacheHeight;
  final bool isThumbnail;
  final Widget placeholder;

  const _ImageWidget({
    this.filePath,
    this.data,
    this.width,
    this.event,
    this.height,
    required this.needResize,
    this.fit,
    required this.imageErrorWidgetBuilder,
    this.cacheWidth,
    this.cacheHeight,
    required this.isThumbnail,
    required this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    if (_isVideoData) {
      final matrixVideoFile = MatrixVideoFile(
        bytes: data!,
        name: event?.filename ?? '${DateTime.now().millisecondsSinceEpoch}.mp4',
        mimeType: event?.mimeType,
      );
      return FutureBuilder(
        future: event?.room.generateVideoThumbnail(matrixVideoFile),
        builder: (context, snapshot) {
          if (snapshot.data == null) {
            return placeholder;
          }

          return Image.memory(
            snapshot.data!.bytes,
            width: width,
            height: height,
            cacheWidth: cacheWidth != null
                ? cacheWidth!
                : (width != null && needResize)
                ? context.getCacheSize(width!)
                : null,
            cacheHeight: cacheHeight != null
                ? cacheHeight!
                : (height != null && needResize)
                ? context.getCacheSize(height!)
                : null,
            fit: fit,
            filterQuality: FilterQuality.medium,
            errorBuilder: imageErrorWidgetBuilder,
          );
        },
      );
    }
    return filePath != null && filePath!.isNotEmpty
        ? _ImageNativeBuilder(
            filePath: filePath,
            width: width,
            height: height,
            cacheWidth: cacheWidth,
            needResize: needResize,
            cacheHeight: cacheHeight,
            fit: fit,
            event: event,
            imageErrorWidgetBuilder: imageErrorWidgetBuilder,
          )
        : data != null
        ? event?.mimeType == TwakeMimeTypeExtension.avifMimeType
              ? AvifImage.memory(
                  data!,
                  height: height,
                  width: width,
                  fit: BoxFit.cover,
                  errorBuilder: imageErrorWidgetBuilder,
                )
              : Image.memory(
                  data!,
                  width: width,
                  height: height,
                  cacheWidth: cacheWidth != null
                      ? cacheWidth!
                      : (width != null && needResize)
                      ? context.getCacheSize(width!)
                      : null,
                  cacheHeight: cacheHeight != null
                      ? cacheHeight!
                      : (height != null && needResize)
                      ? context.getCacheSize(height!)
                      : null,
                  fit: fit,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: imageErrorWidgetBuilder,
                )
        : const SizedBox.shrink();
  }

  bool get _isVideoData {
    return event?.messageType == MessageTypes.Video &&
        data != null &&
        !isThumbnail;
  }
}

class _ImageNativeBuilder extends StatelessWidget {
  const _ImageNativeBuilder({
    this.filePath,
    this.width,
    this.height,
    this.cacheWidth,
    required this.needResize,
    this.cacheHeight,
    this.fit,
    required this.imageErrorWidgetBuilder,
    this.event,
  });

  final String? filePath;
  final Event? event;
  final double? width;
  final double? height;
  final int? cacheWidth;
  final bool needResize;
  final int? cacheHeight;
  final BoxFit? fit;
  final ImageErrorWidgetBuilder imageErrorWidgetBuilder;

  @override
  Widget build(BuildContext context) {
    if (event?.mimeType == TwakeMimeTypeExtension.avifMimeType) {
      return AvifImage.file(
        File(filePath!),
        height: height,
        width: width,
        fit: BoxFit.cover,
        errorBuilder: imageErrorWidgetBuilder,
      );
    }
    return Image.file(
      File(filePath!),
      width: width,
      height: height,
      cacheWidth: cacheWidth != null
          ? cacheWidth!
          : (width != null && needResize)
          ? context.getCacheSize(width!)
          : null,
      cacheHeight: cacheHeight != null
          ? cacheHeight!
          : (height != null && needResize)
          ? context.getCacheSize(height!)
          : null,
      fit: fit,
      filterQuality: FilterQuality.medium,
      errorBuilder: imageErrorWidgetBuilder,
    );
  }
}
