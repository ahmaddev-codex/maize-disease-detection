/**
 * Google Gemini 2.0 Flash API advisor.
 * Ported from Flutter AiAdvisor with identical prompt template and fallback logic.
 */
import axios from 'axios';
import {Prediction} from '../types/prediction';
import {ScanRecord} from '../types/scanRecord';
import {RecommendationResult} from '../types/recommendation';
import {generateOnDeviceRecommendation} from './recommendationEngine';

const GEMINI_ENDPOINT =
  'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';

interface GeminiResponse {
  candidates?: Array<{
    content?: {
      parts?: Array<{text?: string}>;
    };
  }>;
}

export async function getAiAdvice(
  prediction: Prediction,
  recentScans: ScanRecord[],
  apiKey: string | null,
): Promise<{text: string; isAi: boolean}> {
  if (!apiKey) {
    const recommendation = generateOnDeviceRecommendation(
      prediction,
      recentScans,
    );
    return {text: formatRecommendation(recommendation), isAi: false};
  }

  try {
    const prompt = buildPrompt(prediction, recentScans);
    const response = await axios.post<GeminiResponse>(
      `${GEMINI_ENDPOINT}?key=${apiKey}`,
      {
        contents: [{parts: [{text: prompt}]}],
        generationConfig: {
          temperature: 0.3,
          maxOutputTokens: 1024,
          topP: 0.8,
        },
      },
      {timeout: 15000},
    );

    const text =
      response.data.candidates?.[0]?.content?.parts?.[0]?.text ?? '';
    if (!text) throw new Error('Empty response from Gemini');
    return {text, isAi: true};
  } catch {
    const recommendation = generateOnDeviceRecommendation(
      prediction,
      recentScans,
    );
    return {text: formatRecommendation(recommendation), isAi: false};
  }
}

function buildPrompt(
  prediction: Prediction,
  recentScans: ScanRecord[],
): string {
  const diseaseCount = recentScans.filter(
    s => s.classId === prediction.classId,
  ).length;
  const totalScans = recentScans.length;
  const confidence = Math.round(prediction.confidence * 100);

  return `You are an expert agronomist specializing in maize (corn) production in West Africa, particularly Nigeria.

A farmer has just scanned a maize leaf and received the following diagnosis:
- Disease: ${prediction.className} (${prediction.shortName})
- Confidence: ${confidence}%
- Recent scan history: ${diseaseCount} out of ${totalScans} recent scans show the same disease

Please provide practical agricultural advice in the following sections:

## Immediate Actions
List 3-4 specific steps the farmer should take within the next 24-48 hours.

## Treatment Options
Recommend specific fungicides or treatments available in Nigeria, with application rates and timing.

## Prevention for Next Season
Give 2-3 actionable prevention strategies for the next planting season.

## Economic Impact
Brief note on potential yield loss if untreated and cost-benefit of treatment.

Keep advice practical, specific to Nigerian smallholder farming conditions, and avoid technical jargon.`;
}

function formatRecommendation(rec: RecommendationResult): string {
  const lines: string[] = [];
  lines.push(`## Immediate Actions`);
  rec.immediateActions.forEach(a => lines.push(`• ${a}`));
  lines.push('');
  lines.push(`## Treatment Options`);
  if (rec.fungicides.length === 0) {
    lines.push('• No fungicide treatment required for healthy plants.');
  } else {
    rec.fungicides.forEach(f => {
      lines.push(
        `• ${f.brandName} (${f.activeIngredient}) — ${f.ratePerHa} via ${f.applicationMethod}`,
      );
    });
  }
  lines.push('');
  lines.push(`## Prevention`);
  rec.preventiveActions.forEach(a => lines.push(`• ${a}`));
  lines.push('');
  lines.push(`_On-device recommendation (offline mode)_`);
  return lines.join('\n');
}
