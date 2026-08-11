import 'package:apnipost_admin/features/data_upload/domain/upload_limits.dart';
import 'package:apnipost_admin/features/data_upload/domain/upload_media_mapping.dart';
import 'package:apnipost_admin/features/data_upload/domain/upload_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UploadMediaMapping', () {
    test('maps MIME types to posts.media_type values', () {
      expect(
        UploadMediaMapping.mediaTypeForContentType('image/jpeg')?.dbValue,
        'image',
      );
      expect(
        UploadMediaMapping.mediaTypeForContentType('image/png')?.dbValue,
        'image',
      );
      expect(
        UploadMediaMapping.mediaTypeForContentType('image/webp')?.dbValue,
        'image',
      );
      expect(
        UploadMediaMapping.mediaTypeForContentType('image/gif')?.dbValue,
        'gif',
      );
      expect(
        UploadMediaMapping.mediaTypeForContentType('video/mp4')?.dbValue,
        'video',
      );
      expect(
        UploadMediaMapping.mediaTypeForContentType('video/webm')?.dbValue,
        'video',
      );
      expect(
        UploadMediaMapping.mediaTypeForContentType('video/quicktime')?.dbValue,
        'video',
      );
    });

    test('rejects unsupported MIME', () {
      expect(
        UploadMediaMapping.validateContentType('image/bmp'),
        'Unsupported file type.',
      );
      expect(
        UploadMediaMapping.validateContentType(''),
        'Unsupported file type.',
      );
      expect(UploadMediaMapping.validateContentType('image/jpeg'), isNull);
    });

    test('enforces image / gif / video size limits', () {
      expect(
        UploadMediaMapping.validateSize(
          contentType: 'image/jpeg',
          sizeBytes: UploadLimits.maxImageBytes + 1,
        ),
        isNotNull,
      );
      expect(
        UploadMediaMapping.validateSize(
          contentType: 'image/gif',
          sizeBytes: UploadLimits.maxGifBytes + 1,
        ),
        isNotNull,
      );
      expect(
        UploadMediaMapping.validateSize(
          contentType: 'video/mp4',
          sizeBytes: UploadLimits.maxVideoBytes + 1,
        ),
        isNotNull,
      );
      expect(
        UploadMediaMapping.validateSize(
          contentType: 'image/png',
          sizeBytes: 1024,
        ),
        isNull,
      );
    });

    test('enforces batch limit of 100', () {
      expect(UploadMediaMapping.validateBatchCount(0), isNotNull);
      expect(UploadMediaMapping.validateBatchCount(101), isNotNull);
      expect(UploadMediaMapping.validateBatchCount(100), isNull);
    });

    test('requires category selection', () {
      expect(UploadMediaMapping.validateCategoryName(null), isNotNull);
      expect(UploadMediaMapping.validateCategoryName('  '), isNotNull);
      expect(UploadMediaMapping.validateCategoryName('Updesh'), isNull);
    });
  });

  group('UploadBatchSummary', () {
    SelectedUploadFile file({
      required UploadItemStatus status,
      required String contentType,
      bool r2 = false,
      bool db = false,
      UploadFailureStage? stage,
    }) {
      return SelectedUploadFile(
        localId: UniqueKey().toString(),
        originalFileName: 'x.jpg',
        clientFileName: 'x.jpg',
        contentType: contentType,
        sizeBytes: 10,
        bytes: Uint8List(0),
        status: status,
        r2Succeeded: r2,
        dbSucceeded: db,
        failureStage: stage,
      );
    }

    test('aggregates partial failures', () {
      final summary = UploadBatchSummary.fromFiles([
        file(
          status: UploadItemStatus.uploaded,
          contentType: 'image/jpeg',
          r2: true,
          db: true,
        ),
        file(
          status: UploadItemStatus.uploaded,
          contentType: 'image/gif',
          r2: true,
          db: true,
        ),
        file(
          status: UploadItemStatus.uploaded,
          contentType: 'video/mp4',
          r2: true,
          db: true,
        ),
        file(
          status: UploadItemStatus.failed,
          contentType: 'image/png',
          r2: true,
          db: false,
          stage: UploadFailureStage.databaseInsert,
        ),
        file(
          status: UploadItemStatus.failed,
          contentType: 'video/webm',
          stage: UploadFailureStage.r2Upload,
        ),
      ]);

      expect(summary.total, 5);
      expect(summary.succeeded, 3);
      expect(summary.failed, 2);
      expect(summary.imageCount, 1);
      expect(summary.gifCount, 1);
      expect(summary.videoCount, 1);
      expect(summary.r2Uploaded, 4);
      expect(summary.dbInserted, 3);
      expect(summary.hasFailures, isTrue);
      expect(summary.isCompleteSuccess, isFalse);
    });

    test('complete success summary', () {
      final summary = UploadBatchSummary.fromFiles([
        file(
          status: UploadItemStatus.uploaded,
          contentType: 'image/jpeg',
          r2: true,
          db: true,
        ),
      ]);
      expect(summary.isCompleteSuccess, isTrue);
    });
  });
}
