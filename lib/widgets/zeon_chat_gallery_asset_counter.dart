import 'package:flutter/scheduler.dart';
import 'package:fluffychat/zeon/utils/toast.dart';
import 'package:linagora_design_flutter/images_picker/asset_counter.dart';
import 'package:linagora_design_flutter/images_picker/images_picker.dart';

/// Limits how many gallery items can be toggled on at once ([maxSelections]).
/// Extend upstream [AssetCounter] so taps still route through Linagora grid logic.
class ZeonChatGalleryAssetCounter extends AssetCounter {
  ZeonChatGalleryAssetCounter({
    super.imagePickerMode = ImagePickerMode.multiple,
    required this.maxSelections,
    this.onReachedSelectionLimit,
  });

  final int maxSelections;

  /// Optional extra hook after the limit toast (e.g. analytics).
  final VoidCallback? onReachedSelectionLimit;

  @override
  void toggleAssetSelection(int index) {
    if (isSelected(index)) {
      super.toggleAssetSelection(index);
      return;
    }
    if (currentTotalSelectedIndex >= maxSelections) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        Toast.show('最多可选${maxSelections}个');
        onReachedSelectionLimit?.call();
      });
      return;
    }
    super.toggleAssetSelection(index);
  }
}
