import 'dart:io';

import 'package:file_picker/file_picker.dart';
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

mixin SendFilesMixin {
  static const int _maxVideoSizeBytes = 100 * 1024 * 1024; // 100 MB

  Future<void> sendMedia(
    ImagePickerGridController imagePickerController, {
    required BuildContext context,
    String? caption,
    Room? room,
    Event? inReplyTo,
  }) async {
    if (room == null) return;

    final selectedAssets = imagePickerController.sortedSelectedAssets;

    // Validate video file sizes before uploading.
    for (final indexed in selectedAssets) {
      final asset = indexed.asset;
      if (asset.type != AssetType.video) continue;

      final file = await asset.originFile;
      if (file == null) continue;

      final sizeBytes = await File(file.path).length();
      if (sizeBytes > _maxVideoSizeBytes) {
        if (context.mounted) {
          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF1C1B1C),
              title: const Text(
                '视频文件过大',
                style: TextStyle(color: Color(0xFFE5E2E3)),
              ),
              content: const Text(
                '视频文件不能超过 100MB，请重新选择。',
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
        return; // abort send
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
      withData: true,
      allowMultiple: true,
    );
    if (result == null || result.xFiles.isEmpty) return [];
    return await Future.wait(
      result.xFiles.map((file) => file.toMatrixFileOnWeb()),
    );
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
