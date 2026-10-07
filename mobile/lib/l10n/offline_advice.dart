/// Says, in one short phrase, when the advice on screen is not in the language
/// the farmer chose.
///
/// The built-in rules are written in English only (translating them is Q7), and
/// until T27 a Hausa-speaking farmer offline simply got English text with no
/// explanation.
///
/// Returns null when there is nothing to explain.
String? adviceLanguageNote({
  required String requested,
  required String actual,
  required bool isOffline,
}) {
  if (requested == actual) return null;
  return isOffline ? '$actual (offline)' : actual;
}
