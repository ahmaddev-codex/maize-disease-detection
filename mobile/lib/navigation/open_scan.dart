import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/app_provider.dart';

/// Shows one saved scan on the result screen. The screen renders only from this
/// record, so image, variety, feedback and advice always belong to the same scan.
/// The future completes when the result screen is popped, so a caller can
/// pause work — the camera's preview stream — while it is on top (T20).
Future<void> openScan(BuildContext context, WidgetRef ref, int scanId) {
  ref.read(activeScanIdProvider.notifier).state = scanId;
  ref.invalidate(activeScanRecordProvider); // re-read even when the same scan is reopened
  return context.push('/result');
}
