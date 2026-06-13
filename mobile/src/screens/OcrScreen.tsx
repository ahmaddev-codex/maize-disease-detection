import React, {useRef, useState} from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  ScrollView,
  Alert,
} from 'react-native';
import {Camera, useCameraDevice} from 'react-native-vision-camera';
import {useNavigation} from '@react-navigation/native';
import Icon from 'react-native-vector-icons/MaterialCommunityIcons';
import {useAppStore} from '../store/appStore';
import {DarkColors, LightColors} from '../constants/colors';
import {recognizeText} from '../services/ocrService';
import GhButton from '../components/GhButton';
import GhLabel from '../components/GhLabel';

export default function OcrScreen() {
  const nav = useNavigation();
  const {setPendingLabel} = useAppStore();
  const isDarkMode = useAppStore(s => s.isDarkMode);
  const C = isDarkMode ? DarkColors : LightColors;
  const device = useCameraDevice('back');
  const cameraRef = useRef<Camera>(null);
  const [scanning, setScanning] = useState(false);
  const [result, setResult] = useState<{
    cropVariety: string | null;
    batchNumber: string | null;
    plantingDate: string | null;
    rawText: string;
  } | null>(null);

  async function handleScan() {
    if (!cameraRef.current || scanning) return;
    setScanning(true);
    try {
      const photo = await cameraRef.current.takePhoto({flash: 'off'});
      const labelData = await recognizeText(photo.path);
      setResult(labelData);
    } catch (err) {
      Alert.alert('OCR Error', String(err));
    } finally {
      setScanning(false);
    }
  }

  function handleConfirm() {
    if (!result) return;
    setPendingLabel(result);
    nav.goBack();
  }

  function handleClear() {
    setPendingLabel(null);
    nav.goBack();
  }

  return (
    <View style={[styles.container, {backgroundColor: C.canvas}]}>
      {/* Header */}
      <View style={[styles.header, {backgroundColor: C.surface, borderBottomColor: C.border}]}>
        <TouchableOpacity onPress={() => nav.goBack()}>
          <Icon name="arrow-left" size={22} color={C.textPrimary} />
        </TouchableOpacity>
        <Text style={[styles.headerTitle, {color: C.textPrimary}]}>
          Scan Seed Label
        </Text>
        <View style={{width: 22}} />
      </View>

      {!result ? (
        <>
          {device ? (
            <Camera
              ref={cameraRef}
              style={styles.camera}
              device={device}
              isActive={true}
              photo={true}
            />
          ) : (
            <View style={[styles.camera, styles.center]}>
              <Text style={{color: C.textSecondary}}>No camera</Text>
            </View>
          )}

          <View style={[styles.bottomPanel, {backgroundColor: C.surface}]}>
            <Text style={[styles.instruction, {color: C.textSecondary}]}>
              Point camera at the seed bag label and tap Scan
            </Text>
            <GhButton
              label={scanning ? 'Scanning…' : 'Scan Label'}
              icon="text-recognition"
              variant="primary"
              onPress={handleScan}
              loading={scanning}
            />
          </View>
        </>
      ) : (
        <ScrollView contentContainerStyle={styles.resultScroll}>
          <View style={[styles.card, {backgroundColor: C.surface, borderColor: C.border}]}>
            <Text style={[styles.cardTitle, {color: C.textSecondary}]}>
              EXTRACTED FIELDS
            </Text>

            <Field
              label="Crop Variety"
              value={result.cropVariety}
              color={C.accentFg}
              fallback="Not detected"
              C={C}
            />
            <Field
              label="Batch Number"
              value={result.batchNumber}
              color={C.attentionFg}
              fallback="Not detected"
              C={C}
            />
            <Field
              label="Planting Date"
              value={result.plantingDate}
              color={C.successFg}
              fallback="Not detected"
              C={C}
            />
          </View>

          <View style={[styles.card, {backgroundColor: C.surface, borderColor: C.border}]}>
            <Text style={[styles.cardTitle, {color: C.textSecondary}]}>
              RAW OCR TEXT
            </Text>
            <Text style={[styles.rawText, {color: C.textSecondary}]}>
              {result.rawText || 'No text detected'}
            </Text>
          </View>

          <View style={styles.actions}>
            <GhButton
              label="Use This Label"
              icon="check"
              variant="primary"
              onPress={handleConfirm}
              style={styles.actionBtn}
            />
            <GhButton
              label="Rescan"
              icon="refresh"
              onPress={() => setResult(null)}
              style={styles.actionBtn}
            />
          </View>
          <TouchableOpacity style={styles.skipRow} onPress={handleClear}>
            <Text style={[styles.skipText, {color: C.textMuted}]}>
              Skip — scan without label
            </Text>
          </TouchableOpacity>
        </ScrollView>
      )}
    </View>
  );
}

function Field({
  label,
  value,
  color,
  fallback,
  C,
}: {
  label: string;
  value: string | null;
  color: string;
  fallback: string;
  C: typeof DarkColors;
}) {
  return (
    <View style={fieldStyles.row}>
      <Text style={[fieldStyles.label, {color: C.textSecondary}]}>{label}</Text>
      {value ? (
        <GhLabel text={value} color={color} />
      ) : (
        <Text style={[fieldStyles.fallback, {color: C.textMuted}]}>{fallback}</Text>
      )}
    </View>
  );
}

const fieldStyles = StyleSheet.create({
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingVertical: 10,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: '#30363D',
  },
  label: {fontSize: 13, fontWeight: '500'},
  fallback: {fontSize: 13, fontStyle: 'italic'},
});

const styles = StyleSheet.create({
  container: {flex: 1},
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 16,
    paddingVertical: 14,
    borderBottomWidth: StyleSheet.hairlineWidth,
  },
  headerTitle: {fontSize: 16, fontWeight: '600'},
  camera: {flex: 1},
  center: {justifyContent: 'center', alignItems: 'center'},
  bottomPanel: {
    padding: 20,
    paddingBottom: 36,
  },
  instruction: {fontSize: 13, textAlign: 'center', marginBottom: 16},
  resultScroll: {padding: 16, paddingBottom: 40},
  card: {
    borderRadius: 12,
    borderWidth: 1,
    padding: 16,
    marginBottom: 12,
  },
  cardTitle: {
    fontSize: 11,
    fontWeight: '600',
    letterSpacing: 0.8,
    marginBottom: 12,
  },
  rawText: {fontSize: 12, lineHeight: 18, fontFamily: 'monospace'},
  actions: {flexDirection: 'row', gap: 10, marginBottom: 16},
  actionBtn: {flex: 1},
  skipRow: {alignItems: 'center'},
  skipText: {fontSize: 13},
});
