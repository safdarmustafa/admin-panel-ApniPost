import 'package:apnipost_admin/features/data_upload/domain/upload_media_mapping.dart';
import 'package:flutter/foundation.dart';

enum UploadItemStatus {
  ready,
  uploading,
  uploaded,
  failed,
}

enum UploadFailureStage {
  validation,
  presign,
  r2Upload,
  databaseInsert,
}

@immutable
class SelectedUploadFile {
  const SelectedUploadFile({
    required this.localId,
    required this.originalFileName,
    required this.clientFileName,
    required this.contentType,
    required this.sizeBytes,
    required this.bytes,
    required this.status,
    this.failureStage,
    this.errorMessage,
    this.uploadUrl,
    this.publicUrl,
    this.objectKey,
    this.r2Succeeded = false,
    this.dbSucceeded = false,
  });

  final String localId;

  /// Filename shown in the UI.
  final String originalFileName;

  /// Filename sent to the Edge Function / matched in the response.
  final String clientFileName;

  final String contentType;
  final int sizeBytes;
  final Uint8List bytes;
  final UploadItemStatus status;
  final UploadFailureStage? failureStage;
  final String? errorMessage;
  final String? uploadUrl;
  final String? publicUrl;
  final String? objectKey;
  final bool r2Succeeded;
  final bool dbSucceeded;

  PostMediaType? get mediaType =>
      UploadMediaMapping.mediaTypeForContentType(contentType);

  bool get isImagePreviewable {
    return contentType == 'image/jpeg' ||
        contentType == 'image/png' ||
        contentType == 'image/webp' ||
        contentType == 'image/gif';
  }

  bool get canRetry => status == UploadItemStatus.failed;

  /// R2 already succeeded — retry should only insert the post row.
  bool get canRetryDatabaseOnly =>
      status == UploadItemStatus.failed &&
      r2Succeeded &&
      publicUrl != null &&
      !dbSucceeded;

  SelectedUploadFile copyWith({
    String? localId,
    String? originalFileName,
    String? clientFileName,
    String? contentType,
    int? sizeBytes,
    Uint8List? bytes,
    UploadItemStatus? status,
    UploadFailureStage? failureStage,
    String? errorMessage,
    String? uploadUrl,
    String? publicUrl,
    String? objectKey,
    bool? r2Succeeded,
    bool? dbSucceeded,
    bool clearError = false,
    bool clearPresign = false,
  }) {
    final nextR2 = r2Succeeded ?? this.r2Succeeded;
    return SelectedUploadFile(
      localId: localId ?? this.localId,
      originalFileName: originalFileName ?? this.originalFileName,
      clientFileName: clientFileName ?? this.clientFileName,
      contentType: contentType ?? this.contentType,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      bytes: bytes ?? this.bytes,
      status: status ?? this.status,
      failureStage: clearError ? null : (failureStage ?? this.failureStage),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      uploadUrl: clearPresign ? null : (uploadUrl ?? this.uploadUrl),
      publicUrl: clearPresign && !nextR2 ? null : (publicUrl ?? this.publicUrl),
      objectKey: clearPresign && !nextR2 ? null : (objectKey ?? this.objectKey),
      r2Succeeded: nextR2,
      dbSucceeded: dbSucceeded ?? this.dbSucceeded,
    );
  }
}

@immutable
class PresignRequestFile {
  const PresignRequestFile({
    required this.fileName,
    required this.contentType,
    required this.sizeBytes,
  });

  final String fileName;
  final String contentType;
  final int sizeBytes;

  Map<String, dynamic> toJson() => {
        'fileName': fileName,
        'contentType': contentType,
        'sizeBytes': sizeBytes,
      };
}

@immutable
class PresignResponseItem {
  const PresignResponseItem({
    required this.clientFileName,
    required this.contentType,
    required this.objectKey,
    required this.uploadUrl,
    required this.publicUrl,
  });

  final String clientFileName;
  final String contentType;
  final String objectKey;
  final String uploadUrl;
  final String publicUrl;

  factory PresignResponseItem.fromJson(Map<String, dynamic> json) {
    return PresignResponseItem(
      clientFileName: json['clientFileName'] as String,
      contentType: json['contentType'] as String,
      objectKey: json['objectKey'] as String,
      uploadUrl: json['uploadUrl'] as String,
      publicUrl: json['publicUrl'] as String,
    );
  }
}

@immutable
class ProxyUploadResult {
  const ProxyUploadResult({
    required this.clientFileName,
    required this.contentType,
    required this.objectKey,
    required this.publicUrl,
  });

  final String clientFileName;
  final String contentType;
  final String objectKey;
  final String publicUrl;

  factory ProxyUploadResult.fromJson(Map<String, dynamic> json) {
    return ProxyUploadResult(
      clientFileName: json['clientFileName'] as String,
      contentType: json['contentType'] as String,
      objectKey: json['objectKey'] as String,
      publicUrl: json['publicUrl'] as String,
    );
  }
}

@immutable
class UploadBatchSummary {
  const UploadBatchSummary({
    required this.total,
    required this.succeeded,
    required this.failed,
    required this.imageCount,
    required this.gifCount,
    required this.videoCount,
    required this.r2Uploaded,
    required this.dbInserted,
  });

  final int total;
  final int succeeded;
  final int failed;
  final int imageCount;
  final int gifCount;
  final int videoCount;
  final int r2Uploaded;
  final int dbInserted;

  bool get hasFailures => failed > 0;
  bool get isCompleteSuccess => failed == 0 && succeeded == total && total > 0;

  factory UploadBatchSummary.fromFiles(List<SelectedUploadFile> files) {
    var succeeded = 0;
    var failed = 0;
    var images = 0;
    var gifs = 0;
    var videos = 0;
    var r2 = 0;
    var db = 0;

    for (final file in files) {
      if (file.status == UploadItemStatus.uploaded) {
        succeeded++;
      } else if (file.status == UploadItemStatus.failed) {
        failed++;
      }
      if (file.r2Succeeded) r2++;
      if (file.dbSucceeded) db++;
      switch (file.mediaType) {
        case PostMediaType.image:
          if (file.status == UploadItemStatus.uploaded) images++;
        case PostMediaType.gif:
          if (file.status == UploadItemStatus.uploaded) gifs++;
        case PostMediaType.video:
          if (file.status == UploadItemStatus.uploaded) videos++;
        case null:
          break;
      }
    }

    return UploadBatchSummary(
      total: files.length,
      succeeded: succeeded,
      failed: failed,
      imageCount: images,
      gifCount: gifs,
      videoCount: videos,
      r2Uploaded: r2,
      dbInserted: db,
    );
  }
}

enum UploadPhase {
  idle,
  selecting,
  uploading,
  completed,
}

@immutable
class DataUploadState {
  const DataUploadState({
    this.selectedCategoryName,
    this.files = const [],
    this.phase = UploadPhase.idle,
    this.errorMessage,
    this.rejectedCount = 0,
    this.lastRejectedReason,
  });

  final String? selectedCategoryName;
  final List<SelectedUploadFile> files;
  final UploadPhase phase;
  final String? errorMessage;
  final int rejectedCount;
  final String? lastRejectedReason;

  bool get hasCategory =>
      selectedCategoryName != null && selectedCategoryName!.trim().isNotEmpty;

  bool get isUploading => phase == UploadPhase.uploading;

  bool get canPickFiles => hasCategory && !isUploading;

  bool get canUpload =>
      hasCategory &&
      files.any((f) => f.status == UploadItemStatus.ready) &&
      !isUploading;

  int get readyCount =>
      files.where((f) => f.status == UploadItemStatus.ready).length;

  int get uploadedCount =>
      files.where((f) => f.status == UploadItemStatus.uploaded).length;

  int get failedCount =>
      files.where((f) => f.status == UploadItemStatus.failed).length;

  bool get hasFailedFiles => failedCount > 0;

  UploadBatchSummary get summary => UploadBatchSummary.fromFiles(files);

  DataUploadState copyWith({
    String? selectedCategoryName,
    List<SelectedUploadFile>? files,
    UploadPhase? phase,
    String? errorMessage,
    int? rejectedCount,
    String? lastRejectedReason,
    bool clearCategory = false,
    bool clearError = false,
    bool clearRejected = false,
  }) {
    return DataUploadState(
      selectedCategoryName:
          clearCategory ? null : (selectedCategoryName ?? this.selectedCategoryName),
      files: files ?? this.files,
      phase: phase ?? this.phase,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      rejectedCount: clearRejected ? 0 : (rejectedCount ?? this.rejectedCount),
      lastRejectedReason: clearRejected
          ? null
          : (lastRejectedReason ?? this.lastRejectedReason),
    );
  }
}
