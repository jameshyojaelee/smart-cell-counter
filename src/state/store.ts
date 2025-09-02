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
