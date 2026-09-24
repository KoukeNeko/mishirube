import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/theme.dart';
import '../../shared/haptics.dart';
import '../../shared/photo_library.dart';
import '../../app/navigation.dart';
import '../../shared/widgets/widgets.dart';
import '../shell/bottom_chrome/chrome_metrics.dart';
import '../shell/bottom_chrome/press_feedback.dart';

/// A photo from the app's camera, titled [title], or from the library by
/// its button, scaled so its longer side is at most [maxSide]: small
/// print needs more than a plate does, and past about 1600 px a model
/// scales a photo down anyway. The path, or null when none was taken.
Future<String?> takePhoto(
  BuildContext context,
  String title, {
  double maxSide = 2400,
}) => pushModalPage<String>(
  context,
  CameraScreen(
    title: title,
    pickFromLibrary: () => pickPhoto(ImageSource.gallery, maxSide: maxSide),
  ),
);

/// A photo from the system picker, re-encoded as a JPEG at [maxSide]:
/// plenty for reading, a fraction of what the camera takes.
Future<String?> pickPhoto(ImageSource source, {double maxSide = 2400}) async =>
    (await ImagePicker().pickImage(
      source: source,
      maxWidth: maxSide,
      maxHeight: maxSide,
      imageQuality: 85,
    ))?.path;

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
    this.findLatestPhoto = latestPhotoThumbnail,
  });

  final String title;

  /// A photo from the library, as a path; null when none was chosen.
  final Future<String?> Function() pickFromLibrary;

  /// The device's cameras; the plugin's list unless a test hands one in.
  final Future<List<CameraDescription>> Function() findCameras;

  /// The newest photo in the library as a thumbnail about the given
  /// pixels on a side, shown on the library button; null for an icon.
  final Future<Uint8List?> Function(int pixels) findLatestPhoto;

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  CameraController? _controller;

  /// The newest photo in the library, for the library button.
  Uint8List? _latestPhoto;

  /// The white flash over the preview when the shutter fires: 1 at the
  /// moment of the photo, fading to 0.
  late final _flash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );

  /// No camera to open: a Mac, or a camera the user did not allow.
  bool _isUnavailable = false;
  bool _isTaking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _open();
    _showLatestPhoto();
  }

  Future<void> _showLatestPhoto() async {
    // Wait for the first frame, so the screen's pixel density is known.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    final pixels = (_libraryButtonSize * MediaQuery.devicePixelRatioOf(context))
        .round();
    final photo = await widget.findLatestPhoto(pixels);
    if (photo != null && mounted) setState(() => _latestPhoto = photo);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _flash.dispose();
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
    // The photo is taken now, as far as the eye and hand can tell; the
    // file follows.
    AppHaptics.shutter();
    if (chromeDuration(context, _flash.duration!) != Duration.zero) {
      _flash
        ..value = 1
        ..animateTo(0, curve: Curves.easeOut);
    }
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
                IgnorePointer(
                  child: FadeTransition(
                    opacity: _flash,
                    child: const ColoredBox(color: Colors.white),
                  ),
                ),
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
                  _LibraryButton(
                    photo: _latestPhoto,
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
                  const SizedBox(width: _libraryButtonSize),
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
/// green, dimmed while there is no camera to take it with. Only the green
/// answers a press, shrinking inside the ring that stays put.
class _Shutter extends StatefulWidget {
  const _Shutter({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  State<_Shutter> createState() => _ShutterState();
}

class _ShutterState extends State<_Shutter> {
  static const _size = 76.0;
  static const _pressedScale = 0.86;

  bool _isPressed = false;

  void _setPressed(bool isPressed) {
    if (widget.onPressed == null || _isPressed == isPressed) return;
    setState(() => _isPressed = isPressed);
  }

  @override
  Widget build(BuildContext context) {
    final onPressed = widget.onPressed;
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: '拍照',
      onTap: onPressed,
      excludeSemantics: true,
      // The raw pointer, so the green reacts before the tap is decided.
      child: Listener(
        onPointerDown: (_) => _setPressed(true),
        onPointerUp: (_) => _setPressed(false),
        onPointerCancel: (_) => _setPressed(false),
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
              child: AnimatedScale(
                scale: _isPressed && !prefersReducedMotion(context)
                    ? _pressedScale
                    : 1,
                duration: ChromeMetrics.pressDuration,
                curve: Curves.easeOut,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.training,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Size of the library button, and of the space that balances it on the
/// other side of the shutter.
const _libraryButtonSize = 56.0;

/// The library, beside the shutter: the newest photo in it when that can
/// be shown, as camera apps do, and an icon otherwise.
class _LibraryButton extends StatelessWidget {
  const _LibraryButton({required this.photo, required this.onPressed});

  final Uint8List? photo;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final photo = this.photo;
    if (photo == null) {
      return SquareIconButton(
        icon: Icons.photo_library_outlined,
        tooltip: '從相簿選取',
        size: _libraryButtonSize,
        radius: _libraryButtonSize / 2,
        onPressed: onPressed,
      );
    }
    return Tooltip(
      message: '從相簿選取',
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        label: '從相簿選取',
        onTap: onPressed,
        excludeSemantics: true,
        child: PressScale(
          pressedScale: ChromeMetrics.actionPressedScale,
          child: GestureDetector(
            onTap: () {
              AppHaptics.tap();
              onPressed();
            },
            child: Container(
              width: _libraryButtonSize,
              height: _libraryButtonSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.textPrimary, width: 2),
                image: DecorationImage(
                  image: MemoryImage(photo),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
