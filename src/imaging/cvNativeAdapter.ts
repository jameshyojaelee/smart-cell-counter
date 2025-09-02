/**
 * Cross-platform native module adapter
 * Routes to iOS Vision/CoreML on iOS, OpenCV/TFLite on Android
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
        // Try iOS Vision first
        const result = await detectGridAndCornersIOS(inputUri);
        return {
          corners: result.corners as [Point, Point, Point, Point],
          gridType: result.gridType,
          pixelsPerMicron: result.pixelsPerMicron,
          focusScore: result.focusScore,
          glareRatio: result.glareRatio,
        };
      } catch (error) {
        console.warn('iOS Vision detection failed, falling back to OpenCV:', error);
        // Fallback to OpenCV if Vision fails
        return await openCVModule.detectGridAndCorners(inputUri);
      }
    } else {
      // Use OpenCV on Android
      return await openCVModule.detectGridAndCorners(inputUri);
    }
  }

  async perspectiveCorrect(
    inputUri: string,
    corners: [Point, Point, Point, Point]
  ): Promise<string> {
    if (Platform.OS === 'ios') {
      try {
        // Try iOS Core Image first
        return await perspectiveCorrectIOS(inputUri, corners);
      } catch (error) {
        console.warn('iOS perspective correction failed, falling back to OpenCV:', error);
        // Fallback to OpenCV if Core Image fails
        return await openCVModule.perspectiveCorrect(inputUri, corners);
      }
    } else {
      // Use OpenCV on Android
      return await openCVModule.perspectiveCorrect(inputUri, corners);
    }
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
        // Try Core ML segmentation first
        const maskUri = await runCoreMLSegmentationIOS(correctedImageUri);
        
        if (maskUri) {
          // If Core ML succeeded, we still need to extract contours from the mask
          // For now, fallback to OpenCV for contour extraction
          // TODO: Implement native iOS contour extraction from mask
          console.log('Core ML segmentation succeeded, using OpenCV for contour extraction');
          const result = await openCVModule.segmentCells(correctedImageUri, params);
          // Replace the binary mask with Core ML result
          return {
            ...result,
            binaryMaskUri: maskUri,
          };
        } else {
          console.log('Core ML segmentation not available, using OpenCV');
          // Core ML model not available, use OpenCV
          return await openCVModule.segmentCells(correctedImageUri, params);
        }
      } catch (error) {
        console.warn('iOS Core ML segmentation failed, falling back to OpenCV:', error);
        // Fallback to OpenCV if Core ML fails
        return await openCVModule.segmentCells(correctedImageUri, params);
      }
    } else {
      // Use OpenCV/TFLite on Android
      return await openCVModule.segmentCells(correctedImageUri, params);
    }
  }

  async watershedSplit(correctedImageUri: string, binaryMaskUri: string): Promise<string> {
    // For now, always use OpenCV for watershed splitting on both platforms
    return await openCVModule.watershedSplit(correctedImageUri, binaryMaskUri);
  }

  async colorStats(
    correctedImageUri: string,
    objects: Array<{ id: string; centroid: Point }>
  ): Promise<Array<{ id: string; colorStats: any }>> {
    // For now, always use OpenCV for color stats on both platforms
    return await openCVModule.colorStats(correctedImageUri, objects);
  }
}

export const cvNativeAdapter = new CrossPlatformAdapter();
