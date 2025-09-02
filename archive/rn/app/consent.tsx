/**
 * Consent Screen - Privacy preferences for first-time users
 */
import React, { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  ScrollView,
  Switch,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { router } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { consentService } from '../src/privacy/consent';
import { useAppStore } from '../src/state/store';
import { logUserInteraction } from '../src/utils/logger';

export default function ConsentScreen(): JSX.Element {
  const [adPersonalization, setAdPersonalization] = useState<boolean>(false);
  const [crashReporting, setCrashReporting] = useState<boolean>(false);
  const [analytics, setAnalytics] = useState<boolean>(false);

  const initializePurchases = useAppStore((state) => state.initializePurchases);

  const handleContinue = async (): Promise<void> => {
    try {
      // Save consent preferences
      consentService.updateConsent({
        adPersonalizationConsent: adPersonalization,
        crashReportingConsent: crashReporting,
        analyticsConsent: analytics,
      });
      
      // Mark consent screen as shown
      consentService.markConsentScreenShown();

      // Log the consent interaction
      logUserInteraction('Consent', 'Submit', {
        adPersonalization,
        crashReporting,
        analytics,
      });

      // Initialize purchases and ads based on consent
      await initializePurchases();

      // Navigate to main app
      router.replace('/');
    } catch (error) {
      console.error('Failed to save consent:', error);
      // Continue anyway to not block the user
      router.replace('/');
    }
  };

  return (
    <SafeAreaView style={styles.container}>
      <ScrollView style={styles.scrollView} showsVerticalScrollIndicator={false}>
        {/* Header */}
        <View style={styles.header}>
          <View style={styles.iconContainer}>
            <Ionicons name="shield-checkmark" size={48} color="#007AFF" />
          </View>
          <Text style={styles.title}>Privacy & Data Usage</Text>
          <Text style={styles.subtitle}>
            Help us provide you with the best experience while respecting your privacy
          </Text>
        </View>

        {/* Data Usage Explanation */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>How We Use Data</Text>
          <View style={styles.dataPoint}>
            <Ionicons name="cellular" size={20} color="#34C759" />
            <View style={styles.dataPointText}>
              <Text style={styles.dataPointTitle}>Cell Counting Data</Text>
              <Text style={styles.dataPointDescription}>
                All your cell counting data stays on your device. We never upload or access your research data.
              </Text>
            </View>
          </View>
          <View style={styles.dataPoint}>
            <Ionicons name="analytics" size={20} color="#FF9500" />
            <View style={styles.dataPointText}>
              <Text style={styles.dataPointTitle}>App Usage Analytics</Text>
              <Text style={styles.dataPointDescription}>
                Basic app usage statistics to improve features and performance (optional).
              </Text>
            </View>
          </View>
          <View style={styles.dataPoint}>
            <Ionicons name="warning" size={20} color="#FF3B30" />
            <View style={styles.dataPointText}>
              <Text style={styles.dataPointTitle}>Crash Reports</Text>
              <Text style={styles.dataPointDescription}>
                Automatic crash reports help us fix bugs and improve stability (optional).
              </Text>
            </View>
          </View>
        </View>

        {/* Consent Options */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Your Preferences</Text>
          
          <View style={styles.consentOption}>
            <View style={styles.consentInfo}>
              <Text style={styles.consentTitle}>Personalized Advertisements</Text>
              <Text style={styles.consentDescription}>
                Allow personalized ads based on your interests. If disabled, you'll see non-personalized ads instead.
              </Text>
            </View>
            <Switch
              value={adPersonalization}
              onValueChange={setAdPersonalization}
              trackColor={{ false: '#E5E5EA', true: '#007AFF' }}
              thumbColor="#fff"
            />
          </View>

          <View style={styles.consentOption}>
            <View style={styles.consentInfo}>
              <Text style={styles.consentTitle}>Crash Reporting</Text>
              <Text style={styles.consentDescription}>
                Automatically send crash reports to help us improve app stability.
              </Text>
            </View>
            <Switch
              value={crashReporting}
              onValueChange={setCrashReporting}
              trackColor={{ false: '#E5E5EA', true: '#34C759' }}
              thumbColor="#fff"
            />
          </View>

          <View style={styles.consentOption}>
            <View style={styles.consentInfo}>
              <Text style={styles.consentTitle}>Usage Analytics</Text>
              <Text style={styles.consentDescription}>
                Share anonymous usage statistics to help us understand how features are used.
              </Text>
            </View>
            <Switch
              value={analytics}
              onValueChange={setAnalytics}
              trackColor={{ false: '#E5E5EA', true: '#FF9500' }}
              thumbColor="#fff"
            />
          </View>
        </View>

        {/* Privacy Assurance */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Our Privacy Commitment</Text>
          <View style={styles.commitmentList}>
            <View style={styles.commitment}>
              <Ionicons name="checkmark-circle" size={20} color="#34C759" />
              <Text style={styles.commitmentText}>
                Your cell counting data never leaves your device
              </Text>
            </View>
            <View style={styles.commitment}>
              <Ionicons name="checkmark-circle" size={20} color="#34C759" />
              <Text style={styles.commitmentText}>
                No personal health information is collected
              </Text>
            </View>
            <View style={styles.commitment}>
              <Ionicons name="checkmark-circle" size={20} color="#34C759" />
              <Text style={styles.commitmentText}>
                You can change these preferences anytime in Settings
              </Text>
            </View>
            <View style={styles.commitment}>
              <Ionicons name="checkmark-circle" size={20} color="#34C759" />
              <Text style={styles.commitmentText}>
                This app is for research use only, not medical diagnosis
              </Text>
            </View>
          </View>
        </View>

        {/* Legal Notice */}
        <View style={styles.legalSection}>
          <Text style={styles.legalTitle}>Important Notice</Text>
          <Text style={styles.legalText}>
            This application is intended for research and educational purposes only. 
            It is not a medical device and should not be used for clinical diagnosis 
            or treatment decisions.
          </Text>
        </View>
      </ScrollView>

      {/* Continue Button */}
      <View style={styles.actionContainer}>
        <TouchableOpacity style={styles.continueButton} onPress={handleContinue}>
          <Text style={styles.continueButtonText}>Continue to App</Text>
          <Ionicons name="arrow-forward" size={20} color="#fff" />
        </TouchableOpacity>
        
        <Text style={styles.changeNote}>
          You can change these preferences anytime in Settings
        </Text>
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
    alignItems: 'center',
    paddingVertical: 32,
    paddingHorizontal: 20,
  },
  iconContainer: {
    width: 80,
    height: 80,
    borderRadius: 40,
    backgroundColor: '#F0F8FF',
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 16,
  },
  title: {
    fontSize: 28,
    fontWeight: 'bold',
    color: '#333',
    marginBottom: 8,
    textAlign: 'center',
  },
  subtitle: {
    fontSize: 16,
    color: '#666',
    textAlign: 'center',
    lineHeight: 24,
  },
  section: {
    backgroundColor: '#fff',
    marginHorizontal: 20,
    marginBottom: 16,
    borderRadius: 12,
    padding: 20,
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: '600',
    color: '#333',
    marginBottom: 16,
  },
  dataPoint: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    marginBottom: 16,
    gap: 12,
  },
  dataPointText: {
    flex: 1,
  },
  dataPointTitle: {
    fontSize: 16,
    fontWeight: '500',
    color: '#333',
    marginBottom: 4,
  },
  dataPointDescription: {
    fontSize: 14,
    color: '#666',
    lineHeight: 20,
  },
  consentOption: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    marginBottom: 20,
    gap: 16,
  },
  consentInfo: {
    flex: 1,
  },
  consentTitle: {
    fontSize: 16,
    fontWeight: '500',
    color: '#333',
    marginBottom: 4,
  },
  consentDescription: {
    fontSize: 14,
    color: '#666',
    lineHeight: 20,
  },
  commitmentList: {
    gap: 12,
  },
  commitment: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
  },
  commitmentText: {
    fontSize: 14,
    color: '#333',
    flex: 1,
    lineHeight: 20,
  },
  legalSection: {
    backgroundColor: '#FFF9E6',
    marginHorizontal: 20,
    marginBottom: 16,
    borderRadius: 12,
    padding: 20,
    borderWidth: 1,
    borderColor: '#FFE066',
  },
  legalTitle: {
    fontSize: 16,
    fontWeight: '600',
    color: '#B8860B',
    marginBottom: 8,
  },
  legalText: {
    fontSize: 14,
    color: '#8B7000',
    lineHeight: 20,
  },
  actionContainer: {
    padding: 20,
    backgroundColor: '#fff',
    borderTopWidth: 1,
    borderTopColor: '#E5E5EA',
  },
  continueButton: {
    backgroundColor: '#007AFF',
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 16,
    borderRadius: 12,
    marginBottom: 12,
    gap: 8,
  },
  continueButtonText: {
    fontSize: 18,
    fontWeight: '600',
    color: '#fff',
  },
  changeNote: {
    fontSize: 12,
    color: '#666',
    textAlign: 'center',
  },
});
