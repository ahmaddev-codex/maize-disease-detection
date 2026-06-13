import React from 'react';
import {
  TouchableOpacity,
  Text,
  StyleSheet,
  ActivityIndicator,
  ViewStyle,
} from 'react-native';
import Icon from 'react-native-vector-icons/MaterialCommunityIcons';
import {useAppStore} from '../store/appStore';
import {DarkColors, LightColors} from '../constants/colors';

interface Props {
  label: string;
  icon?: string;
  onPress: () => void;
  variant?: 'primary' | 'secondary' | 'danger';
  loading?: boolean;
  disabled?: boolean;
  style?: ViewStyle;
}

export default function GhButton({
  label,
  icon,
  onPress,
  variant = 'secondary',
  loading,
  disabled,
  style,
}: Props) {
  const isDarkMode = useAppStore(s => s.isDarkMode);
  const C = isDarkMode ? DarkColors : LightColors;

  const bg =
    variant === 'primary'
      ? C.successEmphasis
      : variant === 'danger'
      ? C.dangerEmphasis
      : C.surfaceOverlay;

  const textColor =
    variant === 'primary' || variant === 'danger'
      ? '#FFFFFF'
      : C.textPrimary;

  return (
    <TouchableOpacity
      onPress={onPress}
      disabled={disabled || loading}
      activeOpacity={0.7}
      style={[
        styles.btn,
        {
          backgroundColor: bg,
          borderColor: C.border,
          opacity: disabled ? 0.4 : 1,
        },
        style,
      ]}>
      {loading ? (
        <ActivityIndicator size="small" color={textColor} />
      ) : (
        <>
          {icon && (
            <Icon
              name={icon}
              size={16}
              color={textColor}
              style={styles.icon}
            />
          )}
          <Text style={[styles.label, {color: textColor}]}>{label}</Text>
        </>
      )}
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  btn: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 16,
    paddingVertical: 10,
    borderRadius: 6,
    borderWidth: 1,
  },
  icon: {marginRight: 6},
  label: {fontSize: 14, fontWeight: '500'},
});
