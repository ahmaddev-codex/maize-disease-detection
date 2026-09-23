/// Class id of the Healthy class.
const int kHealthyClassId = 3;

/// Where the actives table below comes from, and whether anyone qualified has
/// checked it. The app must not imply a sign-off it does not have (T25, Q5).
class ActivesReview {
  const ActivesReview({
    required this.status,
    required this.updated,
    required this.sources,
    this.reviewer,
  });

  /// 'pending-agronomist-review' until a named agronomist signs it off.
  final String status;
  final String updated; // ISO date
  final List<String> sources;
  final String? reviewer;

  bool get isSignedOff => status == 'reviewed' && reviewer != null;
}

const ActivesReview kActivesReview = ActivesReview(
  status: 'pending-agronomist-review',
  updated: '2026-09-23',
  sources: [
    'CIMMYT, Maize Doctor: Northern corn leaf blight, common rust, gray leaf spot',
    'IITA maize disease management guidance for West Africa',
    'FAO/NAFDAC principle: dose and pre-harvest interval come from the product label',
  ],
);

class DiseaseInfo {
  final int classId;
  final String name;
  final String shortName;
  final String description;
  final List<String> symptoms;
  final List<String> treatments;
  final List<String> prevention;

  /// Chemical groups and active ingredients that control this disease. Named as
  /// actives, not brands: brands differ by market, and two widely sold products
  /// (metalaxyl "Ridomil Gold", copper "Funguran") do not control these fungi.
  final List<String> actives;

  const DiseaseInfo({
    required this.classId,
    required this.name,
    required this.shortName,
    required this.description,
    required this.symptoms,
    required this.treatments,
    required this.prevention,
    this.actives = const [],
  });
}

const List<DiseaseInfo> kDiseases = [
  DiseaseInfo(
    classId: 0,
    name: 'Northern Corn Leaf Blight',
    shortName: 'NCLB',
    description:
        'A fungal disease caused by Exserohilum turcicum. Forms long, cigar-shaped grey-green lesions on leaves. Can reduce yield by 30–50% in severe outbreaks.',
    symptoms: [
      'Long, elliptical grey-green lesions (2.5–15 cm)',
      'Lesions turn tan with dark borders',
      'Affected leaves dry out and die prematurely',
      'Severe infection from bottom leaves upward',
    ],
    treatments: [
      'Apply mancozeb or azoxystrobin fungicide immediately',
      'Remove and destroy severely blighted leaves',
      'Ensure adequate plant spacing for air circulation',
      'Avoid overhead irrigation',
    ],
    actives: [
      'mancozeb (protectant, contact)',
      'azoxystrobin (strobilurin)',
      'propiconazole (triazole)',
    ],
    prevention: [
      'Plant resistant varieties (SAMMAZ 15, SAMMAZ 17)',
      'Rotate crops — avoid maize-after-maize planting',
      'Destroy crop residue after harvest',
      'Apply preventive fungicide at tasselling',
    ],
  ),
  DiseaseInfo(
    classId: 1,
    name: 'Common Rust',
    shortName: 'Rust',
    description:
        'Caused by Puccinia sorghi. Produces brick-red pustules on both leaf surfaces. Spreads rapidly in cool (16–23°C) humid conditions via airborne spores.',
    symptoms: [
      'Small, round to elongated brick-red pustules',
      'Pustules on both upper and lower leaf surfaces',
      'Leaves turn yellow then brown as infection progresses',
      'Rapid spread under cool, humid conditions',
    ],
    treatments: [
      'Apply triazole fungicide (propiconazole or tebuconazole) early',
      'Strobilurin fungicides also effective',
      'Begin treatment at first pustule appearance',
      'Repeat application after 14 days if infection persists',
    ],
    actives: [
      'propiconazole or tebuconazole (triazole)',
      'azoxystrobin (strobilurin)',
    ],
    prevention: [
      'Plant early to avoid peak spore periods',
      'Use rust-resistant varieties where available',
      'Monitor fields weekly during humid seasons',
      'Apply preventive fungicide if neighbours have rust',
    ],
  ),
  DiseaseInfo(
    classId: 2,
    name: 'Gray Leaf Spot',
    shortName: 'GLS',
    description:
        'Caused by Cercospora zeae-maydis. Forms rectangular grey-tan lesions bounded by leaf veins. Favoured by warm temperatures and prolonged leaf wetness.',
    symptoms: [
      'Rectangular, tan-to-grey lesions bounded by veins',
      'Lesions run parallel to leaf veins',
      'Pale yellow halo around mature lesions',
      'Severe blighting of entire leaf in humid conditions',
    ],
    treatments: [
      'Apply strobilurin fungicide (azoxystrobin or pyraclostrobin)',
      'Tank-mix with triazole for broad-spectrum control',
      'Apply at first sign of lesions on lower leaves',
      'Ensure thorough leaf coverage during application',
    ],
    actives: [
      'azoxystrobin or pyraclostrobin (strobilurin)',
      'propiconazole (triazole), often tank-mixed with a strobilurin',
    ],
    prevention: [
      'Increase plant spacing to improve air circulation',
      'Avoid irrigating in the evening',
      'Destroy crop debris after harvest — fungus overwinters in residue',
      'Use certified disease-free seed',
    ],
  ),
  DiseaseInfo(
    classId: 3,
    name: 'Healthy',
    shortName: 'Healthy',
    description:
        'No disease detected. The plant appears healthy. Continue routine monitoring every 7–10 days during the growing season.',
    symptoms: ['No symptoms detected'],
    treatments: ['No treatment required'],
    prevention: [
      'Continue weekly field scouting',
      'Maintain adequate fertilisation',
      'Monitor weather — disease risk increases during humid periods',
      'Keep field records for early trend detection',
    ],
  ),
];

DiseaseInfo diseaseForClass(int classId) =>
    kDiseases.firstWhere((d) => d.classId == classId, orElse: () => kDiseases[3]);

// Nigerian maize varieties (FR-14)
const List<String> kNigerianVarieties = [
  'SAMMAZ 15', 'SAMMAZ 17', 'SAMMAZ 29', 'SAMMAZ 34', 'SAMMAZ 50',
  'OBA SUPER 2', 'EVDT 99', 'POOL 16 DT', 'TZEE-W', 'ABA WHITE',
  'ACROSS 97', 'SUWAN 1', 'EARLY THRIVING',
];
