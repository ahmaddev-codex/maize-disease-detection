/// Class id of the Healthy class (see constants/diseases.dart).
const int kHealthyClassId = 3;

/// Scan counts per disease class over a window, shared by Home and the dashboard
/// so both always report the same numbers for the same period.
class FarmStats {
  const FarmStats({required this.days, required this.countsByClass});

  final int days;
  final Map<int, int> countsByClass;

  int get total => countsByClass.values.fold(0, (sum, count) => sum + count);
  int countFor(int classId) => countsByClass[classId] ?? 0;
  double shareOf(int classId) => total == 0 ? 0 : countFor(classId) / total;

  int get healthy => countFor(kHealthyClassId);
  int get diseased => total - healthy;

  /// Null when there are no scans, so the UI shows an empty state instead of 100%.
  double? get healthRate => total == 0 ? null : healthy / total;
}
