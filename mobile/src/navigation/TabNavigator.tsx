import React from 'react';
import {createBottomTabNavigator} from '@react-navigation/bottom-tabs';
import Icon from 'react-native-vector-icons/MaterialCommunityIcons';
import {useAppStore} from '../store/appStore';
import {DarkColors, LightColors} from '../constants/colors';
import HomeScreen from '../screens/HomeScreen';
import DashboardScreen from '../screens/DashboardScreen';
import HistoryScreen from '../screens/HistoryScreen';
import MapScreen from '../screens/MapScreen';

export type TabParamList = {
  Home: undefined;
  Dashboard: undefined;
  History: undefined;
  Map: undefined;
};

const Tab = createBottomTabNavigator<TabParamList>();

export default function TabNavigator() {
  const isDarkMode = useAppStore(s => s.isDarkMode);
  const C = isDarkMode ? DarkColors : LightColors;

  return (
    <Tab.Navigator
      screenOptions={({route}) => ({
        headerShown: false,
        tabBarStyle: {
          backgroundColor: C.surface,
          borderTopColor: C.border,
          borderTopWidth: 1,
          height: 60,
          paddingBottom: 8,
        },
        tabBarActiveTintColor: C.accentEmphasis,
        tabBarInactiveTintColor: C.textSecondary,
        tabBarLabelStyle: {fontSize: 11, fontWeight: '500'},
        tabBarIcon: ({color, size}) => {
          const icons: Record<string, string> = {
            Home: 'leaf',
            Dashboard: 'chart-bar',
            History: 'history',
            Map: 'map-marker-multiple',
          };
          return <Icon name={icons[route.name]} color={color} size={size} />;
        },
      })}>
      <Tab.Screen
        name="Home"
        component={HomeScreen}
        options={{tabBarLabel: 'Scan'}}
      />
      <Tab.Screen
        name="Dashboard"
        component={DashboardScreen}
        options={{tabBarLabel: 'Overview'}}
      />
      <Tab.Screen
        name="History"
        component={HistoryScreen}
        options={{tabBarLabel: 'History'}}
      />
      <Tab.Screen
        name="Map"
        component={MapScreen}
        options={{tabBarLabel: 'Farm Map'}}
      />
    </Tab.Navigator>
  );
}
