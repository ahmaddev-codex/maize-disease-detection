import {create} from 'zustand';
import AsyncStorage from '@react-native-async-storage/async-storage';
import {SeedLabelData} from '../types/prediction';

type ModelState = 'idle' | 'loading' | 'ready' | 'error';

interface AppState {
  // Theme
  isDarkMode: boolean;
  toggleTheme: () => void;

  // TFLite model lifecycle
  modelState: ModelState;
  modelError: string | null;
  setModelState: (state: ModelState, error?: string) => void;

  // Pending OCR label (scanned before camera classification)
  pendingLabel: SeedLabelData | null;
  setPendingLabel: (label: SeedLabelData | null) => void;

  // Gemini API key (loaded from keychain at startup)
  geminiApiKey: string | null;
  setGeminiApiKey: (key: string | null) => void;

  // Hydrate from AsyncStorage
  hydrate: () => Promise<void>;
}

export const useAppStore = create<AppState>((set, get) => ({
  isDarkMode: true,
  toggleTheme: async () => {
    const next = !get().isDarkMode;
    set({isDarkMode: next});
    await AsyncStorage.setItem('theme', next ? 'dark' : 'light');
  },

  modelState: 'idle',
  modelError: null,
  setModelState: (state, error) =>
    set({modelState: state, modelError: error ?? null}),

  pendingLabel: null,
  setPendingLabel: label => set({pendingLabel: label}),

  geminiApiKey: null,
  setGeminiApiKey: key => set({geminiApiKey: key}),

  hydrate: async () => {
    const theme = await AsyncStorage.getItem('theme');
    if (theme) {
      set({isDarkMode: theme === 'dark'});
    }
  },
}));
