import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:fluffychat/config/app_config.dart';
import 'package:fluffychat/di/global/get_it_initializer.dart';
import 'package:fluffychat/domain/model/extensions/xfile/xfile_extension.dart';
import 'package:fluffychat/domain/model/file_info/file_info.dart';
import 'package:fluffychat/pages/chat/chat_actions.dart';
import 'package:fluffychat/presentation/model/file/file_asset_entity.dart';
import 'package:fluffychat/utils/manager/upload_manager/upload_manager.dart';
import 'package:flutter/material.dart';
import 'package:linagora_design_flutter/images_picker/images_picker.dart';
import 'package:matrix/matrix.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:fluffychat/utils/matrix_sdk_extensions/matrix_file_extension.dart';
import 'package:fluffychat/utils/twake_snackbar.dart';
import 'package:fluffychat/utils/zeon_chat_pick_limits.dart';

mixin SendFilesMixin {
  Future<void> sendMedia(
    ImagePickerGridController imagePickerController, {
    required BuildContext context,
    String? caption,
    Room? room,
    Event? inReplyTo,
  }) async {
    if (room == null) return;

    final selectedAssets = imagePickerController.sortedSelectedAssets;

    if (selectedAssets.length > AppConfig.maxChatGallerySelectionCount) {
      if (context.mounted) {
        TwakeSnackBar.show(
          context,
          '单次最多只能选择 ${AppConfig.maxChatGallerySelectionCount} 个相册文件',
        );
      }
      return;
    }

    int? serverMUpload;
    try {
      serverMUpload = (await room.client.getConfig()).mUploadSize;
    } catch (_) {}

    for (final indexed in selectedAssets) {
      final asset = indexed.asset;
      final file = await asset.originFile;
      if (file == null) continue;

      final sizeBytes = await File(file.path).length();
      final imageCap = AppConfig.zeonChatClientFacingUploadMaxBytes(
        serverMUploadSize: serverMUpload,
        isChatImagePayload: true,
      );
      final videoCap = AppConfig.zeonChatClientFacingUploadMaxBytes(
        serverMUploadSize: serverMUpload,
        isChatImagePayload: false,
      );

      if (asset.type == AssetType.image && sizeBytes > imageCap) {
        if (context.mounted) {
          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF1C1B1C),
              title: const Text(
                '图片过大',
                style: TextStyle(color: Color(0xFFE5E2E3)),
              ),
              content: const Text(
                '单张图片不能超过 10MB，请重新选择。',
                style: TextStyle(color: Color(0xFF919191)),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text(
                    '知道了',
                    style: TextStyle(color: Color(0xFFE5E2E3)),
                  ),
                ),
              ],
            ),
          );
        }
        return;
      }

      if (asset.type == AssetType.video && sizeBytes > videoCap) {
        if (context.mounted) {
          TwakeSnackBar.show(
            context,
            '文件不可大于50M',
          );
        }
        return;
      }
    }

    final uploadManger = getIt.get<UploadManager>();
    uploadManger.uploadMediaMobile(
      room: room,
      entities: selectedAssets.map<FileAssetEntity>((entity) {
        return FileAssetEntity.createAssetEntity(entity.asset);
      }).toList(),
      caption: caption,
      inReplyTo: inReplyTo,
    );
  }

  void sendFileAction(
    BuildContext context, {
    Room? room,
    List<FileInfo>? fileInfos,
    VoidCallback? onSendFileCallback,
    Event? inReplyTo,
  }) async {
    if (room == null) return;
    Navigator.pop(context);
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    fileInfos ??= result?.xFiles.map((file) {
      return FileInfo(file.name, filePath: file.path);
    }).toList();

    if (fileInfos == null || fileInfos.isEmpty) return;

    for (final info in fileInfos) {
      if (zeonWarnIfPickFileInfoTooBig(info)) return;
    }

    onSendFileCallback?.call();
    final uploadManger = getIt.get<UploadManager>();
    uploadManger.uploadFileMobile(
      room: room,
      fileInfos: fileInfos,
      inReplyTo: inReplyTo,
    );
  }

  Future<List<MatrixFile>> pickFilesFromSystem() async {
    final result = await FilePicker.platform.pickFiles(
      withData: false,
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return [];

    final xList = result.xFiles.toList();
    for (var i = 0; i < result.files.length; i++) {
      final pf = result.files[i];
      final sz =
          pf.size > 0 ? pf.size : await xList[i].length();
      if (sz > 0 && zeonWarnIfPickNameSizeTooBig(xList[i].name, sz)) {
        return [];
      }
    }

    final list = await Future.wait(
      xList.map((file) => file.toMatrixFileOnWeb()),
    );
    if (zeonWarnChatMatrixPickFilesTooBig(list)) {
      return [];
    }
    return list;
  }

  void onPickerTypeClick({
    required BuildContext context,
    Room? room,
    required PickerType type,
    VoidCallback? onSendFileCallback,
    Event? inReplyTo,
  }) async {
    switch (type) {
      case PickerType.gallery:
        break;
      case PickerType.documents:
        sendFileAction(
          context,
          room: room,
          onSendFileCallback: onSendFileCallback,
          inReplyTo: inReplyTo,
        );
        break;
      case PickerType.location:
        break;
      case PickerType.contact:
        break;
    }
  }
}
