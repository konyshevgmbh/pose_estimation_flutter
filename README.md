# Pose Estimation

Real-time pose detection from camera using [RTMPose](https://github.com/open-mmlab/mmpose/tree/main/projects/rtmpose) and [ONNX Runtime](https://onnxruntime.ai/), built with Flutter.

**[Live demo on GitHub Pages](https://konyshevgmbh.github.io/pose_estimation_flutter/)**

This project is also a practical example of **cross-platform camera access in Flutter** using [flutter_webrtc](https://pub.dev/packages/flutter_webrtc) — a single implementation that works on all six platforms without platform-specific code.

## Platforms

| Platform | Status |
|----------|--------|
| Android  | ✅ |
| iOS      | ✅ |
| Web      | ✅ |
| Windows  | ✅ |
| Linux    | ✅ |
| macOS    | ✅ |

## Features

- Real-time 17-keypoint body pose detection
- Runs fully on-device via ONNX Runtime (no server required)
- Camera input via WebRTC — works on mobile, desktop, and browser
- RTMPose-t model — lightweight and fast

## Screenshot

![Pose Estimation](icon.png)

## Getting Started

```bash
flutter pub get
flutter run -d chrome          # web
flutter run -d windows         # Windows desktop
flutter run -d macos           # macOS desktop
flutter run -d linux           # Linux desktop
flutter run                    # Android or iOS (device/emulator)
```

### Prerequisites

The ONNX model file must be placed at `assets/models/rtmpose.onnx`.  
See [assets/models/README.md](assets/models/README.md) for download instructions.

## Architecture

```
lib/
  main.dart              — app entry point
  screens/
    pose_screen.dart     — camera + inference UI
  services/
    pose_detector.dart   — ONNX Runtime inference
    camera_service.dart  — WebRTC camera capture
  painters/
    skeleton_painter.dart — keypoint overlay rendering
```

## Model

RTMPose-t exported to ONNX format.  
Input: `1 × 3 × 256 × 192` (RGB, normalized).  
Output: `1 × 17 × 3` (x, y, score per keypoint, COCO format).

## Tech Stack

| Component | Library |
|-----------|---------|
| UI | Flutter 3.x |
| Inference | [flutter_onnxruntime](https://pub.dev/packages/flutter_onnxruntime) |
| Camera | [flutter_webrtc](https://pub.dev/packages/flutter_webrtc) |
| Image processing | [image](https://pub.dev/packages/image) |

## License

MIT
