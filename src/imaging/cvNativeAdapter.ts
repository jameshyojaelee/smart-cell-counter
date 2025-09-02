/**
 * Cross-platform native module adapter
 * Routes to iOS Vision/CoreML on iOS, OpenCV/TFLite on Android
 */
import { Platform } from 'react-native';
import { Point, GridDetectionResult, ProcessingParams } from '../types';
import { mockCVNative } from './cvNativeMock';

export interface CrossPlatformCVModule {
  detectGridAndCorners(inputUri: string): Promise<GridDetectionResult>;
  perspectiveCorrect(inputUri: string, corners: [Point, Point, Point, Point]): Promise<string>;
  segmentCells(
    correctedImageUri: string,
    params: ProcessingParams
  ): Promise<{
    binaryMaskUri: string;
    contours: Array<{
      id: string;
      areaPx: number;
      circularity: number;
      bbox: { x: number; y: number; width: number; height: number };
      centroid: Point;
    }>;
  }>;
  watershedSplit(correctedImageUri: string, binaryMaskUri: string): Promise<string>;
  colorStats(
    correctedImageUri: string,
    objects: Array<{ id: string; centroid: Point }>
  ): Promise<Array<{ id: string; colorStats: any }>>;
}

class CrossPlatformAdapter implements CrossPlatformCVModule {
  async detectGridAndCorners(inputUri: string): Promise<GridDetectionResult> {
    console.log(`Mock CV: Detecting grid for ${Platform.OS}`);
    return await mockCVNative.detectGridAndCorners(inputUri);
  }

  async perspectiveCorrect(
    inputUri: string,
    corners: [Point, Point, Point, Point]
  ): Promise<string> {
    console.log(`Mock CV: Applying perspective correction for ${Platform.OS}`);
    return await mockCVNative.perspectiveCorrect(inputUri, corners);
  }

  async segmentCells(
    correctedImageUri: string,
    params: ProcessingParams
  ): Promise<{
    binaryMaskUri: string;
    contours: Array<{
      id: string;
      areaPx: number;
      circularity: number;
      bbox: { x: number; y: number; width: number; height: number };
      centroid: Point;
    }>;
  }> {
    console.log(`Mock CV: Segmenting cells for ${Platform.OS}`);
    return await mockCVNative.segmentCells(correctedImageUri, params);
  }

  async watershedSplit(correctedImageUri: string, binaryMaskUri: string): Promise<string> {
    console.log(`Mock CV: Applying watershed splitting for ${Platform.OS}`);
    return await mockCVNative.watershedSplit(correctedImageUri, binaryMaskUri);
  }

  async colorStats(
    correctedImageUri: string,
    objects: Array<{ id: string; centroid: Point }>
  ): Promise<Array<{ id: string; colorStats: any }>> {
    console.log(`Mock CV: Analyzing color statistics for ${Platform.OS}`);
    return await mockCVNative.colorStats(correctedImageUri, objects);
  }
}

export const cvNativeAdapter = new CrossPlatformAdapter();
