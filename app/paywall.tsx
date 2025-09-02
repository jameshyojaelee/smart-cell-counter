/**
 * Paywall Screen - Pro upgrade and feature comparison
 */
import React, { useEffect, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  ScrollView,
  Alert,
  ActivityIndicator,
  Linking,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { router } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { usePurchase } from '../src/hooks/usePurchase';
import { logUserInteraction } from '../src/utils/logger';

interface Feature {
  icon: keyof typeof Ionicons.glyphMap;
  title: string;
  free: string;
  pro: string;
  highlight?: boolean;
}

const features: Feature[] = [
  {
    icon: 'camera',
    title: 'Cell Counting',
    free: 'Full counting pipeline',
    pro: 'Full counting pipeline',
  },
  {
    icon: 'analytics',
    title: 'Basic Analysis',
    free: 'Standard viability & concentration',
    pro: 'Standard viability & concentration',
  },
  {
    icon: 'document-text',
    title: 'CSV Export',
    free: 'Basic CSV export',
    pro: 'Advanced CSV with per-square stats',
    highlight: true,
  },
  {
    icon: 'document',
    title: 'PDF Reports',
    free: 'With watermark',
    pro: 'Professional, no watermark',
    highlight: true,
  },
  {
    icon: 'flash',
    title: 'Processing Speed',
    free: 'Standard processing',
    pro: 'Priority ML processing',
    highlight: true,
  },
  {
    icon: 'grid',
    title: 'Grid Presets',
    free: 'Standard presets',
    pro: 'Custom grid configurations',
    highlight: true,
  },
  {
    icon: 'color-palette',
    title: 'Stain Profiles',
    free: 'Trypan blue only',
    pro: 'Multiple stain types',
    highlight: true,
  },
  {
    icon: 'cloud-upload',
    title: 'Batch Export',
    free: 'One at a time',
    pro: 'Batch export multiple samples',
    highlight: true,
  },
  {
    icon: 'ban',
    title: 'Advertisements',
    free: 'Light ads outside counting flow',
    pro: 'Completely ad-free experience',
    highlight: true,
  },
];

export default function PaywallScreen(): JSX.Element {
  const {
    isPro,
    isLoading,
    products,
    error,
    purchasePro,
    restorePurchases,
  } = usePurchase();

  const [selectedPlan, setSelectedPlan] = useState<string>('lifetime');

  useEffect(() => {
    logUserInteraction('Paywall', 'View');
  }, []);

  const handlePurchase = async (): Promise<void> => {
    try {
      logUserInteraction('Paywall', 'PurchaseAttempt');
      const success = await purchasePro();
      
      if (success) {
        logUserInteraction('Paywall', 'PurchaseSuccess');
        Alert.alert(
          'Welcome to Pro!',
          'You now have access to all premium features. Enjoy your ad-free experience!',
          [{ text: 'Continue', onPress: () => router.back() }]
        );
      }
    } catch (error) {
      logUserInteraction('Paywall', 'PurchaseError', { error: String(error) });
      Alert.alert('Purchase Failed', 'Please try again or contact support if the problem persists.');
    }
  };

  const handleRestore = async (): Promise<void> => {
    try {
      logUserInteraction('Paywall', 'RestoreAttempt');
      const success = await restorePurchases();
      
      if (success) {
        logUserInteraction('Paywall', 'RestoreSuccess');
        Alert.alert(
          'Purchases Restored!',
          'Your Pro features have been restored.',
          [{ text: 'Continue', onPress: () => router.back() }]
        );
      } else {
        Alert.alert(
          'No Purchases Found',
          'We couldn\'t find any purchases to restore. If you believe this is an error, please contact support.'
        );
      }
    } catch (error) {
      logUserInteraction('Paywall', 'RestoreError', { error: String(error) });
      Alert.alert('Restore Failed', 'Please try again or contact support if the problem persists.');
    }
  };

  const handleContinueFree = (): void => {
    logUserInteraction('Paywall', 'ContinueFree');
    router.back();
  };

  const openPrivacyPolicy = (): void => {
    // Replace with your actual privacy policy URL
    Linking.openURL('https://smartcellcounter.com/privacy');
  };

  const openTermsOfService = (): void => {
    // Replace with your actual terms of service URL
    Linking.openURL('https://smartcellcounter.com/terms');
  };

  const getPrice = (): string => {
    const product = products.find(p => p.id.includes('pro') || p.id === 'lifetime');
    return product?.localizedPrice || product?.price || '$9.99';
  };

  if (isPro) {
    return (
      <SafeAreaView style={styles.container}>
        <View style={styles.proContainer}>
          <Ionicons name="checkmark-circle" size={64} color="#34C759" />
          <Text style={styles.proTitle}>You're Pro!</Text>
          <Text style={styles.proSubtitle}>
            Enjoy all premium features with no ads.
          </Text>
          <TouchableOpacity style={styles.continueButton} onPress={() => router.back()}>
            <Text style={styles.continueButtonText}>Continue</Text>
          </TouchableOpacity>
        </View>
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView style={styles.container}>
      <ScrollView style={styles.scrollView} showsVerticalScrollIndicator={false}>
        {/* Header */}
        <View style={styles.header}>
          <TouchableOpacity style={styles.closeButton} onPress={() => router.back()}>
            <Ionicons name="close" size={24} color="#666" />
          </TouchableOpacity>
          <Text style={styles.title}>Upgrade to Pro</Text>
          <Text style={styles.subtitle}>
            Unlock premium features and remove ads
          </Text>
        </View>

        {/* Pricing Card */}
        <View style={styles.pricingCard}>
          <View style={styles.pricingHeader}>
            <Text style={styles.pricingTitle}>Smart Cell Counter Pro</Text>
            <Text style={styles.pricingSubtitle}>One-time purchase</Text>
          </View>
          
          <View style={styles.priceContainer}>
            <Text style={styles.price}>{getPrice()}</Text>
            <Text style={styles.priceNote}>Lifetime access</Text>
          </View>

          <View style={styles.highlights}>
            <View style={styles.highlight}>
              <Ionicons name="checkmark-circle" size={20} color="#34C759" />
              <Text style={styles.highlightText}>Remove all advertisements</Text>
            </View>
            <View style={styles.highlight}>
              <Ionicons name="checkmark-circle" size={20} color="#34C759" />
              <Text style={styles.highlightText}>Professional PDF reports</Text>
            </View>
            <View style={styles.highlight}>
              <Ionicons name="checkmark-circle" size={20} color="#34C759" />
              <Text style={styles.highlightText}>Advanced analysis features</Text>
            </View>
            <View style={styles.highlight}>
              <Ionicons name="checkmark-circle" size={20} color="#34C759" />
              <Text style={styles.highlightText}>Priority ML processing</Text>
            </View>
          </View>
        </View>

        {/* Feature Comparison */}
        <View style={styles.featuresContainer}>
          <Text style={styles.featuresTitle}>Feature Comparison</Text>
          
          <View style={styles.featureHeader}>
            <Text style={styles.featureHeaderText}>Feature</Text>
            <Text style={styles.featureHeaderText}>Free</Text>
            <Text style={styles.featureHeaderText}>Pro</Text>
          </View>

          {features.map((feature, index) => (
            <View key={index} style={[
              styles.featureRow,
              feature.highlight && styles.featureRowHighlight
            ]}>
              <View style={styles.featureInfo}>
                <Ionicons 
                  name={feature.icon} 
                  size={20} 
                  color={feature.highlight ? "#007AFF" : "#666"} 
                />
                <Text style={[
                  styles.featureTitle,
                  feature.highlight && styles.featureTitleHighlight
                ]}>
                  {feature.title}
                </Text>
              </View>
              <Text style={styles.featureFree}>{feature.free}</Text>
              <Text style={styles.featurePro}>{feature.pro}</Text>
            </View>
          ))}
        </View>

        {/* Legal Footer */}
        <View style={styles.legalContainer}>
          <Text style={styles.disclaimer}>
            This is not a medical device. For research and educational purposes only.
          </Text>
          <View style={styles.legalLinks}>
            <TouchableOpacity onPress={openPrivacyPolicy}>
              <Text style={styles.legalLink}>Privacy Policy</Text>
            </TouchableOpacity>
            <Text style={styles.legalSeparator}>•</Text>
            <TouchableOpacity onPress={openTermsOfService}>
              <Text style={styles.legalLink}>Terms of Service</Text>
            </TouchableOpacity>
          </View>
        </View>
      </ScrollView>

      {/* Action Buttons */}
      <View style={styles.actionContainer}>
        {error && (
          <Text style={styles.errorText}>{error}</Text>
        )}
        
        <TouchableOpacity
          style={[styles.purchaseButton, isLoading && styles.purchaseButtonDisabled]}
          onPress={handlePurchase}
          disabled={isLoading}
        >
          {isLoading ? (
            <ActivityIndicator color="#fff" />
          ) : (
            <>
              <Text style={styles.purchaseButtonText}>
                Upgrade to Pro {getPrice()}
              </Text>
              <Ionicons name="arrow-forward" size={20} color="#fff" />
            </>
          )}
        </TouchableOpacity>

        <View style={styles.secondaryActions}>
          <TouchableOpacity
            style={styles.restoreButton}
            onPress={handleRestore}
            disabled={isLoading}
          >
            <Text style={styles.restoreButtonText}>Restore Purchases</Text>
          </TouchableOpacity>

          <TouchableOpacity
            style={styles.continueButton}
            onPress={handleContinueFree}
          >
            <Text style={styles.continueButtonText}>Continue Free</Text>
          </TouchableOpacity>
        </View>
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
    paddingVertical: 20,
    paddingHorizontal: 20,
    position: 'relative',
  },
  closeButton: {
    position: 'absolute',
    top: 20,
    right: 20,
    width: 32,
    height: 32,
    borderRadius: 16,
    backgroundColor: '#f0f0f0',
    alignItems: 'center',
    justifyContent: 'center',
  },
  title: {
    fontSize: 28,
    fontWeight: 'bold',
    color: '#333',
    marginBottom: 8,
  },
  subtitle: {
    fontSize: 16,
    color: '#666',
    textAlign: 'center',
  },
  pricingCard: {
    backgroundColor: '#fff',
    marginHorizontal: 20,
    marginBottom: 20,
    borderRadius: 16,
    padding: 24,
    elevation: 4,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 8,
  },
  pricingHeader: {
    alignItems: 'center',
    marginBottom: 16,
  },
  pricingTitle: {
    fontSize: 20,
    fontWeight: '600',
    color: '#333',
    marginBottom: 4,
  },
  pricingSubtitle: {
    fontSize: 14,
    color: '#666',
  },
  priceContainer: {
    alignItems: 'center',
    marginBottom: 20,
  },
  price: {
    fontSize: 36,
    fontWeight: 'bold',
    color: '#007AFF',
    marginBottom: 4,
  },
  priceNote: {
    fontSize: 14,
    color: '#666',
  },
  highlights: {
    gap: 12,
  },
  highlight: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
  },
  highlightText: {
    fontSize: 16,
    color: '#333',
    flex: 1,
  },
  featuresContainer: {
    backgroundColor: '#fff',
    marginHorizontal: 20,
    marginBottom: 20,
    borderRadius: 16,
    padding: 20,
  },
  featuresTitle: {
    fontSize: 18,
    fontWeight: '600',
    color: '#333',
    marginBottom: 16,
    textAlign: 'center',
  },
  featureHeader: {
    flexDirection: 'row',
    paddingVertical: 12,
    borderBottomWidth: 1,
    borderBottomColor: '#E5E5EA',
    marginBottom: 8,
  },
  featureHeaderText: {
    fontSize: 14,
    fontWeight: '600',
    color: '#666',
    flex: 1,
    textAlign: 'center',
  },
  featureRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 12,
    borderBottomWidth: 1,
    borderBottomColor: '#F5F5F5',
  },
  featureRowHighlight: {
    backgroundColor: '#F0F8FF',
    marginHorizontal: -10,
    paddingHorizontal: 10,
    borderRadius: 8,
  },
  featureInfo: {
    flexDirection: 'row',
    alignItems: 'center',
    flex: 1,
    gap: 8,
  },
  featureTitle: {
    fontSize: 14,
    color: '#333',
    flex: 1,
  },
  featureTitleHighlight: {
    fontWeight: '500',
    color: '#007AFF',
  },
  featureFree: {
    fontSize: 12,
    color: '#666',
    flex: 1,
    textAlign: 'center',
  },
  featurePro: {
    fontSize: 12,
    color: '#34C759',
    flex: 1,
    textAlign: 'center',
    fontWeight: '500',
  },
  legalContainer: {
    paddingHorizontal: 20,
    paddingVertical: 16,
    alignItems: 'center',
  },
  disclaimer: {
    fontSize: 12,
    color: '#666',
    textAlign: 'center',
    marginBottom: 12,
    fontStyle: 'italic',
  },
  legalLinks: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  legalLink: {
    fontSize: 12,
    color: '#007AFF',
  },
  legalSeparator: {
    fontSize: 12,
    color: '#666',
  },
  actionContainer: {
    padding: 20,
    backgroundColor: '#fff',
    borderTopWidth: 1,
    borderTopColor: '#E5E5EA',
  },
  errorText: {
    fontSize: 14,
    color: '#FF3B30',
    textAlign: 'center',
    marginBottom: 12,
  },
  purchaseButton: {
    backgroundColor: '#007AFF',
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 16,
    borderRadius: 12,
    marginBottom: 16,
    gap: 8,
  },
  purchaseButtonDisabled: {
    backgroundColor: '#ccc',
  },
  purchaseButtonText: {
    fontSize: 18,
    fontWeight: '600',
    color: '#fff',
  },
  secondaryActions: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    gap: 12,
  },
  restoreButton: {
    flex: 1,
    alignItems: 'center',
    paddingVertical: 12,
  },
  restoreButtonText: {
    fontSize: 16,
    color: '#007AFF',
  },
  continueButton: {
    flex: 1,
    alignItems: 'center',
    paddingVertical: 12,
  },
  continueButtonText: {
    fontSize: 16,
    color: '#666',
  },
  proContainer: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    padding: 20,
  },
  proTitle: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#34C759',
    marginTop: 16,
    marginBottom: 8,
  },
  proSubtitle: {
    fontSize: 16,
    color: '#666',
    textAlign: 'center',
    marginBottom: 24,
  },
});
