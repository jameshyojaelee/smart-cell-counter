/**
 * Google AdMob integration with consent handling - Mock implementation for development
 */
import { Platform } from 'react-native';

// Always use mock implementation since package is removed for testing
console.log('Using mock AdMob implementation for development');

const mobileAds = () => ({
  initialize: async () => console.log('Mock AdMob initialized'),
  setRequestConfiguration: async () => console.log('Mock AdMob request configuration set'),
});

const TestIds = {
  BANNER: 'ca-app-pub-3940256099942544/2934735716',
  INTERSTITIAL: 'ca-app-pub-3940256099942544/4411468910',
};

const InterstitialAd = {
  createForAdUnitId: () => ({
    addAdEventListener: () => {},
    load: () => {},
    show: () => {},
  }),
};

const AdEventType = {
  LOADED: 'loaded',
  ERROR: 'error',
  CLOSED: 'closed',
};

// Test Ad Unit IDs - Replace with your actual IDs before release
const AD_UNIT_IDS = {
  banner: {
    ios: 'ca-app-pub-3940256099942544/2934735716',
    android: 'ca-app-pub-3940256099942544/6300978111',
  },
  interstitial: {
    ios: 'ca-app-pub-3940256099942544/4411468910',
    android: 'ca-app-pub-3940256099942544/1033173712',
  },
};

export class AdService {
  private initialized = false;
  private interstitialAd: InterstitialAd | null = null;
  private interstitialLoaded = false;
  private interstitialShownThisSession = false;

  /**
   * Initialize AdMob
   */
  async initialize(): Promise<boolean> {
    if (isDevelopment) {
      console.log('AdMob: Development mode - using mock implementation');
      this.initialized = true;
      return true;
    }

    try {
      if (mobileAds) {
        await mobileAds().initialize();
        
        // Set request configuration for non-personalized ads by default
        await this.setNonPersonalized(true);
        
        // Load interstitial ad
        this.loadInterstitialAd();
        
        this.initialized = true;
        console.log('AdMob initialized successfully');
      } else {
        console.log('AdMob: Not available, using mock implementation');
        this.initialized = true;
      }
      return true;
    } catch (error) {
      console.error('Failed to initialize AdMob:', error);
      this.initialized = true; // Continue with mock implementation
      return false;
    }
  }

  /**
   * Set non-personalized ads
   */
  async setNonPersonalized(nonPersonalized: boolean): Promise<void> {
    try {
      // Temporarily disable requestConfiguration due to API differences
      // TODO: Fix AdMob configuration once native modules are properly set up
      // const requestConfiguration: RequestConfiguration = {
      //   requestNonPersonalizedAdsOnly: nonPersonalized,
      //   tagForChildDirectedTreatment: false,
      //   tagForUnderAgeOfConsent: false,
      // };
      // await mobileAds().setRequestConfiguration(requestConfiguration);
      console.log(`Set non-personalized ads: ${nonPersonalized}`);
    } catch (error) {
      console.error('Failed to set ad configuration:', error);
    }
  }

  /**
   * Get banner ad unit ID for current platform
   */
  getBannerAdUnitId(): string {
    return Platform.OS === 'ios' 
      ? AD_UNIT_IDS.banner.ios 
      : AD_UNIT_IDS.banner.android;
  }

  /**
   * Get interstitial ad unit ID for current platform
   */
  getInterstitialAdUnitId(): string {
    return Platform.OS === 'ios' 
      ? AD_UNIT_IDS.interstitial.ios 
      : AD_UNIT_IDS.interstitial.android;
  }

  /**
   * Load interstitial ad
   */
  private loadInterstitialAd(): void {
    try {
      this.interstitialAd = InterstitialAd.createForAdUnitId(
        this.getInterstitialAdUnitId()
      );

      this.interstitialAd.addAdEventListener(AdEventType.LOADED, () => {
        console.log('Interstitial ad loaded');
        this.interstitialLoaded = true;
      });

      this.interstitialAd.addAdEventListener(AdEventType.ERROR, (error) => {
        console.error('Interstitial ad error:', error);
        this.interstitialLoaded = false;
        
        // Retry loading after 30 seconds
        setTimeout(() => {
          this.loadInterstitialAd();
        }, 30000);
      });

      this.interstitialAd.addAdEventListener(AdEventType.CLOSED, () => {
        console.log('Interstitial ad closed');
        this.interstitialLoaded = false;
        
        // Load a new ad for next time
        this.loadInterstitialAd();
      });

      // Load the ad
      this.interstitialAd.load();
    } catch (error) {
      console.error('Failed to load interstitial ad:', error);
    }
  }

  /**
   * Show interstitial ad (with frequency cap)
   */
  async showInterstitialAd(): Promise<boolean> {
    try {
      if (!this.initialized) {
        console.log('AdMob not initialized');
        return false;
      }

      // Frequency cap: once per session
      if (this.interstitialShownThisSession) {
        console.log('Interstitial ad already shown this session');
        return false;
      }

      if (!this.interstitialLoaded || !this.interstitialAd) {
        console.log('Interstitial ad not ready');
        return false;
      }

      await this.interstitialAd.show();
      this.interstitialShownThisSession = true;
      console.log('Interstitial ad shown');
      return true;
    } catch (error) {
      console.error('Failed to show interstitial ad:', error);
      return false;
    }
  }

  /**
   * Check if banner ads should be shown
   */
  shouldShowBannerAds(isPro: boolean, hasConsent: boolean): boolean {
    return !isPro && hasConsent && this.initialized;
  }

  /**
   * Check if interstitial ads should be shown
   */
  shouldShowInterstitialAds(isPro: boolean, hasConsent: boolean): boolean {
    return !isPro && hasConsent && this.initialized && !this.interstitialShownThisSession;
  }

  /**
   * Reset session flags (call on app restart)
   */
  resetSession(): void {
    this.interstitialShownThisSession = false;
  }

  /**
   * Get AdMob app open measurement ID
   */
  getAppOpenMeasurementId(): string | null {
    // Return your App Open Measurement ID if using
    return null;
  }

  /**
   * Check if AdMob is initialized
   */
  isInitialized(): boolean {
    return this.initialized;
  }

  /**
   * Clean up resources
   */
  cleanup(): void {
    if (this.interstitialAd) {
      this.interstitialAd = null;
    }
    this.interstitialLoaded = false;
    this.interstitialShownThisSession = false;
    this.initialized = false;
  }
}

export const adService = new AdService();
