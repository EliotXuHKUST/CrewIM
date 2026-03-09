import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/audio/audio_recorder.dart';

typedef MediaCallback = void Function({String? audioPath, List<String>? imagePaths});

class ChatInputBar extends StatefulWidget {
  final ValueChanged<String>? onSubmitText;
  final MediaCallback? onSubmitMedia;
  final VoidCallback? onFile;

  const ChatInputBar({
    super.key,
    this.onSubmitText,
    this.onSubmitMedia,
    this.onFile,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _picker = ImagePicker();
  bool _isVoiceMode = true;
  bool _hasText = false;
  bool _isRecording = false;
  bool _isCancelling = false;
  bool _showMorePanel = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final has = _controller.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
    _focusNode.addListener(() {
      if (_focusNode.hasFocus && _showMorePanel) {
        setState(() => _showMorePanel = false);
      }
    });
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _recordTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSubmitText?.call(text);
    _controller.clear();
  }

  void _toggleVoiceMode() {
    HapticFeedback.lightImpact();
    setState(() {
      _isVoiceMode = !_isVoiceMode;
      _showMorePanel = false;
    });
    if (!_isVoiceMode) {
      Future.microtask(() => _focusNode.requestFocus());
    } else {
      _focusNode.unfocus();
    }
  }

  void _toggleMorePanel() {
    HapticFeedback.lightImpact();
    setState(() => _showMorePanel = !_showMorePanel);
    if (_showMorePanel) _focusNode.unfocus();
  }

  Future<void> _onPanStart(DragStartDetails _) async {
    final started = await AppAudioRecorder.instance.start();
    if (!started) return;

    setState(() {
      _isRecording = true;
      _isCancelling = false;
      _recordSeconds = 0;
    });
    _pulseController.repeat(reverse: true);
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _recordSeconds++);
    });
    HapticFeedback.mediumImpact();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isRecording) return;
    final shouldCancel = details.localPosition.dy < -60;
    if (shouldCancel != _isCancelling) {
      setState(() => _isCancelling = shouldCancel);
      if (shouldCancel) HapticFeedback.lightImpact();
    }
  }

  Future<void> _onPanEnd(DragEndDetails _) async {
    if (!_isRecording) return;
    _pulseController.stop();
    _pulseController.reset();
    _recordTimer?.cancel();

    if (_isCancelling) {
      await AppAudioRecorder.instance.cancel();
    } else {
      final path = await AppAudioRecorder.instance.stop();
      if (path != null) {
        widget.onSubmitMedia?.call(audioPath: path);
      }
    }
    setState(() {
      _isRecording = false;
      _isCancelling = false;
      _recordSeconds = 0;
    });
  }

  Future<void> _onCamera() async {
    setState(() => _showMorePanel = false);
    try {
      final image = await _picker.pickImage(source: ImageSource.camera, imageQuality: 80);
      if (image != null) {
        widget.onSubmitMedia?.call(imagePaths: [image.path]);
      }
    } catch (e) {
      debugPrint('Camera pick failed: $e');
    }
  }

  Future<void> _onPhotoLibrary() async {
    setState(() => _showMorePanel = false);
    try {
      final images = await _picker.pickMultiImage(imageQuality: 80);
      if (images.isNotEmpty) {
        widget.onSubmitMedia?.call(imagePaths: images.map((x) => x.path).toList());
      }
    } catch (e) {
      debugPrint('Photo library pick failed: $e');
    }
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barColor = isDark ? AppColors.cardDark : AppColors.card;
    final iconColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;
    final separatorColor = isDark ? AppColors.separatorDark : AppColors.separator;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: barColor,
            border: Border(top: BorderSide(color: separatorColor, width: 0.5)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: SafeArea(
            top: false,
            child: _isRecording
                ? _buildRecordingState(isDark)
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildVoiceToggle(iconColor),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _isVoiceMode
                            ? _buildHoldToTalk(isDark)
                            : _buildTextField(isDark),
                      ),
                      const SizedBox(width: 6),
                      _buildRightButton(iconColor, isDark),
                    ],
                  ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: _showMorePanel ? _buildMorePanel(isDark) : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildRecordingState(bool isDark) {
    final color = _isCancelling ? AppColors.error : AppColors.accent;

    return GestureDetector(
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (_, __) {
          final alpha = _isCancelling
              ? 30
              : (15 + 10 * _pulseAnimation.value).toInt();

          return Container(
            height: 44,
            decoration: BoxDecoration(
              color: color.withAlpha(alpha),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: color.withAlpha(60), width: 1),
            ),
            child: Row(
              children: [
                const SizedBox(width: 16),
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 10),
                Text(
                  _formatDuration(_recordSeconds),
                  style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w500,
                    color: color, fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const Spacer(),
                Text(
                  _isCancelling ? '松开取消' : '上滑取消 · 松开发送',
                  style: TextStyle(fontSize: 13, color: color.withAlpha(180)),
                ),
                const SizedBox(width: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildVoiceToggle(Color iconColor) {
    return GestureDetector(
      onTap: _toggleVoiceMode,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        child: Icon(
          _isVoiceMode ? Icons.keyboard_outlined : Icons.mic_none_rounded,
          size: 22,
          color: iconColor,
        ),
      ),
    );
  }

  Widget _buildHoldToTalk(bool isDark) {
    final fillColor = isDark ? AppColors.inputFillDark : AppColors.inputFill;

    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: fillColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mic_none_rounded, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              '按住说话',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(bool isDark) {
    final fillColor = isDark ? AppColors.inputFillDark : AppColors.inputFill;

    return Container(
      constraints: const BoxConstraints(minHeight: 40, maxHeight: 120),
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        maxLines: 5,
        minLines: 1,
        onSubmitted: (_) => _submit(),
        textInputAction: TextInputAction.send,
        decoration: InputDecoration(
          hintText: '输入指令…',
          hintStyle: TextStyle(
            fontSize: 15,
            color: isDark ? AppColors.textSecondaryDark.withAlpha(150) : AppColors.textPlaceholder,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          isDense: true,
        ),
        style: TextStyle(
          fontSize: 15,
          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildRightButton(Color iconColor, bool isDark) {
    if (!_isVoiceMode && _hasText) {
      return GestureDetector(
        onTap: _submit,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isDark ? AppColors.accentDark : AppColors.accent,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.arrow_upward_rounded, size: 20, color: Colors.white),
        ),
      );
    }

    return GestureDetector(
      onTap: _toggleMorePanel,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Icon(
            _showMorePanel ? Icons.close_rounded : Icons.add_circle_outline_rounded,
            key: ValueKey(_showMorePanel),
            size: 22,
            color: iconColor,
          ),
        ),
      ),
    );
  }

  Widget _buildMorePanel(bool isDark) {
    final iconColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;

    return Container(
      color: isDark ? AppColors.cardDark : AppColors.card,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            _MoreAction(
              icon: Icons.camera_alt_outlined,
              label: '拍照',
              color: iconColor,
              isDark: isDark,
              onTap: _onCamera,
            ),
            const SizedBox(width: 20),
            _MoreAction(
              icon: Icons.photo_library_outlined,
              label: '相册',
              color: iconColor,
              isDark: isDark,
              onTap: _onPhotoLibrary,
            ),
            const SizedBox(width: 20),
            _MoreAction(
              icon: Icons.folder_outlined,
              label: '文件',
              color: iconColor,
              isDark: isDark,
              onTap: () {
                setState(() => _showMorePanel = false);
                widget.onFile?.call();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MoreAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _MoreAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? AppColors.surfaceSecondaryDark : AppColors.surfaceSecondary;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 22, color: color),
          ),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontSize: 11, color: color)),
        ],
      ),
    );
  }
}
