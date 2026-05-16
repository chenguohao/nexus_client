import 'package:fluffychat/config/app_config.dart';
import 'package:fluffychat/data/network/extensions/file_info_extension.dart';
import 'package:fluffychat/domain/model/file_info/file_info.dart';
import 'package:fluffychat/zeon/utils/toast.dart';
import 'package:matrix/matrix.dart';

/// Client-side limit only (no Matrix [getConfig] round-trip), for instant picker feedback.
bool zeonWarnIfPickFileInfoTooBig(FileInfo info) {
  final isPhoto = info.msgType == MessageTypes.Image;
  final cap = AppConfig.zeonChatClientFacingUploadMaxBytes(
    serverMUploadSize: null,
    isChatImagePayload: isPhoto,
  );
  if (info.fileSize <= cap) return false;

  if (isPhoto) {
    Toast.show('单张图片不能超过 10MB，请重新选择。');
  } else {
    Toast.show('文件不可大于50M');
  }
  return true;
}

/// Same caps as [zeonWarnIfPickFileInfoTooBig] using name + known size (e.g. [PlatformFile.size]).
bool zeonWarnIfPickNameSizeTooBig(String fileName, int sizeBytes) {
  final probe = FileInfo(fileName);
  final isPhoto = probe.msgType == MessageTypes.Image;
  final cap = AppConfig.zeonChatClientFacingUploadMaxBytes(
    serverMUploadSize: null,
    isChatImagePayload: isPhoto,
  );
  if (sizeBytes <= cap) return false;

  if (isPhoto) {
    Toast.show('单张图片不能超过 10MB，请重新选择。');
  } else {
    Toast.show('文件不可大于50M');
  }
  return true;
}
