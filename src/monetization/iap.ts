/**
 * React Native IAP fallback implementation
 */
// Mock react-native-iap for development since package is removed
console.log('Using mock react-native-iap for development');

const initConnection = async () => console.log('Mock IAP connection initialized');
const endConnection = async () => console.log('Mock IAP connection ended');
const purchaseUpdatedListener = () => ({ remove: () => {} });
const purchaseErrorListener = () => ({ remove: () => {} });
const getProducts = async (productIds: string[]) => productIds.map(id => ({
  productId: id,
  price: '$4.99',
  localizedPrice: '$4.99',
  currency: 'USD',
  title: 'Smart Cell Counter Pro',
  description: 'Unlock all Pro features',
}));
const requestPurchase = async (productId: string) => ({
  productId,
  transactionId: 'mock_transaction_' + Date.now(),
  transactionDate: Date.now(),
  transactionReceipt: 'mock_receipt',
});
const getAvailablePurchases = async () => [];
const finishTransaction = async () => {};

type Product = any;
type Purchase = any;
type SubscriptionPurchase = any;
type PurchaseError = any;
import { Platform } from 'react-native';

// Mock MMKV for development since package is removed
const MockMMKV = class {
  private storage = new Map();
  constructor(options?: any) {}
  set(key: string, value: any) { this.storage.set(key, String(value)); }
  getString(key: string) { return this.storage.get(key); }
  getBoolean(key: string) { return this.storage.get(key) === 'true'; }
  delete(key: string) { this.storage.delete(key); }
};

const storage = new MockMMKV({ id: 'iap' });

// Product IDs
export const IAP_PRODUCT_IDS = {
  PRO: Platform.OS === 'ios' 
    ? 'com.smartcellcounter.pro' 
    : 'com.smartcellcounter.pro',
};

export interface IAPPurchaseState {
  isPro: boolean;
  isLoading: boolean;
  products: Product[];
  error: string | null;
}

class IAPService {
  private initialized = false;
  private listeners: Array<(state: Partial<IAPPurchaseState>) => void> = [];
  private purchaseUpdateSubscription: any;
  private purchaseErrorSubscription: any;

  /**
   * Initialize IAP connection
   */
  async initialize(): Promise<boolean> {
    try {
      const result = await initConnection();
      console.log('IAP connection result:', result);

      // Set up purchase listeners
      this.purchaseUpdateSubscription = purchaseUpdatedListener(
        this.handlePurchaseUpdate
      );
      this.purchaseErrorSubscription = purchaseErrorListener(
        this.handlePurchaseError
      );

      // Load available products
      await this.loadProducts();

      // Check for existing purchases
      await this.checkExistingPurchases();

      this.initialized = true;
      console.log('IAP initialized successfully');
      return true;
    } catch (error) {
      console.error('Failed to initialize IAP:', error);
      this.notifyListeners({ error: `Failed to initialize: ${error}` });
      return false;
    }
  }

  /**
   * Load available products
   */
  async loadProducts(): Promise<Product[]> {
    try {
      if (!this.initialized) {
        throw new Error('IAP not initialized');
      }

      const products = await getProducts({
        skus: [IAP_PRODUCT_IDS.PRO],
      });

      this.notifyListeners({ products });
      return products;
    } catch (error) {
      console.error('Failed to load products:', error);
      this.notifyListeners({ error: `Failed to load products: ${error}` });
      return [];
    }
  }

  /**
   * Purchase Pro upgrade
   */
  async purchasePro(): Promise<boolean> {
    try {
      if (!this.initialized) {
        throw new Error('IAP not initialized');
      }

      this.notifyListeners({ isLoading: true, error: null });

      await requestPurchase({
        sku: IAP_PRODUCT_IDS.PRO,
      });

      // Purchase result will be handled by purchaseUpdatedListener
      return true;
    } catch (error) {
      console.error('Purchase failed:', error);
      this.notifyListeners({ 
        isLoading: false, 
        error: `Purchase failed: ${error}` 
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
        throw new Error('IAP not initialized');
      }

      this.notifyListeners({ isLoading: true, error: null });

      const purchases = await getAvailablePurchases();
      console.log('Available purchases:', purchases);

      const proPurchase = purchases.find(
        purchase => purchase.productId === IAP_PRODUCT_IDS.PRO
      );

      const isPro = !!proPurchase;
      this.setPro(isPro);

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
   * Check for existing purchases on startup
   */
  private async checkExistingPurchases(): Promise<void> {
    try {
      const purchases = await getAvailablePurchases();
      const proPurchase = purchases.find(
        purchase => purchase.productId === IAP_PRODUCT_IDS.PRO
      );

      const isPro = !!proPurchase;
      this.setPro(isPro);
      this.notifyListeners({ isPro });
    } catch (error) {
      console.error('Failed to check existing purchases:', error);
      // Don't notify error for this background check
    }
  }

  /**
   * Handle purchase updates
   */
  private handlePurchaseUpdate = async (purchase: Purchase | SubscriptionPurchase) => {
    console.log('Purchase updated:', purchase);

    try {
      if (purchase.productId === IAP_PRODUCT_IDS.PRO) {
        // Verify purchase if needed (implement server-side verification in production)
        const isValid = this.validatePurchase(purchase);
        
        if (isValid) {
          this.setPro(true);
          this.notifyListeners({ isLoading: false, isPro: true, error: null });
        } else {
          this.notifyListeners({ 
            isLoading: false, 
            error: 'Purchase verification failed' 
          });
        }
      }

      // Finish the transaction
      await finishTransaction({ purchase, isConsumable: false });
    } catch (error) {
      console.error('Failed to process purchase:', error);
      this.notifyListeners({ 
        isLoading: false, 
        error: `Failed to process purchase: ${error}` 
      });
    }
  };

  /**
   * Handle purchase errors
   */
  private handlePurchaseError = (error: PurchaseError) => {
    console.error('Purchase error:', error);
    
    let errorMessage = 'Purchase failed';
    if (error.code === 'E_USER_CANCELLED') {
      errorMessage = 'Purchase cancelled';
    } else if (error.code === 'E_ITEM_UNAVAILABLE') {
      errorMessage = 'Item unavailable';
    } else if (error.code === 'E_NETWORK_ERROR') {
      errorMessage = 'Network error';
    }

    this.notifyListeners({ 
      isLoading: false, 
      error: errorMessage 
    });
  };

  /**
   * Basic purchase validation (implement proper server-side validation in production)
   */
  private validatePurchase(purchase: Purchase | SubscriptionPurchase): boolean {
    // Basic validation - in production, validate with your server
    return !!(purchase.transactionReceipt || purchase.purchaseToken);
  }

  /**
   * Set Pro status and persist to storage
   */
  private setPro(isPro: boolean): void {
    storage.set('isPro', isPro);
  }

  /**
   * Get current Pro status
   */
  getProStatus(): boolean {
    return storage.getBoolean('isPro') || false;
  }

  /**
   * Add listener for purchase state changes
   */
  addListener(listener: (state: Partial<IAPPurchaseState>) => void) {
    this.listeners.push(listener);
  }

  /**
   * Remove listener
   */
  removeListener(listener: (state: Partial<IAPPurchaseState>) => void) {
    this.listeners = this.listeners.filter(l => l !== listener);
  }

  /**
   * Notify all listeners of state changes
   */
  private notifyListeners(state: Partial<IAPPurchaseState>) {
    this.listeners.forEach(listener => listener(state));
  }

  /**
   * Clean up resources
   */
  async cleanup(): Promise<void> {
    try {
      if (this.purchaseUpdateSubscription) {
        this.purchaseUpdateSubscription.remove();
      }
      if (this.purchaseErrorSubscription) {
        this.purchaseErrorSubscription.remove();
      }
      
      if (this.initialized) {
        await endConnection();
      }
      
      this.listeners = [];
      this.initialized = false;
    } catch (error) {
      console.error('Failed to cleanup IAP:', error);
    }
  }

  /**
   * Check if IAP is available
   */
  isAvailable(): boolean {
    return this.initialized;
  }

  /**
   * Get product by ID
   */
  getProduct(productId: string): Product | undefined {
    // This would be populated after loadProducts() is called
    return undefined; // Implementation depends on how you want to cache products
  }
}

export const iapService = new IAPService();
