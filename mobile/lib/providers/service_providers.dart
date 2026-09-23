import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/ai_advisor.dart';
import '../services/classifier_service.dart';
import '../services/database_service.dart';
import '../services/location_service.dart';
import '../services/ocr_service.dart';
import '../services/scan_storage.dart';
import '../services/yarn_tts_service.dart';

// Services are read through these providers so tests can override them with
// fakes. The defaults are the app-wide singletons.
final classifierServiceProvider = Provider<ClassifierService>((ref) => ClassifierService.instance);
final ocrServiceProvider        = Provider<OcrService>((ref) => OcrService.instance);
final locationServiceProvider   = Provider<LocationService>((ref) => LocationService.instance);
final aiAdvisorProvider         = Provider<AiAdvisor>((ref) => AiAdvisor.instance);
final yarnTtsServiceProvider    = Provider<YarnTtsService>((ref) => YarnTtsService.instance);
final databaseServiceProvider   = Provider<DatabaseService>((ref) => DatabaseService.instance);
final scanStorageProvider       = Provider<ScanStorage>((ref) => ScanStorage.instance);
