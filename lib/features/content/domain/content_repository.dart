import 'package:apnipost_admin/features/content/domain/content_post.dart';

abstract class ContentRepository {
  Future<ContentPage> fetchPosts({
    required ContentQuery query,
    required int offset,
    required int limit,
  });

  /// Distinct `posts.category` values, including ones with no matching
  /// `categories` row (renamed/deleted categories).
  Future<List<String>> fetchPostCategoryNames();

  Future<void> movePosts({
    required List<String> ids,
    required String category,
  });

  /// Moves every post in [from] (not just loaded ones) into [to].
  /// Returns the number of posts moved.
  Future<int> moveAllInCategory({required String from, required String to});

  /// Removes the post rows. Files stay in R2.
  Future<void> deletePosts(List<String> ids);
}
