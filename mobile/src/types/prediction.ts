export interface Prediction {
  classId: number;
  className: string;
  shortName: string;
  confidence: number;
  allScores: number[];
  latencyMs: number;
}

export interface SeedLabelData {
  cropVariety: string | null;
  batchNumber: string | null;
  plantingDate: string | null;
  rawText: string;
}

export interface DiseaseInfo {
  id: number;
  shortName: string;
  fullName: string;
  description: string;
  severity: 'high' | 'medium' | 'low' | 'none';
  treatments: string[];
  preventions: string[];
  color: string;
}
