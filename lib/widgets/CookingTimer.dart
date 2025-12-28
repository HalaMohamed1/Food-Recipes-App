import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

class CookingTimer extends StatefulWidget {
  const CookingTimer({super.key});

  @override
  State<CookingTimer> createState() => _CookingTimerState();
}

class _CookingTimerState extends State<CookingTimer> {
  final TextEditingController _minutesController = TextEditingController();
  final TextEditingController _secondsController = TextEditingController();
  
  final AudioPlayer _audioPlayer = AudioPlayer(); //  AudioPlayer instance

  Timer? _timer;
  int _remainingSeconds = 0;
  bool _isRunning = false;
  bool _isPaused = false;
  bool _isFinished = false;

  @override
  void dispose() {
    _timer?.cancel();
    _audioPlayer.dispose(); // Dispose audio player
    _minutesController.dispose();
    _secondsController.dispose();
    super.dispose();
  }

  void _startTimer() {
    if (_isRunning && !_isPaused) return;

    if (_isPaused) {
      setState(() {
        _isPaused = false;
        _isRunning = true;
      });
    } else {
      int minutes = int.tryParse(_minutesController.text) ?? 0;
      int seconds = int.tryParse(_secondsController.text) ?? 0;

      if (minutes == 0 && seconds == 0) return;

      setState(() {
        _remainingSeconds = minutes * 60 + seconds;
        _isRunning = true;
        _isFinished = false;
      });
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        _stopTimer(finished: true);
      }
    });
  }

  void _pauseTimer() {
    if (_timer != null) {
      _timer!.cancel();
      setState(() {
        _isPaused = true;
        _isRunning = false;
      });
    }
  }

  void _stopTimer({bool finished = false}) {
    _timer?.cancel();
    if (finished) {
       _playAlarm(); //  Play sound when finished
    } else {
      _audioPlayer.stop(); //  Stop sound if reset manually
    }
    
    setState(() {
      _isRunning = false;
      _isPaused = false;
      _isFinished = finished;
      if (!finished) {
        _remainingSeconds = 0;
      }
    });
  }

  Future<void> _playAlarm() async {
    try {
      // Set volume to max
      await _audioPlayer.setVolume(1.0);
      
      
      // Using a source for my audio :3
      await _audioPlayer.play(UrlSource('https://assets.mixkit.co/active_storage/sfx/989/989-preview.mp3')); 
    } catch (e) {
      debugPrint("Error playing alarm: $e");
    }
  }

  String _formatTime(int totalSeconds) {
    int minutes = totalSeconds ~/ 60;
    int seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: theme.dividerColor.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.timer_outlined, color: theme.colorScheme.primary, size: 24),
              const SizedBox(width: 8),
              Text(
                "Cooking Timer",
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (!_isRunning && !_isPaused && !_isFinished) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildTimeInput(context, _minutesController, "Min"),
                const SizedBox(width: 15),
                Text(
                  ":",
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.hintColor,
                  ),
                ),
                const SizedBox(width: 15),
                _buildTimeInput(context, _secondsController, "Sec"),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _startTimer,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text("Start Timer"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ] else ...[
            Text(
              _isFinished ? "00:00" : _formatTime(_remainingSeconds),
              style: theme.textTheme.displayLarge?.copyWith(
                fontWeight: FontWeight.bold,
                fontFeatures: [const FontFeature.tabularFigures()],
                color: _isFinished ? theme.colorScheme.error : theme.colorScheme.primary,
              ),
            ),
            if (_isFinished) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_active, color: theme.colorScheme.error),
                  const SizedBox(width: 8),
                  Text(
                    "Time's up!",
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!_isFinished) ...[
                  if (_isRunning)
                    _buildControlButton(
                      context,
                      icon: Icons.pause_rounded,
                      label: "Pause",
                      color: Colors.orangeAccent,
                      onPressed: _pauseTimer,
                    )
                  else
                    _buildControlButton(
                      context,
                      icon: Icons.play_arrow_rounded,
                      label: "Resume",
                      color: Colors.green,
                      onPressed: _startTimer,
                    ),
                  const SizedBox(width: 15),
                ],
                _buildControlButton(
                  context,
                  icon: Icons.stop_rounded,
                  label: _isFinished ? "Reset" : "Stop",
                  color: Colors.redAccent,
                  onPressed: () => _stopTimer(finished: false),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimeInput(BuildContext context, TextEditingController controller, String label) {
    return Column(
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Center(
            child: TextField(
              controller: controller,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                counterText: "",
                hintText: "00",
              ),
              maxLength: 2,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).hintColor,
              ),
        ),
      ],
    );
  }

  Widget _buildControlButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
          side: BorderSide(color: color.withOpacity(0.5)),
        ),
      ),
      icon: Icon(icon, size: 20),
      label: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}
