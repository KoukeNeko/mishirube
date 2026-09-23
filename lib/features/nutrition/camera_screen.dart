import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../../shared/haptics.dart';
import '../../shared/widgets/widgets.dart';

/// A viewfinder for a food or a nutrition label: the shutter, and beside
/// it the library for a photo already taken. Pops with the photo's path,
/// or nothing when closed.
///
/// No collapsing app bar: the preview is the page, and a header over it
/// would only cover what is being framed.
class CameraScreen extends StatefulWidget {
  const CameraScreen({
    super.key,
    required this.title,
    required this.pickFromLibrary,
    this.findCameras = availableCameras,
  });

  final String title;

  /// A photo from the library, as a path; null when none was chosen.
  final Future<String?> Function() pickFromLibrary;

  /// The device's cameras; the plugin's list unless a test hands one in.
  final Future<List<CameraDescription>> Function() findCameras;

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;

  /// No camera to open: a Mac, or a camera the user did not allow.
  bool _isUnavailable = false;
  bool _isTaking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _open();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  /// The camera is released while the app is in the background, as the
  /// platform expects, and opened again on the way back.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
        final controller = _controller;
        setState(() => _controller = null);
        controller?.dispose();
      case AppLifecycleState.resumed:
        if (_controller == null && !_isUnavailable) _open();
      default:
        break;
    }
  }

  Future<void> _open() async {
    try {
      final cameras = await widget.findCameras();
      final camera =
          cameras
              .where(
                (camera) => camera.lensDirection == CameraLensDirection.back,
              )
              .firstOrNull ??
          cameras.firstOrNull;
      if (camera == null) {
        if (mounted) setState(() => _isUnavailable = true);
        return;
      }
      // Sharp enough for a label's small print; the photo is scaled
      // down before it is sent anywhere.
      final controller = CameraController(
        camera,
        ResolutionPreset.veryHigh,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } on CameraException {
      if (mounted) setState(() => _isUnavailable = true);
    } on MissingPluginException {
      // A platform the camera plugin does not run on.
      if (mounted) setState(() => _isUnavailable = true);
    } on PlatformException {
      // Its native side is missing or refused to answer.
      if (mounted) setState(() => _isUnavailable = true);
    }
  }

  Future<void> _take() async {
    final controller = _controller;
    if (controller == null || _isTaking) return;
    AppHaptics.tap();
    setState(() => _isTaking = true);
    try {
      final photo = await controller.takePicture();
      if (mounted) Navigator.of(context).pop(photo.path);
    } on CameraException {
      if (mounted) setState(() => _isTaking = false);
    }
  }

  Future<void> _pickFromLibrary() async {
    final path = await widget.pickFromLibrary();
    if (path != null && mounted) Navigator.of(context).pop(path);
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final controller = _controller;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (controller != null)
                  ClipRect(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        // The preview's size is the sensor's, on its side.
                        width: controller.value.previewSize?.height ?? 1,
                        height: controller.value.previewSize?.width ?? 1,
                        child: CameraPreview(controller),
                      ),
                    ),
                  )
                else if (_isUnavailable)
                  Center(child: Text('沒有可用的相機', style: AppTextStyles.caption)),
                Positioned(
                  top: padding.top + AppSpacing.xs,
                  left: padding.left + AppSpacing.screenGutter,
                  right: padding.right + AppSpacing.screenGutter,
                  child: Row(
                    children: [
                      const AppBarBackButton(icon: Icons.close, tooltip: '關閉'),
                      Expanded(
                        child: Text(
                          widget.title,
                          textAlign: TextAlign.center,
                          style: compactTitleStyle,
                        ),
                      ),
                      // Balances the close button, so the title is centred.
                      const SizedBox(width: 44),
                    ],
                  ),
                ),
              ],
            ),
          ),
          DecoratedBox(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppRadius.card),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                padding.left + AppSpacing.xl,
                AppSpacing.xl,
                padding.right + AppSpacing.xl,
                padding.bottom + AppSpacing.xl,
              ),
              child: Row(
                children: [
                  SquareIconButton(
                    icon: Icons.photo_library_outlined,
                    tooltip: '從相簿選取',
                    size: 56,
                    radius: 28,
                    onPressed: _pickFromLibrary,
                  ),
                  Expanded(
                    child: Center(
                      child: _Shutter(
                        onPressed: controller == null || _isTaking
                            ? null
                            : _take,
                      ),
                    ),
                  ),
                  const SizedBox(width: 56),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The round button that takes the photo: a ring around the app's
/// green, dimmed while there is no camera to take it with.
class _Shutter extends StatelessWidget {
  const _Shutter({required this.onPressed});

  final VoidCallback? onPressed;

  static const _size = 76.0;

  @override
  Widget build(BuildContext context) {
    final onPressed = this.onPressed;
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: '拍照',
      onTap: onPressed,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onPressed,
        child: Opacity(
          opacity: onPressed == null ? 0.4 : 1,
          child: Container(
            width: _size,
            height: _size,
            padding: const EdgeInsets.all(5),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              border: Border.fromBorderSide(
                BorderSide(color: AppColors.textPrimary, width: 3),
              ),
            ),
            child: const DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.training,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
