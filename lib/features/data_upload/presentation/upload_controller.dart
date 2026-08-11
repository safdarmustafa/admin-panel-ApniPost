import 'dart:math';

import 'package:apnipost_admin/core/errors/app_failure.dart';
import 'package:apnipost_admin/features/categories/domain/category.dart';
import 'package:apnipost_admin/features/categories/presentation/categories_controller.dart';
import 'package:apnipost_admin/features/data_upload/data/browser_file_picker.dart';
import 'package:apnipost_admin/features/data_upload/data/supabase_upload_repository.dart';
import 'package:apnipost_admin/features/data_upload/domain/upload_limits.dart';
import 'package:apnipost_admin/features/data_upload/domain/upload_media_mapping.dart';
import 'package:apnipost_admin/features/data_upload/domain/upload_models.dart';
import 'package:apnipost_admin/features/data_upload/domain/upload_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final uploadRepositoryProvider = Provider<UploadRepository>((ref) {
  return SupabaseUploadRepository();
});

/// Reuses the categories repository — does not invent a second category service.
final uploadCategoriesProvider =
    FutureProvider.autoDispose<List<ContentCategory>>((ref) async {
  return ref.watch(categoriesRepositoryProvider).fetchCategories();
});

class DataUploadController extends Notifier<DataUploadState> {
  UploadRepository get _repository => ref.read(uploadRepositoryProvider);

  @override
  DataUploadState build() => const DataUploadState();

  void selectCategory(String? categoryName) {
    if (state.isUploading) return;
    state = state.copyWith(
      selectedCategoryName: categoryName,
      clearError: true,
    );
  }

  Future<void> pickFiles() async {
    if (!state.canPickFiles) {
      state = state.copyWith(
        errorMessage: UploadMediaMapping.validateCategoryName(
          state.selectedCategoryName,
        ),
      );
      return;
    }

    late final List<BrowserPickedFile> picked;
    try {
      // Call picker immediately (no prior awaits) so the browser keeps the
      // user activation needed to open the native file dialog.
      picked = await BrowserFilePicker.pickMultiple();
    } catch (error, stackTrace) {
      debugPrint('BrowserFilePicker failed: $error\n$stackTrace');
      state = state.copyWith(
        errorMessage: 'Unable to open the file picker. Please try again.',
      );
      return;
    }

    if (picked.isEmpty) return; // User cancelled — no error.

    try {
      addBrowserFiles(picked);
    } catch (error, stackTrace) {
      debugPrint('addBrowserFiles failed: $error\n$stackTrace');
      state = state.copyWith(
        errorMessage: 'Unable to process the selected file(s). Please try again.',
      );
    }
  }

  void addBrowserFiles(List<BrowserPickedFile> picked) {
    if (!state.canPickFiles) return;

    final next = [...state.files];
    var rejected = 0;
    String? rejectReason;
    final usedClientNames = {
      for (final file in next) file.clientFileName,
    };

    for (final platformFile in picked) {
      if (next.length >= UploadLimits.maxFilesPerBatch) {
        rejected++;
        rejectReason =
            'A maximum of ${UploadLimits.maxFilesPerBatch} files can be uploaded at once.';
        break;
      }

      final contentType = _resolveContentType(
        mimeType: platformFile.mimeType,
        fileName: platformFile.name,
      );
      final typeError = UploadMediaMapping.validateContentType(contentType);
      if (typeError != null) {
        rejected++;
        rejectReason = typeError;
        continue;
      }

      final sizeError = UploadMediaMapping.validateSize(
        contentType: contentType!,
        sizeBytes: platformFile.bytes.length,
      );
      if (sizeError != null) {
        rejected++;
        rejectReason = sizeError;
        continue;
      }

      final originalName = platformFile.name;
      final clientFileName = _uniqueClientFileName(
        originalName,
        usedClientNames,
      );
      usedClientNames.add(clientFileName);

      next.add(
        SelectedUploadFile(
          localId: _newLocalId(),
          originalFileName: originalName,
          clientFileName: clientFileName,
          contentType: contentType,
          sizeBytes: platformFile.bytes.length,
          bytes: Uint8List.fromList(platformFile.bytes),
          status: UploadItemStatus.ready,
        ),
      );
    }

    state = state.copyWith(
      files: next,
      rejectedCount: rejected,
      lastRejectedReason: rejectReason,
      clearError: true,
      phase: UploadPhase.selecting,
    );
  }

  void removeFile(String localId) {
    if (state.isUploading) return;
    final next = state.files
        .where((file) => file.localId != localId)
        .toList(growable: false);
    state = state.copyWith(
      files: next,
      phase: next.isEmpty ? UploadPhase.idle : UploadPhase.selecting,
      clearRejected: true,
      clearError: true,
    );
  }

  void clearAll() {
    if (state.isUploading) return;
    state = state.copyWith(
      files: const [],
      phase: UploadPhase.idle,
      clearError: true,
      clearRejected: true,
    );
  }

  void resetForMoreUploads() {
    state = DataUploadState(
      selectedCategoryName: state.selectedCategoryName,
    );
  }

  Future<void> startUpload() async {
    if (state.isUploading) return;

    final categoryError =
        UploadMediaMapping.validateCategoryName(state.selectedCategoryName);
    if (categoryError != null) {
      state = state.copyWith(errorMessage: categoryError);
      return;
    }

    final readyFiles = state.files
        .where((file) => file.status == UploadItemStatus.ready)
        .toList(growable: false);
    final batchError = UploadMediaMapping.validateBatchCount(readyFiles.length);
    if (batchError != null) {
      state = state.copyWith(errorMessage: batchError);
      return;
    }

    final categoryName = state.selectedCategoryName!.trim();
    state = state.copyWith(
      phase: UploadPhase.uploading,
      clearError: true,
      clearRejected: true,
    );

    try {
      final exists = await _repository.categoryExists(categoryName);
      if (!exists) {
        state = state.copyWith(
          phase: UploadPhase.selecting,
          errorMessage:
              'The selected category was not found. Refresh and try again.',
        );
        return;
      }
    } on AppFailure catch (failure) {
      state = state.copyWith(
        phase: UploadPhase.selecting,
        errorMessage: failure.message,
      );
      return;
    }

    await _presignAndUpload(categoryName: categoryName, targets: readyFiles);
  }

  Future<void> retryFailed() async {
    if (state.isUploading || !state.hasFailedFiles) return;

    final categoryError =
        UploadMediaMapping.validateCategoryName(state.selectedCategoryName);
    if (categoryError != null) {
      state = state.copyWith(errorMessage: categoryError);
      return;
    }

    final categoryName = state.selectedCategoryName!.trim();
    final failed = state.files
        .where((file) => file.status == UploadItemStatus.failed)
        .toList(growable: false);

    state = state.copyWith(
      phase: UploadPhase.uploading,
      clearError: true,
    );

    final dbOnly = failed.where((f) => f.canRetryDatabaseOnly).toList();
    final needsFullRetry =
        failed.where((f) => !f.canRetryDatabaseOnly).toList();

    for (final file in dbOnly) {
      await _retryDatabaseInsert(categoryName: categoryName, file: file);
    }

    if (needsFullRetry.isNotEmpty) {
      final reset = [
        for (final file in state.files)
          if (needsFullRetry.any((f) => f.localId == file.localId))
            file.copyWith(
              status: UploadItemStatus.ready,
              clearError: true,
              clearPresign: true,
              r2Succeeded: false,
              dbSucceeded: false,
            )
          else
            file,
      ];
      state = state.copyWith(files: reset);

      final targets = state.files
          .where(
            (file) => needsFullRetry.any((f) => f.localId == file.localId),
          )
          .toList(growable: false);

      await _presignAndUpload(categoryName: categoryName, targets: targets);
      return;
    }

    state = state.copyWith(phase: UploadPhase.completed);
  }

  Future<void> _presignAndUpload({
    required String categoryName,
    required List<SelectedUploadFile> targets,
  }) async {
    debugPrint(
      '[Upload] controller stage=presign batchSize=${targets.length}',
    );
    late final List<PresignResponseItem> pred;
    try {
      pred = await _repository.createUploadUrls(
        categoryName: categoryName,
        files: [
          for (final file in targets)
            PresignRequestFile(
              fileName: file.clientFileName,
              contentType: file.contentType,
              sizeBytes: file.sizeBytes,
            ),
        ],
      );
    } on AppFailure catch (failure) {
      debugPrint(
        '[Upload] controller stage=presign FAILED message=${failure.message}',
      );
      final marked = [
        for (final file in state.files)
          if (targets.any((t) => t.localId == file.localId))
            file.copyWith(
              status: UploadItemStatus.failed,
              failureStage: UploadFailureStage.presign,
              errorMessage: failure.message,
            )
          else
            file,
      ];
      state = state.copyWith(
        files: marked,
        phase: UploadPhase.completed,
        errorMessage: failure.message,
      );
      return;
    }

    final byClientName = <String, PresignResponseItem>{
      for (final item in pred) item.clientFileName: item,
    };

    final withPresign = <SelectedUploadFile>[
      for (final file in state.files)
        if (targets.any((t) => t.localId == file.localId))
          _attachPresign(file, byClientName)
        else
          file,
    ];
    state = state.copyWith(files: withPresign);

    final toUpload = state.files
        .where(
          (file) =>
              targets.any((t) => t.localId == file.localId) &&
              file.status != UploadItemStatus.failed &&
              file.uploadUrl != null,
        )
        .toList(growable: false);

    debugPrint(
      '[Upload] controller stage=r2_put queueSize=${toUpload.length}',
    );

    await _runWithConcurrency(
      toUpload,
      UploadLimits.maxConcurrentUploads,
      (file) => _uploadOne(categoryName: categoryName, file: file),
    );

    for (final file in state.files.where(
      (f) => targets.any((t) => t.localId == f.localId),
    )) {
      debugPrint(
        '[Upload] controller result file=${file.originalFileName} '
        'status=${file.status.name} stage=${file.failureStage?.name ?? '-'} '
        'r2=${file.r2Succeeded} db=${file.dbSucceeded} '
        'objectKey=${file.objectKey ?? '-'} '
        'message=${file.errorMessage ?? '-'}',
      );
    }

    state = state.copyWith(phase: UploadPhase.completed);
  }

  SelectedUploadFile _attachPresign(
    SelectedUploadFile file,
    Map<String, PresignResponseItem> byClientName,
  ) {
    final item = byClientName[file.clientFileName];
    if (item == null) {
      return file.copyWith(
        status: UploadItemStatus.failed,
        failureStage: UploadFailureStage.presign,
        errorMessage: 'Upload authorization missing for this file.',
      );
    }
    return file.copyWith(
      uploadUrl: item.uploadUrl,
      publicUrl: item.publicUrl,
      objectKey: item.objectKey,
      status: UploadItemStatus.ready,
      clearError: true,
    );
  }

  Future<void> _uploadOne({
    required String categoryName,
    required SelectedUploadFile file,
  }) async {
    _updateFile(
      file.localId,
      (current) => current.copyWith(
        status: UploadItemStatus.uploading,
        clearError: true,
      ),
    );

    final latest = _find(file.localId);
    if (latest == null || latest.uploadUrl == null || latest.publicUrl == null) {
      _updateFile(
        file.localId,
        (current) => current.copyWith(
          status: UploadItemStatus.failed,
          failureStage: UploadFailureStage.presign,
          errorMessage: 'Upload authorization missing for this file.',
        ),
      );
      return;
    }

    try {
      await _repository.uploadToR2(
        uploadUrl: latest.uploadUrl!,
        contentType: latest.contentType,
        bytes: latest.bytes,
        objectKey: latest.objectKey,
      );
    } on AppFailure catch (failure) {
      debugPrint(
        '[Upload] controller stage=r2_put FAILED '
        'objectKey=${latest.objectKey ?? '-'} message=${failure.message}',
      );

      final canProxy =
          latest.bytes.lengthInBytes <= UploadLimits.maxProxyUploadBytes;
      if (!canProxy) {
        _updateFile(
          file.localId,
          (current) => current.copyWith(
            status: UploadItemStatus.failed,
            failureStage: UploadFailureStage.r2Upload,
            errorMessage: failure.message,
            r2Succeeded: false,
          ),
        );
        return;
      }

      debugPrint(
        '[Upload] controller falling back to proxy-r2-upload '
        '(bytes=${latest.bytes.lengthInBytes})',
      );

      try {
        final proxied = await _repository.uploadViaProxy(
          categoryName: categoryName,
          fileName: latest.clientFileName,
          contentType: latest.contentType,
          bytes: latest.bytes,
        );
        _updateFile(
          file.localId,
          (current) => current.copyWith(
            publicUrl: proxied.publicUrl,
            objectKey: proxied.objectKey,
            r2Succeeded: true,
            clearError: true,
          ),
        );
      } on AppFailure catch (proxyFailure) {
        debugPrint(
          '[Upload] controller stage=proxy_put FAILED '
          'message=${proxyFailure.message}',
        );
        _updateFile(
          file.localId,
          (current) => current.copyWith(
            status: UploadItemStatus.failed,
            failureStage: UploadFailureStage.r2Upload,
            errorMessage: proxyFailure.message,
            r2Succeeded: false,
          ),
        );
        return;
      }

      final afterProxy = _find(file.localId);
      if (afterProxy?.publicUrl == null) {
        _updateFile(
          file.localId,
          (current) => current.copyWith(
            status: UploadItemStatus.failed,
            failureStage: UploadFailureStage.r2Upload,
            errorMessage: 'Proxy upload did not return a public URL.',
            r2Succeeded: false,
          ),
        );
        return;
      }

      await _insertDatabase(
        categoryName: categoryName,
        localId: file.localId,
        publicUrl: afterProxy!.publicUrl!,
        contentType: latest.contentType,
      );
      return;
    }

    debugPrint(
      '[Upload] controller stage=r2_put OK objectKey=${latest.objectKey ?? '-'}',
    );

    _updateFile(
      file.localId,
      (current) => current.copyWith(r2Succeeded: true),
    );

    await _insertDatabase(
      categoryName: categoryName,
      localId: file.localId,
      publicUrl: latest.publicUrl!,
      contentType: latest.contentType,
    );
  }

  Future<void> _retryDatabaseInsert({
    required String categoryName,
    required SelectedUploadFile file,
  }) async {
    _updateFile(
      file.localId,
      (current) => current.copyWith(
        status: UploadItemStatus.uploading,
        clearError: true,
      ),
    );

    final publicUrl = file.publicUrl;
    if (publicUrl == null) {
      _updateFile(
        file.localId,
        (current) => current.copyWith(
          status: UploadItemStatus.failed,
          failureStage: UploadFailureStage.databaseInsert,
          errorMessage: 'Missing public URL for database retry.',
        ),
      );
      return;
    }

    await _insertDatabase(
      categoryName: categoryName,
      localId: file.localId,
      publicUrl: publicUrl,
      contentType: file.contentType,
    );
  }

  Future<void> _insertDatabase({
    required String categoryName,
    required String localId,
    required String publicUrl,
    required String contentType,
  }) async {
    final mediaType = UploadMediaMapping.mediaTypeForContentType(contentType);
    if (mediaType == null) {
      _updateFile(
        localId,
        (current) => current.copyWith(
          status: UploadItemStatus.failed,
          failureStage: UploadFailureStage.databaseInsert,
          errorMessage: 'Uploaded to storage, database record failed.',
          r2Succeeded: true,
        ),
      );
      return;
    }

    try {
      await _repository.insertPost(
        categoryName: categoryName,
        mediaUrl: publicUrl,
        mediaType: mediaType,
      );
      debugPrint('[Upload] controller stage=db_insert OK localId=$localId');
      _updateFile(
        localId,
        (current) => current.copyWith(
          status: UploadItemStatus.uploaded,
          dbSucceeded: true,
          r2Succeeded: true,
          clearError: true,
        ),
      );
    } on AppFailure catch (failure) {
      debugPrint(
        '[Upload] controller stage=db_insert FAILED localId=$localId '
        'message=${failure.message}',
      );
      _updateFile(
        localId,
        (current) => current.copyWith(
          status: UploadItemStatus.failed,
          failureStage: UploadFailureStage.databaseInsert,
          errorMessage: failure.message.isNotEmpty
              ? failure.message
              : 'Uploaded to storage, database record failed.',
          r2Succeeded: true,
          dbSucceeded: false,
        ),
      );
    }
  }

  SelectedUploadFile? _find(String localId) {
    for (final file in state.files) {
      if (file.localId == localId) return file;
    }
    return null;
  }

  void _updateFile(
    String localId,
    SelectedUploadFile Function(SelectedUploadFile current) transform,
  ) {
    state = state.copyWith(
      files: [
        for (final file in state.files)
          if (file.localId == localId) transform(file) else file,
      ],
    );
  }

  Future<void> _runWithConcurrency<T>(
    List<T> items,
    int concurrency,
    Future<void> Function(T item) worker,
  ) async {
    if (items.isEmpty) return;
    final limit = max(1, concurrency);
    var index = 0;

    Future<void> consume() async {
      while (true) {
        final current = index;
        index++;
        if (current >= items.length) return;
        await worker(items[current]);
      }
    }

    await Future.wait([
      for (var i = 0; i < min(limit, items.length); i++) consume(),
    ]);
  }

  /// Prefer browser MIME; fall back to extension only when MIME is empty.
  String? _resolveContentType({
    required String mimeType,
    required String fileName,
  }) {
    final mime = mimeType.trim().toLowerCase();
    if (mime.isNotEmpty) {
      return mime;
    }

    final dot = fileName.lastIndexOf('.');
    if (dot < 0 || dot == fileName.length - 1) return null;
    final extension = fileName.substring(dot + 1).toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'mp4':
        return 'video/mp4';
      case 'webm':
        return 'video/webm';
      case 'mov':
        return 'video/quicktime';
      default:
        return null;
    }
  }

  String _uniqueClientFileName(String original, Set<String> used) {
    if (!used.contains(original)) return original;
    final dot = original.lastIndexOf('.');
    final stem = dot > 0 ? original.substring(0, dot) : original;
    final ext = dot > 0 ? original.substring(dot) : '';
    var i = 1;
    while (true) {
      final candidate = '$stem ($i)$ext';
      if (!used.contains(candidate)) return candidate;
      i++;
    }
  }

  /// Local ids only — must stay JS-safe. On web, `1 << 32` is `0`, which makes
  /// `Random.nextInt` throw `RangeError`.
  String _newLocalId() =>
      '${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(1 << 31)}';
}

final dataUploadControllerProvider =
    NotifierProvider<DataUploadController, DataUploadState>(
  DataUploadController.new,
);
