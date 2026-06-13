import {DiseaseInfo} from '../types/prediction';
import {DiseaseColors} from './colors';

export const DISEASE_INFO: DiseaseInfo[] = [
  {
    id: 0,
    shortName: 'NCLB',
    fullName: 'Northern Corn Leaf Blight',
    description:
      'Caused by Exserohilum turcicum. Produces long, cigar-shaped grey-green to tan lesions on leaves. Severe infections can cause significant yield loss, especially when upper leaves are affected before silking.',
    severity: 'high',
    color: DiseaseColors.nclb,
    treatments: [
      'Apply foliar fungicides (propiconazole, azoxystrobin) at first sign of infection',
      'Remove and destroy severely infected plant debris',
      'Increase plant spacing to improve air circulation',
    ],
    preventions: [
      'Use resistant hybrid varieties (Ht gene)',
      'Practice crop rotation with non-host crops',
      'Avoid overhead irrigation',
      'Apply balanced fertilizer to reduce plant stress',
    ],
  },
  {
    id: 1,
    shortName: 'Rust',
    fullName: 'Common Rust',
    description:
      'Caused by Puccinia sorghi. Produces small, circular to elongated, golden-brown to dark brown pustules on both leaf surfaces. Spreads rapidly in cool, moist conditions with heavy dew.',
    severity: 'medium',
    color: DiseaseColors.rust,
    treatments: [
      'Apply mancozeb or copper-based fungicide at early pustule stage',
      'Spray azoxystrobin + propiconazole mixture for systemic control',
      'Repeat application every 14 days if disease pressure persists',
    ],
    preventions: [
      'Plant early to avoid peak rust season (Aug–Sep)',
      'Use rust-resistant varieties',
      'Monitor fields weekly during humid periods',
      'Avoid excessive nitrogen application',
    ],
  },
  {
    id: 2,
    shortName: 'GLS',
    fullName: 'Gray Leaf Spot',
    description:
      'Caused by Cercospora zeae-maydis. Produces rectangular, tan lesions with yellow halos bounded by leaf veins. Thrives in warm, humid conditions with prolonged leaf wetness.',
    severity: 'medium',
    color: DiseaseColors.gls,
    treatments: [
      'Apply strobilurin fungicides (azoxystrobin, pyraclostrobin) at VT/R1 growth stage',
      'Use triazole fungicides (tebuconazole, propiconazole) as alternatives',
      'Targeted application to upper canopy where infection begins',
    ],
    preventions: [
      'No-till or minimum-till farming increases risk — rotate crops',
      'Bury or incorporate infected residues after harvest',
      'Choose GLS-tolerant hybrids',
      'Ensure adequate potassium nutrition',
    ],
  },
  {
    id: 3,
    shortName: 'Healthy',
    fullName: 'Healthy Plant',
    description:
      'No visible disease symptoms detected. The plant shows normal green coloration and leaf texture consistent with healthy maize at this growth stage.',
    severity: 'none',
    color: DiseaseColors.healthy,
    treatments: [],
    preventions: [
      'Continue regular field monitoring every 7–10 days',
      'Maintain balanced fertilizer program',
      'Ensure adequate soil moisture',
      'Scout for early disease or pest signs',
    ],
  },
];

export const CLASS_NAMES = DISEASE_INFO.map(d => d.className);
export const SHORT_NAMES = DISEASE_INFO.map(d => d.shortName);

export function getDiseaseInfo(classId: number): DiseaseInfo {
  return DISEASE_INFO[classId] ?? DISEASE_INFO[3];
}
