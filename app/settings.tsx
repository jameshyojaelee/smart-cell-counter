/**
 * Settings Screen - App configuration and preferences
 */
import React from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
  Switch,
  Alert,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import { useAppStore } from '../src/state/store';
import { ThresholdSlider } from '../src/components/ThresholdSlider';
import { logUserInteraction } from '../src/utils/logger';
import { usePurchase, useProFeatures } from '../src/hooks/usePurchase';
import { consentService } from '../src/privacy/consent';
import { router } from 'expo-router';

export default function SettingsScreen(): JSX.Element {
  const { settings, updateSettings } = useAppStore();
  const { isPro, isLoading, restorePurchases } = usePurchase();
  const proFeatures = useProFeatures();
  const [consent, setConsent] = React.useState(consentService.getConsentState());

  const handleResetSettings = (): void => {
    Alert.alert(
      'Reset Settings',
      'Are you sure you want to reset all settings to their default values?',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Reset',
          style: 'destructive',
          onPress: () => {
            // Reset to default settings
            updateSettings({
              defaultChamberType: 'neubauer',
              defaultStainType: 'trypan_blue',
              defaultDilutionFactor: 1.0,
              defaultOperator: '',
              defaultProject: '',
              processingParams: {
                thresholdMethod: 'adaptive',
                blockSize: 51,
                C: -2,
                minAreaUm2: 50,
                maxAreaUm2: 5000,
                useWatershed: true,
                useTFLiteRefinement: false,
              },
              viabilityThresholds: {
                hueMin: 200,
                hueMax: 260,
                saturationMin: 0.3,
                valueMax: 0.7,
              },
              qcThresholds: {
                minFocusScore: 100,
                maxGlareRatio: 0.1,
                minCellsPerSquare: 10,
                maxCellsPerSquare: 300,
                maxVarianceMAD: 2.5,
              },
              units: 'metric',
              enableAnalytics: true,
              enableCrashReporting: true,
            });
            logUserInteraction('Settings', 'ResetToDefaults');
          },
        },
      ]
    );
  };

  const handleGoToPro = (): void => {
    logUserInteraction('Settings', 'GoToPro');
    router.push('/paywall');
  };

  const handleRestorePurchases = async (): Promise<void> => {
    try {
      logUserInteraction('Settings', 'RestorePurchases');
      const success = await restorePurchases();
      if (success) {
        Alert.alert('Success', 'Your Pro features have been restored!');
      } else {
        Alert.alert('No Purchases Found', 'We couldn\'t find any purchases to restore.');
      }
    } catch (error) {
      Alert.alert('Error', 'Failed to restore purchases. Please try again.');
    }
  };

  const updateConsent = (updates: any): void => {
    consentService.updateConsent(updates);
    setConsent(consentService.getConsentState());
  };

  return (
    <SafeAreaView style={styles.container}>
      <ScrollView style={styles.scrollView}>
        {/* Pro Status */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>
            {isPro ? (
              <>
                <Ionicons name="checkmark-circle" size={20} color="#34C759" /> Pro Status
              </>
            ) : (
              'Upgrade to Pro'
            )}
          </Text>
          
          {isPro ? (
            <View style={styles.proStatusContainer}>
              <View style={styles.proStatusCard}>
                <Ionicons name="star" size={24} color="#FFD60A" />
                <Text style={styles.proStatusText}>Pro features unlocked!</Text>
                <Text style={styles.proStatusSubtext}>
                  Enjoy ad-free experience and advanced features
                </Text>
              </View>
              <TouchableOpacity
                style={styles.restoreButton}
                onPress={handleRestorePurchases}
                disabled={isLoading}
              >
                <Text style={styles.restoreButtonText}>Restore Purchases</Text>
              </TouchableOpacity>
            </View>
          ) : (
            <View style={styles.upgradeContainer}>
              <TouchableOpacity style={styles.upgradeButton} onPress={handleGoToPro}>
                <Ionicons name="star" size={20} color="#fff" />
                <Text style={styles.upgradeButtonText}>Upgrade to Pro</Text>
              </TouchableOpacity>
              <TouchableOpacity
                style={styles.restoreButton}
                onPress={handleRestorePurchases}
                disabled={isLoading}
              >
                <Text style={styles.restoreButtonText}>Restore Purchases</Text>
              </TouchableOpacity>
            </View>
          )}
        </View>

        {/* Processing Parameters */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Processing Parameters</Text>
          
          <ThresholdSlider
            label="Block Size"
            value={settings.processingParams.blockSize}
            minimumValue={31}
            maximumValue={101}
            step={2}
            description="Size of the neighborhood area for adaptive thresholding (must be odd)"
            onValueChange={(value) =>
              updateSettings({
                processingParams: {
                  ...settings.processingParams,
                  blockSize: value % 2 === 0 ? value + 1 : value,
                },
              })
            }
          />
          
          <ThresholdSlider
            label="Threshold Constant (C)"
            value={settings.processingParams.C}
            minimumValue={-10}
            maximumValue={10}
            step={0.5}
            description="Constant subtracted from the mean in adaptive thresholding"
            onValueChange={(value) =>
              updateSettings({
                processingParams: {
                  ...settings.processingParams,
                  C: value,
                },
              })
            }
          />
          
          <ThresholdSlider
            label="Minimum Cell Area"
            value={settings.processingParams.minAreaUm2}
            minimumValue={10}
            maximumValue={200}
            step={5}
            unit=" μm²"
            description="Minimum area threshold for cell detection"
            onValueChange={(value) =>
              updateSettings({
                processingParams: {
                  ...settings.processingParams,
                  minAreaUm2: value,
                },
              })
            }
          />
          
          <ThresholdSlider
            label="Maximum Cell Area"
            value={settings.processingParams.maxAreaUm2}
            minimumValue={1000}
            maximumValue={10000}
            step={100}
            unit=" μm²"
            description="Maximum area threshold for cell detection"
            onValueChange={(value) =>
              updateSettings({
                processingParams: {
                  ...settings.processingParams,
                  maxAreaUm2: value,
                },
              })
            }
          />
        </View>

        {/* Viability Thresholds */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Viability Classification</Text>
          
          <ThresholdSlider
            label="Blue Hue Min"
            value={settings.viabilityThresholds.hueMin}
            minimumValue={180}
            maximumValue={220}
            step={5}
            unit="°"
            description="Minimum hue value for blue color detection"
            onValueChange={(value) =>
              updateSettings({
                viabilityThresholds: {
                  ...settings.viabilityThresholds,
                  hueMin: value,
                },
              })
            }
          />
          
          <ThresholdSlider
            label="Blue Hue Max"
            value={settings.viabilityThresholds.hueMax}
            minimumValue={240}
            maximumValue={280}
            step={5}
            unit="°"
            description="Maximum hue value for blue color detection"
            onValueChange={(value) =>
              updateSettings({
                viabilityThresholds: {
                  ...settings.viabilityThresholds,
                  hueMax: value,
                },
              })
            }
          />
          
          <ThresholdSlider
            label="Minimum Saturation"
            value={settings.viabilityThresholds.saturationMin}
            minimumValue={0.1}
            maximumValue={0.8}
            step={0.05}
            description="Minimum saturation for dead cell classification"
            onValueChange={(value) =>
              updateSettings({
                viabilityThresholds: {
                  ...settings.viabilityThresholds,
                  saturationMin: value,
                },
              })
            }
          />
          
          <ThresholdSlider
            label="Maximum Value"
            value={settings.viabilityThresholds.valueMax}
            minimumValue={0.3}
            maximumValue={0.9}
            step={0.05}
            description="Maximum brightness for dead cell classification"
            onValueChange={(value) =>
              updateSettings({
                viabilityThresholds: {
                  ...settings.viabilityThresholds,
                  valueMax: value,
                },
              })
            }
          />
        </View>

        {/* Quality Control */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Quality Control</Text>
          
          <ThresholdSlider
            label="Min Focus Score"
            value={settings.qcThresholds.minFocusScore}
            minimumValue={50}
            maximumValue={200}
            step={10}
            description="Minimum acceptable focus score"
            onValueChange={(value) =>
              updateSettings({
                qcThresholds: {
                  ...settings.qcThresholds,
                  minFocusScore: value,
                },
              })
            }
          />
          
          <ThresholdSlider
            label="Max Glare Ratio"
            value={settings.qcThresholds.maxGlareRatio}
            minimumValue={0.05}
            maximumValue={0.3}
            step={0.01}
            unit="%"
            description="Maximum acceptable glare percentage"
            onValueChange={(value) =>
              updateSettings({
                qcThresholds: {
                  ...settings.qcThresholds,
                  maxGlareRatio: value,
                },
              })
            }
          />
        </View>

        {/* Advanced Options */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Advanced Options</Text>
          
          <View style={styles.switchRow}>
            <Text style={styles.switchLabel}>Use Watershed Splitting</Text>
            <Switch
              value={settings.processingParams.useWatershed}
              onValueChange={(value) =>
                updateSettings({
                  processingParams: {
                    ...settings.processingParams,
                    useWatershed: value,
                  },
                })
              }
            />
          </View>
          
          <View style={styles.switchRow}>
            <View style={styles.switchLabelContainer}>
              <Text style={styles.switchLabel}>Priority ML Processing</Text>
              {!proFeatures.canUsePriorityProcessing && (
                <Text style={styles.proLabel}>Pro</Text>
              )}
            </View>
            <Switch
              value={proFeatures.canUsePriorityProcessing ? settings.processingParams.useTFLiteRefinement : false}
              onValueChange={(value) => {
                if (!proFeatures.canUsePriorityProcessing) {
                  Alert.alert(
                    'Pro Feature',
                    'Priority ML processing is available in Pro version.',
                    [
                      { text: 'Cancel', style: 'cancel' },
                      { text: 'Upgrade', onPress: handleGoToPro },
                    ]
                  );
                  return;
                }
                updateSettings({
                  processingParams: {
                    ...settings.processingParams,
                    useTFLiteRefinement: value,
                  },
                });
              }}
              disabled={!proFeatures.canUsePriorityProcessing}
            />
          </View>
        </View>

        {/* Pro Features */}
        {proFeatures.canUseAdvancedSettings && (
          <View style={styles.section}>
            <Text style={styles.sectionTitle}>Pro Features</Text>
            
            <TouchableOpacity style={styles.menuRow} disabled>
              <Ionicons name="grid" size={20} color="#007AFF" />
              <Text style={styles.menuLabel}>Custom Grid Presets</Text>
              <Text style={styles.menuSubtitle}>Coming soon</Text>
            </TouchableOpacity>
            
            <TouchableOpacity style={styles.menuRow} disabled>
              <Ionicons name="color-palette" size={20} color="#007AFF" />
              <Text style={styles.menuLabel}>Multiple Stain Profiles</Text>
              <Text style={styles.menuSubtitle}>Coming soon</Text>
            </TouchableOpacity>
            
            <TouchableOpacity style={styles.menuRow} disabled>
              <Ionicons name="analytics" size={20} color="#007AFF" />
              <Text style={styles.menuLabel}>Per-Square Statistics</Text>
              <Text style={styles.menuSubtitle}>Enhanced CSV exports</Text>
            </TouchableOpacity>
          </View>
        )}

        {/* Privacy & Consent */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Privacy & Consent</Text>
          
          <View style={styles.switchRow}>
            <View style={styles.switchLabelContainer}>
              <Text style={styles.switchLabel}>Personalized Ads</Text>
              <Text style={styles.switchSubtitle}>
                {consent.adPersonalizationConsent === null 
                  ? 'Not set (using non-personalized)'
                  : consent.adPersonalizationConsent 
                    ? 'Personalized ads enabled'
                    : 'Non-personalized ads only'
                }
              </Text>
            </View>
            <Switch
              value={consent.adPersonalizationConsent === true}
              onValueChange={(value) => updateConsent({ adPersonalizationConsent: value })}
            />
          </View>
          
          <View style={styles.switchRow}>
            <Text style={styles.switchLabel}>Crash Reporting</Text>
            <Switch
              value={consent.crashReportingConsent}
              onValueChange={(value) => updateConsent({ crashReportingConsent: value })}
            />
          </View>
          
          <View style={styles.switchRow}>
            <Text style={styles.switchLabel}>Usage Analytics</Text>
            <Switch
              value={consent.analyticsConsent}
              onValueChange={(value) => updateConsent({ analyticsConsent: value })}
            />
          </View>
          
          <View style={styles.infoRow}>
            <Text style={styles.infoText}>
              Your cell counting data never leaves your device. We only collect anonymous usage statistics to improve the app.
            </Text>
          </View>
        </View>



        {/* Actions */}
        <View style={styles.section}>
          <TouchableOpacity style={styles.resetButton} onPress={handleResetSettings}>
            <Ionicons name="refresh" size={20} color="#FF3B30" />
            <Text style={styles.resetButtonText}>Reset to Defaults</Text>
          </TouchableOpacity>
        </View>
      </ScrollView>
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
  section: {
    backgroundColor: '#fff',
    marginTop: 20,
    paddingVertical: 20,
  },
  sectionTitle: {
    fontSize: 20,
    fontWeight: '600',
    color: '#333',
    paddingHorizontal: 20,
    marginBottom: 16,
  },
  switchRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 20,
    paddingVertical: 16,
    borderBottomWidth: 1,
    borderBottomColor: '#f0f0f0',
  },
  switchLabel: {
    fontSize: 16,
    color: '#333',
    flex: 1,
  },
  resetButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 16,
    marginHorizontal: 20,
    borderRadius: 8,
    backgroundColor: '#ffebee',
    borderWidth: 1,
    borderColor: '#FF3B30',
  },
  resetButtonText: {
    fontSize: 16,
    color: '#FF3B30',
    fontWeight: '600',
    marginLeft: 8,
  },
  proStatusContainer: {
    paddingHorizontal: 20,
  },
  proStatusCard: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#F0F8FF',
    padding: 16,
    borderRadius: 12,
    marginBottom: 12,
  },
  proStatusText: {
    fontSize: 16,
    fontWeight: '600',
    color: '#007AFF',
    marginLeft: 12,
    flex: 1,
  },
  proStatusSubtext: {
    fontSize: 14,
    color: '#666',
    marginTop: 4,
  },
  upgradeContainer: {
    paddingHorizontal: 20,
  },
  upgradeButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#007AFF',
    paddingVertical: 16,
    borderRadius: 12,
    marginBottom: 12,
  },
  upgradeButtonText: {
    fontSize: 16,
    fontWeight: '600',
    color: '#fff',
    marginLeft: 8,
  },
  restoreButton: {
    alignItems: 'center',
    paddingVertical: 12,
  },
  restoreButtonText: {
    fontSize: 14,
    color: '#007AFF',
  },
  switchLabelContainer: {
    flex: 1,
  },
  switchSubtitle: {
    fontSize: 12,
    color: '#666',
    marginTop: 2,
  },
  proLabel: {
    backgroundColor: '#007AFF',
    color: '#fff',
    fontSize: 10,
    fontWeight: '600',
    paddingHorizontal: 6,
    paddingVertical: 2,
    borderRadius: 4,
    marginLeft: 8,
  },
  menuRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 20,
    paddingVertical: 16,
    borderBottomWidth: 1,
    borderBottomColor: '#f0f0f0',
  },
  menuLabel: {
    fontSize: 16,
    color: '#333',
    marginLeft: 12,
    flex: 1,
  },
  menuSubtitle: {
    fontSize: 12,
    color: '#666',
  },
  infoRow: {
    paddingHorizontal: 20,
    paddingVertical: 12,
  },
  infoText: {
    fontSize: 12,
    color: '#666',
    lineHeight: 18,
    fontStyle: 'italic',
  },
});
