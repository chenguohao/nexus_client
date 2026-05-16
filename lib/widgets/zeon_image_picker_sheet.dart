import 'package:fluffychat/utils/zeon_gallery_photo_filter.dart';
import 'package:fluffychat/widgets/zeon_gallery_picker_content.dart';
import 'package:fluffychat/widgets/zeon_photo_picker_tokens.dart';
import 'package:flutter/material.dart';
import 'package:linagora_design_flutter/images_picker/image_item_widget.dart';
import 'package:linagora_design_flutter/images_picker/image_picker_grid_with_counter.dart';
import 'package:linagora_design_flutter/images_picker/images_picker_grid.dart';
import 'package:linagora_design_flutter/images_picker/use_camera_widget.dart';
import 'package:linagora_design_flutter/images_picker/view_permission_not_authorized.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';

/// Same API as [linagora_design_flutter] `ImagePicker`, plus Zeon-colored sheet /
/// album picker and stable Android sort ([zeonGalleryPathListFilter]).
class ZeonLinagoraImagePicker {
  static Future<T?> showImagesGridBottomSheet<T>({
    required BuildContext context,
    required ImagePickerGridController controller,
    required PermissionStatus permissionStatus,
    double? heightOfBottomSheet,
    Widget? goToSettingsWidget,
    CounterImageBuilder? counterImageBuilder,
    Widget? cameraWidget,
    Widget? bottomWidget,
    ImageProvider<Object>? backgroundImageCamera,
    void Function()? onCameraPressed,
    Color? backgroundColor,
    Color? assetBackgroundColor,
    Widget? selectMoreImageWidget,
    double initialChildSize = 0.4,
    double minChildSize = 0.4,
    double maxChildSize = 0.9,
    bool isScrollControlled = true,
    bool expandDraggableScrollableSheet = false,
    Widget? expandedWidget,
    AssetItemBuilder? assetItemBuilder,
    EdgeInsets? gridPadding,
    RequestType type = RequestType.common,
    void Function(BuildContext context)? onGoToSettings,
  }) async {
    var albums = <AssetPathEntity>[];

    final permission = permissionStatus == PermissionStatus.granted ||
        permissionStatus == PermissionStatus.limited;
    if (permission) {
      albums = await getAllAssetPaths(
        hasAll: true,
        onlyAll: false,
        type: type,
        filterOption: zeonGalleryPathListFilter,
      );
    }

    Widget buildBodyBottomSheet(
      List<AssetPathEntity> albumsIn,
      ScrollController scrollController,
    ) {
      const fallbackSelectMorePhoto = Icon(
        Icons.add_photo_alternate_outlined,
        size: 40,
        color: ZeonPhotoPickerTokens.textSecondary,
      );
      final effectiveSelectMoreTile =
          permissionStatus == PermissionStatus.limited
              ? (selectMoreImageWidget ?? fallbackSelectMorePhoto)
              : selectMoreImageWidget;

      if (permissionStatus == PermissionStatus.permanentlyDenied ||
          permissionStatus == PermissionStatus.denied) {
        return PermissionNotAuthorizedWidget(
          backgroundColor: backgroundColor,
          backgroundImageCamera: backgroundImageCamera,
          goToSettingsWidget: goToSettingsWidget,
          cameraWidget: cameraWidget,
          onCameraPressed: onCameraPressed,
          onGoToSettings: onGoToSettings,
        );
      }

      if (albumsIn.isNotEmpty) {
        if (counterImageBuilder != null) {
          return ZeonGalleryPickerContent(
            albums: albumsIn,
            controller: controller,
            scrollController: scrollController,
            counterImageBuilder: counterImageBuilder,
            permissionLimited:
                permissionStatus == PermissionStatus.limited,
            assetBackgroundColor: assetBackgroundColor,
            cameraWidget: cameraWidget,
            backgroundImageCamera: backgroundImageCamera,
            selectMoreImageWidget: effectiveSelectMoreTile,
            onCameraPressed: onCameraPressed,
            assetItemBuilder: assetItemBuilder,
            gridPadding: gridPadding,
          );
        }

        final firstAlbum = albumsIn.first;
        return ImagesPickerGrid(
          assetPath: firstAlbum,
          controller: controller,
          scrollController: scrollController,
          assetBackgroundColor: assetBackgroundColor,
          backgroundImage: backgroundImageCamera,
          selectMoreImageWidget: effectiveSelectMoreTile,
          isLimitSelectImage:
              permissionStatus == PermissionStatus.limited,
          cameraWidget: cameraWidget,
          onCameraPressed: onCameraPressed,
          assetItemBuilder: assetItemBuilder,
          gridPadding: gridPadding,
        );
      }

      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.only(left: 4.0, top: 12.0),
              width: 100,
              height: 100,
              child: cameraWidget ??
                  UseCameraWidget(
                    backgroundImage: backgroundImageCamera,
                    onPressed: onCameraPressed,
                  ),
            ),
          ),
        ],
      );
    }

    if (!context.mounted) return null;

    final resolvedBg =
        backgroundColor ?? ZeonPhotoPickerTokens.pageBg;

    // ignore: use_build_context_synchronously
    return showModalBottomSheet(
      context: context,
      backgroundColor: resolvedBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
      ),
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: MediaQuery.viewInsetsOf(context),
        child: Stack(
          children: [
            DraggableScrollableSheet(
              initialChildSize: initialChildSize,
              minChildSize: minChildSize,
              maxChildSize: maxChildSize,
              expand: false,
              builder:
                  (BuildContext context, ScrollController scrollController) {
                return Column(
                  children: [
                    Expanded(
                      child: buildBodyBottomSheet(albums, scrollController),
                    ),
                    expandedWidget ?? const SizedBox.shrink(),
                  ],
                );
              },
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: bottomWidget ?? const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  static Future<List<AssetPathEntity>> getAllAssetPaths({
    bool hasAll = true,
    bool onlyAll = false,
    RequestType type = RequestType.common,
    PMFilter? filterOption,
  }) async {
    return PhotoManager.getAssetPathList(
      hasAll: hasAll,
      onlyAll: onlyAll,
      type: type,
      filterOption: filterOption ?? zeonGalleryPathListFilter,
    );
  }
}
