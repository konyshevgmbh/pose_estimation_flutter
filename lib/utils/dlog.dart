import 'package:flutter/foundation.dart';

void dlog(String msg) {
  if (kDebugMode) debugPrint(msg);
}
