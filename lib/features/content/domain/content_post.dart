import 'package:apnipost_admin/features/data_upload/domain/upload_media_mapping.dart';
import 'package:flutter/foundation.dart';

/// A row of `public.posts` as shown in the content library.
@immutable
class ContentPost {
  const ContentPost({
    required this.id,
    required this.category,
    required this.mediaUrl,
    required this.mediaType,
    required this.createdAt,
  });

  factory ContentPost.fromMap(Map<String, dynamic> map) {
    final type = map['media_type']?.toString();
    return ContentPost(
      id: map['id'].toString(),
      category: map['category']?.toString() ?? '',
      mediaUrl: map['media_url']?.toString() ?? '',
      mediaType: PostMediaType.values.firstWhere(
        (value) => value.dbValue == type,
        orElse: () => PostMediaType.image,
      ),
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? ''),
    );
  }

  final String id;
  final String category;
  final String mediaUrl;
  final PostMediaType mediaType;
  final DateTime? createdAt;

  bool get isVideo => mediaType == PostMediaType.video;

  /// Object key inside the bucket, e.g. `love/20260909_ab12.mp4`.
  String get fileName {
    final uri = Uri.tryParse(mediaUrl);
    if (uri == null || uri.pathSegments.isEmpty) return mediaUrl;
    return uri.pathSegments.last;
  }

  ContentPost copyWith({String? category}) {
    return ContentPost(
      id: id,
      category: category ?? this.category,
      mediaUrl: mediaUrl,
      mediaType: mediaType,
      createdAt: createdAt,
    );
  }
}

enum ContentSort {
  newest('Newest first'),
  oldest('Oldest first');

  const ContentSort(this.label);
  final String label;
}

@immutable
class ContentQuery {
  const ContentQuery({
    this.category,
    this.mediaType,
    this.sort = ContentSort.newest,
  });

  /// Null means all categories.
  final String? category;

  /// Null means all media types.
  final PostMediaType? mediaType;
  final ContentSort sort;

  ContentQuery copyWith({
    String? category,
    PostMediaType? mediaType,
    ContentSort? sort,
    bool clearCategory = false,
    bool clearMediaType = false,
  }) {
    return ContentQuery(
      category: clearCategory ? null : (category ?? this.category),
      mediaType: clearMediaType ? null : (mediaType ?? this.mediaType),
      sort: sort ?? this.sort,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ContentQuery &&
      other.category == category &&
      other.mediaType == mediaType &&
      other.sort == sort;

  @override
  int get hashCode => Object.hash(category, mediaType, sort);
}

@immutable
class ContentPage {
  const ContentPage({required this.items, required this.total});

  final List<ContentPost> items;

  /// Total rows matching the query (across all pages).
  final int total;
}
