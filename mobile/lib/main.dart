import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'design_system/tokens/app_typography.dart';
import 'services/database_service.dart';
import 'services/path_resolver.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Fonts ship with the app; never fetch them over the network.
  AppTypography.configureBundledFonts();

  // Configure the iOS AVAudioSession to playback + mixWithOthers so that
  // audioplayers and flutter_tts can coexist. audioplayers_darwin registers
  // its native plugin at startup and sets the session category exclusively,
  // which blocks flutter_tts. Setting mixWithOthers here, before either
  // engine speaks, prevents that conflict.
  try {
    final cfgPlayer = AudioPlayer();
    await cfgPlayer.setAudioContext(AudioContext(
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playback,
        options: const {AVAudioSessionOptions.mixWithOthers},
      ),
    ));
    await cfgPlayer.dispose();
  } catch (e) {
    debugPrint('[audio] session config failed: $e');
  }

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
