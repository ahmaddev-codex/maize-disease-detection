export interface ScanRecord {
  id: number;
  imagePath: string;
  classId: number;
  className: string;
  shortName: string;
  confidence: number;
  allScores: number[];
  latencyMs: number;
  latitude?: number;
  longitude?: number;
  cropVariety?: string;
  batchNumber?: string;
  plantingDate?: string;
  scannedAt: string;
  notes?: string;
}
