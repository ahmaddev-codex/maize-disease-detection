import React, {useEffect, useState} from 'react';
import {
  View,
  Text,
  ScrollView,
  StyleSheet,
  TouchableOpacity,
  ActivityIndicator,
} from 'react-native';
import {useRoute, useNavigation, RouteProp} from '@react-navigation/native';
import Icon from 'react-native-vector-icons/MaterialCommunityIcons';
import {RootStackParamList} from '../navigation/RootNavigator';
import {useAppStore} from '../store/appStore';
import {DarkColors, LightColors} from '../constants/colors';
import {getDiseaseInfo} from '../constants/diseases';
import {getAiAdvice} from '../services/aiAdvisor';
import {recentScans} from '../services/database';
import {ScanRecord} from '../types/scanRecord';
import GhLabel from '../components/GhLabel';

type RouteType = RouteProp<RootStackParamList, 'Recommendation'>;

export default function RecommendationScreen() {
  const route = useRoute<RouteType>();
  const nav = useNavigation();
  const {scanRecord} = route.params;
  const {geminiApiKey} = useAppStore();
  const isDarkMode = useAppStore(s => s.isDarkMode);
  const C = isDarkMode ? DarkColors : LightColors;
  const disease = getDiseaseInfo(scanRecord.classId);

  const [advice, setAdvice] = useState<string | null>(null);
  const [isAi, setIsAi] = useState(false);
  const [loading, setLoading] = useState(true);
  const [history, setHistory] = useState<ScanRecord[]>([]);

  useEffect(() => {
    recentScans(20).then(setHistory);
  }, []);

  useEffect(() => {
    if (history.length === 0 && loading) {
      // Wait for history to load first
      return;
    }
    const prediction = {
      classId: scanRecord.classId,
      className: scanRecord.className,
      shortName: scanRecord.shortName,
      confidence: scanRecord.confidence,
      allScores: scanRecord.allScores,
      latencyMs: scanRecord.latencyMs,
    };
    setLoading(true);
    getAiAdvice(prediction, history, geminiApiKey)
      .then(result => {
        setAdvice(result.text);
        setIsAi(result.isAi);
      })
      .finally(() => setLoading(false));
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [history]);

  return (
    <View style={[styles.container, {backgroundColor: C.canvas}]}>
      <View style={[styles.header, {backgroundColor: C.surface, borderBottomColor: C.border}]}>
        <TouchableOpacity onPress={() => nav.goBack()}>
          <Icon name="arrow-left" size={22} color={C.textPrimary} />
        </TouchableOpacity>
        <Text style={[styles.headerTitle, {color: C.textPrimary}]}>
          Agronomic Advice
        </Text>
        <View style={{width: 22}} />
      </View>

      <ScrollView contentContainerStyle={styles.scroll}>
        {/* Scan summary card */}
        <View
          style={[
            styles.summaryCard,
            {
              backgroundColor: C.surface,
              borderColor: disease.color,
              borderLeftWidth: 4,
            },
          ]}>
          <View style={styles.summaryTop}>
            <GhLabel text={scanRecord.shortName} color={disease.color} />
            <View style={styles.sourceRow}>
              <Icon
                name={isAi ? 'robot' : 'cpu-64-bit'}
                size={14}
                color={isAi ? C.accentFg : C.textMuted}
              />
              <Text style={[styles.sourceLabel, {color: isAi ? C.accentFg : C.textMuted}]}>
                {isAi ? 'Gemini AI' : 'On-device'}
              </Text>
            </View>
          </View>
          <Text style={[styles.summaryDisease, {color: C.textPrimary}]}>
            {disease.fullName}
          </Text>
          <Text style={[styles.summaryConf, {color: C.textSecondary}]}>
            {Math.round(scanRecord.confidence * 100)}% confidence
            {scanRecord.cropVariety ? `  ·  ${scanRecord.cropVariety}` : ''}
          </Text>
        </View>

        {/* Advice body */}
        {loading ? (
          <View style={styles.loadingWrap}>
            <ActivityIndicator size="large" color={C.accentEmphasis} />
            <Text style={[styles.loadingText, {color: C.textSecondary}]}>
              Generating recommendations…
            </Text>
          </View>
        ) : (
          <View style={[styles.adviceCard, {backgroundColor: C.surface, borderColor: C.border}]}>
            {advice?.split('\n').map((line, i) => {
              if (line.startsWith('## ')) {
                return (
                  <Text key={i} style={[styles.section, {color: C.textPrimary}]}>
                    {line.replace('## ', '')}
                  </Text>
                );
              }
              if (line.startsWith('• ') || line.startsWith('- ')) {
                return (
                  <View key={i} style={styles.bulletRow}>
                    <View style={[styles.bullet, {backgroundColor: disease.color}]} />
                    <Text style={[styles.bulletText, {color: C.textPrimary}]}>
                      {line.slice(2)}
                    </Text>
                  </View>
                );
              }
              if (line.startsWith('_') && line.endsWith('_')) {
                return (
                  <Text key={i} style={[styles.italic, {color: C.textMuted}]}>
                    {line.slice(1, -1)}
                  </Text>
                );
              }
              if (line.trim() === '') return <View key={i} style={styles.spacer} />;
              return (
                <Text key={i} style={[styles.body, {color: C.textSecondary}]}>
                  {line}
                </Text>
              );
            })}
          </View>
        )}
      </ScrollView>
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
  headerTitle: {fontSize: 16, fontWeight: '600'},
  scroll: {padding: 16, paddingBottom: 40},
  summaryCard: {borderRadius: 12, borderWidth: 1, padding: 16, marginBottom: 12},
  summaryTop: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 8,
  },
  sourceRow: {flexDirection: 'row', alignItems: 'center'},
  sourceLabel: {fontSize: 12, marginLeft: 4},
  summaryDisease: {fontSize: 16, fontWeight: '700', marginBottom: 4},
  summaryConf: {fontSize: 13},
  loadingWrap: {alignItems: 'center', paddingVertical: 48},
  loadingText: {marginTop: 16, fontSize: 14},
  adviceCard: {borderRadius: 12, borderWidth: 1, padding: 16},
  section: {fontSize: 14, fontWeight: '700', marginTop: 16, marginBottom: 8},
  bulletRow: {flexDirection: 'row', alignItems: 'flex-start', marginBottom: 8},
  bullet: {width: 6, height: 6, borderRadius: 3, marginTop: 7, marginRight: 10},
  bulletText: {flex: 1, fontSize: 13, lineHeight: 22},
  italic: {fontSize: 12, fontStyle: 'italic', marginTop: 16},
  spacer: {height: 4},
  body: {fontSize: 13, lineHeight: 20, marginBottom: 4},
});
