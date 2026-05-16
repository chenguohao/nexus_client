import 'package:fluffychat/presentation/state/failure.dart';
import 'package:fluffychat/presentation/state/success.dart';
import 'package:matrix/matrix.dart';

class GenerateThumbnailsMediaState extends UIState {}

class GenerateThumbnailsMediaInitial extends GenerateThumbnailsMediaState {
  /// Matrix `/config` `m.upload.size` when authenticated; nullable if unknown.
  final int? serverMUploadSize;

  GenerateThumbnailsMediaInitial({required this.serverMUploadSize});

  @override
  List<Object?> get props => [serverMUploadSize];
}

class GenerateThumbnailsMediaSuccess extends GenerateThumbnailsMediaState {
  final MatrixFile file;

  final MatrixImageFile thumbnail;

  GenerateThumbnailsMediaSuccess({required this.file, required this.thumbnail});

  @override
  List<Object?> get props => [file, thumbnail];
}

class GenerateThumbnailsMediaFailure extends FeatureFailure {
  const GenerateThumbnailsMediaFailure(dynamic exception)
    : super(exception: exception);
}
