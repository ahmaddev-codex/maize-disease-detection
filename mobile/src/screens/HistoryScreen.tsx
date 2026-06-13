import React, {useState} from 'react';
import {
  View,
  Text,
  FlatList,
  StyleSheet,
  TouchableOpacity,
  Alert,
} from 'react-native';
import {useNavigation} from '@react-navigation/native';
import {NativeStackNavigationProp} from '@react-navigation/native-stack';
import Icon from 'react-native-vector-icons/MaterialCommunityIcons';
import {RootStackParamList} from '../navigation/RootNavigator';
import {useAppStore} from '../store/appStore';
import {DarkColors, LightColors} from '../constants/colors';
import {DISEASE_INFO} from '../constants/diseases';
import {deleteScan} from '../services/database';
import {useAllScans} from '../hooks/useScans';
import ScanRow from '../components/ScanRow';
import {ScanRecord} from '../types/scanRecord';

type NavProp = NativeStackNavigationProp<RootStackParamList>;

type Filter = 'all' | 0 | 1 | 2 | 3;

const FILTERS: {label: string; value: Filter}[] = [
  {label: 'All', value: 'all'},
  {label: 'NCLB', value: 0},
  {label: 'Rust', value: 1},
  {label: 'GLS', value: 2},
  {label: 'Healthy', value: 3},
];

export default function HistoryScreen() {
  const nav = useNavigation<NavProp>();
  const isDarkMode = useAppStore(s => s.isDarkMode);
  const C = isDarkMode ? DarkColors : LightColors;
  const [filter, setFilter] = useState<Filter>('all');
  const [refreshKey, setRefreshKey] = useState(0);
  const {scans, loading} = useAllScans(refreshKey);

  const filtered =
    filter === 'all' ? scans : scans.filter(s => s.classId === filter);

  async function handleDelete(scan: ScanRecord) {
    Alert.alert(
      'Delete Scan',
      `Remove this ${scan.shortName} scan from history?`,
      [
        {text: 'Cancel', style: 'cancel'},
        {
          text: 'Delete',
          style: 'destructive',
          onPress: async () => {
            await deleteScan(scan.id);
            setRefreshKey(k => k + 1);
          },
        },
      ],
    );
  }

  return (
    <View style={[styles.container, {backgroundColor: C.canvas}]}>
      {/* Header */}
      <View style={[styles.header, {backgroundColor: C.surface, borderBottomColor: C.border}]}>
        <Text style={[styles.title, {color: C.textPrimary}]}>Scan History</Text>
        <Text style={[styles.count, {color: C.textSecondary}]}>
          {filtered.length} records
        </Text>
      </View>

      {/* Filter chips */}
      <View style={[styles.filterRow, {backgroundColor: C.surface, borderBottomColor: C.border}]}>
        {FILTERS.map(f => {
          const isActive = filter === f.value;
          const diseaseColor =
            typeof f.value === 'number'
              ? DISEASE_INFO[f.value].color
              : C.accentEmphasis;
          return (
            <TouchableOpacity
              key={String(f.value)}
              onPress={() => setFilter(f.value)}
              style={[
                styles.chip,
                {
                  backgroundColor: isActive ? `${diseaseColor}22` : C.surfaceOverlay,
                  borderColor: isActive ? diseaseColor : C.border,
                },
              ]}>
              <Text
                style={[
                  styles.chipText,
                  {color: isActive ? diseaseColor : C.textSecondary},
                ]}>
                {f.label}
              </Text>
            </TouchableOpacity>
          );
        })}
      </View>

      {loading ? (
        <View style={styles.center}>
          <Text style={[styles.empty, {color: C.textMuted}]}>Loading…</Text>
        </View>
      ) : filtered.length === 0 ? (
        <View style={styles.center}>
          <Icon name="history" size={48} color={C.borderMuted} />
          <Text style={[styles.empty, {color: C.textMuted}]}>No scans yet</Text>
          <Text style={[styles.emptySub, {color: C.textMuted}]}>
            Scans will appear here after you analyse a leaf
          </Text>
        </View>
      ) : (
        <FlatList
          data={filtered}
          keyExtractor={item => String(item.id)}
          renderItem={({item}) => (
            <ScanRow
              scan={item}
              onPress={() => nav.navigate('Recommendation', {scanRecord: item})}
              onDelete={() => handleDelete(item)}
            />
          )}
          contentContainerStyle={styles.list}
        />
      )}
    </View>
  );
}

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
  title: {fontSize: 18, fontWeight: '700'},
  count: {fontSize: 13},
  filterRow: {
    flexDirection: 'row',
    paddingHorizontal: 12,
    paddingVertical: 10,
    gap: 8,
    borderBottomWidth: StyleSheet.hairlineWidth,
  },
  chip: {
    paddingHorizontal: 10,
    paddingVertical: 5,
    borderRadius: 12,
    borderWidth: 1,
  },
  chipText: {fontSize: 12, fontWeight: '500'},
  list: {paddingBottom: 24},
  center: {flex: 1, justifyContent: 'center', alignItems: 'center'},
  empty: {fontSize: 16, marginTop: 12, fontWeight: '500'},
  emptySub: {fontSize: 13, marginTop: 4, textAlign: 'center', paddingHorizontal: 32},
});
