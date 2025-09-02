/**
 * Quality control and guidance for hemocytometer imaging
 */
import { GridDetectionResult, QCAlert, SquareCount } from '../types';

export interface QCThresholds {
  minFocusScore: number;
  maxGlareRatio: number;
  minCellsPerSquare: number;
  maxCellsPerSquare: number;
  maxVarianceMAD: number;
}

/**
 * Evaluate image quality before processing
 */
export function evaluateImageQuality(
  gridResult: GridDetectionResult,
  thresholds: QCThresholds
): QCAlert[] {
  const alerts: QCAlert[] = [];
  
  // Check focus quality
  if (gridResult.focusScore < thresholds.minFocusScore) {
    alerts.push({
      type: 'focus',
      severity: gridResult.focusScore < thresholds.minFocusScore * 0.5 ? 'error' : 'warning',
      message: `Poor focus detected (score: ${gridResult.focusScore.toFixed(1)}). Refocus camera for better accuracy.`,
    });
  }
  
  // Check for glare
  if (gridResult.glareRatio > thresholds.maxGlareRatio) {
    alerts.push({
      type: 'glare',
      severity: gridResult.glareRatio > thresholds.maxGlareRatio * 2 ? 'error' : 'warning',
      message: `Excessive glare detected (${(gridResult.glareRatio * 100).toFixed(1)}%). Adjust lighting or angle.`,
    });
  }
  
  // Check grid detection
  if (!gridResult.gridType) {
    alerts.push({
      type: 'focus',
      severity: 'error',
      message: 'Hemocytometer grid not detected. Ensure grid is clearly visible and in focus.',
    });
  }
  
  return alerts;
}

/**
 * Evaluate counting results for quality issues
 */
export function evaluateCountingQuality(
  squareCounts: SquareCount[],
  thresholds: QCThresholds
): QCAlert[] {
  const alerts: QCAlert[] = [];
  
  if (squareCounts.length === 0) {
    alerts.push({
      type: 'undercrowding',
      severity: 'error',
      message: 'No counting squares detected.',
    });
    return alerts;
  }
  
  // Check for overcrowding
  const maxCount = Math.max(...squareCounts.map(s => s.total));
  if (maxCount > thresholds.maxCellsPerSquare) {
    alerts.push({
      type: 'overcrowding',
      severity: maxCount > thresholds.maxCellsPerSquare * 1.5 ? 'error' : 'warning',
      message: `Overcrowding detected (${maxCount} cells in one square). Consider diluting sample.`,
    });
  }
  
  // Check for undercrowding
  const minCount = Math.min(...squareCounts.map(s => s.total));
  if (minCount < thresholds.minCellsPerSquare) {
    alerts.push({
      type: 'undercrowding',
      severity: minCount < thresholds.minCellsPerSquare * 0.5 ? 'error' : 'warning',
      message: `Low cell density detected (${minCount} cells in one square). Consider concentrating sample.`,
    });
  }
  
  // Check for high variance between squares
  const validSquares = squareCounts.filter(s => s.isSelected && !s.isOutlier);
  if (validSquares.length > 1) {
    const counts = validSquares.map(s => s.total);
    const mean = counts.reduce((a, b) => a + b, 0) / counts.length;
    const variance = counts.reduce((sum, count) => sum + Math.pow(count - mean, 2), 0) / counts.length;
    const cv = Math.sqrt(variance) / mean; // Coefficient of variation
    
    if (cv > 0.3) {
      alerts.push({
        type: 'variance',
        severity: cv > 0.5 ? 'error' : 'warning',
        message: `High variance between squares (CV: ${(cv * 100).toFixed(1)}%). Check sample mixing.`,
      });
    }
  }
  
  // Check for outlier squares
  const outlierCount = squareCounts.filter(s => s.isOutlier).length;
  if (outlierCount > 0) {
    alerts.push({
      type: 'variance',
      severity: outlierCount > squareCounts.length / 2 ? 'error' : 'warning',
      message: `${outlierCount} outlier square(s) detected. Check for debris or uneven distribution.`,
    });
  }
  
  return alerts;
}

/**
 * Generate pre-capture guidance based on current camera conditions
 */
export function generateCaptureGuidance(
  focusScore: number,
  glareRatio: number,
  thresholds: QCThresholds
): {
  canCapture: boolean;
  guidance: string[];
  warnings: string[];
} {
  const guidance: string[] = [];
  const warnings: string[] = [];
  let canCapture = true;
  
  // Focus guidance
  if (focusScore < thresholds.minFocusScore) {
    if (focusScore < thresholds.minFocusScore * 0.5) {
      warnings.push('Image is severely out of focus');
      canCapture = false;
    } else {
      warnings.push('Image appears slightly out of focus');
    }
    guidance.push('Tap on the hemocytometer grid to focus');
    guidance.push('Ensure camera is steady and at proper distance');
  }
  
  // Glare guidance
  if (glareRatio > thresholds.maxGlareRatio) {
    if (glareRatio > thresholds.maxGlareRatio * 2) {
      warnings.push('Excessive glare detected');
      canCapture = false;
    } else {
      warnings.push('Some glare detected');
    }
    guidance.push('Adjust camera angle to reduce reflections');
    guidance.push('Turn off flash if enabled');
    guidance.push('Ensure even lighting without direct reflections');
  }
  
  // General guidance
  if (canCapture && guidance.length === 0) {
    guidance.push('Image quality looks good');
    guidance.push('Ensure hemocytometer grid is centered');
    guidance.push('Check that cells are evenly distributed');
  }
  
  return {
    canCapture,
    guidance,
    warnings,
  };
}

/**
 * Estimate optimal dilution based on preliminary cell density
 */
export function estimateOptimalDilution(
  estimatedCellsPerSquare: number,
  currentDilution: number = 1
): {
  recommendedDilution: number;
  reason: string;
  confidence: 'high' | 'medium' | 'low';
} {
  const optimalRange = { min: 50, max: 200 };
  
  if (estimatedCellsPerSquare >= optimalRange.min && estimatedCellsPerSquare <= optimalRange.max) {
    return {
      recommendedDilution: currentDilution,
      reason: 'Current dilution appears optimal',
      confidence: 'high',
    };
  }
  
  if (estimatedCellsPerSquare > optimalRange.max) {
    const factor = Math.ceil(estimatedCellsPerSquare / ((optimalRange.min + optimalRange.max) / 2));
    return {
      recommendedDilution: currentDilution * factor,
      reason: `Too crowded (~${estimatedCellsPerSquare} cells/square). Dilute ${factor}x.`,
      confidence: estimatedCellsPerSquare > optimalRange.max * 2 ? 'high' : 'medium',
    };
  }
  
  if (estimatedCellsPerSquare < optimalRange.min && currentDilution > 1) {
    const factor = Math.max(1, Math.floor(currentDilution / 2));
    return {
      recommendedDilution: factor,
      reason: `Too sparse (~${estimatedCellsPerSquare} cells/square). Reduce dilution.`,
      confidence: estimatedCellsPerSquare < optimalRange.min / 2 ? 'high' : 'medium',
    };
  }
  
  return {
    recommendedDilution: currentDilution,
    reason: 'Dilution is acceptable but not optimal',
    confidence: 'low',
  };
}

/**
 * Generate processing recommendations based on QC results
 */
export function generateProcessingRecommendations(
  alerts: QCAlert[]
): {
  canProceed: boolean;
  recommendations: string[];
  criticalIssues: string[];
} {
  const recommendations: string[] = [];
  const criticalIssues: string[] = [];
  
  const errors = alerts.filter(a => a.severity === 'error');
  const warnings = alerts.filter(a => a.severity === 'warning');
  
  // Critical issues that prevent processing
  errors.forEach(alert => {
    criticalIssues.push(alert.message);
  });
  
  // Recommendations for warnings
  warnings.forEach(alert => {
    switch (alert.type) {
      case 'focus':
        recommendations.push('Consider retaking image with better focus for improved accuracy');
        break;
      case 'glare':
        recommendations.push('Reduce glare for more accurate color-based viability assessment');
        break;
      case 'overcrowding':
        recommendations.push('Dilute sample to reduce cell overlap and improve counting accuracy');
        break;
      case 'undercrowding':
        recommendations.push('Consider concentrating sample or counting additional squares');
        break;
      case 'variance':
        recommendations.push('Mix sample thoroughly and ensure even distribution');
        break;
    }
  });
  
  // General recommendations
  if (recommendations.length === 0 && criticalIssues.length === 0) {
    recommendations.push('Image quality is good - proceed with confidence');
  }
  
  return {
    canProceed: errors.length === 0,
    recommendations,
    criticalIssues,
  };
}

/**
 * Calculate overall quality score (0-100)
 */
export function calculateQualityScore(
  gridResult: GridDetectionResult,
  squareCounts: SquareCount[],
  thresholds: QCThresholds
): number {
  let score = 100;
  
  // Focus score component (30% weight)
  const focusRatio = Math.min(1, gridResult.focusScore / thresholds.minFocusScore);
  score -= (1 - focusRatio) * 30;
  
  // Glare component (20% weight)
  const glareRatio = Math.min(1, gridResult.glareRatio / thresholds.maxGlareRatio);
  score -= glareRatio * 20;
  
  // Grid detection component (20% weight)
  if (!gridResult.gridType) {
    score -= 20;
  }
  
  // Counting quality component (30% weight)
  if (squareCounts.length > 0) {
    const validSquares = squareCounts.filter(s => !s.isOutlier);
    const outlierRatio = (squareCounts.length - validSquares.length) / squareCounts.length;
    score -= outlierRatio * 15;
    
    // Check density
    const counts = validSquares.map(s => s.total);
    const avgCount = counts.reduce((a, b) => a + b, 0) / counts.length;
    
    if (avgCount > thresholds.maxCellsPerSquare) {
      score -= 10;
    } else if (avgCount < thresholds.minCellsPerSquare) {
      score -= 5;
    }
    
    // Check variance
    if (counts.length > 1) {
      const mean = avgCount;
      const variance = counts.reduce((sum, count) => sum + Math.pow(count - mean, 2), 0) / counts.length;
      const cv = Math.sqrt(variance) / mean;
      score -= Math.min(10, cv * 20);
    }
  }
  
  return Math.max(0, Math.round(score));
}
