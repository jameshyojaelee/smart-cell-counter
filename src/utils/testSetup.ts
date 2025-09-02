/**
 * Jest test setup and utilities
 */
import 'react-native-gesture-handler/jestSetup';

// Mock react-native-mmkv if available; otherwise skip to avoid resolver errors in CI
try {
  // Only attempt to mock if module is installed
  require.resolve('react-native-mmkv');
  jest.mock('react-native-mmkv', () => ({
    MMKV: jest.fn().mockImplementation(() => ({
      set: jest.fn(),
      getString: jest.fn(),
      getNumber: jest.fn(),
      getBoolean: jest.fn(),
      delete: jest.fn(),
      clearAll: jest.fn(),
    })),
  }));
} catch (_) {
  // no-op
}

// Mock expo modules
jest.mock('expo-sqlite', () => ({
  openDatabaseAsync: jest.fn().mockResolvedValue({
    execAsync: jest.fn(),
    runAsync: jest.fn(),
    getFirstAsync: jest.fn(),
    getAllAsync: jest.fn(),
    withTransactionAsync: jest.fn((callback) => callback()),
  }),
}));

jest.mock('expo-file-system', () => ({
  documentDirectory: 'file:///mock/documents/',
  writeAsStringAsync: jest.fn(),
  readAsStringAsync: jest.fn(),
  getInfoAsync: jest.fn().mockResolvedValue({ exists: true, size: 1000 }),
  deleteAsync: jest.fn(),
  moveAsync: jest.fn(),
}));

jest.mock('expo-camera', () => ({
  Camera: {
    requestCameraPermissionsAsync: jest.fn().mockResolvedValue({ status: 'granted' }),
    Constants: {
      AutoFocus: { on: 'on' },
    },
  },
  CameraType: { back: 'back', front: 'front' },
  FlashMode: { off: 'off', on: 'on', auto: 'auto' },
}));

jest.mock('expo-image-picker', () => ({
  launchImageLibraryAsync: jest.fn().mockResolvedValue({
    canceled: false,
    assets: [{ uri: 'mock://image.jpg' }],
  }),
  MediaTypeOptions: { Images: 'Images' },
}));

jest.mock('expo-sharing', () => ({
  shareAsync: jest.fn(),
  isAvailableAsync: jest.fn().mockResolvedValue(true),
}));

jest.mock('expo-print', () => ({
  printToFileAsync: jest.fn().mockResolvedValue({ uri: 'mock://report.pdf' }),
}));

// Mock native modules
jest.mock('../imaging/cvNative', () => ({
  cvNative: {
    detectGridAndCorners: jest.fn().mockResolvedValue({
      corners: [
        { x: 100, y: 100 },
        { x: 900, y: 100 },
        { x: 900, y: 900 },
        { x: 100, y: 900 },
      ],
      gridType: 'neubauer',
      pixelsPerMicron: 10.5,
      focusScore: 150.2,
      glareRatio: 0.05,
    }),
    perspectiveCorrect: jest.fn().mockResolvedValue('mock://corrected.jpg'),
    segmentCells: jest.fn().mockResolvedValue({
      binaryMaskUri: 'mock://mask.jpg',
      contours: [],
    }),
    watershedSplit: jest.fn().mockResolvedValue('mock://watershed.jpg'),
    colorStats: jest.fn().mockResolvedValue([]),
  },
}));

// Global test utilities
global.mockSample = {
  id: 'test-sample-1',
  timestamp: Date.now(),
  operator: 'Test User',
  project: 'Test Project',
  chamberType: 'neubauer' as const,
  dilutionFactor: 1.0,
  stainType: 'trypan_blue',
  liveTotal: 150,
  deadTotal: 50,
  concentration: 2000000,
  viability: 75.0,
  squaresUsed: 4,
  rejectedSquares: 0,
  focusScore: 150.2,
  glareRatio: 0.05,
  imagePath: 'mock://image.jpg',
  maskPath: 'mock://mask.jpg',
  detections: [],
};

global.mockDetection = {
  id: 'cell-1',
  centroid: { x: 100, y: 100 },
  areaPx: 150,
  areaUm2: 120,
  circularity: 0.85,
  bbox: { x: 90, y: 90, width: 20, height: 20 },
  isLive: true,
  confidence: 0.92,
  squareIndex: 0,
  colorStats: {
    hue: 220,
    saturation: 0.4,
    value: 0.8,
    lightness: 0.6,
    a: -5,
    b: 10,
  },
};

// Suppress console warnings in tests
global.console = {
  ...console,
  warn: jest.fn(),
  error: jest.fn(),
};
