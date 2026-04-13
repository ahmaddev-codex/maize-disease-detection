/// Platform-conditional export — uses TFLite on native, stub on web.
library;

export 'classifier_native.dart' if (dart.library.html) 'classifier_web.dart';
