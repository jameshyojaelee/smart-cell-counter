/**
 * Threshold slider component for adjusting processing parameters
 */
import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import Slider from '@react-native-community/slider';

interface ThresholdSliderProps {
  label: string;
  value: number;
  minimumValue: number;
  maximumValue: number;
  step?: number;
  unit?: string;
  description?: string;
  onValueChange: (value: number) => void;
  disabled?: boolean;
}

export function ThresholdSlider({
  label,
  value,
  minimumValue,
  maximumValue,
  step = 1,
  unit = '',
  description,
  onValueChange,
  disabled = false,
}: ThresholdSliderProps): JSX.Element {
  const formatValue = (val: number): string => {
    if (step < 1) {
      return val.toFixed(2);
    } else if (step === 1) {
      return Math.round(val).toString();
    } else {
      return val.toFixed(1);
    }
  };

  return (
    <View style={[styles.container, disabled && styles.containerDisabled]}>
      <View style={styles.header}>
        <Text style={[styles.label, disabled && styles.labelDisabled]}>
          {label}
        </Text>
        <Text style={[styles.value, disabled && styles.valueDisabled]}>
          {formatValue(value)}{unit}
        </Text>
      </View>

      <Slider
        style={styles.slider}
        value={value}
        minimumValue={minimumValue}
        maximumValue={maximumValue}
        step={step}
        onValueChange={onValueChange}
        minimumTrackTintColor={disabled ? '#ccc' : '#007AFF'}
        maximumTrackTintColor="#E5E5EA"
        thumbStyle={disabled ? styles.thumbDisabled : styles.thumb}
        trackStyle={styles.track}
        disabled={disabled}
      />

      <View style={styles.range}>
        <Text style={[styles.rangeText, disabled && styles.rangeTextDisabled]}>
          {formatValue(minimumValue)}{unit}
        </Text>
        <Text style={[styles.rangeText, disabled && styles.rangeTextDisabled]}>
          {formatValue(maximumValue)}{unit}
        </Text>
      </View>

      {description && (
        <Text style={[styles.description, disabled && styles.descriptionDisabled]}>
          {description}
        </Text>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    backgroundColor: '#fff',
    borderRadius: 12,
    padding: 16,
    marginVertical: 8,
    elevation: 2,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.05,
    shadowRadius: 4,
  },
  containerDisabled: {
    backgroundColor: '#f8f9fa',
    opacity: 0.6,
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 12,
  },
  label: {
    fontSize: 16,
    fontWeight: '600',
    color: '#333',
    flex: 1,
  },
  labelDisabled: {
    color: '#999',
  },
  value: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#007AFF',
    minWidth: 60,
    textAlign: 'right',
  },
  valueDisabled: {
    color: '#ccc',
  },
  slider: {
    height: 40,
    marginHorizontal: -8,
  },
  thumb: {
    backgroundColor: '#007AFF',
    width: 24,
    height: 24,
  },
  thumbDisabled: {
    backgroundColor: '#ccc',
    width: 24,
    height: 24,
  },
  track: {
    height: 4,
    borderRadius: 2,
  },
  range: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginTop: 8,
  },
  rangeText: {
    fontSize: 12,
    color: '#8E8E93',
  },
  rangeTextDisabled: {
    color: '#ccc',
  },
  description: {
    fontSize: 13,
    color: '#666',
    marginTop: 8,
    lineHeight: 18,
  },
  descriptionDisabled: {
    color: '#999',
  },
});
