import 'package:apnipost_admin/shared/web/web_audio.dart';
import 'package:flutter/material.dart';

/// Play/stop toggle with a progress ring. All buttons share one player, so
/// starting a ringtone stops whichever was playing.
class AudioPlayButton extends StatelessWidget {
  const AudioPlayButton({super.key, required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final player = AudioPreviewPlayer.instance;
    return ListenableBuilder(
      listenable: player,
      builder: (context, _) {
        final playing = player.isPlaying(url);
        final failed = player.failedUrl == url;
        return SizedBox(
          width: 40,
          height: 40,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (playing)
                CircularProgressIndicator(
                  value: player.progress,
                  strokeWidth: 2.5,
                ),
              IconButton(
                tooltip: failed
                    ? 'Could not play this file'
                    : (playing ? 'Stop' : 'Play'),
                onPressed: () => player.toggle(url),
                icon: Icon(
                  failed
                      ? Icons.error_outline
                      : (playing ? Icons.stop_rounded : Icons.play_arrow_rounded),
                  color: failed ? Theme.of(context).colorScheme.error : null,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
