import 'package:flutter/material.dart';

/// Non-web fallback — the admin app targets Flutter Web.
class WebVideo extends StatelessWidget {
  const WebVideo({
    super.key,
    required this.url,
    this.playing = false,
    this.controls = false,
    this.cover = true,
  });

  final String url;
  final bool playing;
  final bool controls;
  final bool cover;

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Colors.black,
      child: Center(child: Icon(Icons.movie_outlined, color: Colors.white54)),
    );
  }
}

void openUrlInNewTab(String url) {}
