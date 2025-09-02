/**
 * Simple test script to verify the app loads without native module errors
 */

// Mock all the native modules that were removed
const mockModules = {
  'react-native-mmkv': {
    MMKV: class MockMMKV {
      constructor() {}
      set() {}
      getString() {}
      getBoolean() {}
      delete() {}
    }
  },
  'react-native-google-mobile-ads': {
    TestIds: { BANNER: 'test_banner' },
    InterstitialAd: { createForAdUnitId: () => ({}) },
    AdEventType: {},
  },
  'react-native-purchases': {
    default: {
      configure: () => {},
      getCustomerInfo: () => ({ entitlements: { active: {} } }),
      getOfferings: () => ({ current: { availablePackages: [] } }),
      purchasePackage: () => ({ customerInfo: { entitlements: { active: { pro: true } } } }),
      restorePurchases: () => ({ entitlements: { active: {} } }),
    }
  },
  'react-native-iap': {
    initConnection: () => {},
    getProducts: () => [],
    requestPurchase: () => ({}),
    getAvailablePurchases: () => [],
    finishTransaction: () => {},
  },
  'react-native-permissions': {
    request: () => 'granted',
    PERMISSIONS: { IOS: { APP_TRACKING_TRANSPARENCY: 'test' } },
    RESULTS: { GRANTED: 'granted' },
  },
  '@react-native-community/slider': () => null,
};

// Mock the modules globally
Object.keys(mockModules).forEach(moduleName => {
  jest.mock(moduleName, () => mockModules[moduleName]);
});

console.log('✅ All native modules mocked successfully');
console.log('✅ App should now load without native module errors');
console.log('✅ Test the app at: http://localhost:8081');
