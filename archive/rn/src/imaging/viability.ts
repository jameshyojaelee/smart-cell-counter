/**
 * Cell viability classification using color analysis
 */
import { DetectionObject, ColorStats } from '../types';

export interface ViabilityThresholds {
  hueMin: number;
  hueMax: number;
  saturationMin: number;
  valueMax: number;
}

export interface ViabilityResult {
  isLive: boolean;
  confidence: number;
  reason: string;
}

/**
 * Classify cell viability based on trypan blue staining
 * Dead cells appear blue due to trypan blue uptake
 */
export function classifyTrypanBlueViability(
  colorStats: ColorStats,
  thresholds: ViabilityThresholds,
  adaptiveMargin: number = 0.1
): ViabilityResult {
  const { hue, saturation, value } = colorStats;
  
  // Normalize hue to 0-360 range if needed
  const normalizedHue = hue < 0 ? hue + 360 : hue;
  
  // Check if hue falls in blue range (trypan blue)
  const isInBlueRange = normalizedHue >= thresholds.hueMin && normalizedHue <= thresholds.hueMax;
  
  // Check saturation (dead cells should have higher saturation)
  const hasHighSaturation = saturation >= thresholds.saturationMin;
  
  // Check value/brightness (dead cells often appear darker)
  const hasLowValue = value <= thresholds.valueMax;
  
  // Calculate confidence based on how well the cell matches dead cell criteria
  let confidence = 0.5; // Base confidence
  
  if (isInBlueRange) {
    confidence += 0.3;
  }
  
  if (hasHighSaturation) {
    confidence += 0.2;
  }
  
  if (hasLowValue) {
    confidence += 0.1;
  }
  
  // Apply adaptive margin based on image histogram
  confidence = Math.max(0.1, Math.min(0.95, confidence + adaptiveMargin));
  
  // Determine if cell is dead based on criteria
  const isDead = isInBlueRange && hasHighSaturation && hasLowValue;
  
  let reason = '';
  if (isDead) {
    reason = `Blue staining detected: H=${normalizedHue.toFixed(1)}, S=${saturation.toFixed(2)}, V=${value.toFixed(2)}`;
  } else {
    reason = `Live cell: insufficient blue staining`;
  }
  
  return {
    isLive: !isDead,
    confidence,
    reason,
  };
}

/**
 * Classify viability for multiple stain types
 */
export function classifyViability(
  detections: DetectionObject[],
  stainType: string,
  thresholds: ViabilityThresholds
): DetectionObject[] {
  return detections.map(detection => {
    if (!detection.colorStats) {
      // If no color stats available, assume live with low confidence
      return {
        ...detection,
        isLive: true,
        confidence: 0.5,
      };
    }
    
    let result: ViabilityResult;
    
    switch (stainType.toLowerCase()) {
      case 'trypan_blue':
      case 'trypan blue':
        result = classifyTrypanBlueViability(detection.colorStats, thresholds);
        break;
      
      // Add support for other stains in the future
      case 'propidium_iodide':
        // TODO: Implement PI-specific classification
        result = classifyTrypanBlueViability(detection.colorStats, thresholds);
        break;
      
      default:
        console.warn(`Unknown stain type: ${stainType}, using trypan blue classification`);
        result = classifyTrypanBlueViability(detection.colorStats, thresholds);
    }
    
    return {
      ...detection,
      isLive: result.isLive,
      confidence: result.confidence,
    };
  });
}

/**
 * Calculate adaptive thresholds based on image histogram
 * This helps account for variations in lighting and staining intensity
 */
export function calculateAdaptiveThresholds(
  detections: DetectionObject[],
  baseThresholds: ViabilityThresholds
): ViabilityThresholds {
  if (detections.length === 0 || !detections[0]?.colorStats) {
    return baseThresholds;
  }
  
  // Extract color statistics
  const colorStats = detections
    .map(d => d.colorStats)
    .filter((stats): stats is ColorStats => stats !== undefined);
  
  if (colorStats.length === 0) {
    return baseThresholds;
  }
  
  // Calculate median values for adaptive adjustment
  const sortedHues = colorStats.map(s => s.hue).sort((a, b) => a - b);
  const sortedSaturations = colorStats.map(s => s.saturation).sort((a, b) => a - b);
  const sortedValues = colorStats.map(s => s.value).sort((a, b) => a - b);
  
  const medianSaturation = sortedSaturations[Math.floor(sortedSaturations.length / 2)];
  const medianValue = sortedValues[Math.floor(sortedValues.length / 2)];
  
  // Adjust thresholds based on median values
  const adaptiveThresholds: ViabilityThresholds = {
    ...baseThresholds,
    saturationMin: Math.max(0.1, medianSaturation * 1.2),
    valueMax: Math.min(0.9, medianValue * 0.8),
  };
  
  return adaptiveThresholds;
}

/**
 * Get default viability thresholds for different stain types
 */
export function getDefaultViabilityThresholds(stainType: string): ViabilityThresholds {
  switch (stainType.toLowerCase()) {
    case 'trypan_blue':
    case 'trypan blue':
      return {
        hueMin: 200, // Blue hue range start
        hueMax: 260, // Blue hue range end
        saturationMin: 0.3, // Minimum saturation for dead cells
        valueMax: 0.7, // Maximum brightness for dead cells
      };
    
    case 'propidium_iodide':
      return {
        hueMin: 0, // Red hue range start
        hueMax: 20, // Red hue range end
        saturationMin: 0.4,
        valueMax: 0.8,
      };
    
    default:
      console.warn(`Unknown stain type: ${stainType}, using trypan blue defaults`);
      return {
        hueMin: 200,
        hueMax: 260,
        saturationMin: 0.3,
        valueMax: 0.7,
      };
  }
}

/**
 * Validate viability thresholds
 */
export function validateViabilityThresholds(thresholds: ViabilityThresholds): ViabilityThresholds {
  return {
    hueMin: Math.max(0, Math.min(360, thresholds.hueMin)),
    hueMax: Math.max(thresholds.hueMin, Math.min(360, thresholds.hueMax)),
    saturationMin: Math.max(0, Math.min(1, thresholds.saturationMin)),
    valueMax: Math.max(0, Math.min(1, thresholds.valueMax)),
  };
}

/**
 * Calculate viability statistics
 */
export function calculateViabilityStats(detections: DetectionObject[]): {
  total: number;
  live: number;
  dead: number;
  viability: number;
  averageConfidence: number;
} {
  const total = detections.length;
  const live = detections.filter(d => d.isLive).length;
  const dead = total - live;
  const viability = total > 0 ? (live / total) * 100 : 0;
  
  const averageConfidence = total > 0 
    ? detections.reduce((sum, d) => sum + d.confidence, 0) / total 
    : 0;
  
  return {
    total,
    live,
    dead,
    viability,
    averageConfidence,
  };
}
