/**
 * Hemocytometer counting rules and concentration calculations
 */
import { DetectionObject, SquareCount, Point } from '../types';

/**
 * Hemocytometer inclusion rule: include top and left borders, exclude bottom and right
 * This prevents double-counting cells that lie on square boundaries
 */
export function applyInclusionRule(
  detections: DetectionObject[],
  squareIndex: number,
  squareWidth: number,
  squareHeight: number
): DetectionObject[] {
  const squareRow = Math.floor(squareIndex / 2);
  const squareCol = squareIndex % 2;
  
  const left = squareCol * squareWidth;
  const right = left + squareWidth;
  const top = squareRow * squareHeight;
  const bottom = top + squareHeight;
  
  return detections.filter(detection => {
    const { x, y } = detection.centroid;
    
    // Include top and left borders, exclude bottom and right
    return x >= left && x < right && y >= top && y < bottom;
  });
}

/**
 * Count cells in each hemocytometer square
 */
export function countCellsPerSquare(
  detections: DetectionObject[],
  imageWidth: number,
  imageHeight: number,
  numSquares: number = 4
): SquareCount[] {
  const squareWidth = imageWidth / 2; // Assuming 2x2 grid
  const squareHeight = imageHeight / 2;
  
  const squareCounts: SquareCount[] = [];
  
  for (let squareIndex = 0; squareIndex < numSquares; squareIndex++) {
    // Get detections for this square
    const squareDetections = detections.filter(d => d.squareIndex === squareIndex);
    
    // Apply inclusion rule
    const includedDetections = applyInclusionRule(
      squareDetections,
      squareIndex,
      squareWidth,
      squareHeight
    );
    
    // Count live and dead cells
    const live = includedDetections.filter(d => d.isLive).length;
    const dead = includedDetections.filter(d => !d.isLive).length;
    const total = live + dead;
    
    squareCounts.push({
      index: squareIndex,
      live,
      dead,
      total,
      isOutlier: false, // Will be determined by outlier detection
      isSelected: true, // Default to selected
    });
  }
  
  return squareCounts;
}

/**
 * Detect and mark outlier squares using Median Absolute Deviation (MAD)
 */
export function detectOutliers(
  squareCounts: SquareCount[],
  maxVarianceMAD: number = 2.5
): SquareCount[] {
  if (squareCounts.length < 3) {
    // Need at least 3 squares for meaningful outlier detection
    return squareCounts;
  }
  
  // Get total counts for each square
  const totalCounts = squareCounts.map(s => s.total);
  
  // Calculate median
  const sortedCounts = [...totalCounts].sort((a, b) => a - b);
  const median = sortedCounts[Math.floor(sortedCounts.length / 2)];
  
  // Calculate Median Absolute Deviation (MAD)
  const absoluteDeviations = totalCounts.map(count => Math.abs(count - median));
  const sortedDeviations = [...absoluteDeviations].sort((a, b) => a - b);
  const mad = sortedDeviations[Math.floor(sortedDeviations.length / 2)];
  
  // Mark outliers
  return squareCounts.map((square, index) => ({
    ...square,
    isOutlier: mad > 0 && absoluteDeviations[index] > maxVarianceMAD * mad,
  }));
}

/**
 * Calculate concentration per mL using hemocytometer formula
 */
export function calculateConcentration(
  squareCounts: SquareCount[],
  dilutionFactor: number,
  chamberType: 'neubauer' | 'disposable' = 'neubauer'
): {
  concentration: number;
  viability: number;
  liveTotal: number;
  deadTotal: number;
  squaresUsed: number;
  rejectedSquares: number;
} {
  // Only use selected, non-outlier squares
  const validSquares = squareCounts.filter(s => s.isSelected && !s.isOutlier);
  
  if (validSquares.length === 0) {
    return {
      concentration: 0,
      viability: 0,
      liveTotal: 0,
      deadTotal: 0,
      squaresUsed: 0,
      rejectedSquares: squareCounts.length,
    };
  }
  
  // Calculate totals
  const totalLive = validSquares.reduce((sum, s) => sum + s.live, 0);
  const totalDead = validSquares.reduce((sum, s) => sum + s.dead, 0);
  const totalCells = totalLive + totalDead;
  
  // Calculate mean count per square
  const meanCountPerSquare = totalCells / validSquares.length;
  
  // Hemocytometer concentration formula
  // For Neubauer chamber: cells/mL = mean_count_per_large_square × 10^4 × dilution_factor
  // Each large square represents 0.1 μL (10^-4 mL)
  let concentrationFactor = 1e4; // Standard Neubauer chamber
  
  if (chamberType === 'disposable') {
    // Disposable chambers may have different volumes
    concentrationFactor = 1e4; // Assume same for now, but could be adjusted
  }
  
  const concentration = meanCountPerSquare * concentrationFactor * dilutionFactor;
  
  // Calculate viability percentage
  const viability = totalCells > 0 ? (totalLive / totalCells) * 100 : 0;
  
  return {
    concentration,
    viability,
    liveTotal: totalLive,
    deadTotal: totalDead,
    squaresUsed: validSquares.length,
    rejectedSquares: squareCounts.length - validSquares.length,
  };
}

/**
 * Seeding calculator: determine volume to add for target cell count
 */
export function calculateSeedingVolume(
  concentration: number,
  targetCells: number,
  finalVolume: number
): {
  volumeToAdd: number;
  finalConcentration: number;
  isValid: boolean;
  message: string;
} {
  if (concentration <= 0) {
    return {
      volumeToAdd: 0,
      finalConcentration: 0,
      isValid: false,
      message: 'Invalid concentration: must be greater than 0',
    };
  }
  
  if (targetCells <= 0 || finalVolume <= 0) {
    return {
      volumeToAdd: 0,
      finalConcentration: 0,
      isValid: false,
      message: 'Invalid parameters: target cells and final volume must be greater than 0',
    };
  }
  
  // Calculate required volume to add
  const volumeToAdd = targetCells / concentration;
  
  if (volumeToAdd > finalVolume) {
    return {
      volumeToAdd: 0,
      finalConcentration: 0,
      isValid: false,
      message: 'Required volume exceeds final volume. Consider using a higher concentration.',
    };
  }
  
  const finalConcentration = targetCells / finalVolume;
  
  return {
    volumeToAdd,
    finalConcentration,
    isValid: true,
    message: `Add ${volumeToAdd.toFixed(3)} mL to achieve ${targetCells} cells in ${finalVolume} mL`,
  };
}

/**
 * Validate square selection for counting
 */
export function validateSquareSelection(
  squareCounts: SquareCount[],
  minSquares: number = 2
): {
  isValid: boolean;
  message: string;
  suggestions: string[];
} {
  const selectedSquares = squareCounts.filter(s => s.isSelected);
  const validSquares = selectedSquares.filter(s => !s.isOutlier);
  
  const suggestions: string[] = [];
  
  if (selectedSquares.length === 0) {
    return {
      isValid: false,
      message: 'No squares selected for counting',
      suggestions: ['Select at least one square to count'],
    };
  }
  
  if (validSquares.length < minSquares) {
    suggestions.push(`Select at least ${minSquares} non-outlier squares for reliable counting`);
  }
  
  // Check for extremely low or high counts
  const counts = validSquares.map(s => s.total);
  const maxCount = Math.max(...counts);
  const minCount = Math.min(...counts);
  
  if (maxCount > 300) {
    suggestions.push('High cell density detected. Consider diluting sample for more accurate counting.');
  }
  
  if (maxCount < 10) {
    suggestions.push('Low cell density detected. Consider concentrating sample or counting more squares.');
  }
  
  // Check variance
  if (counts.length > 1) {
    const mean = counts.reduce((a, b) => a + b, 0) / counts.length;
    const variance = counts.reduce((sum, count) => sum + Math.pow(count - mean, 2), 0) / counts.length;
    const cv = Math.sqrt(variance) / mean; // Coefficient of variation
    
    if (cv > 0.3) {
      suggestions.push('High variance between squares. Check for uneven cell distribution or mixing.');
    }
  }
  
  return {
    isValid: validSquares.length >= minSquares,
    message: validSquares.length >= minSquares 
      ? 'Square selection is valid' 
      : `Need at least ${minSquares} valid squares`,
    suggestions,
  };
}

/**
 * Get recommended dilution factor based on cell density
 */
export function getRecommendedDilution(
  averageCellsPerSquare: number,
  currentDilution: number = 1
): {
  recommendedDilution: number;
  reason: string;
  shouldRedilute: boolean;
} {
  const idealRange = { min: 50, max: 200 }; // Ideal cells per square
  
  if (averageCellsPerSquare >= idealRange.min && averageCellsPerSquare <= idealRange.max) {
    return {
      recommendedDilution: currentDilution,
      reason: 'Current dilution is optimal',
      shouldRedilute: false,
    };
  }
  
  if (averageCellsPerSquare > idealRange.max) {
    // Too crowded, need higher dilution
    const dilutionFactor = Math.ceil(averageCellsPerSquare / idealRange.max);
    return {
      recommendedDilution: currentDilution * dilutionFactor,
      reason: `Sample is overcrowded (${averageCellsPerSquare} cells/square). Increase dilution.`,
      shouldRedilute: true,
    };
  }
  
  if (averageCellsPerSquare < idealRange.min && currentDilution > 1) {
    // Too sparse, can reduce dilution
    const dilutionFactor = Math.max(1, Math.floor(currentDilution / 2));
    return {
      recommendedDilution: dilutionFactor,
      reason: `Sample is sparse (${averageCellsPerSquare} cells/square). Consider reducing dilution.`,
      shouldRedilute: averageCellsPerSquare < idealRange.min / 2,
    };
  }
  
  return {
    recommendedDilution: currentDilution,
    reason: 'Current dilution is acceptable',
    shouldRedilute: false,
  };
}
