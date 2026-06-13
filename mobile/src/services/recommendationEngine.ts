/**
 * On-device recommendation engine.
 * Ported from Flutter recommendation_engine.dart with identical:
 * - Nigerian farming calendar heuristics
 * - Urgency calculation logic
 * - Fungicide recommendations per disease class
 */
import {Prediction} from '../types/prediction';
import {ScanRecord} from '../types/scanRecord';
import {
  RecommendationResult,
  FarmingSeason,
  UrgencyLevel,
  FungicideOption,
} from '../types/recommendation';

// Nigerian farming calendar
// Main season: March–July | Off season: August–November | Dry: December–February
function getCurrentSeason(): FarmingSeason {
  const month = new Date().getMonth() + 1; // 1-12
  if (month >= 3 && month <= 7) return 'main';
  if (month >= 8 && month <= 11) return 'off';
  return 'dry';
}

function calcTrend(
  classId: number,
  recentScans: ScanRecord[],
): 'worsening' | 'stable' | 'improving' {
  if (recentScans.length < 3) return 'stable';
  const last5 = recentScans.slice(0, 5);
  const diseaseCount = last5.filter(s => s.classId === classId).length;
  const prev5 = recentScans.slice(5, 10);
  if (prev5.length === 0) return diseaseCount > 2 ? 'worsening' : 'stable';
  const prevCount = prev5.filter(s => s.classId === classId).length;
  if (diseaseCount > prevCount + 1) return 'worsening';
  if (diseaseCount < prevCount - 1) return 'improving';
  return 'stable';
}

function calcUrgency(
  classId: number,
  confidence: number,
  trend: string,
): UrgencyLevel {
  if (classId === 3) return 'none'; // Healthy
  if (confidence > 0.85 && trend === 'worsening') return 'critical';
  if (confidence > 0.75) return 'high';
  if (confidence > 0.5) return 'moderate';
  return 'low';
}

const FUNGICIDES: Record<number, FungicideOption[]> = {
  0: [
    // NCLB
    {
      activeIngredient: 'Propiconazole',
      brandName: 'Tilt 250EC',
      ratePerHa: '500ml/ha',
      applicationMethod: 'foliar spray',
    },
    {
      activeIngredient: 'Azoxystrobin',
      brandName: 'Amistar 250SC',
      ratePerHa: '750ml/ha',
      applicationMethod: 'foliar spray',
    },
  ],
  1: [
    // Rust
    {
      activeIngredient: 'Mancozeb',
      brandName: 'Dithane M-45',
      ratePerHa: '2.0 kg/ha',
      applicationMethod: 'foliar spray',
    },
    {
      activeIngredient: 'Azoxystrobin + Propiconazole',
      brandName: 'Quilt Xcel 200SE',
      ratePerHa: '1.0L/ha',
      applicationMethod: 'foliar spray',
    },
  ],
  2: [
    // GLS
    {
      activeIngredient: 'Pyraclostrobin',
      brandName: 'Headline 250EC',
      ratePerHa: '1.0L/ha',
      applicationMethod: 'foliar spray',
    },
    {
      activeIngredient: 'Tebuconazole',
      brandName: 'Folicur 250EW',
      ratePerHa: '1.0L/ha',
      applicationMethod: 'foliar spray',
    },
  ],
  3: [], // Healthy — no fungicide needed
};

const IMMEDIATE_ACTIONS: Record<number, string[]> = {
  0: [
    'Isolate affected plants to slow disease spread to adjacent rows',
    'Remove and dispose of heavily infected lower leaves (do not compost)',
    'Apply propiconazole or azoxystrobin fungicide at first signs of infection',
    'Ensure adequate potassium — K deficiency increases NCLB susceptibility',
  ],
  1: [
    'Monitor fields early morning when rust pustules are most visible',
    'Apply mancozeb or copper-based fungicide immediately',
    'Increase air circulation by avoiding dense planting in subsequent seasons',
    'Avoid overhead irrigation — wet leaves accelerate rust spread',
  ],
  2: [
    'Apply strobilurin or triazole fungicide to upper canopy',
    'Minimize crop residue on soil surface — GLS overwinters in debris',
    'Check crop rotation history — continuous maize increases GLS pressure',
    'Target fungicide application to the VT/R1 growth stage for best results',
  ],
  3: [
    'Continue regular field scouting every 7–10 days',
    'Maintain current fertilizer and irrigation schedule',
    'Record observation for disease trend tracking',
    'No immediate action required — plant looks healthy',
  ],
};

const PREVENTIVE_ACTIONS: Record<number, string[]> = {
  0: [
    'Plant NCLB-resistant hybrids (Ht gene) next season',
    'Practice 2-year crop rotation with legumes',
    'Avoid overhead irrigation to reduce leaf wetness duration',
  ],
  1: [
    'Plant early (March) to avoid peak rust season (August–September)',
    'Choose rust-resistant varieties for next season',
    'Monitor weekly during humid periods and act at first pustule',
  ],
  2: [
    'Practice minimum-till to bury infected residues',
    'Select GLS-tolerant hybrids for continuous maize systems',
    'Ensure balanced K nutrition to strengthen cell walls',
  ],
  3: [
    'Continue current good agronomic practices',
    'Plan seasonal disease scouting calendar',
    'Consider prophylactic fungicide at VT/R1 if regional disease pressure is high',
  ],
};

export function generateOnDeviceRecommendation(
  prediction: Prediction,
  recentScans: ScanRecord[],
): RecommendationResult {
  const season = getCurrentSeason();
  const trend = calcTrend(prediction.classId, recentScans);
  const urgency = calcUrgency(prediction.classId, prediction.confidence, trend);

  const summaries: Record<UrgencyLevel, string> = {
    critical: `Critical: ${prediction.shortName} spreading rapidly. Immediate intervention required.`,
    high: `High priority: Confirmed ${prediction.shortName} at ${Math.round(prediction.confidence * 100)}% confidence. Act within 48 hours.`,
    moderate: `Moderate: ${prediction.shortName} detected. Schedule treatment within this week.`,
    low: `Low risk: Possible early ${prediction.shortName} signs. Monitor closely for 3–5 days.`,
    none: 'Plant appears healthy. Continue routine monitoring.',
  };

  const followUpDays: Record<UrgencyLevel, number> = {
    critical: 1,
    high: 3,
    moderate: 7,
    low: 14,
    none: 21,
  };

  return {
    urgency,
    summary: summaries[urgency],
    immediateActions: IMMEDIATE_ACTIONS[prediction.classId] ?? [],
    preventiveActions: PREVENTIVE_ACTIONS[prediction.classId] ?? [],
    fungicides: FUNGICIDES[prediction.classId] ?? [],
    followUpDays: followUpDays[urgency],
    season,
    trend,
  };
}
