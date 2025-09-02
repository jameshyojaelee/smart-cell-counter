/**
 * Privacy consent management
 */
import { Platform } from 'react-native';
import { MMKV } from 'react-native-mmkv';
import { request, PERMISSIONS, RESULTS } from 'react-native-permissions';

const storage = new MMKV({ id: 'consent' });

export interface ConsentState {
  hasShownConsentScreen: boolean;
  adPersonalizationConsent: boolean | null; // null = not asked, true = yes, false = no
  crashReportingConsent: boolean;
  analyticsConsent: boolean;
  attStatus: 'not-determined' | 'denied' | 'authorized' | 'restricted' | 'unavailable';
}

export class ConsentService {
  /**
   * Get current consent state
   */
  getConsentState(): ConsentState {
    return {
      hasShownConsentScreen: storage.getBoolean('hasShownConsentScreen') || false,
      adPersonalizationConsent: this.getAdPersonalizationConsent(),
      crashReportingConsent: storage.getBoolean('crashReportingConsent') || false,
      analyticsConsent: storage.getBoolean('analyticsConsent') || false,
      attStatus: this.getATTStatus(),
    };
  }

  /**
   * Check if we should show consent screen
   */
  shouldShowConsentScreen(): boolean {
    return !storage.getBoolean('hasShownConsentScreen');
  }

  /**
   * Mark consent screen as shown
   */
  markConsentScreenShown(): void {
    storage.set('hasShownConsentScreen', true);
  }

  /**
   * Set ad personalization consent
   */
  setAdPersonalizationConsent(consent: boolean): void {
    storage.set('adPersonalizationConsent', consent);
    
    // If user consents to personalized ads on iOS, request ATT
    if (consent && Platform.OS === 'ios') {
      this.requestATTPermission();
    }
  }

  /**
   * Get ad personalization consent
   */
  getAdPersonalizationConsent(): boolean | null {
    const stored = storage.getString('adPersonalizationConsent');
    if (stored === undefined) return null;
    return storage.getBoolean('adPersonalizationConsent') ?? null;
  }

  /**
   * Set crash reporting consent
   */
  setCrashReportingConsent(consent: boolean): void {
    storage.set('crashReportingConsent', consent);
  }

  /**
   * Set analytics consent
   */
  setAnalyticsConsent(consent: boolean): void {
    storage.set('analyticsConsent', consent);
  }

  /**
   * Check if we have any ad consent (personalized or non-personalized)
   */
  hasAdConsent(): boolean {
    const consent = this.getAdPersonalizationConsent();
    // If null (not asked), default to non-personalized ads (true)
    // If false, user declined personalized but we can show non-personalized
    // If true, user accepted personalized ads
    return consent !== false; // Only false means no ads at all
  }

  /**
   * Check if we should use non-personalized ads
   */
  shouldUseNonPersonalizedAds(): boolean {
    const consent = this.getAdPersonalizationConsent();
    // Use non-personalized if:
    // - User hasn't been asked (null) - default to non-personalized
    // - User explicitly declined personalized ads (false)
    return consent !== true;
  }

  /**
   * Request App Tracking Transparency permission (iOS only)
   */
  async requestATTPermission(): Promise<string> {
    if (Platform.OS !== 'ios') {
      return 'unavailable';
    }

    try {
      // Note: This requires react-native-permissions
      // You might need to implement this differently based on your setup
      const result = await request(PERMISSIONS.IOS.APP_TRACKING_TRANSPARENCY);
      
      let status: string;
      switch (result) {
        case RESULTS.GRANTED:
          status = 'authorized';
          break;
        case RESULTS.DENIED:
          status = 'denied';
          break;
        case RESULTS.BLOCKED:
          status = 'restricted';
          break;
        case RESULTS.UNAVAILABLE:
          status = 'unavailable';
          break;
        default:
          status = 'not-determined';
      }

      storage.set('attStatus', status);
      return status;
    } catch (error) {
      console.error('Failed to request ATT permission:', error);
      storage.set('attStatus', 'unavailable');
      return 'unavailable';
    }
  }

  /**
   * Get ATT status from storage
   */
  private getATTStatus(): 'not-determined' | 'denied' | 'authorized' | 'restricted' | 'unavailable' {
    const stored = storage.getString('attStatus');
    return (stored as any) || 'not-determined';
  }

  /**
   * Reset all consent (for testing)
   */
  resetConsent(): void {
    storage.clearAll();
  }

  /**
   * Get consent summary for display
   */
  getConsentSummary(): string {
    const state = this.getConsentState();
    const parts: string[] = [];

    if (state.adPersonalizationConsent === true) {
      parts.push('Personalized ads');
    } else if (state.adPersonalizationConsent === false) {
      parts.push('Non-personalized ads only');
    } else {
      parts.push('Non-personalized ads (default)');
    }

    if (state.crashReportingConsent) {
      parts.push('Crash reporting');
    }

    if (state.analyticsConsent) {
      parts.push('Analytics');
    }

    return parts.join(', ') || 'Minimal data usage';
  }

  /**
   * Check if we need to show ATT prompt
   */
  shouldShowATTPrompt(): boolean {
    if (Platform.OS !== 'ios') return false;
    
    const adConsent = this.getAdPersonalizationConsent();
    const attStatus = this.getATTStatus();
    
    // Show ATT prompt if user consented to personalized ads but ATT is not determined
    return adConsent === true && attStatus === 'not-determined';
  }

  /**
   * Update consent preferences
   */
  updateConsent(updates: Partial<{
    adPersonalizationConsent: boolean;
    crashReportingConsent: boolean;
    analyticsConsent: boolean;
  }>): void {
    if (updates.adPersonalizationConsent !== undefined) {
      this.setAdPersonalizationConsent(updates.adPersonalizationConsent);
    }
    
    if (updates.crashReportingConsent !== undefined) {
      this.setCrashReportingConsent(updates.crashReportingConsent);
    }
    
    if (updates.analyticsConsent !== undefined) {
      this.setAnalyticsConsent(updates.analyticsConsent);
    }
  }
}

export const consentService = new ConsentService();
