import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'services/database_service.dart';
import 'services/path_resolver.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait for field use
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialise services — PathResolver must run before any image is displayed
  await PathResolver.init();
  await DatabaseService.instance.init();

  runApp(const ProviderScope(child: MaizeGuardApp()));
}
