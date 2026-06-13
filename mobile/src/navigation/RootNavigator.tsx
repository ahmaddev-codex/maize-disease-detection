import React from 'react';
import {createNativeStackNavigator} from '@react-navigation/native-stack';
import TabNavigator from './TabNavigator';
import CameraScreen from '../screens/CameraScreen';
import ResultScreen from '../screens/ResultScreen';
import OcrScreen from '../screens/OcrScreen';
import RecommendationScreen from '../screens/RecommendationScreen';
import SettingsScreen from '../screens/SettingsScreen';
import {Prediction} from '../types/prediction';
import {ScanRecord} from '../types/scanRecord';
import {useAppStore} from '../store/appStore';
import {DarkColors, LightColors} from '../constants/colors';

export type RootStackParamList = {
  Tabs: undefined;
  Camera: undefined;
  Result: {prediction: Prediction; imagePath: string; scanId: number};
  OCR: undefined;
  Recommendation: {scanRecord: ScanRecord};
  Settings: undefined;
};

const Stack = createNativeStackNavigator<RootStackParamList>();

export default function RootNavigator() {
  const isDarkMode = useAppStore(s => s.isDarkMode);
  const C = isDarkMode ? DarkColors : LightColors;

  return (
    <Stack.Navigator
      screenOptions={{
        headerShown: false,
        contentStyle: {backgroundColor: C.canvas},
        animation: 'slide_from_right',
      }}>
      <Stack.Screen name="Tabs" component={TabNavigator} />
      <Stack.Screen
        name="Camera"
        component={CameraScreen}
        options={{animation: 'fade'}}
      />
      <Stack.Screen name="Result" component={ResultScreen} />
      <Stack.Screen name="OCR" component={OcrScreen} />
      <Stack.Screen name="Recommendation" component={RecommendationScreen} />
      <Stack.Screen name="Settings" component={SettingsScreen} />
    </Stack.Navigator>
  );
}
