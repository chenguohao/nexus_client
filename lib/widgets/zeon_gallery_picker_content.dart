import 'package:flutter/material.dart';
import 'package:linagora_design_flutter/images_picker/image_picker_grid_with_counter.dart';
import 'package:linagora_design_flutter/images_picker/image_item_widget.dart';
import 'package:linagora_design_flutter/images_picker/images_picker_grid.dart';
import 'package:photo_manager/photo_manager.dart';

import 'zeon_image_picker_grid_with_counter.dart';
import 'zeon_photo_picker_tokens.dart';

/// Album dropdown + gallery grid using Zeon colors; clears selection when album changes.
class ZeonGalleryPickerContent extends StatefulWidget {
  const ZeonGalleryPickerContent({
    super.key,
    required this.albums,
    required this.controller,
    required this.counterImageBuilder,
    required this.scrollController,
    required this.permissionLimited,
    this.assetBackgroundColor,
    this.cameraWidget,
    this.backgroundImageCamera,
    this.selectMoreImageWidget,
    this.onCameraPressed,
    this.assetItemBuilder,
    this.gridPadding,
  });

  final List<AssetPathEntity> albums;
  final ImagePickerGridController controller;
  final CounterImageBuilder counterImageBuilder;
  final ScrollController scrollController;
  final bool permissionLimited;
  final Color? assetBackgroundColor;
  final Widget? cameraWidget;
  final ImageProvider<Object>? backgroundImageCamera;
  final Widget? selectMoreImageWidget;
  final void Function()? onCameraPressed;
  final AssetItemBuilder? assetItemBuilder;
  final EdgeInsets? gridPadding;

  @override
  State<ZeonGalleryPickerContent> createState() =>
      _ZeonGalleryPickerContentState();
}

class _ZeonGalleryPickerContentState extends State<ZeonGalleryPickerContent> {
  late AssetPathEntity _album;

  @override
  void initState() {
    super.initState();
    _album = widget.albums.first;
    widget.controller.assetPath = _album;
  }

  void _switchAlbum(String? id) {
    if (id == null || id == _album.id) return;
    AssetPathEntity? next;
    for (final p in widget.albums) {
      if (p.id == id) {
        next = p;
        break;
      }
    }
    if (next == null) return;

    final AssetPathEntity picked = next;
    setState(() {
      _album = picked;
      widget.controller.assetPath = picked;
      widget.controller.removeAllSelectedItem();
    });
  }

  Widget _albumBar() {
    if (widget.albums.length <= 1) return const SizedBox.shrink();

    final items = widget.albums.map<DropdownMenuItem<String>>((album) {
      final label = album.name.trim().isEmpty ? 'Album' : album.name;
      return DropdownMenuItem<String>(
        value: album.id,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: ZeonPhotoPickerTokens.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.28,
              fontFamily: 'Inter',
            ),
          ),
        ),
      );
    }).toList();

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: ZeonPhotoPickerTokens.sectionBg,
        border:
            Border(bottom: BorderSide(color: ZeonPhotoPickerTokens.divider)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Theme(
        data: Theme.of(context).copyWith(
          canvasColor: ZeonPhotoPickerTokens.cardBg,
          brightness: Brightness.dark,
          splashColor: Colors.white10,
          highlightColor: Colors.white10,
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _album.id,
            isExpanded: true,
            dropdownColor: ZeonPhotoPickerTokens.cardBg,
            borderRadius: BorderRadius.zero,
            iconEnabledColor: ZeonPhotoPickerTokens.textSecondary,
            style: const TextStyle(
              color: ZeonPhotoPickerTokens.textPrimary,
              fontSize: 13,
              fontFamily: 'Inter',
              letterSpacing: 0.28,
            ),
            items: items,
            onChanged: _switchAlbum,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _albumBar(),
        Expanded(
          child: ZeonImagePickerGridWithCounter(
            assetPath: _album,
            counterBuilder: widget.counterImageBuilder,
            scrollController: widget.scrollController,
            controller: widget.controller,
            assetBackgroundColor: widget.assetBackgroundColor,
            cameraWidget: widget.cameraWidget,
            backgroundImageCamera: widget.backgroundImageCamera,
            isLimitSelectImage: widget.permissionLimited,
            selectMoreImageWidget: widget.selectMoreImageWidget,
            onCameraPressed: widget.onCameraPressed,
            assetItemBuilder: widget.assetItemBuilder,
            gridPadding: widget.gridPadding,
          ),
        ),
      ],
    );
  }
}
