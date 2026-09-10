import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/app_provider.dart';

/// Shows one saved scan on the result screen. The screen renders only from this
/// record, so image, variety, feedback and advice always belong to the same scan.
void openScan(BuildContext context, WidgetRef ref, int scanId) {
  ref.read(activeScanIdProvider.notifier).state = scanId;
  ref.invalidate(activeScanRecordProvider); // re-read even when the same scan is reopened
  context.push('/result');
}
