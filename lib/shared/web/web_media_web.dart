import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

/// Native `<video>` element. Media on media.apnipost.com is served without
/// CORS headers, which `<video>` (unlike canvas image decoding) does not need.
class WebVideo extends StatefulWidget {
  const WebVideo({
    super.key,
    required this.url,
    this.playing = false,
    this.controls = false,
    this.cover = true,
  });

  final String url;

  /// Muted autoplay preview (e.g. on hover). Ignored when [controls] is set.
  final bool playing;

  /// Full player with sound and controls (preview dialog).
  final bool controls;
  final bool cover;

  @override
  State<WebVideo> createState() => _WebVideoState();
}

class _WebVideoState extends State<WebVideo> {
  web.HTMLVideoElement? _video;

  @override
  void didUpdateWidget(WebVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playing != widget.playing) _syncPlayback();
  }

  @override
  void dispose() {
    final video = _video;
    if (video != null) {
      video.pause();
      // Release the network connection held by the element.
      video.removeAttribute('src');
      video.load();
    }
    super.dispose();
  }

  void _syncPlayback() {
    final video = _video;
    if (video == null || widget.controls) return;
    if (widget.playing) {
      video.play();
    } else {
      video.pause();
      video.currentTime = 0.5;
    }
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView.fromTagName(
      // Rebuild the element if the URL changes (e.g. next/previous in preview).
      key: ValueKey(widget.url),
      tagName: 'video',
      onElementCreated: (element) {
        final video = element as web.HTMLVideoElement;
        _video = video;
        video
          ..muted = !widget.controls
          ..controls = widget.controls
          ..autoplay = widget.controls
          ..loop = !widget.controls
          ..playsInline = true
          ..preload = 'metadata'
          // `#t=0.5` makes the browser paint a real frame as the thumbnail.
          ..src = widget.controls ? widget.url : '${widget.url}#t=0.5';
        video.style
          ..width = '100%'
          ..height = '100%'
          ..objectFit = widget.cover ? 'cover' : 'contain'
          ..backgroundColor = '#000'
          ..pointerEvents = widget.controls ? 'auto' : 'none';
        _syncPlayback();
      },
    );
  }
}

void openUrlInNewTab(String url) {
  web.window.open(url, '_blank', 'noopener');
}
