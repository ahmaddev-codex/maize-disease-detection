import React, {useState, useCallback} from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  Modal,
  ScrollView,
} from 'react-native';
import MapView, {Marker, UrlTile, PROVIDER_DEFAULT} from 'react-native-maps';
import {useFocusEffect} from '@react-navigation/native';
import Icon from 'react-native-vector-icons/MaterialCommunityIcons';
import {useAppStore} from '../store/appStore';
import {DarkColors, LightColors} from '../constants/colors';
import {allScans} from '../services/database';
import {getDiseaseInfo} from '../constants/diseases';
import {ScanRecord} from '../types/scanRecord';
import GhLabel from '../components/GhLabel';
import {format} from 'date-fns';

export default function MapScreen() {
  const isDarkMode = useAppStore(s => s.isDarkMode);
  const C = isDarkMode ? DarkColors : LightColors;
  const [scans, setScans] = useState<ScanRecord[]>([]);
  const [selected, setSelected] = useState<ScanRecord | null>(null);

  useFocusEffect(
    useCallback(() => {
      allScans().then(data =>
        setScans(data.filter(s => s.latitude != null && s.longitude != null)),
      );
    }, []),
  );

  const geoScans = scans.filter(s => s.latitude != null && s.longitude != null);

  const initialRegion =
    geoScans.length > 0
      ? {
          latitude: geoScans[0].latitude!,
          longitude: geoScans[0].longitude!,
          latitudeDelta: 0.05,
          longitudeDelta: 0.05,
        }
      : {
          // Default: Abuja, Nigeria
          latitude: 9.0765,
          longitude: 7.3986,
          latitudeDelta: 0.5,
          longitudeDelta: 0.5,
        };

  return (
    <View style={styles.container}>
      <MapView
        style={StyleSheet.absoluteFill}
        provider={PROVIDER_DEFAULT}
        initialRegion={initialRegion}
        mapType="standard">
        {/* OpenStreetMap tile layer */}
        <UrlTile
          urlTemplate="https://tile.openstreetmap.org/{z}/{x}/{y}.png"
          maximumZ={19}
          flipY={false}
        />
        {geoScans.map(scan => {
          const disease = getDiseaseInfo(scan.classId);
          return (
            <Marker
              key={scan.id}
              coordinate={{
                latitude: scan.latitude!,
                longitude: scan.longitude!,
              }}
              onPress={() => setSelected(scan)}>
              <View
                style={[styles.markerOuter, {borderColor: disease.color}]}>
                <View
                  style={[styles.markerInner, {backgroundColor: disease.color}]}
                />
              </View>
            </Marker>
          );
        })}
      </MapView>

      {/* Header overlay */}
      <View style={[styles.headerOverlay, {backgroundColor: `${C.surface}EE`, borderColor: C.border}]}>
        <Text style={[styles.headerTitle, {color: C.textPrimary}]}>Farm Disease Map</Text>
        <Text style={[styles.headerSub, {color: C.textSecondary}]}>
          {geoScans.length} GPS-tagged scans
        </Text>
      </View>

      {/* Empty state */}
      {geoScans.length === 0 && (
        <View style={[styles.emptyOverlay, {backgroundColor: `${C.surface}CC`}]}>
          <Icon name="map-marker-off" size={40} color={C.textMuted} />
          <Text style={[styles.emptyText, {color: C.textSecondary}]}>
            No GPS-tagged scans yet
          </Text>
          <Text style={[styles.emptySub, {color: C.textMuted}]}>
            Enable location access when scanning to see disease markers here
          </Text>
        </View>
      )}

      {/* Scan detail bottom sheet */}
      <Modal
        visible={selected != null}
        transparent
        animationType="slide"
        onRequestClose={() => setSelected(null)}>
        <TouchableOpacity
          style={styles.modalOverlay}
          activeOpacity={1}
          onPress={() => setSelected(null)}
        />
        {selected && (
          <View style={[styles.sheet, {backgroundColor: C.surface, borderTopColor: C.border}]}>
            <View style={styles.sheetHandle} />
            <View style={styles.sheetHeader}>
              <GhLabel
                text={selected.shortName}
                color={getDiseaseInfo(selected.classId).color}
              />
              <TouchableOpacity onPress={() => setSelected(null)}>
                <Icon name="close" size={20} color={C.textSecondary} />
              </TouchableOpacity>
            </View>
            <Text style={[styles.sheetDisease, {color: C.textPrimary}]}>
              {getDiseaseInfo(selected.classId).fullName}
            </Text>
            <Text style={[styles.sheetDate, {color: C.textSecondary}]}>
              {format(new Date(selected.scannedAt), 'MMMM d, yyyy · HH:mm')}
            </Text>
            <Text style={[styles.sheetConf, {color: getDiseaseInfo(selected.classId).color}]}>
              {Math.round(selected.confidence * 100)}% confidence
            </Text>
            {selected.latitude && (
              <Text style={[styles.sheetCoords, {color: C.textMuted}]}>
                {selected.latitude.toFixed(5)}, {selected.longitude?.toFixed(5)}
              </Text>
            )}
          </View>
        )}
      </Modal>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {flex: 1},
  headerOverlay: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    padding: 16,
    paddingTop: 52,
    borderBottomWidth: StyleSheet.hairlineWidth,
  },
  headerTitle: {fontSize: 18, fontWeight: '700'},
  headerSub: {fontSize: 13, marginTop: 2},
  markerOuter: {
    width: 20,
    height: 20,
    borderRadius: 10,
    borderWidth: 2,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: 'rgba(0,0,0,0.3)',
  },
  markerInner: {width: 8, height: 8, borderRadius: 4},
  emptyOverlay: {
    position: 'absolute',
    top: '40%',
    left: 24,
    right: 24,
    borderRadius: 16,
    padding: 24,
    alignItems: 'center',
  },
  emptyText: {fontSize: 16, fontWeight: '600', marginTop: 12, marginBottom: 6},
  emptySub: {fontSize: 13, textAlign: 'center', lineHeight: 20},
  modalOverlay: {flex: 1},
  sheet: {
    paddingHorizontal: 20,
    paddingBottom: 36,
    paddingTop: 12,
    borderTopLeftRadius: 20,
    borderTopRightRadius: 20,
    borderTopWidth: StyleSheet.hairlineWidth,
  },
  sheetHandle: {
    width: 36,
    height: 4,
    borderRadius: 2,
    backgroundColor: '#666',
    alignSelf: 'center',
    marginBottom: 16,
  },
  sheetHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 8,
  },
  sheetDisease: {fontSize: 16, fontWeight: '600', marginBottom: 4},
  sheetDate: {fontSize: 13, marginBottom: 4},
  sheetConf: {fontSize: 14, fontWeight: '700', marginBottom: 4},
  sheetCoords: {fontSize: 11, fontFamily: 'monospace'},
});
