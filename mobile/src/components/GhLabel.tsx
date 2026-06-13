import React from 'react';
import {View, Text, StyleSheet} from 'react-native';

interface Props {
  text: string;
  color: string;
}

export default function GhLabel({text, color}: Props) {
  return (
    <View style={[styles.badge, {borderColor: color, backgroundColor: `${color}22`}]}>
      <Text style={[styles.text, {color}]}>{text}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  badge: {
    paddingHorizontal: 8,
    paddingVertical: 3,
    borderRadius: 12,
    borderWidth: 1,
    alignSelf: 'flex-start',
  },
  text: {fontSize: 11, fontWeight: '600'},
});
