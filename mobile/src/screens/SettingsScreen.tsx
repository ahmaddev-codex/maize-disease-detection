import React, {useState} from 'react';
import {
  View,
  Text,
  ScrollView,
  Switch,
  TextInput,
  TouchableOpacity,
  StyleSheet,
  Alert,
} from 'react-native';
import {useNavigation} from '@react-navigation/native';
import Icon from 'react-native-vector-icons/MaterialCommunityIcons';
import Keychain from 'react-native-keychain';
import {useAppStore} from '../store/appStore';
import {DarkColors, LightColors} from '../constants/colors';

export default function SettingsScreen() {
  const nav = useNavigation();
  const {isDarkMode, toggleTheme, geminiApiKey, setGeminiApiKey, modelState} =
    useAppStore();
  const C = isDarkMode ? DarkColors : LightColors;
  const [keyInput, setKeyInput] = useState(geminiApiKey ?? '');
  const [saving, setSaving] = useState(false);

  async function saveApiKey() {
    setSaving(true);
    try {
      const trimmed = keyInput.trim();
      if (trimmed) {
        await Keychain.setGenericPassword('gemini_api_key', trimmed, {
          service: 'com.maizeguard.gemini',
        });
        setGeminiApiKey(trimmed);
      } else {
        await Keychain.resetGenericPassword({service: 'com.maizeguard.gemini'});
        setGeminiApiKey(null);
      }
      Alert.alert('Saved', trimmed ? 'Gemini API key saved.' : 'API key cleared.');
    } catch (e) {
      Alert.alert('Error', String(e));
    } finally {
      setSaving(false);
    }
  }

  return (
    <View style={[styles.container, {backgroundColor: C.canvas}]}>
      <View style={[styles.header, {backgroundColor: C.surface, borderBottomColor: C.border}]}>
        <TouchableOpacity onPress={() => nav.goBack()}>
          <Icon name="arrow-left" size={22} color={C.textPrimary} />
        </TouchableOpacity>
        <Text style={[styles.headerTitle, {color: C.textPrimary}]}>Settings</Text>
        <View style={{width: 22}} />
      </View>

      <ScrollView contentContainerStyle={styles.scroll}>
        {/* Appearance */}
        <Text style={[styles.groupLabel, {color: C.textSecondary}]}>APPEARANCE</Text>
        <View style={[styles.row, {backgroundColor: C.surface, borderColor: C.border}]}>
          <Icon name="theme-light-dark" size={20} color={C.textSecondary} />
          <Text style={[styles.rowLabel, {color: C.textPrimary}]}>Dark Mode</Text>
          <Switch
            value={isDarkMode}
            onValueChange={toggleTheme}
            trackColor={{false: C.border, true: C.accentEmphasis}}
            thumbColor="#FFFFFF"
          />
        </View>

        {/* Model status */}
        <Text style={[styles.groupLabel, {color: C.textSecondary}]}>ML MODEL</Text>
        <View style={[styles.infoRow, {backgroundColor: C.surface, borderColor: C.border}]}>
          <Icon name="brain" size={20} color={C.textSecondary} />
          <View style={styles.infoText}>
            <Text style={[styles.rowLabel, {color: C.textPrimary}]}>
              EfficientNetB3 INT8
            </Text>
            <Text style={[styles.rowSub, {color: C.textSecondary}]}>
              4-class maize disease · ~13MB
            </Text>
          </View>
          <View
            style={[
              styles.statusDot,
              {
                backgroundColor:
                  modelState === 'ready'
                    ? C.successFg
                    : modelState === 'error'
                    ? C.dangerFg
                    : C.attentionFg,
              },
            ]}
          />
        </View>

        {/* Gemini API key */}
        <Text style={[styles.groupLabel, {color: C.textSecondary}]}>AI ADVISOR</Text>
        <View style={[styles.keyCard, {backgroundColor: C.surface, borderColor: C.border}]}>
          <Text style={[styles.keyLabel, {color: C.textPrimary}]}>
            Gemini API Key
          </Text>
          <Text style={[styles.keySub, {color: C.textSecondary}]}>
            Optional. Enables AI-powered agronomic advice. Leave empty for
            on-device recommendations.
          </Text>
          <TextInput
            style={[
              styles.keyInput,
              {
                backgroundColor: C.canvas,
                borderColor: C.border,
                color: C.textPrimary,
              },
            ]}
            value={keyInput}
            onChangeText={setKeyInput}
            placeholder="AIza…"
            placeholderTextColor={C.textMuted}
            secureTextEntry
            autoCapitalize="none"
            autoCorrect={false}
          />
          <TouchableOpacity
            style={[styles.saveBtn, {backgroundColor: C.accentEmphasis}]}
            onPress={saveApiKey}
            disabled={saving}>
            <Text style={styles.saveBtnText}>{saving ? 'Saving…' : 'Save Key'}</Text>
          </TouchableOpacity>
        </View>

        {/* About */}
        <Text style={[styles.groupLabel, {color: C.textSecondary}]}>ABOUT</Text>
        <View style={[styles.aboutCard, {backgroundColor: C.surface, borderColor: C.border}]}>
          {[
            ['App', 'MaizeGuard v1.0.0'],
            ['Platform', 'React Native 0.73'],
            ['Model', 'EfficientNetB3 (PlantVillage)'],
            ['Dataset', 'PlantVillage — 4,188 images'],
            ['Classes', 'NCLB · Rust · GLS · Healthy'],
          ].map(([label, value]) => (
            <View key={label} style={styles.aboutRow}>
              <Text style={[styles.aboutLabel, {color: C.textSecondary}]}>{label}</Text>
              <Text style={[styles.aboutValue, {color: C.textPrimary}]}>{value}</Text>
            </View>
          ))}
        </View>
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
  groupLabel: {
    fontSize: 11,
    fontWeight: '600',
    letterSpacing: 0.8,
    marginBottom: 8,
    marginTop: 20,
    marginLeft: 4,
  },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 14,
    borderRadius: 10,
    borderWidth: 1,
    gap: 12,
  },
  rowLabel: {flex: 1, fontSize: 15},
  rowSub: {fontSize: 12, marginTop: 2},
  infoRow: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 14,
    borderRadius: 10,
    borderWidth: 1,
    gap: 12,
  },
  infoText: {flex: 1},
  statusDot: {width: 10, height: 10, borderRadius: 5},
  keyCard: {
    borderRadius: 10,
    borderWidth: 1,
    padding: 16,
  },
  keyLabel: {fontSize: 15, fontWeight: '600', marginBottom: 4},
  keySub: {fontSize: 13, lineHeight: 18, marginBottom: 12},
  keyInput: {
    borderWidth: 1,
    borderRadius: 6,
    padding: 10,
    fontSize: 13,
    fontFamily: 'monospace',
    marginBottom: 12,
  },
  saveBtn: {
    padding: 10,
    borderRadius: 6,
    alignItems: 'center',
  },
  saveBtnText: {color: '#FFF', fontWeight: '600'},
  aboutCard: {borderRadius: 10, borderWidth: 1, overflow: 'hidden'},
  aboutRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    padding: 12,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: '#30363D',
  },
  aboutLabel: {fontSize: 13},
  aboutValue: {fontSize: 13, fontWeight: '500'},
});
