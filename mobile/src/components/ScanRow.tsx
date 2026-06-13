import React from 'react';
import {
  View,
  Text,
  Image,
  TouchableOpacity,
  StyleSheet,
} from 'react-native';
import Icon from 'react-native-vector-icons/MaterialCommunityIcons';
import {ScanRecord} from '../types/scanRecord';
import {getDiseaseInfo} from '../constants/diseases';
import {useAppStore} from '../store/appStore';
import {DarkColors, LightColors} from '../constants/colors';
import GhLabel from './GhLabel';
import {format} from 'date-fns';

interface Props {
  scan: ScanRecord;
  onPress: () => void;
  onDelete: () => void;
}

export default function ScanRow({scan, onPress, onDelete}: Props) {
  const isDarkMode = useAppStore(s => s.isDarkMode);
  const C = isDarkMode ? DarkColors : LightColors;
  const disease = getDiseaseInfo(scan.classId);

  return (
    <TouchableOpacity
      activeOpacity={0.8}
      onPress={onPress}
      style={[styles.row, {backgroundColor: C.surface, borderBottomColor: C.border}]}>
      <Image
        source={{uri: `file://${scan.imagePath}`}}
        style={styles.thumb}
        resizeMode="cover"
      />
      <View style={styles.info}>
        <View style={styles.topRow}>
          <GhLabel text={scan.shortName} color={disease.color} />
          {scan.latitude != null && (
            <Icon name="map-marker" size={12} color={C.textMuted} style={styles.gpsIcon} />
          )}
        </View>
        <Text style={[styles.date, {color: C.textSecondary}]}>
          {format(new Date(scan.scannedAt), 'MMM d, yyyy · HH:mm')}
        </Text>
        {scan.cropVariety && (
          <Text style={[styles.variety, {color: C.textMuted}]}>
            {scan.cropVariety}
          </Text>
        )}
      </View>
      <Text style={[styles.confidence, {color: disease.color}]}>
        {Math.round(scan.confidence * 100)}%
      </Text>
      <TouchableOpacity onPress={onDelete} hitSlop={{top: 12, bottom: 12, left: 12, right: 12}}>
        <Icon name="trash-can-outline" size={18} color={C.textMuted} />
      </TouchableOpacity>
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingVertical: 12,
    borderBottomWidth: StyleSheet.hairlineWidth,
  },
  thumb: {width: 48, height: 48, borderRadius: 6, marginRight: 12},
  info: {flex: 1},
  topRow: {flexDirection: 'row', alignItems: 'center', marginBottom: 4},
  gpsIcon: {marginLeft: 6},
  date: {fontSize: 12, marginBottom: 2},
  variety: {fontSize: 11},
  confidence: {fontSize: 14, fontWeight: '700', marginHorizontal: 12},
});
