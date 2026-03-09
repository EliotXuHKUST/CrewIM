import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';

class VoiceRecordButton extends StatefulWidget {
  final VoidCallback? onRecordStart;
  final VoidCallback? onRecordEnd;
  final VoidCallback? onRecordCancel;

  const VoiceRecordButton({
    super.key,
    this.onRecordStart,
    this.onRecordEnd,
    this.onRecordCancel,
  });

  @override
  State<VoiceRecordButton> createState() => _VoiceRecordButtonState();
}

class _VoiceRecordButtonState extends State<VoiceRecordButton>
    with TickerProviderStateMixin {
  bool _isRecording = false;
  bool _isCancelling = false;
  late AnimationController _scaleController;
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOut),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.8).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _onLongPressStart(LongPressStartDetails details) {
    setState(() {
      _isRecording = true;
      _isCancelling = false;
    });
    _scaleController.forward();
    _pulseController.repeat();
    HapticFeedback.lightImpact();
    widget.onRecordStart?.call();
  }

  void _onLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    final shouldCancel = details.offsetFromOrigin.dy < -80;
    if (shouldCancel != _isCancelling) {
      setState(() => _isCancelling = shouldCancel);
      if (shouldCancel) HapticFeedback.lightImpact();
    }
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    _scaleController.reverse();
    _pulseController.stop();
    _pulseController.reset();

    if (_isCancelling) {
      widget.onRecordCancel?.call();
    } else {
      widget.onRecordEnd?.call();
    }

    setState(() {
      _isRecording = false;
      _isCancelling = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = _isCancelling ? AppColors.error : AppColors.accent;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 150),
          child: _isRecording
              ? Text(
                  _isCancelling ? '松开取消' : '松开发送',
                  key: ValueKey(_isCancelling),
                  style: TextStyle(
                    fontSize: 13,
                    color: _isCancelling ? AppColors.error : AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                )
              : const SizedBox(height: 18, key: ValueKey('empty')),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 100,
          height: 100,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (_isRecording && !_isCancelling)
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (_, __) => Container(
                    width: 64 * _pulseAnimation.value,
                    height: 64 * _pulseAnimation.value,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withAlpha(
                        (40 * (1 - (_pulseAnimation.value - 1) / 0.8)).clamp(0, 255).toInt(),
                      ),
                    ),
                  ),
                ),
              ScaleTransition(
                scale: _scaleAnimation,
                child: GestureDetector(
                  onLongPressStart: _onLongPressStart,
                  onLongPressMoveUpdate: _onLongPressMoveUpdate,
                  onLongPressEnd: _onLongPressEnd,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isRecording ? Icons.mic : Icons.mic_none_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
