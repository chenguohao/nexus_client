import 'package:flutter/material.dart';
import 'package:linagora_design_flutter/images_picker/asset_counter.dart';
import 'package:linagora_design_flutter/images_picker/image_item_widget.dart';
import 'package:linagora_design_flutter/images_picker/image_picker_grid_with_counter.dart';
import 'package:linagora_design_flutter/images_picker/images_picker_grid.dart';
import 'package:photo_manager/photo_manager.dart';

import 'zeon_photo_picker_tokens.dart';

/// Zeon-themed variant of Linagora [ImagePickerGridWithCounter]:
/// rectangular drag indicator, Zeon divider colors — no upstream Linagora colors API.
class ZeonImagePickerGridWithCounter extends StatefulWidget {
  const ZeonImagePickerGridWithCounter({
    super.key,
    required this.assetPath,
    required this.counterBuilder,
    required this.scrollController,
    this.assetBackgroundColor,
    this.cameraWidget,
    this.backgroundImageCamera,
    this.controller,
    this.isLimitSelectImage = false,
    this.selectMoreImageWidget,
    this.onCameraPressed,
    this.assetItemBuilder,
    this.gridPadding,
  });

  final AssetPathEntity assetPath;
  final CounterImageBuilder counterBuilder;
  final ImagePickerGridController? controller;
  final Color? assetBackgroundColor;
  final Widget? cameraWidget;
  final ImageProvider<Object>? backgroundImageCamera;
  final bool isLimitSelectImage;
  final Widget? selectMoreImageWidget;
  final ScrollController scrollController;
  final void Function()? onCameraPressed;
  final AssetItemBuilder? assetItemBuilder;
  final EdgeInsets? gridPadding;

  @override
  State<ZeonImagePickerGridWithCounter> createState() =>
      _ZeonImagePickerGridWithCounterState();
}

class _ZeonImagePickerGridWithCounterState
    extends State<ZeonImagePickerGridWithCounter> {
  late final controller =
      widget.controller ?? ImagePickerGridController(AssetCounter());

  final imageCounterNotifier = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    controller.addListener(() {
      imageCounterNotifier.value = controller.selectedAssets.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ValueListenableBuilder(
          valueListenable: imageCounterNotifier,
          builder: (context, value, _) {
            if (value == 0) {
              return Column(
                children: [
                  const SizedBox(height: 16),
                  Container(
                    height: 2,
                    width: 36,
                    color: ZeonPhotoPickerTokens.textSecondary,
                  ),
                  const SizedBox(height: 20),
                ],
              );
            }
            return widget.counterBuilder(value);
          },
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 7,
              vertical: 4,
            ),
            child: ImagesPickerGrid(
              key: ValueKey<String>(widget.assetPath.id),
              assetPath: widget.assetPath,
              controller: controller,
              assetBackgroundColor: widget.assetBackgroundColor,
              cameraWidget: widget.cameraWidget,
              backgroundImage: widget.backgroundImageCamera,
              isLimitSelectImage: widget.isLimitSelectImage,
              selectMoreImageWidget: widget.selectMoreImageWidget,
              scrollController: widget.scrollController,
              onCameraPressed: widget.onCameraPressed,
              assetItemBuilder: widget.assetItemBuilder,
              gridPadding: widget.gridPadding,
            ),
          ),
        ),
      ],
    );
  }
}
