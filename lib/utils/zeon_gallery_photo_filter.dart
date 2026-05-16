import 'package:photo_manager/photo_manager.dart';

/// Default sort for PhotoManager album / asset queries.
///
/// Android: some OEM MediaStore implementations treat the `sortOrder` argument
/// as the fragment after `ORDER BY`. When [FilterOptionGroup.orders] is empty,
/// `photo_manager` can pass only `LIMIT … OFFSET …`, producing invalid SQL
/// (`ORDER BY LIMIT …`) and an infinite loading grid. A non-empty order fixes it.
/// See https://github.com/fluttercandies/flutter_photo_manager/issues/1340
final PMFilter zeonGalleryPathListFilter = FilterOptionGroup(
  orders: const <OrderOption>[
    OrderOption(
      type: OrderOptionType.createDate,
      asc: false,
    ),
  ],
);
