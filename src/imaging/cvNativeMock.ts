/**
 * Mock CV implementation for development
 */
import { GridDetectionResult, ProcessingParams } from '../types';
import { Point } from '../types';

export const mockCVNative = {
  detectGridAndCorners: async (inputUri: string): Promise<GridDetectionResult> => {
    console.log('Mock: Detecting grid corners for', inputUri);
    
    // Simulate a delay for more realistic behavior
    await new Promise(resolve => setTimeout(resolve, 1000));
    
    // Return mock grid corners positioned for the center grid area of a hemocytometer
    // These coordinates should be adjusted based on typical image dimensions
    return {
      corners: [
        { x: 150, y: 120 },  // Top-left of center grid
        { x: 550, y: 120 },  // Top-right of center grid
        { x: 550, y: 420 },  // Bottom-right of center grid
        { x: 150, y: 420 }   // Bottom-left of center grid
      ],
      gridType: 'neubauer',
      pixelsPerMicron: 5.2,
      focusScore: 0.85,
      glareRatio: 0.05
    };
  },

  perspectiveCorrect: async (inputUri: string, corners: [Point, Point, Point, Point]): Promise<string> => {
    console.log('Mock: Applying perspective correction');
    // Return original image URI so it displays in development
    return inputUri;
  },

  segmentCells: async (correctedImageUri: string, params: ProcessingParams) => {
    console.log('Mock: Segmenting cells from', correctedImageUri);
    // Return mock cell detection results
    return {
      binaryMaskUri: 'mock_mask_uri',
      contours: [
        {
          id: 'cell_1',
          areaPx: 6000,
          circularity: 0.85,
          bbox: { x: 200, y: 150, width: 80, height: 80 },
          centroid: { x: 240, y: 190 }
        },
        {
          id: 'cell_2',
          areaPx: 8000,
          circularity: 0.88,
          bbox: { x: 300, y: 200, width: 90, height: 90 },
          centroid: { x: 345, y: 245 }
        }
      ]
    };
  },

  watershedSplit: async (correctedImageUri: string, binaryMaskUri: string): Promise<string> => {
    console.log('Mock: Applying watershed splitting');
    return 'mock_watershed_mask_uri';
  },

  colorStats: async (correctedImageUri: string, objects: Array<{ id: string; centroid: Point }>) => {
    console.log('Mock: Analyzing color statistics');
    return objects.map(obj => ({
      id: obj.id,
      colorStats: {
        hue: Math.random() * 360,
        saturation: 0.7 + Math.random() * 0.3,
        value: 0.6 + Math.random() * 0.4,
        isLive: Math.random() > 0.3 // 70% live cells
      }
    }));
  }
};

export const mockCVNativeAdapter = {
  detectGridAndCorners: mockCVNative.detectGridAndCorners,
  perspectiveCorrect: mockCVNative.perspectiveCorrect,
  segmentCells: mockCVNative.segmentCells,
  watershedSplit: mockCVNative.watershedSplit,
  colorStats: mockCVNative.colorStats
};
