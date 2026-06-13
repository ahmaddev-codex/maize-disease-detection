export type FarmingSeason = 'main' | 'off' | 'dry';
export type UrgencyLevel = 'critical' | 'high' | 'moderate' | 'low' | 'none';

export interface FungicideOption {
  activeIngredient: string;
  brandName: string;
  ratePerHa: string;
  applicationMethod: string;
}

export interface RecommendationResult {
  urgency: UrgencyLevel;
  summary: string;
  immediateActions: string[];
  preventiveActions: string[];
  fungicides: FungicideOption[];
  followUpDays: number;
  season: FarmingSeason;
  trend: 'worsening' | 'stable' | 'improving';
}
