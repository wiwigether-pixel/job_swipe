import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

// 把邏輯搬到這裡
final logger = Logger(
  filter: kReleaseMode ? ProductionFilter() : DevelopmentFilter(),
  level: kReleaseMode ? Level.off : Level.all,
  printer: PrettyPrinter(methodCount: 0),
);