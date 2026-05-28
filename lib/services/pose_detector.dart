import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:image/image.dart' as img;

import '../models/pose_keypoint.dart';
import '../models/rtmpose_config.dart';

class PoseDetector {
  final RTMPoseConfig config;

  final _ort = OnnxRuntime();
  OrtSession? _session;
  bool _isInitialized = false;

  PoseDetector({this.config = RTMPoseConfig.defaultConfig});

  bool get isInitialized => _isInitialized;

  /// [onProgress] is called with a short status string at each sub-step.
  Future<void> initialize(String assetPath, {void Function(String)? onProgress}) async {
    onProgress?.call('Reading asset…');

    final options = OrtSessionOptions(
      intraOpNumThreads: 2,
      interOpNumThreads: 2,
    );

    onProgress?.call('Copying model to cache…');
    _session = await _ort.createSessionFromAsset(assetPath, options: options);

    onProgress?.call('ONNX session ready');
    _isInitialized = true;
  }

  /// Run inference on an [img.Image] frame.
  Future<PoseResult?> detect(img.Image frame) async {
    if (!_isInitialized || _session == null) return null;

    final t0 = DateTime.now().millisecondsSinceEpoch;
    debugPrint('[ORT] detect() frame=${frame.width}x${frame.height}');

    // 1. Preprocess
    final floatData = _preprocess(frame);

    // 2. Create input tensor
    final inputValue = await OrtValue.fromList(
      floatData,
      [1, 3, config.inputHeight, config.inputWidth],
    );

    // 3. Run inference
    final inputName = _session!.inputNames.first;
    final outputs = await _session!.run({inputName: inputValue});
    final t3 = DateTime.now().millisecondsSinceEpoch;

    // 4. Postprocess
    final result = await _postprocessSimcc(outputs, (t3 - t0).toDouble());

    // 5. Dispose
    await inputValue.dispose();
    for (final v in outputs.values) {
      await v.dispose();
    }

    return result;
  }

  Float32List _preprocess(img.Image frame) {
    final resized = img.copyResize(
      frame,
      width: config.inputWidth,
      height: config.inputHeight,
      interpolation: img.Interpolation.linear,
    );

    final floatData = Float32List(3 * config.inputHeight * config.inputWidth);
    final cStride = config.inputHeight * config.inputWidth;

    for (int y = 0; y < config.inputHeight; y++) {
      for (int x = 0; x < config.inputWidth; x++) {
        final pixel = resized.getPixel(x, y);
        final r = pixel.rNormalized * 255.0;
        final g = pixel.gNormalized * 255.0;
        final b = pixel.bNormalized * 255.0;
        final idx = y * config.inputWidth + x;
        floatData[idx] = (r - config.mean[0]) / config.std[0];
        floatData[cStride + idx] = (g - config.mean[1]) / config.std[1];
        floatData[2 * cStride + idx] = (b - config.mean[2]) / config.std[2];
      }
    }

    return floatData;
  }

  Future<PoseResult> _postprocessSimcc(
    Map<String, OrtValue> outputs,
    double inferenceMs,
  ) async {
    // RTMPose SimCC: two output tensors
    // simcc_x → shape [1, numKeypoints, simccXLength]
    // simcc_y → shape [1, numKeypoints, simccYLength]
    OrtValue? simccX;
    OrtValue? simccY;

    for (final entry in outputs.entries) {
      final shape = entry.value.shape;
      if (shape.length == 3) {
        final last = shape[2];
        if (last == config.simccXLength) {
          simccX = entry.value;
        } else if (last == config.simccYLength) {
          simccY = entry.value;
        }
      }
    }

    // Fallback: first=X, second=Y
    if (simccX == null && outputs.length >= 2) {
      final vals = outputs.values.toList();
      simccX = vals[0];
      simccY = vals[1];
    }

    if (simccX == null || simccY == null) {
      return PoseResult(keypoints: [], inferenceMs: inferenceMs);
    }

    final xFlat = await simccX.asFlattenedList();
    final yFlat = await simccY.asFlattenedList();

    final xData = xFlat.map((v) => (v as num).toDouble()).toList();
    final yData = yFlat.map((v) => (v as num).toDouble()).toList();

    final xLen = config.simccXLength;
    final yLen = config.simccYLength;
    final keypoints = <PoseKeypoint>[];

    for (int k = 0; k < config.numKeypoints; k++) {
      final xSlice = xData.sublist(k * xLen, (k + 1) * xLen);
      final ySlice = yData.sublist(k * yLen, (k + 1) * yLen);

      final xArgmax = _argmax(xSlice);
      final yArgmax = _argmax(ySlice);
      final confidence = (_peakConf(xSlice) + _peakConf(ySlice)) / 2.0;

      if (k == 0) {
        final xMax = xSlice.reduce(math.max);
        final xMin = xSlice.reduce(math.min);
        final xSum = xSlice.fold(0.0, (a, b) => a + b);
        debugPrint('[ORT] nose xSlice: max=$xMax  min=$xMin  sum=${xSum.toStringAsFixed(2)}  argmax=$xArgmax  softmaxMax=${_softmaxMax(xSlice).toStringAsFixed(5)}');
      }

      keypoints.add(PoseKeypoint(
        x: xArgmax / (xLen - 1),
        y: yArgmax / (yLen - 1),
        confidence: confidence,
      ));
    }

    final maxConf = keypoints.isEmpty
        ? 0.0
        : keypoints.map((k) => k.confidence).reduce(math.max);
    debugPrint('[ORT] keypoints=${keypoints.length}  maxConf=${maxConf.toStringAsFixed(3)}  '
        'valid=${keypoints.where((k) => k.isValid).length}  ms=${inferenceMs.toStringAsFixed(0)}');
    // Head keypoints: 0=nose 1=leftEye 2=rightEye 3=leftEar 4=rightEar
    for (int i = 0; i < math.min(5, keypoints.length); i++) {
      final k = keypoints[i];
      debugPrint('[ORT]   kp[$i] x=${k.x.toStringAsFixed(3)} y=${k.y.toStringAsFixed(3)} conf=${k.confidence.toStringAsFixed(3)}');
    }

    return PoseResult(keypoints: keypoints, inferenceMs: inferenceMs);
  }

  double _peakConf(List<double> v) {
    final m = v.reduce(math.max);
    final mean = v.fold(0.0, (a, b) => a + b) / v.length;
    return m - mean;
  }

  int _argmax(List<double> v) {
    int idx = 0;
    double max = v[0];
    for (int i = 1; i < v.length; i++) {
      if (v[i] > max) {
        max = v[i];
        idx = i;
      }
    }
    return idx;
  }

  double _softmaxMax(List<double> v) {
    final m = v.reduce(math.max);
    double sum = 0;
    for (final x in v) {
      sum += math.exp(x - m);
    }
    return 1.0 / sum; // exp(0) / sum after shift
  }

  Future<void> dispose() async {
    await _session?.close();
    _session = null;
    _isInitialized = false;
  }
}
