/**
 * Zustand store for global app state management
 */
import { create } from 'zustand';
import { MMKV } from 'react-native-mmkv';
import {
  Sample,
  AppSettings,
  ProcessingState,
  CameraState,
  ProcessingParams,
  DetectionObject,
} from '../types';
import { revenueCatService } from '../monetization/revenuecat';
import { iapService } from '../monetization/iap';
import { adService } from '../ads/ads';
import { consentService } from '../privacy/consent';

// Initialize MMKV storage
const storage = new MMKV();

// Default settings
const defaultSettings: AppSettings = {
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
};

interface PurchaseState {
  isPro: boolean;
  isLoading: boolean;
  products: Array<{ id: string; price: string; localizedPrice?: string }>;
  error: string | null;
  hasConsent: boolean;
  shouldShowAds: boolean;
}

interface AppState {
  // Settings
  settings: AppSettings;
  updateSettings: (updates: Partial<AppSettings>) => void;
  
  // Current sample being processed
  currentSample: Partial<Sample> | null;
  setCurrentSample: (sample: Partial<Sample> | null) => void;
  updateCurrentSample: (updates: Partial<Sample>) => void;
  
  // Processing state
  processing: ProcessingState;
  setProcessingState: (state: Partial<ProcessingState>) => void;
  
  // Camera state
  camera: CameraState;
  setCameraState: (state: Partial<CameraState>) => void;
  
  // Current image paths
  originalImageUri: string | null;
  correctedImageUri: string | null;
  maskImageUri: string | null;
  setImageUris: (uris: {
    original?: string | null;
    corrected?: string | null;
    mask?: string | null;
  }) => void;
  
  // Detection results
  detections: DetectionObject[];
  setDetections: (detections: DetectionObject[]) => void;
  updateDetection: (id: string, updates: Partial<DetectionObject>) => void;
  
  // UI state
  selectedSquares: number[];
  setSelectedSquares: (squares: number[]) => void;
  
  // Purchase state
  purchase: PurchaseState;
  setPurchaseState: (state: Partial<PurchaseState>) => void;
  
  // Purchase actions
  initializePurchases: () => Promise<void>;
  purchasePro: () => Promise<boolean>;
  restorePurchases: () => Promise<boolean>;
  
  // Actions
  resetSession: () => void;
  loadSettings: () => void;
  saveSettings: () => void;
}

export const useAppStore = create<AppState>((set, get) => ({
  // Settings
  settings: defaultSettings,
  updateSettings: (updates) => {
    set((state) => ({
      settings: { ...state.settings, ...updates },
    }));
    get().saveSettings();
  },
  
  // Current sample
  currentSample: null,
  setCurrentSample: (sample) => set({ currentSample: sample }),
  updateCurrentSample: (updates) => {
    set((state) => ({
      currentSample: state.currentSample
        ? { ...state.currentSample, ...updates }
        : updates,
    }));
  },
  
  // Processing state
  processing: {
    isProcessing: false,
    currentStep: '',
    progress: 0,
  },
  setProcessingState: (state) => {
    set((prev) => ({
      processing: { ...prev.processing, ...state },
    }));
  },
  
  // Camera state
  camera: {
    isReady: false,
    hasPermission: false,
    flashMode: 'off',
    focusDepth: 0,
    exposureLocked: false,
  },
  setCameraState: (state) => {
    set((prev) => ({
      camera: { ...prev.camera, ...state },
    }));
  },
  
  // Image URIs
  originalImageUri: null,
  correctedImageUri: null,
  maskImageUri: null,
  setImageUris: (uris) => {
    set((state) => ({
      originalImageUri: uris.original !== undefined ? uris.original : state.originalImageUri,
      correctedImageUri: uris.corrected !== undefined ? uris.corrected : state.correctedImageUri,
      maskImageUri: uris.mask !== undefined ? uris.mask : state.maskImageUri,
    }));
  },
  
  // Detections
  detections: [],
  setDetections: (detections) => set({ detections }),
  updateDetection: (id, updates) => {
    set((state) => ({
      detections: state.detections.map((det) =>
        det.id === id ? { ...det, ...updates } : det
      ),
    }));
  },
  
  // Selected squares
  selectedSquares: [0, 1, 2, 3], // Default to first 4 squares
  setSelectedSquares: (squares) => set({ selectedSquares: squares }),

  // Purchase state
  purchase: {
    isPro: false,
    isLoading: false,
    products: [],
    error: null,
    hasConsent: false,
    shouldShowAds: false,
  },
  setPurchaseState: (state) => {
    set((prev) => ({
      purchase: { ...prev.purchase, ...state },
    }));
  },

  // Purchase actions
  initializePurchases: async () => {
    try {
      set((prev) => ({ purchase: { ...prev.purchase, isLoading: true, error: null } }));

      // Initialize consent
      const consent = consentService.getConsentState();
      const hasConsent = consentService.hasAdConsent();

      // Initialize ads
      await adService.initialize();
      await adService.setNonPersonalized(consentService.shouldUseNonPersonalizedAds());

      // Try RevenueCat first, fallback to IAP
      let isPro = false;
      let products: Array<{ id: string; price: string; localizedPrice?: string }> = [];

      const revenueCatInitialized = await revenueCatService.initialize();
      if (revenueCatInitialized) {
        console.log('Using RevenueCat for purchases');
        isPro = await revenueCatService.getProStatus();
        
        const offerings = await revenueCatService.getOfferings();
        if (offerings?.current?.availablePackages) {
          products = offerings.current.availablePackages.map(pkg => ({
            id: pkg.identifier,
            price: pkg.product.priceString,
            localizedPrice: pkg.product.priceString,
          }));
        }

        // Set up listener for purchase updates
        revenueCatService.addListener((rcState) => {
          set((prev) => ({
            purchase: {
              ...prev.purchase,
              isPro: rcState.isPro ?? prev.purchase.isPro,
              isLoading: rcState.isLoading ?? prev.purchase.isLoading,
              error: rcState.error ?? prev.purchase.error,
            },
          }));
        });
      } else {
        console.log('Using react-native-iap for purchases');
        const iapInitialized = await iapService.initialize();
        if (iapInitialized) {
          isPro = iapService.getProStatus();
          const iapProducts = await iapService.loadProducts();
          products = iapProducts.map(product => ({
            id: product.productId,
            price: product.localizedPrice,
            localizedPrice: product.localizedPrice,
          }));

          // Set up listener for purchase updates
          iapService.addListener((iapState) => {
            set((prev) => ({
              purchase: {
                ...prev.purchase,
                isPro: iapState.isPro ?? prev.purchase.isPro,
                isLoading: iapState.isLoading ?? prev.purchase.isLoading,
                error: iapState.error ?? prev.purchase.error,
                products: iapState.products ? iapState.products.map(p => ({
                  id: p.productId,
                  price: p.localizedPrice,
                  localizedPrice: p.localizedPrice,
                })) : prev.purchase.products,
              },
            }));
          });
        }
      }

      const shouldShowAds = !isPro && hasConsent;

      set((prev) => ({
        purchase: {
          ...prev.purchase,
          isPro,
          products,
          hasConsent,
          shouldShowAds,
          isLoading: false,
        },
      }));
    } catch (error) {
      console.error('Failed to initialize purchases:', error);
      set((prev) => ({
        purchase: {
          ...prev.purchase,
          isLoading: false,
          error: `Initialization failed: ${error}`,
        },
      }));
    }
  },

  purchasePro: async () => {
    try {
      set((prev) => ({ purchase: { ...prev.purchase, isLoading: true, error: null } }));

      let success = false;

      if (revenueCatService.isAvailable()) {
        const offerings = await revenueCatService.getOfferings();
        const proPackage = offerings?.current?.availablePackages.find(
          pkg => pkg.identifier === 'lifetime' || pkg.product.identifier.includes('pro')
        );
        
        if (proPackage) {
          success = await revenueCatService.purchasePackage(proPackage);
        }
      } else if (iapService.isAvailable()) {
        success = await iapService.purchasePro();
      }

      if (success) {
        set((prev) => ({
          purchase: {
            ...prev.purchase,
            isPro: true,
            shouldShowAds: false,
            isLoading: false,
          },
        }));
      }

      return success;
    } catch (error) {
      console.error('Purchase failed:', error);
      set((prev) => ({
        purchase: {
          ...prev.purchase,
          isLoading: false,
          error: `Purchase failed: ${error}`,
        },
      }));
      return false;
    }
  },

  restorePurchases: async () => {
    try {
      set((prev) => ({ purchase: { ...prev.purchase, isLoading: true, error: null } }));

      let success = false;

      if (revenueCatService.isAvailable()) {
        success = await revenueCatService.restorePurchases();
      } else if (iapService.isAvailable()) {
        success = await iapService.restorePurchases();
      }

      if (success) {
        set((prev) => ({
          purchase: {
            ...prev.purchase,
            isPro: true,
            shouldShowAds: false,
            isLoading: false,
          },
        }));
      } else {
        set((prev) => ({
          purchase: {
            ...prev.purchase,
            isLoading: false,
            error: 'No purchases found to restore',
          },
        }));
      }

      return success;
    } catch (error) {
      console.error('Restore failed:', error);
      set((prev) => ({
        purchase: {
          ...prev.purchase,
          isLoading: false,
          error: `Restore failed: ${error}`,
        },
      }));
      return false;
    }
  },
  
  // Actions
  resetSession: () => {
    set({
      currentSample: null,
      originalImageUri: null,
      correctedImageUri: null,
      maskImageUri: null,
      detections: [],
      processing: {
        isProcessing: false,
        currentStep: '',
        progress: 0,
      },
      selectedSquares: [0, 1, 2, 3],
    });
  },
  
  loadSettings: () => {
    try {
      const savedSettings = storage.getString('app_settings');
      if (savedSettings) {
        const parsed = JSON.parse(savedSettings) as AppSettings;
        set({ settings: { ...defaultSettings, ...parsed } });
      }
    } catch (error) {
      console.warn('Failed to load settings:', error);
    }
  },
  
  saveSettings: () => {
    try {
      const { settings } = get();
      storage.set('app_settings', JSON.stringify(settings));
    } catch (error) {
      console.warn('Failed to save settings:', error);
    }
  },
}));

// Initialize settings on app start
useAppStore.getState().loadSettings();
