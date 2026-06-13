import React, {useState} from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
  Alert,
  StatusBar,
} from 'react-native';
import {useNavigation} from '@react-navigation/native';
import {NativeStackNavigationProp} from '@react-navigation/native-stack';
import {launchImageLibrary} from 'react-native-image-picker';
import {Skia} from '@shopify/react-native-skia';
import RNFS from 'react-native-fs';
import Icon from 'react-native-vector-icons/MaterialCommunityIcons';
import {RootStackParamList} from '../navigation/RootNavigator';
import {useAppStore} from '../store/appStore';
import {DarkColors, LightColors} from '../constants/colors';
import {classify, rgbaToRgb} from '../services/classifier';
import {insertScan} from '../services/database';
import {getCurrentLocation, requestLocationPermission} from '../services/locationService';
import {useRecentScans} from '../hooks/useScans';
import InferenceDialog from '../components/InferenceDialog';
import GhButton from '../components/GhButton';
import ScanRow from '../components/ScanRow';
import {deleteScan} from '../services/database';

type NavProp = NativeStackNavigationProp<RootStackParamList>;

const MODEL_SIZE = 300;

export default function HomeScreen() {
  const nav = useNavigation<NavProp>();
  const isDarkMode = useAppStore(s => s.isDarkMode);
  const {modelState, pendingLabel} = useAppStore();
  const C = isDarkMode ? DarkColors : LightColors;
  const [inferring, setInferring] = useState(false);
  const [refreshKey, setRefreshKey] = useState(0);
  const {scans, loading} = useRecentScans(5, refreshKey);

  async function handleGallery() {
    const result = await launchImageLibrary({
      mediaType: 'photo',
      quality: 1,
    });
    if (result.didCancel || !result.assets?.[0]?.uri) return;
    await runClassify(result.assets[0].uri.replace('file://', ''));
  }

  async function runClassify(imagePath: string) {
    if (modelState !== 'ready') {
      Alert.alert('Model Loading', 'Please wait for the model to load.');
      return;
    }
    setInferring(true);
    try {
      // Read image bytes as base64, decode with Skia
      const base64 = await RNFS.readFile(imagePath, 'base64');
      const skiaData = Skia.Data.fromBase64(base64);
      const skiaImage = Skia.Image.MakeImageFromEncoded(skiaData);
      if (!skiaImage) throw new Error('Failed to decode image');

      // Draw onto 300×300 offscreen surface
      const surface = Skia.Surface.MakeOffscreen(MODEL_SIZE, MODEL_SIZE);
      if (!surface) throw new Error('Failed to create Skia surface');
      const canvas = surface.getCanvas();
      const paint = Skia.Paint();
      canvas.drawImageRect(
        skiaImage,
        {x: 0, y: 0, width: skiaImage.width(), height: skiaImage.height()},
        {x: 0, y: 0, width: MODEL_SIZE, height: MODEL_SIZE},
        paint,
      );
      const snapshot = surface.makeImageSnapshot();
      const rgbaBytes = snapshot.readPixels(0, 0, {
        width: MODEL_SIZE,
        height: MODEL_SIZE,
        colorType: 4, // RGBA_8888
        alphaType: 1,
        colorSpace: Skia.ColorSpace.SRGB,
      });
      if (!rgbaBytes) throw new Error('Failed to read pixels');

      const rgbBytes = rgbaToRgb(new Uint8Array(rgbaBytes));
      const prediction = await classify(rgbBytes);

      // Geo-tag
      await requestLocationPermission();
      const location = await getCurrentLocation();

      // Persist
      const scanId = await insertScan(imagePath, prediction, location, pendingLabel);
      setRefreshKey(k => k + 1);

      nav.navigate('Result', {prediction, imagePath, scanId});
    } catch (err) {
      Alert.alert('Inference Error', String(err));
    } finally {
      setInferring(false);
    }
  }

  const modelStatusColor =
    modelState === 'ready'
      ? C.successFg
      : modelState === 'error'
      ? C.dangerFg
      : C.attentionFg;

  return (
    <View style={[styles.container, {backgroundColor: C.canvas}]}>
      <StatusBar
        barStyle={isDarkMode ? 'light-content' : 'dark-content'}
        backgroundColor={C.canvas}
      />
      <ScrollView contentContainerStyle={styles.scroll}>
        {/* Header */}
        <View style={styles.header}>
          <View>
            <Text style={[styles.title, {color: C.textPrimary}]}>MaizeGuard</Text>
            <View style={styles.statusRow}>
              <View style={[styles.dot, {backgroundColor: modelStatusColor}]} />
              <Text style={[styles.statusText, {color: C.textSecondary}]}>
                {modelState === 'ready'
                  ? 'EfficientNetB3 ready'
                  : modelState === 'loading'
                  ? 'Loading model…'
                  : modelState === 'error'
                  ? 'Model error'
                  : 'Initialising…'}
              </Text>
            </View>
          </View>
          <TouchableOpacity onPress={() => nav.navigate('Settings')}>
            <Icon name="cog-outline" size={24} color={C.textSecondary} />
          </TouchableOpacity>
        </View>

        {/* Hero action card */}
        <View style={[styles.card, {backgroundColor: C.surface, borderColor: C.border}]}>
          <Icon name="leaf-circle" size={48} color={C.successEmphasis} />
          <Text style={[styles.cardTitle, {color: C.textPrimary}]}>
            Scan Maize Leaf
          </Text>
          <Text style={[styles.cardSub, {color: C.textSecondary}]}>
            Point camera at a maize leaf or upload a photo to detect{'\n'}
            NCLB · Rust · Gray Leaf Spot
          </Text>
          <View style={styles.actions}>
            <GhButton
              label="Open Camera"
              icon="camera"
              variant="primary"
              onPress={() => nav.navigate('Camera')}
              disabled={modelState !== 'ready'}
              style={styles.actionBtn}
            />
            <GhButton
              label="From Gallery"
              icon="image"
              onPress={handleGallery}
              disabled={modelState !== 'ready'}
              style={styles.actionBtn}
            />
          </View>
          <TouchableOpacity
            style={styles.ocrRow}
            onPress={() => nav.navigate('OCR')}>
            <Icon name="text-recognition" size={16} color={C.accentFg} />
            <Text style={[styles.ocrText, {color: C.accentFg}]}>
              Scan seed label first (optional)
            </Text>
            {pendingLabel && (
              <View style={[styles.pendingDot, {backgroundColor: C.successFg}]} />
            )}
          </TouchableOpacity>
        </View>

        {/* Recent scans */}
        {scans.length > 0 && (
          <View style={[styles.section, {backgroundColor: C.surface, borderColor: C.border}]}>
            <Text style={[styles.sectionTitle, {color: C.textSecondary}]}>
              RECENT SCANS
            </Text>
            {scans.map(scan => (
              <ScanRow
                key={scan.id}
                scan={scan}
                onPress={() =>
                  nav.navigate('Recommendation', {scanRecord: scan})
                }
                onDelete={async () => {
                  await deleteScan(scan.id);
                  setRefreshKey(k => k + 1);
                }}
              />
            ))}
          </View>
        )}
      </ScrollView>
      <InferenceDialog visible={inferring} />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {flex: 1},
  scroll: {padding: 16, paddingBottom: 32},
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    marginBottom: 20,
  },
  title: {fontSize: 22, fontWeight: '700', marginBottom: 4},
  statusRow: {flexDirection: 'row', alignItems: 'center'},
  dot: {width: 8, height: 8, borderRadius: 4, marginRight: 6},
  statusText: {fontSize: 12},
  card: {
    borderRadius: 12,
    borderWidth: 1,
    padding: 24,
    alignItems: 'center',
    marginBottom: 20,
  },
  cardTitle: {fontSize: 20, fontWeight: '700', marginTop: 12, marginBottom: 8},
  cardSub: {fontSize: 13, textAlign: 'center', lineHeight: 20, marginBottom: 20},
  actions: {flexDirection: 'row', gap: 10, marginBottom: 16},
  actionBtn: {flex: 1},
  ocrRow: {flexDirection: 'row', alignItems: 'center'},
  ocrText: {fontSize: 13, marginLeft: 6},
  pendingDot: {width: 8, height: 8, borderRadius: 4, marginLeft: 6},
  section: {borderRadius: 12, borderWidth: 1, overflow: 'hidden'},
  sectionTitle: {
    fontSize: 11,
    fontWeight: '600',
    letterSpacing: 0.8,
    paddingHorizontal: 16,
    paddingTop: 12,
    paddingBottom: 8,
  },
});
