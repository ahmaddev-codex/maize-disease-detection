import React, {useMemo} from 'react';
import {
  View,
  Text,
  ScrollView,
  StyleSheet,
  StatusBar,
} from 'react-native';
import {VictoryBar, VictoryChart, VictoryAxis, VictoryTheme} from 'victory-native';
import {subDays, format, parseISO, isAfter} from 'date-fns';
import {useAppStore} from '../store/appStore';
import {DarkColors, LightColors, DiseaseColors} from '../constants/colors';
import {DISEASE_INFO} from '../constants/diseases';
import {useScansLastDays} from '../hooks/useScans';
import GhLabel from '../components/GhLabel';

export default function DashboardScreen() {
  const isDarkMode = useAppStore(s => s.isDarkMode);
  const C = isDarkMode ? DarkColors : LightColors;
  const {scans} = useScansLastDays(30);

  // 7-day trend data
  const trendData = useMemo(() => {
    const days = Array.from({length: 7}, (_, i) => {
      const date = subDays(new Date(), 6 - i);
      const label = format(date, 'EEE');
      const dayScans = scans.filter(s => {
        const scanDate = parseISO(s.scannedAt);
        return (
          isAfter(scanDate, subDays(date, 1)) &&
          !isAfter(scanDate, date)
        );
      });
      const diseaseCount = dayScans.filter(s => s.classId !== 3).length;
      return {x: label, y: dayScans.length, diseaseCount};
    });
    return days;
  }, [scans]);

  // Disease breakdown
  const breakdown = useMemo(() => {
    const counts = [0, 0, 0, 0];
    scans.forEach(s => {
      if (s.classId >= 0 && s.classId <= 3) counts[s.classId]++;
    });
    return DISEASE_INFO.map((d, i) => ({...d, count: counts[i]}));
  }, [scans]);

  // Health score = (healthy / total) * 100
  const healthScore = useMemo(() => {
    if (scans.length === 0) return 100;
    const healthy = scans.filter(s => s.classId === 3).length;
    return Math.round((healthy / scans.length) * 100);
  }, [scans]);

  const scoreColor =
    healthScore >= 70
      ? C.successFg
      : healthScore >= 40
      ? C.attentionFg
      : C.dangerFg;

  return (
    <View style={[styles.container, {backgroundColor: C.canvas}]}>
      <StatusBar
        barStyle={isDarkMode ? 'light-content' : 'dark-content'}
        backgroundColor={C.canvas}
      />
      <ScrollView contentContainerStyle={styles.scroll}>
        <Text style={[styles.pageTitle, {color: C.textPrimary}]}>Overview</Text>
        <Text style={[styles.pageSubtitle, {color: C.textSecondary}]}>
          Last 30 days · {scans.length} scans
        </Text>

        {/* Health score */}
        <View style={[styles.card, {backgroundColor: C.surface, borderColor: C.border}]}>
          <Text style={[styles.cardTitle, {color: C.textSecondary}]}>
            FARM HEALTH SCORE
          </Text>
          <View style={styles.scoreRow}>
            <Text style={[styles.scoreValue, {color: scoreColor}]}>
              {healthScore}
            </Text>
            <Text style={[styles.scoreUnit, {color: C.textSecondary}]}>/100</Text>
          </View>
          <Text style={[styles.scoreLabel, {color: C.textSecondary}]}>
            {healthScore >= 70
              ? 'Good — Low disease pressure'
              : healthScore >= 40
              ? 'Moderate — Monitor closely'
              : 'Poor — Immediate action needed'}
          </Text>
        </View>

        {/* 7-day trend chart */}
        <View style={[styles.card, {backgroundColor: C.surface, borderColor: C.border}]}>
          <Text style={[styles.cardTitle, {color: C.textSecondary}]}>
            SCAN ACTIVITY (7 DAYS)
          </Text>
          <VictoryChart
            height={180}
            padding={{top: 10, bottom: 40, left: 40, right: 20}}
            theme={VictoryTheme.grayscale}>
            <VictoryAxis
              tickFormat={t => t}
              style={{
                tickLabels: {fill: C.textMuted, fontSize: 10},
                axis: {stroke: C.border},
                grid: {stroke: 'none'},
              }}
            />
            <VictoryAxis
              dependentAxis
              tickFormat={t => (Number.isInteger(t) ? t : '')}
              style={{
                tickLabels: {fill: C.textMuted, fontSize: 10},
                axis: {stroke: C.border},
                grid: {stroke: C.borderMuted, strokeDasharray: '4'},
              }}
            />
            <VictoryBar
              data={trendData}
              style={{
                data: {fill: C.accentEmphasis, borderRadius: 3},
              }}
              barWidth={20}
            />
          </VictoryChart>
        </View>

        {/* Disease breakdown */}
        <View style={[styles.card, {backgroundColor: C.surface, borderColor: C.border}]}>
          <Text style={[styles.cardTitle, {color: C.textSecondary}]}>
            DISEASE BREAKDOWN
          </Text>
          {breakdown.map(d => {
            const pct = scans.length > 0 ? d.count / scans.length : 0;
            return (
              <View key={d.id} style={styles.breakdownRow}>
                <View style={styles.breakdownLabel}>
                  <GhLabel text={d.shortName} color={d.color} />
                  <Text style={[styles.breakdownCount, {color: C.textSecondary}]}>
                    {d.count} scans
                  </Text>
                </View>
                <View style={[styles.barTrack, {backgroundColor: C.borderMuted}]}>
                  <View
                    style={[
                      styles.barFill,
                      {width: `${pct * 100}%`, backgroundColor: d.color},
                    ]}
                  />
                </View>
              </View>
            );
          })}
        </View>

        {/* Stats row */}
        <View style={styles.statsRow}>
          {[
            {label: 'Total Scans', value: scans.length},
            {
              label: 'Diseased',
              value: scans.filter(s => s.classId !== 3).length,
            },
            {
              label: 'GPS Tagged',
              value: scans.filter(s => s.latitude != null).length,
            },
          ].map(stat => (
            <View
              key={stat.label}
              style={[styles.statCard, {backgroundColor: C.surface, borderColor: C.border}]}>
              <Text style={[styles.statValue, {color: C.textPrimary}]}>
                {stat.value}
              </Text>
              <Text style={[styles.statLabel, {color: C.textSecondary}]}>
                {stat.label}
              </Text>
            </View>
          ))}
        </View>
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {flex: 1},
  scroll: {padding: 16, paddingBottom: 32},
  pageTitle: {fontSize: 22, fontWeight: '700', marginBottom: 4},
  pageSubtitle: {fontSize: 13, marginBottom: 20},
  card: {borderRadius: 12, borderWidth: 1, padding: 16, marginBottom: 12},
  cardTitle: {fontSize: 11, fontWeight: '600', letterSpacing: 0.8, marginBottom: 12},
  scoreRow: {flexDirection: 'row', alignItems: 'baseline', marginBottom: 4},
  scoreValue: {fontSize: 56, fontWeight: '800', lineHeight: 60},
  scoreUnit: {fontSize: 20, marginLeft: 4},
  scoreLabel: {fontSize: 13},
  breakdownRow: {marginBottom: 12},
  breakdownLabel: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: 4,
  },
  breakdownCount: {fontSize: 12},
  barTrack: {height: 6, borderRadius: 3, overflow: 'hidden'},
  barFill: {height: '100%', borderRadius: 3},
  statsRow: {flexDirection: 'row', gap: 8},
  statCard: {
    flex: 1,
    borderRadius: 10,
    borderWidth: 1,
    padding: 12,
    alignItems: 'center',
  },
  statValue: {fontSize: 24, fontWeight: '700', marginBottom: 2},
  statLabel: {fontSize: 11, textAlign: 'center'},
});
