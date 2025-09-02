/**
 * Cross-platform native module adapter
 * iOS: Vision/CoreImage/CoreML via native bridge with OpenCV fallback
 * Android: OpenCV/TFLite via cvNative (currently mocked in this project)
 */
import { Platform } from 'react-native';
import { Point, GridDetectionResult, ProcessingParams } from '../types';
import { cvNative as openCVModule } from './cvNative';
import { detectGridAndCornersIOS, perspectiveCorrectIOS, runCoreMLSegmentationIOS } from './iosBridge';

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
    if (Platform.OS === 'ios') {
      try {
        const result = await detectGridAndCornersIOS(inputUri);
        return {
          corners: result.corners as [Point, Point, Point, Point],
          gridType: result.gridType,
          pixelsPerMicron: result.pixelsPerMicron,
          focusScore: result.focusScore,
          glareRatio: result.glareRatio,
        };
      } catch (e) {
        console.warn('iOS Vision detection failed, falling back to OpenCV', e);
        return await openCVModule.detectGridAndCorners(inputUri);
      }
    }
    // Android or web: use OpenCV module (currently mocked)
    return await openCVModule.detectGridAndCorners(inputUri);
  }

  async perspectiveCorrect(
    inputUri: string,
    corners: [Point, Point, Point, Point]
  ): Promise<string> {
    if (Platform.OS === 'ios') {
      try {
        return await perspectiveCorrectIOS(inputUri, corners);
      } catch (e) {
        console.warn('iOS perspective correction failed, falling back to OpenCV', e);
        return await openCVModule.perspectiveCorrect(inputUri, corners);
      }
    }
    return await openCVModule.perspectiveCorrect(inputUri, corners);
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
    if (Platform.OS === 'ios') {
      try {
        const maskUri = await runCoreMLSegmentationIOS(correctedImageUri);
        if (maskUri) {
          // Extract contours from the image via OpenCV and replace mask with CoreML output
          const result = await openCVModule.segmentCells(correctedImageUri, params);
          return { ...result, binaryMaskUri: maskUri };
        }
      } catch (e) {
        console.warn('iOS Core ML segmentation failed, falling back to OpenCV', e);
      }
    }
    return await openCVModule.segmentCells(correctedImageUri, params);
  }

  async watershedSplit(correctedImageUri: string, binaryMaskUri: string): Promise<string> {
    return await openCVModule.watershedSplit(correctedImageUri, binaryMaskUri);
  }

  async colorStats(
    correctedImageUri: string,
    objects: Array<{ id: string; centroid: Point }>
  ): Promise<Array<{ id: string; colorStats: any }>> {
    return await openCVModule.colorStats(correctedImageUri, objects);
  }
}

export const cvNativeAdapter = new CrossPlatformAdapter();
