import 'package:apnipost_admin/core/utils/date_formatters.dart';
import 'package:apnipost_admin/features/content/domain/content_post.dart';
import 'package:apnipost_admin/shared/web/web_media.dart';
import 'package:flutter/material.dart';

enum PostCardAction { preview, move, copyLink, openOriginal, delete }

/// Image or first video frame, filling its box.
class MediaThumbnail extends StatelessWidget {
  const MediaThumbnail({
    super.key,
    required this.post,
    this.playing = false,
  });

  final ContentPost post;
  final bool playing;

  @override
  Widget build(BuildContext context) {
    if (post.isVideo) {
      return WebVideo(url: post.mediaUrl, playing: playing);
    }

    final scheme = Theme.of(context).colorScheme;
    return Image.network(
      post.mediaUrl,
      fit: BoxFit.cover,
      // media.apnipost.com sends no CORS headers; an <img> element works
      // without them where a canvas byte fetch would fail.
      webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return ColoredBox(color: scheme.surfaceContainerHighest);
      },
      errorBuilder: (context, error, stackTrace) => ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: Icon(
          Icons.broken_image_outlined,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class PostCard extends StatefulWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.selected,
    required this.selectionMode,
    required this.onTap,
    required this.onToggleSelected,
    required this.onAction,
  });

  final ContentPost post;
  final bool selected;

  /// When true, tapping the card toggles selection instead of previewing.
  final bool selectionMode;
  final VoidCallback onTap;
  final VoidCallback onToggleSelected;
  final void Function(PostCardAction action) onAction;

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final post = widget.post;
    final showSelect = _hovered || widget.selectionMode || widget.selected;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedScale(
        scale: _hovered && !widget.selected ? 1.02 : 1,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.selected ? scheme.primary : Colors.transparent,
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _hovered ? 0.18 : 0.06),
                blurRadius: _hovered ? 18 : 6,
                offset: Offset(0, _hovered ? 8 : 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: Stack(
              fit: StackFit.expand,
              children: [
                MediaThumbnail(post: post, playing: _hovered),
                // Tap target above the platform view so clicks reach Flutter.
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onTap,
                  ),
                ),
                if (widget.selected)
                  IgnorePointer(
                    child: ColoredBox(
                      color: scheme.primary.withValues(alpha: 0.18),
                    ),
                  ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: IgnorePointer(child: _Caption(post: post)),
                ),
                if (post.isVideo)
                  const Positioned(
                    top: 10,
                    right: 10,
                    child: IgnorePointer(child: _VideoBadge()),
                  ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: AnimatedOpacity(
                    opacity: showSelect ? 1 : 0,
                    duration: const Duration(milliseconds: 120),
                    child: _SelectDot(
                      selected: widget.selected,
                      onTap: widget.onToggleSelected,
                    ),
                  ),
                ),
                if (_hovered && !widget.selectionMode)
                  Positioned(
                    bottom: 6,
                    right: 6,
                    child: _ActionsMenu(onAction: widget.onAction),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Caption extends StatelessWidget {
  const _Caption({required this.post});

  final ContentPost post;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0),
            Colors.black.withValues(alpha: 0.72),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 28, 44, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              post.category,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              DateFormatters.relativeDate(post.createdAt),
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoBadge extends StatelessWidget {
  const _VideoBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Padding(
        padding: EdgeInsets.fromLTRB(6, 3, 9, 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_arrow_rounded, size: 16, color: Colors.white),
            SizedBox(width: 2),
            Text(
              'Video',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectDot extends StatelessWidget {
  const _SelectDot({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: selected ? 'Deselect' : 'Select',
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected
                ? scheme.primary
                : Colors.black.withValues(alpha: 0.35),
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: selected
              ? Icon(Icons.check_rounded, size: 18, color: scheme.onPrimary)
              : null,
        ),
      ),
    );
  }
}

class _ActionsMenu extends StatelessWidget {
  const _ActionsMenu({required this.onAction});

  final void Function(PostCardAction action) onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      child: PopupMenuButton<PostCardAction>(
        tooltip: 'More actions',
        iconSize: 20,
        padding: EdgeInsets.zero,
        icon: Icon(Icons.more_horiz_rounded, color: scheme.onSurface),
        onSelected: onAction,
        itemBuilder: (context) => [
          _item(PostCardAction.preview, Icons.visibility_outlined, 'Preview'),
          _item(
            PostCardAction.move,
            Icons.drive_file_move_outline,
            'Move to category',
          ),
          _item(PostCardAction.copyLink, Icons.link_rounded, 'Copy media link'),
          _item(
            PostCardAction.openOriginal,
            Icons.open_in_new_rounded,
            'Open original',
          ),
          const PopupMenuDivider(),
          PopupMenuItem(
            value: PostCardAction.delete,
            child: Row(
              children: [
                Icon(Icons.delete_outline_rounded, color: scheme.error),
                const SizedBox(width: 12),
                Text('Delete', style: TextStyle(color: scheme.error)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<PostCardAction> _item(
    PostCardAction action,
    IconData icon,
    String label,
  ) {
    return PopupMenuItem(
      value: action,
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
    );
  }
}
