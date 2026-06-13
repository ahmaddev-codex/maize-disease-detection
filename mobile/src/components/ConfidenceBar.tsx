import React, {useEffect, useRef} from 'react';
import {View, Text, Animated, StyleSheet} from 'react-native';
import {useAppStore} from '../store/appStore';
import {DarkColors, LightColors} from '../constants/colors';

interface Props {
  label: string;
  score: number;
  color: string;
  isTop?: boolean;
}

export default function ConfidenceBar({label, score, color, isTop}: Props) {
  const isDarkMode = useAppStore(s => s.isDarkMode);
  const C = isDarkMode ? DarkColors : LightColors;
  const anim = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    Animated.timing(anim, {
      toValue: score,
      duration: 700,
      useNativeDriver: false,
    }).start();
  }, [score, anim]);

  const widthPct = anim.interpolate({
    inputRange: [0, 1],
    outputRange: ['0%', '100%'],
  });

  return (
    <View style={styles.row}>
      <Text
        style={[
          styles.label,
          {color: isTop ? C.textPrimary : C.textSecondary},
        ]}>
        {label}
      </Text>
      <View style={[styles.track, {backgroundColor: C.borderMuted}]}>
        <Animated.View
          style={[styles.fill, {width: widthPct, backgroundColor: color}]}
        />
      </View>
      <Text style={[styles.pct, {color: C.textSecondary}]}>
        {Math.round(score * 100)}%
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  row: {flexDirection: 'row', alignItems: 'center', marginVertical: 4},
  label: {width: 72, fontSize: 12, fontWeight: '500'},
  track: {flex: 1, height: 6, borderRadius: 3, overflow: 'hidden', marginHorizontal: 8},
  fill: {height: '100%', borderRadius: 3},
  pct: {width: 40, fontSize: 12, textAlign: 'right'},
});
