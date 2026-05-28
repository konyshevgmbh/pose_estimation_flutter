/// RTMPose model configuration
class RTMPoseConfig {
  final int inputWidth;
  final int inputHeight;
  final int numKeypoints;
  final double simccSplitRatio;
  final List<double> mean;
  final List<double> std;

  const RTMPoseConfig({
    this.inputWidth = 192,
    this.inputHeight = 256,
    this.numKeypoints = 17,
    this.simccSplitRatio = 2.0,
    this.mean = const [123.675, 116.28, 103.53],
    this.std = const [58.395, 57.12, 57.375],
  });

  /// SimCC output length for x-axis
  int get simccXLength => (inputWidth * simccSplitRatio).round();

  /// SimCC output length for y-axis
  int get simccYLength => (inputHeight * simccSplitRatio).round();

  static const RTMPoseConfig defaultConfig = RTMPoseConfig();
}
