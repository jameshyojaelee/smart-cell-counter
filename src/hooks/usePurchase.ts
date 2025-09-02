/**
 * Convenience hooks for purchase state
 */
import { useAppStore } from '../state/store';

/**
 * Hook to get Pro status
 */
export function useIsPro(): boolean {
  return useAppStore((state) => state.purchase.isPro);
}

/**
 * Hook to get whether ads should be shown
 */
export function useShouldShowAds(): boolean {
  return useAppStore((state) => state.purchase.shouldShowAds);
}

/**
 * Hook to get purchase state and actions
 */
export function usePurchase() {
  const purchase = useAppStore((state) => state.purchase);
  const setPurchaseState = useAppStore((state) => state.setPurchaseState);
  const initializePurchases = useAppStore((state) => state.initializePurchases);
  const purchasePro = useAppStore((state) => state.purchasePro);
  const restorePurchases = useAppStore((state) => state.restorePurchases);

  return {
    ...purchase,
    setPurchaseState,
    initializePurchases,
    purchasePro,
    restorePurchases,
  };
}

/**
 * Hook to get Pro features availability
 */
export function useProFeatures() {
  const isPro = useIsPro();
  
  return {
    isPro,
    canRemoveWatermark: isPro,
    canUseAdvancedSettings: isPro,
    canUseBatchExport: isPro,
    canUseCustomGridPresets: isPro,
    canUseMultipleStainProfiles: isPro,
    canUsePriorityProcessing: isPro,
    canAccessPerSquareStats: isPro,
  };
}
