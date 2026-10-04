import 'package:flutter/material.dart';
import '../../services/tts_service.dart';

final ttsServiceInstance = TtsService();

/// Polished audio visualizer button for TTS bullet point readout.
///
/// Features:
/// - Full `Semantics` accessibility wrappers for screen readers.
/// - Dynamic font scaling support resilient to high text scale factors.
/// - Real-time visual states: Playing (animated equalizer bars), Paused, Buffering, and Stopped.
class TtsPlayerButton extends StatefulWidget {
  final List<String> bullets;

  const TtsPlayerButton({
    super.key,
    required this.bullets,
  });

  @override
  State<TtsPlayerButton> createState() => _TtsPlayerButtonState();
}

class _TtsPlayerButtonState extends State<TtsPlayerButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  String _getSemanticsLabel(TtsPlaybackState state) {
    switch (state) {
      case TtsPlaybackState.playing:
        return 'Pause audio perspective readout';
      case TtsPlaybackState.paused:
        return 'Resume audio perspective readout';
      case TtsPlaybackState.loading:
        return 'Buffering speech audio';
      case TtsPlaybackState.stopped:
        return 'Read bullet points aloud';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textScaler = MediaQuery.textScalerOf(context);

    return ValueListenableBuilder<TtsPlaybackState>(
      valueListenable: ttsServiceInstance.stateNotifier,
      builder: (context, state, _) {
        final isPlaying = state == TtsPlaybackState.playing;
        final isPaused = state == TtsPlaybackState.paused;
        final isLoading = state == TtsPlaybackState.loading;

        final buttonColor = isPlaying
            ? theme.colorScheme.primary.withOpacity(0.18)
            : (isPaused
                ? theme.colorScheme.secondary.withOpacity(0.12)
                : theme.colorScheme.outline.withOpacity(0.12));

        final borderColor = isPlaying
            ? theme.colorScheme.primary
            : (isPaused ? theme.colorScheme.secondary : Colors.transparent);

        final activeColor = isPlaying
            ? theme.colorScheme.primary
            : (isPaused ? theme.colorScheme.secondary : theme.textTheme.bodyMedium?.color);

        String buttonText = 'Read Aloud';
        if (isLoading) {
          buttonText = 'Preparing...';
        } else if (isPlaying) {
          buttonText = 'Pause Audio';
        } else if (isPaused) {
          buttonText = 'Resume';
        }

        return Semantics(
          button: true,
          label: _getSemanticsLabel(state),
          hint: 'Double tap to toggle text-to-speech audio for this perspective',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                if (isPlaying) {
                  ttsServiceInstance.pause();
                } else if (isPaused) {
                  ttsServiceInstance.speakBullets(widget.bullets);
                } else {
                  ttsServiceInstance.speakBullets(widget.bullets);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: buttonColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: borderColor,
                    width: isPlaying ? 1.2 : 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isLoading)
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.primary,
                        ),
                      )
                    else if (isPlaying)
                      _EqualizerVisualizer(
                        animation: _animController,
                        color: theme.colorScheme.primary,
                      )
                    else if (isPaused)
                      Icon(Icons.play_arrow_rounded, size: 16, color: activeColor)
                    else
                      Icon(Icons.volume_up_outlined, size: 16, color: activeColor),
                    const SizedBox(width: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 120),
                      child: Text(
                        buttonText,
                        style: TextStyle(
                          fontSize: textScaler.scale(12),
                          fontWeight: FontWeight.w600,
                          color: activeColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Dynamic 3-bar animated sound wave visualizer mimicking an audio equalizer.
class _EqualizerVisualizer extends StatelessWidget {
  final Animation<double> animation;
  final Color color;

  const _EqualizerVisualizer({
    required this.animation,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final val = animation.value;
        return SizedBox(
          width: 14,
          height: 14,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _Bar(height: 5 + (7 * val), color: color),
              _Bar(height: 12 - (6 * val), color: color),
              _Bar(height: 4 + (9 * (1 - val)), color: color),
            ],
          ),
        );
      },
    );
  }
}

class _Bar extends StatelessWidget {
  final double height;
  final Color color;

  const _Bar({required this.height, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 3,
      height: height.clamp(3.0, 14.0),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(1.5),
      ),
    );
  }
}
