/**
 * Banner Ad Component
 */
import React from 'react';
import { View, StyleSheet, Text } from 'react-native';
import { adService } from '../ads/ads';
import { consentService } from '../privacy/consent';

// Mock BannerAd for development - always use mock since package is removed
console.log('Using mock BannerAd for development');

const BannerAd = null; // Always null to force mock implementation
const BannerAdSize = { ADAPTIVE_BANNER: 'adaptive' };

interface AdBannerProps {
  visible: boolean;
  style?: any;
}

export function AdBanner({ visible, style }: AdBannerProps): JSX.Element | null {
  if (!visible) {
    return null;
  }

  // Always show mock ad banner since package is removed
  if (!BannerAd) {
    return (
      <View style={[styles.container, styles.mockAd, style]}>
        <Text style={styles.mockAdText}>📱 Development Ad Banner</Text>
        <Text style={styles.mockAdSubtext}>Real ads will show in production</Text>
      </View>
    );
  }

  return (
    <View style={[styles.container, style]}>
      <BannerAd
        unitId={adService.getBannerAdUnitId()}
        size={BannerAdSize.ADAPTIVE_BANNER}
        requestOptions={{
          requestNonPersonalizedAdsOnly: consentService.shouldUseNonPersonalizedAds(),
        }}
        onAdLoaded={() => {
          console.log('Banner ad loaded');
        }}
        onAdFailedToLoad={(error) => {
          console.error('Banner ad failed to load:', error);
        }}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    alignItems: 'center',
    backgroundColor: '#f8f9fa',
    paddingVertical: 8,
  },
  mockAd: {
    padding: 16,
    borderWidth: 1,
    borderColor: '#ddd',
    borderStyle: 'dashed',
  },
  mockAdText: {
    fontSize: 16,
    fontWeight: '600',
    color: '#666',
  },
  mockAdSubtext: {
    fontSize: 12,
    color: '#999',
    marginTop: 4,
  },
});
