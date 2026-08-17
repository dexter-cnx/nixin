import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_storage.dart';

final appStorageProvider = Provider<AppStorage>((ref) {
  throw StateError(
    'appStorageProvider must be overridden at application bootstrap',
  );
});
