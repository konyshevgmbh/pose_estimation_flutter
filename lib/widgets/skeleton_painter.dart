import 'package:flutter/material.dart';

import '../models/pose_keypoint.dart';

// Standard MMPose color palette per connection
const _boneColors = <(KeypointIndex, KeypointIndex), Color>{
  // Face
  (KeypointIndex.nose, KeypointIndex.leftEye):       Color(0xFFAA00FF),
  (KeypointIndex.nose, KeypointIndex.rightEye):      Color(0xFFFF00AA),
  (KeypointIndex.leftEye, KeypointIndex.leftEar):    Color(0xFF8800FF),
  (KeypointIndex.rightEye, KeypointIndex.rightEar):  Color(0xFFFF0088),
  // Shoulders
  (KeypointIndex.leftShoulder, KeypointIndex.rightShoulder): Color(0xFFFFFF00),
  // Left arm
  (KeypointIndex.leftShoulder, KeypointIndex.leftElbow):  Color(0xFF0088FF),
  (KeypointIndex.leftElbow, KeypointIndex.leftWrist):     Color(0xFF00CCFF),
  // Right arm
  (KeypointIndex.rightShoulder, KeypointIndex.rightElbow): Color(0xFFFF4400),
  (KeypointIndex.rightElbow, KeypointIndex.rightWrist):    Color(0xFFFF8800),
  // Torso
  (KeypointIndex.leftShoulder, KeypointIndex.leftHip):   Color(0xFF00FF88),
  (KeypointIndex.rightShoulder, KeypointIndex.rightHip): Color(0xFFFFCC00),
  (KeypointIndex.leftHip, KeypointIndex.rightHip):       Color(0xFFFFFF00),
  // Left leg
  (KeypointIndex.leftHip, KeypointIndex.leftKnee):    Color(0xFF00FF44),
  (KeypointIndex.leftKnee, KeypointIndex.leftAnkle):  Color(0xFF00FF00),
  // Right leg
  (KeypointIndex.rightHip, KeypointIndex.rightKnee):   Color(0xFFFF6600),
  (KeypointIndex.rightKnee, KeypointIndex.rightAnkle): Color(0xFFFF2200),
};

// Color per keypoint index (COCO 17)
const _keypointColors = <Color>[
  Color(0xFFFF0000), // 0  nose
  Color(0xFFAA00FF), // 1  left_eye
  Color(0xFFFF00AA), // 2  right_eye
  Color(0xFF8800FF), // 3  left_ear
  Color(0xFFFF0088), // 4  right_ear
  Color(0xFF0088FF), // 5  left_shoulder
  Color(0xFFFF4400), // 6  right_shoulder
  Color(0xFF00CCFF), // 7  left_elbow
  Color(0xFFFF8800), // 8  right_elbow
  Color(0xFF00FFFF), // 9  left_wrist
  Color(0xFFFFCC00), // 10 right_wrist
  Color(0xFF00FF88), // 11 left_hip
  Color(0xFFFF6600), // 12 right_hip
  Color(0xFF00FF44), // 13 left_knee
  Color(0xFFFF3300), // 14 right_knee
  Color(0xFF00FF00), // 15 left_ankle
  Color(0xFFFF2200), // 16 right_ankle
];

class SkeletonPainter extends CustomPainter {
  final PoseResult? poseResult;
  final Size previewSize;
  final bool mirror;

  SkeletonPainter({
    required this.poseResult,
    required this.previewSize,
    this.mirror = false,
  });

  double _x(double nx, double width) =>
      mirror ? (1.0 - nx) * width : nx * width;

  @override
  void paint(Canvas canvas, Size size) {
    if (poseResult == null || poseResult!.keypoints.isEmpty) return;

    final sx = size.width;
    final sy = size.height;

    // Bones
    for (final entry in _boneColors.entries) {
      final (fromIdx, toIdx) = entry.key;
      final from = poseResult!.get(fromIdx);
      final to = poseResult!.get(toIdx);
      if (from == null || to == null) continue;
      if (!from.isValid || !to.isValid) continue;

      canvas.drawLine(
        Offset(_x(from.x, sx), from.y * sy),
        Offset(_x(to.x, sx), to.y * sy),
        Paint()
          ..color = entry.value.withAlpha(220)
          ..strokeWidth = 3.0
          ..strokeCap = StrokeCap.round,
      );
    }

    // Keypoints
    for (int i = 0; i < poseResult!.keypoints.length; i++) {
      final kp = poseResult!.keypoints[i];
      if (!kp.isValid) continue;

      final color = i < _keypointColors.length
          ? _keypointColors[i]
          : Colors.white;

      canvas.drawCircle(
        Offset(_x(kp.x, sx), kp.y * sy),
        5.0,
        Paint()..color = color,
      );
      // White border for contrast
      canvas.drawCircle(
        Offset(_x(kp.x, sx), kp.y * sy),
        5.0,
        Paint()
          ..color = Colors.white.withAlpha(180)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(SkeletonPainter oldDelegate) =>
      poseResult != oldDelegate.poseResult ||
      previewSize != oldDelegate.previewSize ||
      mirror != oldDelegate.mirror;
}
