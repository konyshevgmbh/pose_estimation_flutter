import 'package:flutter/foundation.dart' hide debugPrint;

import '../utils/dlog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/pose_keypoint.dart';
import '../services/camera_service.dart';
import '../services/pose_detector.dart';
import '../widgets/init_progress_overlay.dart';
import '../widgets/skeleton_painter.dart';

class PoseScreen extends StatefulWidget {
  const PoseScreen({super.key});

  @override
  State<PoseScreen> createState() => _PoseScreenState();
}

class _PoseScreenState extends State<PoseScreen> {
  final _camera = CameraService();
  final _detector = PoseDetector();

  late final List<InitStep> _steps = [
    InitStep('Camera permission'),
    InitStep('Copy model to cache'),
    InitStep('Load ONNX session'),
    InitStep('Start camera'),
  ];

  PoseResult? _lastPose;
  bool _initDone = false;
  bool _useFrontCamera = true;
  bool _inferring = false;
  double _lastInferenceMs = 0;

  // ── init helpers ─────────────────────────────────────────────────────────

  void _begin(int i) => setState(() => _steps[i].state = InitStepState.running);

  void _finish(int i, int ms) => setState(() {
        _steps[i].state = InitStepState.done;
        _steps[i].elapsedMs = ms;
      });

  void _fail(int i, String msg) => setState(() {
        _steps[i].state = InitStepState.error;
        _steps[i].errorMsg = msg;
      });

  // ── lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _init();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _camera.stop();
    _detector.dispose();
    super.dispose();
  }

  // ── init flow ────────────────────────────────────────────────────────────

  Future<void> _init() async {
    await _stepPermissions();
    final modelOk = await _stepLoadModel();
    await _stepStartCamera();
    if (modelOk && _camera.isRunning) {
      setState(() => _initDone = true);
    }
  }

  Future<void> _stepPermissions() async {
    dlog('[INIT] → permissions');
    _begin(0);
    final sw = Stopwatch()..start();
    if (!kIsWeb) await [Permission.camera].request();
    _finish(0, sw.elapsedMilliseconds);
  }

  Future<bool> _stepLoadModel() async {
    _begin(1);
    final sw = Stopwatch()..start();
    bool copyDone = false;
    try {
      dlog('[INIT] → model load');
      await _detector.initialize(
        'assets/models/rtmpose.onnx',
        onProgress: (msg) {
          dlog('[INIT]   $msg  (${sw.elapsedMilliseconds} ms)');
          if (!copyDone && msg.contains('session')) {
            _finish(1, sw.elapsedMilliseconds);
            sw.reset();
            _begin(2);
            copyDone = true;
          }
        },
      );
      if (!copyDone) {
        _finish(1, sw.elapsedMilliseconds);
        sw.reset();
      }
      _finish(2, sw.elapsedMilliseconds);
      return true;
    } catch (e) {
      dlog('[INIT] ✗ model: $e');
      _fail(copyDone ? 2 : 1, e.toString().split('\n').first);
      return false;
    }
  }

  Future<void> _stepStartCamera() async {
    dlog('[INIT] → camera');
    _begin(3);
    final sw = Stopwatch()..start();
    try {
      await _camera.start(
        useFrontCamera: _useFrontCamera,
        onFrame: _onFrame,
      );
      _finish(3, sw.elapsedMilliseconds);
    } on CameraInUseException catch (e) {
      dlog('[INIT] ✗ camera busy: $e');
      _fail(3, 'Camera busy — close other apps using the camera');
      _showRetrySnackbar();
    } catch (e) {
      dlog('[INIT] ✗ camera: $e');
      _fail(3, e.toString().split('\n').first);
    }
  }

  void _showRetrySnackbar() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Camera is busy. Close other apps and tap Retry.'),
          duration: const Duration(seconds: 15),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () async {
              await _camera.stop();
              await _stepStartCamera();
              if (_camera.isRunning && _detector.isInitialized) {
                setState(() => _initDone = true);
              }
            },
          ),
        ),
      );
    });
  }

  // ── inference ─────────────────────────────────────────────────────────────

  void _onFrame(frame) {
    if (!_detector.isInitialized || _inferring) return;
    _inferring = true;
    _detector.detect(frame).then((result) {
      if (!mounted) return;
      if (result != null) {
        setState(() {
          _lastPose = result;
          _lastInferenceMs = result.inferenceMs;
        });
      }
    }).catchError((e) {
      dlog('[ORT] error: $e');
    }).whenComplete(() {
      _inferring = false;
    });
  }

  // ── camera switch ─────────────────────────────────────────────────────────

  Future<void> _toggleCamera() async {
    _useFrontCamera = !_useFrontCamera;
    await _camera.stop();
    await _stepStartCamera();
    setState(() {});
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (!_initDone) return InitProgressOverlay(steps: _steps);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_camera.renderer != null)
            RTCVideoView(
              _camera.renderer!,
              mirror: _useFrontCamera,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            ),
          LayoutBuilder(
            builder: (_, constraints) => CustomPaint(
              size: constraints.biggest,
              painter: SkeletonPainter(
                poseResult: _lastPose,
                previewSize: constraints.biggest,
                mirror: _useFrontCamera,
              ),
            ),
          ),
          _buildHud(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'switch_cam',
        onPressed: _toggleCamera,
        child: const Icon(Icons.flip_camera_ios),
      ),
    );
  }

  Widget _buildHud() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 12,
      right: 12,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _chip('Running'),
          if (_lastInferenceMs > 0)
            _chip('${_lastInferenceMs.toStringAsFixed(0)} ms'),
        ],
      ),
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text,
          style: const TextStyle(color: Colors.white, fontSize: 12)),
    );
  }
}
