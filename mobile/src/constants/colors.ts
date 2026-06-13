// GitHub-dark palette — matches Flutter GhC / AppColors exactly
export const DarkColors = {
  canvas: '#0D1117',
  surface: '#161B22',
  surfaceOverlay: '#1C2128',
  border: '#30363D',
  borderMuted: '#21262D',
  textPrimary: '#E6EDF3',
  textSecondary: '#7D8590',
  textMuted: '#484F58',
  accentEmphasis: '#1F6FEB',
  accentFg: '#79C0FF',
  successEmphasis: '#238636',
  successFg: '#3FB950',
  dangerEmphasis: '#DA3633',
  dangerFg: '#F85149',
  attentionEmphasis: '#9E6A03',
  attentionFg: '#E3B341',
  doneFg: '#D2A8FF',
  sponsorFg: '#F778BA',
} as const;

export const LightColors = {
  canvas: '#F6F8FA',
  surface: '#FFFFFF',
  surfaceOverlay: '#F6F8FA',
  border: '#D0D7DE',
  borderMuted: '#E1E4E8',
  textPrimary: '#1F2328',
  textSecondary: '#57606A',
  textMuted: '#8C959F',
  accentEmphasis: '#0969DA',
  accentFg: '#0969DA',
  successEmphasis: '#1F883D',
  successFg: '#1F883D',
  dangerEmphasis: '#CF222E',
  dangerFg: '#CF222E',
  attentionEmphasis: '#9A6700',
  attentionFg: '#9A6700',
  doneFg: '#8250DF',
  sponsorFg: '#BF3989',
} as const;

// Disease severity colors (same in both themes)
export const DiseaseColors = {
  nclb: '#F85149',    // Northern Corn Leaf Blight — danger red
  rust: '#E3B341',    // Common Rust — attention yellow
  gls: '#D2A8FF',     // Gray Leaf Spot — purple/done
  healthy: '#3FB950', // Healthy — success green
} as const;

export type ColorScheme = typeof DarkColors;
