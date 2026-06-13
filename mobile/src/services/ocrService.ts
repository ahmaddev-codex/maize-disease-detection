/**
 * OCR service using ML Kit Text Recognition v2.
 * Extracts structured seed label data from raw OCR text.
 * Ported from Flutter OcrService + extractor.py field extraction logic.
 */
import TextRecognition from '@react-native-ml-kit/text-recognition';
import {SeedLabelData} from '../types/prediction';
import {fuzzyMatchVariety} from '../constants/varieties';

// Batch number patterns (from Python extractor.py)
const BATCH_PATTERNS = [
  /BN[- ]?(\d{4}[- ]\d{3,6})/i,
  /LOT\s*#?\s*([A-Z0-9][A-Z0-9\-]{3,12})/i,
  /BATCH\s*NO[:.]\s*([A-Z0-9][A-Z0-9\-]{3,12})/i,
  /BATCH[:.]\s*([A-Z0-9][A-Z0-9\-]{3,12})/i,
  /B\/N[:.]\s*([A-Z0-9][A-Z0-9\-]{3,12})/i,
];

// Planting date patterns
const DATE_PATTERNS = [
  /(\d{4}[-/]\d{2}[-/]\d{2})/, // ISO: 2024-03-15
  /(\d{2}[-/]\d{2}[-/]\d{4})/, // DD/MM/YYYY
  /PLANT(?:ING)?\s*(?:DATE|BY)[:.]\s*(\w+\s+\d{4})/i,
  /SOWING\s*(?:DATE|BY)[:.]\s*(\w+\s+\d{4})/i,
  /SEASON[:.]\s*(\d{4})/i,
];

export async function recognizeText(imagePath: string): Promise<SeedLabelData> {
  const result = await TextRecognition.recognize(imagePath);
  const rawText = result.text;
  return extractFields(rawText);
}

export function extractFields(rawText: string): SeedLabelData {
  const upper = rawText.toUpperCase();

  return {
    cropVariety: extractVariety(upper),
    batchNumber: extractBatchNumber(rawText),
    plantingDate: extractPlantingDate(rawText),
    rawText,
  };
}

function extractVariety(upperText: string): string | null {
  // First try direct substring match for speed
  const {KNOWN_VARIETIES} = require('../constants/varieties');
  for (const v of KNOWN_VARIETIES) {
    if (upperText.includes(v)) return v;
  }
  // Fall back to fuzzy match on each line
  const lines = upperText.split('\n');
  for (const line of lines) {
    const match = fuzzyMatchVariety(line);
    if (match) return match;
  }
  return null;
}

function extractBatchNumber(text: string): string | null {
  for (const pattern of BATCH_PATTERNS) {
    const m = text.match(pattern);
    if (m) return m[1].trim();
  }
  return null;
}

function extractPlantingDate(text: string): string | null {
  for (const pattern of DATE_PATTERNS) {
    const m = text.match(pattern);
    if (m) {
      const raw = m[1].trim();
      return normalizeDate(raw);
    }
  }
  return null;
}

function normalizeDate(raw: string): string {
  // Try ISO
  if (/^\d{4}-\d{2}-\d{2}$/.test(raw)) return raw;
  // Try DD/MM/YYYY
  const dmy = raw.match(/^(\d{2})[-/](\d{2})[-/](\d{4})$/);
  if (dmy) return `${dmy[3]}-${dmy[2]}-${dmy[1]}`;
  // Month name YYYY → first of month
  const monthYear = raw.match(/^(\w+)\s+(\d{4})$/);
  if (monthYear) {
    const months: Record<string, string> = {
      JANUARY: '01', FEBRUARY: '02', MARCH: '03', APRIL: '04',
      MAY: '05', JUNE: '06', JULY: '07', AUGUST: '08',
      SEPTEMBER: '09', OCTOBER: '10', NOVEMBER: '11', DECEMBER: '12',
      JAN: '01', FEB: '02', MAR: '03', APR: '04',
      JUN: '06', JUL: '07', AUG: '08', SEP: '09', OCT: '10', NOV: '11', DEC: '12',
    };
    const m = months[monthYear[1].toUpperCase()];
    if (m) return `${monthYear[2]}-${m}-01`;
  }
  // Season year only
  if (/^\d{4}$/.test(raw)) return `${raw}-03-01`;
  return raw;
}
