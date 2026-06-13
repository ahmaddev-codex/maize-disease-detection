import React from 'react';
import {
  View,
  Text,
  ScrollView,
  Image,
  StyleSheet,
  TouchableOpacity,
} from 'react-native';
import {useRoute, useNavigation, RouteProp} from '@react-navigation/native';
import {NativeStackNavigationProp} from '@react-navigation/native-stack';
import Icon from 'react-native-vector-icons/MaterialCommunityIcons';
import {RootStackParamList} from '../navigation/RootNavigator';
import {useAppStore} from '../store/appStore';
import {DarkColors, LightColors} from '../constants/colors';
import {getDiseaseInfo} from '../constants/diseases';
import {DISEASE_INFO} from '../constants/diseases';
import ConfidenceBar from '../components/ConfidenceBar';
import GhLabel from '../components/GhLabel';
import GhButton from '../components/GhButton';
import {getScanById} from '../services/database';

type RouteType = RouteProp<RootStackParamList, 'Result'>;
type NavProp = NativeStackNavigationProp<RootStackParamList>;

export default function ResultScreen() {
  const route = useRoute<RouteType>();
  const nav = useNavigation<NavProp>();
  const {prediction, imagePath, scanId} = route.params;
  const isDarkMode = useAppStore(s => s.isDarkMode);
  const C = isDarkMode ? DarkColors : LightColors;
  const disease = getDiseaseInfo(prediction.classId);

  async function handleGetAdvice() {
    const scanRecord = await getScanById(scanId);
    if (scanRecord) {
      nav.navigate('Recommendation', {scanRecord});
    }
  }

  return (
    <View style={[styles.container, {backgroundColor: C.canvas}]}>
      {/* Header */}
      <View style={[styles.header, {backgroundColor: C.surface, borderBottomColor: C.border}]}>
        <TouchableOpacity onPress={() => nav.goBack()} hitSlop={{top: 8, bottom: 8, left: 8, right: 8}}>
          <Icon name="arrow-left" size={22} color={C.textPrimary} />
        </TouchableOpacity>
        <Text style={[styles.headerTitle, {color: C.textPrimary}]}>
          Diagnosis Result
        </Text>
        <View style={{width: 22}} />
      </View>

      <ScrollView contentContainerStyle={styles.scroll}>
        {/* Captured image */}
        <Image
          source={{uri: `file://${imagePath}`}}
          style={styles.image}
          resizeMode="cover"
        />

        {/* Result card */}
        <View
          style={[
            styles.resultCard,
            {
              backgroundColor: C.surface,
              borderColor: disease.color,
              borderLeftWidth: 4,
            },
          ]}>
          <View style={styles.resultTop}>
            <View style={styles.resultLeft}>
              <GhLabel text={prediction.shortName} color={disease.color} />
              <Text style={[styles.diseaseName, {color: C.textPrimary}]}>
                {disease.fullName}
              </Text>
            </View>
            <View style={styles.circleWrap}>
              <Text style={[styles.circleText, {color: disease.color}]}>
                {Math.round(prediction.confidence * 100)}%
              </Text>
              <Text style={[styles.circleLabel, {color: C.textSecondary}]}>
                confidence
              </Text>
            </View>
          </View>
          <Text style={[styles.description, {color: C.textSecondary}]}>
            {disease.description}
          </Text>
          <Text style={[styles.latency, {color: C.textMuted}]}>
            Inference: {Math.round(prediction.latencyMs)}ms
          </Text>
        </View>

        {/* Score matrix */}
        <View style={[styles.card, {backgroundColor: C.surface, borderColor: C.border}]}>
          <Text style={[styles.cardTitle, {color: C.textSecondary}]}>
            CLASS SCORES
          </Text>
          {DISEASE_INFO.map((d, i) => (
            <ConfidenceBar
              key={d.id}
              label={d.shortName}
              score={prediction.allScores[i] ?? 0}
              color={d.color}
              isTop={i === prediction.classId}
            />
          ))}
        </View>

        {/* Treatments (if diseased) */}
        {disease.treatments.length > 0 && (
          <View style={[styles.card, {backgroundColor: C.surface, borderColor: C.border}]}>
            <Text style={[styles.cardTitle, {color: C.textSecondary}]}>
              TREATMENT OPTIONS
            </Text>
            {disease.treatments.map((t, i) => (
              <View key={i} style={styles.bulletRow}>
                <View style={[styles.bullet, {backgroundColor: disease.color}]} />
                <Text style={[styles.bulletText, {color: C.textPrimary}]}>{t}</Text>
              </View>
            ))}
          </View>
        )}

        {/* Prevention */}
        <View style={[styles.card, {backgroundColor: C.surface, borderColor: C.border}]}>
          <Text style={[styles.cardTitle, {color: C.textSecondary}]}>
            PREVENTION
          </Text>
          {disease.preventions.map((p, i) => (
            <View key={i} style={styles.bulletRow}>
              <View style={[styles.bullet, {backgroundColor: C.successFg}]} />
              <Text style={[styles.bulletText, {color: C.textPrimary}]}>{p}</Text>
            </View>
          ))}
        </View>

        {/* CTA */}
        <GhButton
          label="Get AI-Powered Advice"
          icon="robot"
          variant="primary"
          onPress={handleGetAdvice}
          style={styles.cta}
        />
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
  scroll: {paddingBottom: 40},
  image: {width: '100%', height: 240},
  resultCard: {
    margin: 16,
    borderRadius: 12,
    borderWidth: 1,
    padding: 16,
  },
  resultTop: {flexDirection: 'row', justifyContent: 'space-between', marginBottom: 12},
  resultLeft: {flex: 1},
  diseaseName: {fontSize: 18, fontWeight: '700', marginTop: 8},
  circleWrap: {alignItems: 'center'},
  circleText: {fontSize: 28, fontWeight: '800'},
  circleLabel: {fontSize: 11},
  description: {fontSize: 13, lineHeight: 20, marginBottom: 8},
  latency: {fontSize: 11},
  card: {
    marginHorizontal: 16,
    marginBottom: 12,
    borderRadius: 12,
    borderWidth: 1,
    padding: 16,
  },
  cardTitle: {
    fontSize: 11,
    fontWeight: '600',
    letterSpacing: 0.8,
    marginBottom: 12,
  },
  bulletRow: {flexDirection: 'row', alignItems: 'flex-start', marginBottom: 8},
  bullet: {width: 6, height: 6, borderRadius: 3, marginTop: 6, marginRight: 10},
  bulletText: {flex: 1, fontSize: 13, lineHeight: 20},
  cta: {marginHorizontal: 16, marginTop: 4},
});
