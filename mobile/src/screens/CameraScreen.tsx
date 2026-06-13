import React, {useRef, useState, useCallback} from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  Alert,
  StatusBar,
} from 'react-native';
import {
  Camera,
  useCameraDevice,
  useFrameProcessor,
} from 'react-native-vision-camera';
import {useNavigation} from '@react-navigation/native';
import {NativeStackNavigationProp} from '@react-navigation/native-stack';
import {Worklets} from 'react-native-worklets-core';
import {Skia} from '@shopify/react-native-skia';
import RNFS from 'react-native-fs';
import Icon from 'react-native-vector-icons/MaterialCommunityIcons';
import {RootStackParamList} from '../navigation/RootNavigator';
import {useAppStore} from '../store/appStore';
import {DarkColors} from '../constants/colors';
import {classify, rgbaToRgb} from '../services/classifier';
import {insertScan} from '../services/database';
import {getCurrentLocation} from '../services/locationService';

type NavProp = NativeStackNavigationProp<RootStackParamList>;
const MODEL_SIZE = 300;
const FRAME_SKIP = 15; // Sample brightness every 15 frames

type BrightnessHint = 'ok' | 'too_dark' | 'too_bright';

export default function CameraScreen() {
  const nav = useNavigation<NavProp>();
  const {pendingLabel} = useAppStore();
  const device = useCameraDevice('back');
  const cameraRef = useRef<Camera>(null);
  const [capturing, setCapturing] = useState(false);
  const [brightnessHint, setBrightnessHint] = useState<BrightnessHint>('ok');
  const frameCounter = useRef(0);

  const setBrightnessJS = Worklets.createRunInJsFn((luma: number) => {
    if (luma < 60) setBrightnessHint('too_dark');
    else if (luma > 200) setBrightnessHint('too_bright');
    else setBrightnessHint('ok');
  });

  const frameProcessor = useFrameProcessor(frame => {
    'worklet';
    frameCounter.value = (frameCounter.value ?? 0) + 1;
    if (frameCounter.value % FRAME_SKIP !== 0) return;

    // Sample Y (luma) plane for brightness estimate
    const yPlane = frame.planes[0];
    if (!yPlane) return;
    const buf = yPlane.buffer;
    const len = buf.byteLength;
    const step = Math.max(1, Math.floor(len / 200));
    let sum = 0;
    let count = 0;
    for (let i = 0; i < len; i += step) {
      sum += buf[i];
      count++;
    }
    setBrightnessJS(count > 0 ? sum / count : 128);
  }, [setBrightnessJS]);

  const frameCounter = useRef({value: 0});

  const handleCapture = useCallback(async () => {
    if (!cameraRef.current || capturing) return;
    setCapturing(true);
    try {
      const photo = await cameraRef.current.takePhoto({
        flash: 'off',
        enableShutterSound: false,
      });

      const imagePath = photo.path;

      // Preprocess + classify
      const base64 = await RNFS.readFile(imagePath, 'base64');
      const skiaData = Skia.Data.fromBase64(base64);
      const skiaImage = Skia.Image.MakeImageFromEncoded(skiaData);
      if (!skiaImage) throw new Error('Decode failed');

      const surface = Skia.Surface.MakeOffscreen(MODEL_SIZE, MODEL_SIZE);
      if (!surface) throw new Error('Surface failed');
      const canvas = surface.getCanvas();
      canvas.drawImageRect(
        skiaImage,
        {x: 0, y: 0, width: skiaImage.width(), height: skiaImage.height()},
        {x: 0, y: 0, width: MODEL_SIZE, height: MODEL_SIZE},
        Skia.Paint(),
      );
      const snapshot = surface.makeImageSnapshot();
      const rgbaBytes = snapshot.readPixels(0, 0, {
        width: MODEL_SIZE,
        height: MODEL_SIZE,
        colorType: 4,
        alphaType: 1,
        colorSpace: Skia.ColorSpace.SRGB,
      });
      if (!rgbaBytes) throw new Error('ReadPixels failed');

      const prediction = await classify(rgbaToRgb(new Uint8Array(rgbaBytes)));
      const location = await getCurrentLocation();
      const scanId = await insertScan(imagePath, prediction, location, pendingLabel);

      nav.replace('Result', {prediction, imagePath, scanId});
    } catch (err) {
      Alert.alert('Error', String(err));
    } finally {
      setCapturing(false);
    }
  }, [capturing, nav, pendingLabel]);

  if (!device) {
    return (
      <View style={[styles.container, styles.center]}>
        <Text style={styles.noCamera}>No camera available</Text>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <StatusBar hidden />
      <Camera
        ref={cameraRef}
        style={StyleSheet.absoluteFill}
        device={device}
        isActive={true}
        photo={true}
        frameProcessor={frameProcessor}
      />

      {/* Viewfinder overlay */}
      <View style={StyleSheet.absoluteFill} pointerEvents="none">
        {/* Dimmed corners */}
        <View style={styles.dimTop} />
        <View style={styles.dimBottom} />
        {/* Frame corners */}
        <View style={styles.frameCornerTL} />
        <View style={styles.frameCornerTR} />
        <View style={styles.frameCornerBL} />
        <View style={styles.frameCornerBR} />
      </View>

      {/* Brightness hint */}
      {brightnessHint !== 'ok' && (
        <View style={styles.hintBanner}>
          <Icon
            name={brightnessHint === 'too_dark' ? 'brightness-4' : 'brightness-7'}
            size={16}
            color="#FFFFFF"
          />
          <Text style={styles.hintText}>
            {brightnessHint === 'too_dark'
              ? 'Too dark — move to better lighting'
              : 'Too bright — avoid direct sunlight'}
          </Text>
        </View>
      )}

      {/* Guide text */}
      <View style={styles.guide} pointerEvents="none">
        <Text style={styles.guideText}>Centre the affected leaf within the frame</Text>
      </View>

      {/* Controls */}
      <View style={styles.controls}>
        <TouchableOpacity style={styles.backBtn} onPress={() => nav.goBack()}>
          <Icon name="arrow-left" size={22} color="#FFFFFF" />
        </TouchableOpacity>
        <TouchableOpacity
          style={[styles.captureBtn, capturing && styles.captureBtnActive]}
          onPress={handleCapture}
          disabled={capturing}>
          <View style={styles.captureInner} />
        </TouchableOpacity>
        <View style={{width: 44}} />
      </View>
    </View>
  );
}

const CORNER = 24;
const BORDER = 3;
const FRAME_SIZE = 260;
const FRAME_TOP = '25%';

const styles = StyleSheet.create({
  container: {flex: 1, backgroundColor: '#000'},
  center: {justifyContent: 'center', alignItems: 'center'},
  noCamera: {color: '#FFF', fontSize: 16},
  dimTop: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    height: FRAME_TOP as any,
    backgroundColor: 'rgba(0,0,0,0.5)',
  },
  dimBottom: {
    position: 'absolute',
    top: `calc(${FRAME_TOP} + ${FRAME_SIZE}px)` as any,
    left: 0,
    right: 0,
    bottom: 0,
    backgroundColor: 'rgba(0,0,0,0.5)',
  },
  frameCornerTL: {
    position: 'absolute',
    top: '25%',
    left: '50%',
    marginLeft: -(FRAME_SIZE / 2),
    width: CORNER,
    height: CORNER,
    borderTopWidth: BORDER,
    borderLeftWidth: BORDER,
    borderColor: '#3FB950',
  },
  frameCornerTR: {
    position: 'absolute',
    top: '25%',
    right: '50%',
    marginRight: -(FRAME_SIZE / 2),
    width: CORNER,
    height: CORNER,
    borderTopWidth: BORDER,
    borderRightWidth: BORDER,
    borderColor: '#3FB950',
  },
  frameCornerBL: {
    position: 'absolute',
    bottom: '35%',
    left: '50%',
    marginLeft: -(FRAME_SIZE / 2),
    width: CORNER,
    height: CORNER,
    borderBottomWidth: BORDER,
    borderLeftWidth: BORDER,
    borderColor: '#3FB950',
  },
  frameCornerBR: {
    position: 'absolute',
    bottom: '35%',
    right: '50%',
    marginRight: -(FRAME_SIZE / 2),
    width: CORNER,
    height: CORNER,
    borderBottomWidth: BORDER,
    borderRightWidth: BORDER,
    borderColor: '#3FB950',
  },
  hintBanner: {
    position: 'absolute',
    top: 60,
    left: 20,
    right: 20,
    backgroundColor: 'rgba(0,0,0,0.75)',
    borderRadius: 8,
    flexDirection: 'row',
    alignItems: 'center',
    padding: 10,
  },
  hintText: {color: '#FFF', fontSize: 13, marginLeft: 8},
  guide: {
    position: 'absolute',
    bottom: 140,
    left: 0,
    right: 0,
    alignItems: 'center',
  },
  guideText: {
    color: 'rgba(255,255,255,0.8)',
    fontSize: 13,
    backgroundColor: 'rgba(0,0,0,0.4)',
    paddingHorizontal: 12,
    paddingVertical: 4,
    borderRadius: 12,
  },
  controls: {
    position: 'absolute',
    bottom: 48,
    left: 0,
    right: 0,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 40,
  },
  backBtn: {
    width: 44,
    height: 44,
    borderRadius: 22,
    backgroundColor: 'rgba(0,0,0,0.5)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  captureBtn: {
    width: 72,
    height: 72,
    borderRadius: 36,
    borderWidth: 4,
    borderColor: '#FFF',
    justifyContent: 'center',
    alignItems: 'center',
  },
  captureBtnActive: {borderColor: '#3FB950'},
  captureInner: {
    width: 56,
    height: 56,
    borderRadius: 28,
    backgroundColor: '#FFF',
  },
});
