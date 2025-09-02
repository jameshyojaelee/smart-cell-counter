/**
 * Results Screen - Final concentration and viability results
 */
import React, { useState, useEffect, useMemo } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  ScrollView,
  Alert,
  TextInput,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { router } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { useAppStore } from '../src/state/store';
import { calculateConcentration } from '../src/imaging/counting';
import { evaluateCountingQuality } from '../src/imaging/qc';
import { StatCard } from '../src/components/StatCard';
import { AdBanner } from '../src/components/AdBanner';
import { SampleRepository } from '../src/data/repositories/SampleRepository';
import { shareSample } from '../src/utils/share';
import { logUserInteraction, logError } from '../src/utils/logger';
import { useShouldShowAds, useIsPro } from '../src/hooks/usePurchase';
import { adService } from '../src/ads/ads';

export default function ResultsScreen(): JSX.Element {
  const [notes, setNotes] = useState('');
  const [isSaving, setIsSaving] = useState(false);
  const [isSharing, setIsSharing] = useState(false);

  const {
    currentSample,
    updateCurrentSample,
    detections,
    selectedSquares,
    settings,
    resetSession,
  } = useAppStore();

  // Dilution factor editor state
  const [dilutionInput, setDilutionInput] = useState<string>(
    (currentSample?.dilutionFactor ?? settings.defaultDilutionFactor ?? 1).toString()
  );

  useEffect(() => {
    // Keep input in sync if sample changes
    if (currentSample?.dilutionFactor != null) {
      setDilutionInput(String(currentSample.dilutionFactor));
    }
  }, [currentSample?.dilutionFactor]);

  const commitDilution = (value: number): void => {
    const clean = isFinite(value) && value > 0 ? value : 1;
    setDilutionInput(String(clean));
    updateCurrentSample({ dilutionFactor: clean });
  };

  const handleDilutionChange = (text: string): void => {
    setDilutionInput(text);
  };

  const handleDilutionEndEditing = (): void => {
    const parsed = Number(dilutionInput.replace(/,/g, '.'));
    commitDilution(parsed);
  };

  const stepDilution = (delta: number): void => {
    const current = Number(dilutionInput.replace(/,/g, '.'));
    const next = Math.max(0.01, (isFinite(current) && current > 0 ? current : 1) + delta);
    commitDilution(Number(next.toFixed(2)));
  };

  const shouldShowAds = useShouldShowAds();
  const isPro = useIsPro();

  const sampleRepository = new SampleRepository();

  // Calculate results - memoized to prevent infinite loops
  const squareCounts = useMemo(() => {
    // Mock square counts for development
    if (detections && detections.length > 0) {
      return [
        { index: 1, squareIndex: 1, live: 45, dead: 12, total: 57, isOutlier: false, isSelected: true },
        { index: 2, squareIndex: 2, live: 48, dead: 8, total: 56, isOutlier: false, isSelected: true },
        { index: 3, squareIndex: 3, live: 52, dead: 15, total: 67, isOutlier: true, isSelected: false },
        { index: 4, squareIndex: 4, live: 43, dead: 10, total: 53, isOutlier: false, isSelected: true },
        { index: 5, squareIndex: 5, live: 50, dead: 14, total: 64, isOutlier: false, isSelected: true }
      ];
    }
    return [];
  }, [detections]);

  const results = useMemo(() => calculateConcentration(
    squareCounts,
    currentSample?.dilutionFactor || 1,
    currentSample?.chamberType || 'neubauer'
  ), [squareCounts, currentSample?.dilutionFactor, currentSample?.chamberType]);

  const qcAlerts = useMemo(() => evaluateCountingQuality(squareCounts, settings.qcThresholds), [squareCounts, settings.qcThresholds]);

  useEffect(() => {
    // Update current sample with final results
    if (currentSample && results) {
      updateCurrentSample({
        concentration: results.concentration,
        viability: results.viability,
        liveTotal: results.liveTotal,
        deadTotal: results.deadTotal,
        squaresUsed: results.squaresUsed,
        rejectedSquares: results.rejectedSquares,
        notes,
      });
    }
  }, [results?.concentration, results?.viability, notes, currentSample?.id, updateCurrentSample]);

  const handleSaveSample = async (): Promise<void> => {
    if (!currentSample) {
      Alert.alert('Error', 'No sample data to save');
      return;
    }

    setIsSaving(true);
    logUserInteraction('Results', 'SaveSample');

    try {
      const sampleToSave = {
        ...currentSample,
        timestamp: currentSample.timestamp || Date.now(),
        id: currentSample.id || `sample_${Date.now()}`,
        detections,
        notes,
      };

      await sampleRepository.saveSample(sampleToSave as any);
      
      Alert.alert(
        'Sample Saved',
        'Your analysis has been saved successfully.',
        [
          { text: 'New Analysis', onPress: startNewAnalysis },
          { text: 'View History', onPress: () => router.push('/history') },
        ]
      );
    } catch (error) {
      logError('Results', error as Error, { context: 'saveSample' });
      Alert.alert('Save Error', 'Failed to save sample. Please try again.');
    } finally {
      setIsSaving(false);
    }
  };

  const handleShareResults = async (): Promise<void> => {
    if (!currentSample) {
      Alert.alert('Error', 'No sample data to share');
      return;
    }

    // Show interstitial ad for free users before PDF export (once per session)
    if (!isPro && shouldShowAds) {
      await adService.showInterstitialAd();
    }

    setIsSharing(true);
    logUserInteraction('Results', 'ShareResults');

    try {
      await shareSample(
        currentSample as any,
        squareCounts,
        qcAlerts,
        { format: 'pdf', includeImages: true, removeWatermark: isPro }
      );
    } catch (error) {
      logError('Results', error as Error, { context: 'shareResults' });
      Alert.alert('Share Error', 'Failed to share results. Please try again.');
    } finally {
      setIsSharing(false);
    }
  };

  const startNewAnalysis = (): void => {
    logUserInteraction('Results', 'StartNewAnalysis');
    resetSession();
    router.push('/capture');
  };

  return (
    <SafeAreaView style={styles.container}>
      <ScrollView style={styles.scrollView}>
        {/* Header */}
        <View style={styles.header}>
          <Text style={styles.headerTitle}>Analysis Complete</Text>
          <Text style={styles.headerSubtitle}>
            Sample: {currentSample?.id || 'Unknown'}
          </Text>
        </View>

        {/* QC Alerts */}
        {qcAlerts.length > 0 && (
          <View style={styles.alertsContainer}>
            <Text style={styles.alertsTitle}>Quality Control Alerts</Text>
            {qcAlerts.map((alert, index) => (
              <View
                key={index}
                style={[
                  styles.alert,
                  alert.severity === 'error' ? styles.alertError : styles.alertWarning,
                ]}
              >
                <Ionicons
                  name={alert.severity === 'error' ? 'warning' : 'information-circle'}
                  size={20}
                  color={alert.severity === 'error' ? '#FF3B30' : '#FF9500'}
                />
                <Text style={styles.alertText}>{alert.message}</Text>
              </View>
            ))}
          </View>
        )}

        {/* Main Results */}
        <View style={styles.resultsContainer}>
          <StatCard
            title="Concentration"
            value={results.concentration.toExponential(2)}
            unit="cells/mL"
            icon="flask"
            color="#007AFF"
          />
          <StatCard
            title="Viability"
            value={results.viability.toFixed(1)}
            unit="%"
            icon="heart"
            color="#34C759"
          />
        </View>

        <View style={styles.resultsContainer}>
          <StatCard
            title="Live Cells"
            value={results.liveTotal}
            icon="checkmark-circle"
            color="#34C759"
          />
          <StatCard
            title="Dead Cells"
            value={results.deadTotal}
            icon="close-circle"
            color="#FF3B30"
          />
        </View>

        {/* Sample Information */}
        <View style={styles.infoContainer}>
          <Text style={styles.infoTitle}>Sample Information</Text>
          
          <View style={styles.infoRow}>
            <Text style={styles.infoLabel}>Operator:</Text>
            <Text style={styles.infoValue}>{currentSample?.operator || 'Not specified'}</Text>
          </View>
          
          <View style={styles.infoRow}>
            <Text style={styles.infoLabel}>Project:</Text>
            <Text style={styles.infoValue}>{currentSample?.project || 'Not specified'}</Text>
          </View>
          
          <View style={styles.infoRow}>
            <Text style={styles.infoLabel}>Chamber Type:</Text>
            <Text style={styles.infoValue}>{currentSample?.chamberType || 'Unknown'}</Text>
          </View>
          
          <View style={[styles.infoRow, { alignItems: 'center' }]}>
            <Text style={styles.infoLabel}>Dilution Factor:</Text>
            <View style={styles.dilutionEditor}>
              <TouchableOpacity style={styles.dilutionButton} onPress={() => stepDilution(-0.5)}>
                <Ionicons name="remove" size={18} color="#007AFF" />
              </TouchableOpacity>
              <TextInput
                style={styles.dilutionInput}
                value={dilutionInput}
                keyboardType="decimal-pad"
                onChangeText={handleDilutionChange}
                onEndEditing={handleDilutionEndEditing}
                returnKeyType="done"
              />
              <Text style={styles.dilutionSuffix}>x</Text>
              <TouchableOpacity style={styles.dilutionButton} onPress={() => stepDilution(0.5)}>
                <Ionicons name="add" size={18} color="#007AFF" />
              </TouchableOpacity>
            </View>
          </View>
          
          <View style={styles.infoRow}>
            <Text style={styles.infoLabel}>Squares Used:</Text>
            <Text style={styles.infoValue}>{results.squaresUsed} of 4</Text>
          </View>
        </View>

        {/* Notes */}
        <View style={styles.notesContainer}>
          <Text style={styles.notesTitle}>Notes</Text>
          <TextInput
            style={styles.notesInput}
            placeholder="Add any additional notes about this sample..."
            value={notes}
            onChangeText={setNotes}
            multiline
            numberOfLines={4}
            textAlignVertical="top"
          />
        </View>

        {/* Seeding Calculator */}
        <View style={styles.calculatorContainer}>
          <Text style={styles.calculatorTitle}>Seeding Calculator</Text>
          <Text style={styles.calculatorSubtitle}>
            Calculate volume needed for target cell count
          </Text>
          {/* Seeding calculator inputs would go here */}
        </View>

        {/* Banner Ad */}
        <AdBanner visible={shouldShowAds} style={styles.adBanner} />
      </ScrollView>

      {/* Action Buttons */}
      <View style={styles.actionsContainer}>
        <TouchableOpacity
          style={styles.actionButton}
          onPress={handleShareResults}
          disabled={isSharing}
        >
          <Ionicons name="share" size={20} color="#007AFF" />
          <Text style={styles.actionButtonText}>Share</Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={[styles.actionButton, styles.primaryAction]}
          onPress={handleSaveSample}
          disabled={isSaving}
        >
          <Ionicons name="save" size={20} color="#fff" />
          <Text style={[styles.actionButtonText, styles.primaryActionText]}>
            {isSaving ? 'Saving...' : 'Save'}
          </Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={styles.actionButton}
          onPress={startNewAnalysis}
        >
          <Ionicons name="add" size={20} color="#34C759" />
          <Text style={[styles.actionButtonText, { color: '#34C759' }]}>New</Text>
        </TouchableOpacity>
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f8f9fa',
  },
  scrollView: {
    flex: 1,
  },
  header: {
    padding: 20,
    alignItems: 'center',
  },
  headerTitle: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#333',
  },
  headerSubtitle: {
    fontSize: 16,
    color: '#666',
    marginTop: 4,
  },
  alertsContainer: {
    margin: 20,
    padding: 16,
    backgroundColor: '#fff',
    borderRadius: 12,
    borderLeftWidth: 4,
    borderLeftColor: '#FF9500',
  },
  alertsTitle: {
    fontSize: 16,
    fontWeight: '600',
    color: '#333',
    marginBottom: 12,
  },
  alert: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 8,
  },
  alertError: {
    // Error-specific styling if needed
  },
  alertWarning: {
    // Warning-specific styling if needed
  },
  alertText: {
    fontSize: 14,
    color: '#666',
    marginLeft: 8,
    flex: 1,
  },
  resultsContainer: {
    flexDirection: 'row',
    paddingHorizontal: 12,
  },
  infoContainer: {
    margin: 20,
    padding: 16,
    backgroundColor: '#fff',
    borderRadius: 12,
  },
  infoTitle: {
    fontSize: 18,
    fontWeight: '600',
    color: '#333',
    marginBottom: 16,
  },
  infoRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 12,
  },
  infoLabel: {
    fontSize: 14,
    color: '#666',
    flex: 1,
  },
  infoValue: {
    fontSize: 14,
    fontWeight: '500',
    color: '#333',
  },
  dilutionEditor: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  dilutionButton: {
    width: 32,
    height: 32,
    borderRadius: 16,
    backgroundColor: '#EAF2FF',
    alignItems: 'center',
    justifyContent: 'center',
    marginHorizontal: 4,
  },
  dilutionInput: {
    width: 70,
    height: 36,
    borderWidth: 1,
    borderColor: '#E5E5EA',
    borderRadius: 8,
    paddingHorizontal: 10,
    fontSize: 14,
    textAlign: 'center',
    color: '#333',
    backgroundColor: '#fff',
  },
  dilutionSuffix: {
    fontSize: 14,
    color: '#666',
    marginLeft: 6,
    marginRight: 4,
  },
  notesContainer: {
    margin: 20,
    padding: 16,
    backgroundColor: '#fff',
    borderRadius: 12,
  },
  notesTitle: {
    fontSize: 16,
    fontWeight: '600',
    color: '#333',
    marginBottom: 12,
  },
  notesInput: {
    borderWidth: 1,
    borderColor: '#E5E5EA',
    borderRadius: 8,
    padding: 12,
    fontSize: 14,
    minHeight: 80,
  },
  calculatorContainer: {
    margin: 20,
    padding: 16,
    backgroundColor: '#fff',
    borderRadius: 12,
  },
  calculatorTitle: {
    fontSize: 16,
    fontWeight: '600',
    color: '#333',
    marginBottom: 4,
  },
  calculatorSubtitle: {
    fontSize: 14,
    color: '#666',
    marginBottom: 16,
  },
  actionsContainer: {
    flexDirection: 'row',
    justifyContent: 'space-around',
    padding: 20,
    backgroundColor: '#fff',
    borderTopWidth: 1,
    borderTopColor: '#E5E5EA',
  },
  actionButton: {
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 20,
    paddingVertical: 12,
    borderRadius: 8,
    backgroundColor: '#f0f0f0',
    minWidth: 80,
  },
  primaryAction: {
    backgroundColor: '#007AFF',
  },
  actionButtonText: {
    fontSize: 14,
    color: '#007AFF',
    marginTop: 4,
    fontWeight: '500',
  },
  primaryActionText: {
    color: '#fff',
  },
  adBanner: {
    marginTop: 20,
    marginBottom: 20,
  },
});
