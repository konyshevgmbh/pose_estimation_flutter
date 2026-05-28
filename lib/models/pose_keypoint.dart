import 'dart:ui';

/// COCO 17-keypoint indices
enum KeypointIndex {
  nose,         // 0
  leftEye,      // 1
  rightEye,     // 2
  leftEar,      // 3
  rightEar,     // 4
  leftShoulder, // 5
  rightShoulder,// 6
  leftElbow,    // 7
  rightElbow,   // 8
  leftWrist,    // 9
  rightWrist,   // 10
  leftHip,      // 11
  rightHip,     // 12
  leftKnee,     // 13
  rightKnee,    // 14
  leftAnkle,    // 15
  rightAnkle,   // 16
}

class PoseKeypoint {
  final double x;
  final double y;
  final double confidence;

  const PoseKeypoint({required this.x, required this.y, required this.confidence});

  Offset toOffset() => Offset(x, y);

  bool get isValid => confidence > 0.3;
}

class PoseResult {
  final List<PoseKeypoint> keypoints;
  final double inferenceMs;

  const PoseResult({required this.keypoints, required this.inferenceMs});

  PoseKeypoint? get(KeypointIndex idx) {
    final i = idx.index;
    if (i >= keypoints.length) return null;
    return keypoints[i];
  }
}

/// COCO skeleton connections for drawing bones
const List<(KeypointIndex, KeypointIndex)> kSkeletonConnections = [
  (KeypointIndex.nose, KeypointIndex.leftEye),
  (KeypointIndex.nose, KeypointIndex.rightEye),
  (KeypointIndex.leftEye, KeypointIndex.leftEar),
  (KeypointIndex.rightEye, KeypointIndex.rightEar),
  (KeypointIndex.leftShoulder, KeypointIndex.rightShoulder),
  (KeypointIndex.leftShoulder, KeypointIndex.leftElbow),
  (KeypointIndex.leftElbow, KeypointIndex.leftWrist),
  (KeypointIndex.rightShoulder, KeypointIndex.rightElbow),
  (KeypointIndex.rightElbow, KeypointIndex.rightWrist),
  (KeypointIndex.leftShoulder, KeypointIndex.leftHip),
  (KeypointIndex.rightShoulder, KeypointIndex.rightHip),
  (KeypointIndex.leftHip, KeypointIndex.rightHip),
  (KeypointIndex.leftHip, KeypointIndex.leftKnee),
  (KeypointIndex.leftKnee, KeypointIndex.leftAnkle),
  (KeypointIndex.rightHip, KeypointIndex.rightKnee),
  (KeypointIndex.rightKnee, KeypointIndex.rightAnkle),
];
