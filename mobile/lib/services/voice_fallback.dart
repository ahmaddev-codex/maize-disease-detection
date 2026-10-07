import 'dart:async';
import 'dart:io';

import '../providers/app_provider.dart' show DisplayLanguage, DisplayLanguageX;

/// Picks the best locale the device's own text-to-speech can actually speak for
/// [lang], or null when it has none.
///
/// A YarnGPT failure used to end the attempt for every language but English,
/// even on a phone with a Hausa voice installed (T27).
String? pickTtsLocale(DisplayLanguage lang, Iterable<String> installedLocales) {
  final installed = installedLocales.toList();
  for (final wanted in lang.ttsLocaleFallbacks) {
    for (final candidate in installed) {
      if (candidate.toLowerCase() == wanted.toLowerCase()) return candidate;
    }
  }
  return null;
}

/// Turns any failure into something a farmer can act on. The snackbar used to
/// carry the raw exception, class name and host included.
String friendlyVoiceError(Object error) {
  if (error is SocketException) {
    return 'No internet connection, so the voice could not be fetched. '
        'The written advice above is complete.';
  }
  if (error is TimeoutException) {
    return 'The voice service did not answer in time. Try again, or read the advice above.';
  }
  return 'The voice could not be played on this phone. The written advice above is complete.';
}

/// What the language picker should say about how this language will be spoken,
/// so the subtitle names the engine that will actually be used.
String voiceEngineLabel(DisplayLanguage lang, {required bool hasYarnKey}) {
  if (hasYarnKey) return 'YarnGPT · ${lang.yarnVoice}';
  if (lang.isEnglish) return 'Device voice · English';
  return 'Needs a YarnGPT key to speak ${lang.label}';
}
