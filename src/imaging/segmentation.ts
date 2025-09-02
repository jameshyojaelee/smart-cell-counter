/**
 * Cell segmentation pipeline combining classical CV and TensorFlow Lite
 */
import * as FileSystem from 'expo-file-system';
import { Image } from 'react-native';
import { cvNativeAdapter } from './cvNativeAdapter';
import { DetectionObject, ProcessingParams, Point } from '../types';

/**
 * TensorFlow Lite model interface
 */
export interface TFLiteSegmentation {
  /**
   * Run TensorFlow Lite segmentation on a 256x256 tile
   * @param imageUri Path to input image tile
   * @returns Path to probability mask
   */
  runTFLiteSegmentation(imageUri: string): Promise<string>;

  /**
   * Check if TFLite model is available
   */
  isModelAvailable(): Promise<boolean>;
}

/**
 * Mock TensorFlow Lite implementation
 */
class MockTFLiteSegmentation implements TFLiteSegmentation {
  private modelPath: string;

  constructor() {
    this.modelPath = `${FileSystem.documentDirectory}assets/models/unet_256.tflite`;
  }

  async isModelAvailable(): Promise<boolean> {
    try {
      const fileInfo = await FileSystem.getInfoAsync(this.modelPath);
      return fileInfo.exists;
    } catch {
      return false;
    }
  }

  async runTFLiteSegmentation(imageUri: string): Promise<string> {
    // Mock implementation - in production this would call the actual TFLite model
    const isAvailable = await this.isModelAvailable();
    
    if (!isAvailable) {
      console.log('TFLite model not available, using classical segmentation only');
      return imageUri; // Return original mask
    }

    // Simulate processing delay
    await new Promise(resolve => setTimeout(resolve, 200));
    
    // Generate mock probability mask path
    const timestamp = Date.now();
    return `file:///tmp/tflite_prob_mask_${timestamp}.jpg`;
  }
}

const tfliteSegmentation = new MockTFLiteSegmentation();

/**
 * Convert pixel area to micrometers squared
 */
function pixelsToMicrometers(areaPx: number, pixelsPerMicron: number): number {
  if (!pixelsPerMicron || pixelsPerMicron <= 0) {
    return areaPx; // Fallback to pixel area
  }
  return areaPx / (pixelsPerMicron * pixelsPerMicron);
}

/**
 * Determine which hemocytometer square a point belongs to
 * Assumes a 2x2 grid of large squares for Neubauer chamber
 */
function getSquareIndex(point: Point, imageWidth: number, imageHeight: number): number {
  const squareWidth = imageWidth / 2;
  const squareHeight = imageHeight / 2;
  
  const col = Math.floor(point.x / squareWidth);
  const row = Math.floor(point.y / squareHeight);
  
  // Clamp to valid range
  const clampedCol = Math.max(0, Math.min(1, col));
  const clampedRow = Math.max(0, Math.min(1, row));
  
  return clampedRow * 2 + clampedCol;
}

/**
 * Filter detections by area constraints
 */
function filterByArea(
  contours: Array<{ id: string; areaPx: number; circularity: number; bbox: any; centroid: Point }>,
  params: ProcessingParams,
  pixelsPerMicron: number
): Array<{ id: string; areaPx: number; circularity: number; bbox: any; centroid: Point }> {
  return contours.filter(contour => {
    const areaUm2 = pixelsToMicrometers(contour.areaPx, pixelsPerMicron);
    return areaUm2 >= params.minAreaUm2 && areaUm2 <= params.maxAreaUm2;
  });
}

/**
 * Fuse classical segmentation with TensorFlow Lite refinement
 */
async function fuseSegmentationMasks(
  classicalMaskUri: string,
  tfliteMaskUri: string
): Promise<string> {
  // Mock implementation - in production this would combine the masks
  // using logical OR and size sanity checks
  
  if (classicalMaskUri === tfliteMaskUri) {
    return classicalMaskUri; // No TFLite refinement
  }
  
  // Simulate mask fusion processing
  await new Promise(resolve => setTimeout(resolve, 100));
  
  const timestamp = Date.now();
  return `file:///tmp/fused_mask_${timestamp}.jpg`;
}

/**
 * Main segmentation pipeline
 */
export async function segmentCells(
  correctedImageUri: string,
  params: ProcessingParams,
  pixelsPerMicron: number,
  onProgress?: (step: string, progress: number) => void
): Promise<{
  detections: DetectionObject[];
  maskUri: string;
  processingTimeMs: number;
}> {
  const startTime = Date.now();
  
  try {
    // Step 1: Classical segmentation
    onProgress?.('Classical segmentation...', 0.1);
    const classicalResult = await cvNativeAdapter.segmentCells(correctedImageUri, params);
    
    // Step 2: Apply watershed if enabled
    let maskUri = classicalResult.binaryMaskUri;
    if (params.useWatershed) {
      onProgress?.('Watershed splitting...', 0.3);
      maskUri = await cvNativeAdapter.watershedSplit(correctedImageUri, maskUri);
    }
    
    // Step 3: TensorFlow Lite refinement if enabled
    if (params.useTFLiteRefinement) {
      onProgress?.('TensorFlow Lite refinement...', 0.5);
      const tfliteMaskUri = await tfliteSegmentation.runTFLiteSegmentation(correctedImageUri);
      maskUri = await fuseSegmentationMasks(maskUri, tfliteMaskUri);
    }
    
    // Step 4: Filter by area constraints
    onProgress?.('Filtering detections...', 0.7);
    const filteredContours = filterByArea(classicalResult.contours, params, pixelsPerMicron);
    
    // Step 5: Extract color statistics
    onProgress?.('Extracting color features...', 0.8);
    const colorResults = await cvNativeAdapter.colorStats(
      correctedImageUri,
      filteredContours.map(c => ({ id: c.id, centroid: c.centroid }))
    );
    
    // Step 6: Determine corrected image dimensions to compute square index
    onProgress?.('Finalizing detections...', 0.9);
    const { width: imageWidth, height: imageHeight } = await getImageDimensionsSafe(correctedImageUri);

    const detections: DetectionObject[] = filteredContours.map(contour => {
      const colorStats = colorResults.find(c => c.id === contour.id)?.colorStats;
      const squareIndex = getSquareIndex(contour.centroid, imageWidth, imageHeight);
      
      return {
        id: contour.id,
        centroid: contour.centroid,
        areaPx: contour.areaPx,
        areaUm2: pixelsToMicrometers(contour.areaPx, pixelsPerMicron),
        circularity: contour.circularity,
        bbox: contour.bbox,
        colorStats,
        isLive: true, // Will be determined by viability classification
        confidence: 0.8, // Mock confidence
        squareIndex,
      };
    });
    
    const processingTimeMs = Date.now() - startTime;
    onProgress?.('Complete', 1.0);
    
    return {
      detections,
      maskUri,
      processingTimeMs,
    };
    
  } catch (error) {
    console.error('Segmentation failed:', error);
    throw new Error(`Segmentation failed: ${error}`);
  }
}

/**
 * Check if TensorFlow Lite model is available
 */
export async function isTFLiteModelAvailable(): Promise<boolean> {
  return tfliteSegmentation.isModelAvailable();
}

/**
 * Estimate processing time based on image size and parameters
 */
export function estimateProcessingTime(
  imageWidth: number,
  imageHeight: number,
  params: ProcessingParams
): number {
  const pixelCount = imageWidth * imageHeight;
  let baseTime = Math.max(1000, pixelCount / 1000); // Base time in ms
  
  if (params.useWatershed) {
    baseTime *= 1.5;
  }
  
  if (params.useTFLiteRefinement) {
    baseTime *= 2.0;
  }
  
  return Math.round(baseTime);
}

/**
 * Safely get image dimensions for a given URI using React Native Image.getSize.
 * Falls back to 1000x1000 if size cannot be determined.
 */
async function getImageDimensionsSafe(uri: string): Promise<{ width: number; height: number }> {
  try {
    const dims = await new Promise<{ width: number; height: number }>((resolve) => {
      Image.getSize(
        uri,
        (width, height) => resolve({ width, height }),
        () => resolve({ width: 1000, height: 1000 })
      );
    });
    return dims;
  } catch {
    return { width: 1000, height: 1000 };
  }
}
