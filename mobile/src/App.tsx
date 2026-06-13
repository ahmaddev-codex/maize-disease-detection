import React, {useEffect} from 'react';
import {NavigationContainer} from '@react-navigation/native';
import {SafeAreaProvider} from 'react-native-safe-area-context';
import Keychain from 'react-native-keychain';
import {useAppStore} from './store/appStore';
import {initDatabase} from './services/database';
import {useClassifier} from './hooks/useClassifier';
import RootNavigator from './navigation/RootNavigator';
import {DarkColors, LightColors} from './constants/colors';

function AppInner() {
  const {hydrate, setGeminiApiKey, isDarkMode} = useAppStore();
  const C = isDarkMode ? DarkColors : LightColors;

  // Load TFLite model
  useClassifier();

  useEffect(() => {
    // Initialise SQLite
    initDatabase().catch(e => console.error('[DB]', e));

    // Load saved preferences
    hydrate().catch(() => {});

    // Load Gemini key from secure storage
    Keychain.getGenericPassword({service: 'com.maizeguard.gemini'})
      .then(creds => {
        if (creds && creds.password) {
          setGeminiApiKey(creds.password);
        }
      })
      .catch(() => {});
  }, [hydrate, setGeminiApiKey]);

  const navigationTheme = {
    dark: isDarkMode,
    colors: {
      primary: C.accentEmphasis,
      background: C.canvas,
      card: C.surface,
      text: C.textPrimary,
      border: C.border,
      notification: C.dangerFg,
    },
  };

  return (
    <NavigationContainer theme={navigationTheme}>
      <RootNavigator />
    </NavigationContainer>
  );
}

export default function App() {
  return (
    <SafeAreaProvider>
      <AppInner />
    </SafeAreaProvider>
  );
}
