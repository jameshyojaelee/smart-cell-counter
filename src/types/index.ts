/**
 * Core type definitions for the Smart Cell Counter app
 */

export interface Point {
  x: number;
  y: number;
}

export interface BoundingBox {
  x: number;
  y: number;
  width: number;
  height: number;
}

export interface ColorStats {
  hue: number;
  saturation: number;
  value: number;
  lightness: number;
  a: number;
  b: number;
}

export interface DetectionObject {
  id: string;
  centroid: Point;
  areaPx?: number;
  areaUm2?: number;
  circularity?: number;
  bbox?: BoundingBox;
  colorStats?: ColorStats;
  isLive?: boolean;
  confidence?: number;
  squareIndex?: number;
}

export interface GridDetectionResult {
  corners: [Point, Point, Point, Point];
  gridType: 'neubauer' | 'disposable' | null;
  pixelsPerMicron: number | null;
  focusScore: number;
  glareRatio: number;
}

export interface ProcessingParams {
  thresholdMethod: 'adaptive' | 'otsu';
  blockSize: number;
  C: number;
  minAreaUm2: number;
  maxAreaUm2: number;
  useWatershed: boolean;
  useTFLiteRefinement: boolean;
  // Advanced tunables (optional, safe defaults applied)
  circularityMin?: number; // default 0.4
  circularityMax?: number; // default 1.2
  solidityMin?: number; // default 0.8
  clipLimit?: number; // CLAHE clip limit, default 2.0
  tileGridSize?: number; // CLAHE tile size, default 8
  illuminationKernel?: number; // opening kernel size, default 51
  enableDualThresholding?: boolean; // OR adaptive+Otsu when needed
}

export interface Sample {
  id: string;
  timestamp: number;
  operator: string;
  project: string;
  chamberType: 'neubauer' | 'disposable';
  dilutionFactor: number;
  stainType: string;
  liveTotal: number;
  deadTotal: number;
  concentration: number;
  viability: number;
  squaresUsed: number;
  rejectedSquares: number;
  focusScore: number;
  glareRatio: number;
  imagePath: string;
  maskPath: string;
  pdfPath?: string;
  notes?: string;
  detections: DetectionObject[];
}

export interface SquareCount {
  index: number;
  live: number;
  dead: number;
  total: number;
  isOutlier: boolean;
  isSelected: boolean;
}

export interface QCAlert {
  type: 'focus' | 'glare' | 'overcrowding' | 'undercrowding' | 'variance';
  severity: 'warning' | 'error';
  message: string;
}

export interface ProcessingResult {
  detections: DetectionObject[];
  squareCounts: SquareCount[];
  qcAlerts: QCAlert[];
  concentration: number;
  viability: number;
  processingTimeMs: number;
}

export interface AppSettings {
  defaultChamberType: 'neubauer' | 'disposable';
  defaultStainType: string;
  defaultDilutionFactor: number;
  defaultOperator: string;
  defaultProject: string;
  processingParams: ProcessingParams;
  viabilityThresholds: {
    hueMin: number;
    hueMax: number;
    saturationMin: number;
    valueMax: number;
  };
  qcThresholds: {
    minFocusScore: number;
    maxGlareRatio: number;
    minCellsPerSquare: number;
    maxCellsPerSquare: number;
    maxVarianceMAD: number;
  };
  units: 'metric' | 'imperial';
  enableAnalytics: boolean;
  enableCrashReporting: boolean;
  // Debug tools toggle
  debugMode?: boolean;
}

export interface CameraState {
  isReady: boolean;
  hasPermission: boolean;
  flashMode: 'off' | 'on' | 'auto';
  focusDepth: number;
  exposureLocked: boolean;
}

export interface ProcessingState {
  isProcessing: boolean;
  currentStep: string;
  progress: number;
  error?: string;
}
