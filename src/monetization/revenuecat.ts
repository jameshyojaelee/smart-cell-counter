/**
 * RevenueCat integration for cross-platform in-app purchases
 */
import Purchases, { 
  CustomerInfo, 
  PurchasesPackage,
  PURCHASES_ERROR_CODE 
} from 'react-native-purchases';

// Define types locally since they're not exported correctly
type Offerings = any;
import { Platform } from 'react-native';
import { MMKV } from 'react-native-mmkv';

const storage = new MMKV({ id: 'purchases' });

// Configuration - replace with your actual keys
const REVENUECAT_API_KEYS = {
  ios: process.env.EXPO_PUBLIC_REVENUECAT_IOS_KEY || '',
  android: process.env.EXPO_PUBLIC_REVENUECAT_ANDROID_KEY || '',
};

// Product IDs
export const PRODUCT_IDS = {
  PRO: 'com.smartcellcounter.pro',
};

// Entitlement identifiers
export const ENTITLEMENTS = {
  PRO: 'pro',
};

export interface RevenueCatPurchaseState {
  isPro: boolean;
  isLoading: boolean;
  offerings: Offerings | null;
  customerInfo: CustomerInfo | null;
  error: string | null;
}

class RevenueCatService {
  private initialized = false;
  private listeners: Array<(state: Partial<RevenueCatPurchaseState>) => void> = [];

  /**
   * Initialize RevenueCat SDK
   */
  async initialize(): Promise<boolean> {
    try {
      const apiKey = Platform.OS === 'ios' 
        ? REVENUECAT_API_KEYS.ios 
        : REVENUECAT_API_KEYS.android;

      if (!apiKey) {
        console.log('RevenueCat API key not found, skipping initialization');
        return false;
      }

      // Configure RevenueCat
      await Purchases.configure({ apiKey });
      
      // Set up customer info listener
      Purchases.addCustomerInfoUpdateListener(this.handleCustomerInfoUpdate);
      
      // Get initial customer info
      const customerInfo = await Purchases.getCustomerInfo();
      this.handleCustomerInfoUpdate(customerInfo);
      
      this.initialized = true;
      console.log('RevenueCat initialized successfully');
      return true;
    } catch (error) {
      console.error('Failed to initialize RevenueCat:', error);
      this.notifyListeners({ error: `Failed to initialize: ${error}` });
      return false;
    }
  }

  /**
   * Check if RevenueCat is available and configured
   */
  isAvailable(): boolean {
    const apiKey = Platform.OS === 'ios' 
      ? REVENUECAT_API_KEYS.ios 
      : REVENUECAT_API_KEYS.android;
    return !!apiKey && this.initialized;
  }

  /**
   * Get available offerings
   */
  async getOfferings(): Promise<Offerings | null> {
    try {
      if (!this.initialized) {
        throw new Error('RevenueCat not initialized');
      }

      const offerings = await Purchases.getOfferings();
      this.notifyListeners({ offerings });
      return offerings;
    } catch (error) {
      console.error('Failed to get offerings:', error);
      this.notifyListeners({ error: `Failed to get offerings: ${error}` });
      return null;
    }
  }

  /**
   * Purchase a package
   */
  async purchasePackage(packageToPurchase: PurchasesPackage): Promise<boolean> {
    try {
      if (!this.initialized) {
        throw new Error('RevenueCat not initialized');
      }

      this.notifyListeners({ isLoading: true, error: null });
      
      const { customerInfo } = await Purchases.purchasePackage(packageToPurchase);
      this.handleCustomerInfoUpdate(customerInfo);
      
      const isPro = this.checkProEntitlement(customerInfo);
      this.notifyListeners({ isLoading: false, isPro });
      
      return isPro;
    } catch (error: any) {
      console.error('Purchase failed:', error);
      
      let errorMessage = 'Purchase failed';
      if (error.code === PURCHASES_ERROR_CODE.PURCHASE_CANCELLED_ERROR) {
        errorMessage = 'Purchase cancelled';
      } else if (error.code === PURCHASES_ERROR_CODE.PURCHASE_NOT_ALLOWED_ERROR) {
        errorMessage = 'Purchase not allowed';
      } else if (error.userCancelled) {
        errorMessage = 'Purchase cancelled';
      }
      
      this.notifyListeners({ 
        isLoading: false, 
        error: errorMessage 
      });
      return false;
    }
  }

  /**
   * Restore purchases
   */
  async restorePurchases(): Promise<boolean> {
    try {
      if (!this.initialized) {
        throw new Error('RevenueCat not initialized');
      }

      this.notifyListeners({ isLoading: true, error: null });
      
      const customerInfo = await Purchases.restorePurchases();
      this.handleCustomerInfoUpdate(customerInfo);
      
      const isPro = this.checkProEntitlement(customerInfo);
      this.notifyListeners({ isLoading: false, isPro });
      
      return isPro;
    } catch (error) {
      console.error('Restore failed:', error);
      this.notifyListeners({ 
        isLoading: false, 
        error: `Restore failed: ${error}` 
      });
      return false;
    }
  }

  /**
   * Get current Pro status
   */
  async getProStatus(): Promise<boolean> {
    try {
      if (!this.initialized) {
        return false;
      }

      const customerInfo = await Purchases.getCustomerInfo();
      return this.checkProEntitlement(customerInfo);
    } catch (error) {
      console.error('Failed to get Pro status:', error);
      return false;
    }
  }

  /**
   * Check if user has Pro entitlement
   */
  private checkProEntitlement(customerInfo: CustomerInfo): boolean {
    const entitlement = customerInfo.entitlements.active[ENTITLEMENTS.PRO];
    const isPro = !!entitlement;
    
    // Persist Pro status
    storage.set('isPro', isPro);
    
    return isPro;
  }

  /**
   * Handle customer info updates
   */
  private handleCustomerInfoUpdate = (customerInfo: CustomerInfo) => {
    const isPro = this.checkProEntitlement(customerInfo);
    this.notifyListeners({ customerInfo, isPro });
  };

  /**
   * Add listener for purchase state changes
   */
  addListener(listener: (state: Partial<RevenueCatPurchaseState>) => void) {
    this.listeners.push(listener);
  }

  /**
   * Remove listener
   */
  removeListener(listener: (state: Partial<RevenueCatPurchaseState>) => void) {
    this.listeners = this.listeners.filter(l => l !== listener);
  }

  /**
   * Notify all listeners of state changes
   */
  private notifyListeners(state: Partial<RevenueCatPurchaseState>) {
    this.listeners.forEach(listener => listener(state));
  }

  /**
   * Get cached Pro status from storage
   */
  getCachedProStatus(): boolean {
    return storage.getBoolean('isPro') || false;
  }

  /**
   * Set user attributes for analytics
   */
  async setUserAttributes(attributes: Record<string, string | null>) {
    try {
      if (!this.initialized) return;
      
      await Purchases.setAttributes(attributes);
    } catch (error) {
      console.error('Failed to set user attributes:', error);
    }
  }

  /**
   * Clean up resources
   */
  cleanup() {
    this.listeners = [];
    if (this.initialized) {
      Purchases.removeCustomerInfoUpdateListener(this.handleCustomerInfoUpdate);
    }
  }
}

export const revenueCatService = new RevenueCatService();
