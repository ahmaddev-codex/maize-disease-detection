import React from 'react';
import {
  Modal,
  View,
  Text,
  ActivityIndicator,
  StyleSheet,
} from 'react-native';
import {useAppStore} from '../store/appStore';
import {DarkColors, LightColors} from '../constants/colors';

interface Props {
  visible: boolean;
}

export default function InferenceDialog({visible}: Props) {
  const isDarkMode = useAppStore(s => s.isDarkMode);
  const C = isDarkMode ? DarkColors : LightColors;

  return (
    <Modal transparent animationType="fade" visible={visible}>
      <View style={styles.overlay}>
        <View style={[styles.card, {backgroundColor: C.surface, borderColor: C.border}]}>
          <ActivityIndicator size="large" color={C.accentEmphasis} />
          <Text style={[styles.title, {color: C.textPrimary}]}>
            Analysing Leaf
          </Text>
          <Text style={[styles.sub, {color: C.textSecondary}]}>
            Running EfficientNetB3 model…
          </Text>
        </View>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  overlay: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.6)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  card: {
    padding: 28,
    borderRadius: 12,
    borderWidth: 1,
    alignItems: 'center',
    minWidth: 200,
  },
  title: {fontSize: 16, fontWeight: '600', marginTop: 16, marginBottom: 4},
  sub: {fontSize: 13},
});
