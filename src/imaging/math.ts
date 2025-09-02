/**
 * Mathematical utilities for cell counting and statistics
 */

/**
 * Calculate median of an array of numbers
 */
export function median(values: number[]): number {
  if (values.length === 0) return 0;
  
  const sorted = [...values].sort((a, b) => a - b);
  const mid = Math.floor(sorted.length / 2);
  
  if (sorted.length % 2 === 0) {
    return (sorted[mid - 1] + sorted[mid]) / 2;
  }
  return sorted[mid];
}

/**
 * Calculate Median Absolute Deviation (MAD)
 */
export function medianAbsoluteDeviation(values: number[]): number {
  if (values.length === 0) return 0;
  
  const med = median(values);
  const deviations = values.map(value => Math.abs(value - med));
  return median(deviations);
}

/**
 * Calculate mean (average) of an array of numbers
 */
export function mean(values: number[]): number {
  if (values.length === 0) return 0;
  return values.reduce((sum, value) => sum + value, 0) / values.length;
}

/**
 * Calculate standard deviation
 */
export function standardDeviation(values: number[]): number {
  if (values.length === 0) return 0;
  
  const avg = mean(values);
  const squaredDiffs = values.map(value => Math.pow(value - avg, 2));
  const avgSquaredDiff = mean(squaredDiffs);
  return Math.sqrt(avgSquaredDiff);
}

/**
 * Calculate coefficient of variation (CV)
 */
export function coefficientOfVariation(values: number[]): number {
  if (values.length === 0) return 0;
  
  const avg = mean(values);
  if (avg === 0) return 0;
  
  const std = standardDeviation(values);
  return std / avg;
}

/**
 * Detect outliers using the MAD method
 */
export function detectOutliers(
  values: number[],
  threshold: number = 2.5
): { outliers: number[]; indices: number[] } {
  if (values.length < 3) {
    return { outliers: [], indices: [] };
  }
  
  const med = median(values);
  const mad = medianAbsoluteDeviation(values);
  
  if (mad === 0) {
    // All values are the same, no outliers
    return { outliers: [], indices: [] };
  }
  
  const outliers: number[] = [];
  const indices: number[] = [];
  
  values.forEach((value, index) => {
    const deviation = Math.abs(value - med) / mad;
    if (deviation > threshold) {
      outliers.push(value);
      indices.push(index);
    }
  });
  
  return { outliers, indices };
}

/**
 * Calculate confidence interval for a mean
 */
export function confidenceInterval(
  values: number[],
  confidence: number = 0.95
): { lower: number; upper: number; margin: number } {
  if (values.length === 0) {
    return { lower: 0, upper: 0, margin: 0 };
  }
  
  const avg = mean(values);
  const std = standardDeviation(values);
  const n = values.length;
  
  // Use t-distribution critical value (approximation for large n)
  const alpha = 1 - confidence;
  const tValue = getTDistributionValue(alpha / 2, n - 1);
  
  const standardError = std / Math.sqrt(n);
  const margin = tValue * standardError;
  
  return {
    lower: avg - margin,
    upper: avg + margin,
    margin,
  };
}

/**
 * Approximate t-distribution critical value
 * For simplicity, using normal distribution approximation for large n
 */
function getTDistributionValue(alpha: number, df: number): number {
  // For large degrees of freedom, t-distribution approaches normal
  if (df > 30) {
    // Normal distribution critical values
    if (alpha <= 0.025) return 1.96; // 95% confidence
    if (alpha <= 0.05) return 1.645; // 90% confidence
    if (alpha <= 0.1) return 1.282; // 80% confidence
  }
  
  // Simplified t-values for small samples
  const tTable: { [key: number]: number } = {
    1: 12.706,
    2: 4.303,
    3: 3.182,
    4: 2.776,
    5: 2.571,
    10: 2.228,
    20: 2.086,
    30: 2.042,
  };
  
  // Find closest df in table
  const dfs = Object.keys(tTable).map(Number).sort((a, b) => a - b);
  let closestDf = dfs[dfs.length - 1];
  
  for (const tableDf of dfs) {
    if (df <= tableDf) {
      closestDf = tableDf;
      break;
    }
  }
  
  return tTable[closestDf] || 1.96;
}

/**
 * Calculate Poisson confidence interval for count data
 */
export function poissonConfidenceInterval(
  count: number,
  confidence: number = 0.95
): { lower: number; upper: number } {
  if (count === 0) {
    return { lower: 0, upper: 3.69 }; // Upper bound for zero counts
  }
  
  const alpha = 1 - confidence;
  
  // Approximate Poisson confidence interval using normal approximation
  const z = 1.96; // 95% confidence
  const sqrt_count = Math.sqrt(count);
  
  const lower = Math.max(0, count - z * sqrt_count);
  const upper = count + z * sqrt_count;
  
  return { lower, upper };
}

/**
 * Calculate statistical power for detecting a difference in cell counts
 */
export function calculateStatisticalPower(
  expectedCount: number,
  minimumDetectableDifference: number,
  alpha: number = 0.05,
  sampleSize: number = 4
): number {
  // Simplified power calculation for Poisson data
  // This is an approximation suitable for cell counting
  
  const effect = minimumDetectableDifference / Math.sqrt(expectedCount);
  const z_alpha = 1.96; // Critical value for alpha = 0.05
  const z_beta = effect * Math.sqrt(sampleSize) - z_alpha;
  
  // Convert to power (1 - beta)
  const power = normalCDF(z_beta);
  return Math.max(0, Math.min(1, power));
}

/**
 * Approximate normal cumulative distribution function
 */
function normalCDF(x: number): number {
  // Approximation of the normal CDF
  const a1 = 0.254829592;
  const a2 = -0.284496736;
  const a3 = 1.421413741;
  const a4 = -1.453152027;
  const a5 = 1.061405429;
  const p = 0.3275911;
  
  const sign = x < 0 ? -1 : 1;
  x = Math.abs(x) / Math.sqrt(2.0);
  
  const t = 1.0 / (1.0 + p * x);
  const y = 1.0 - (((((a5 * t + a4) * t) + a3) * t + a2) * t + a1) * t * Math.exp(-x * x);
  
  return 0.5 * (1.0 + sign * y);
}

/**
 * Validate that a number is within a reasonable range
 */
export function validateRange(
  value: number,
  min: number,
  max: number,
  name: string = 'value'
): number {
  if (isNaN(value) || !isFinite(value)) {
    throw new Error(`${name} must be a valid number`);
  }
  
  if (value < min || value > max) {
    throw new Error(`${name} must be between ${min} and ${max}`);
  }
  
  return value;
}

/**
 * Round to specified number of significant figures
 */
export function roundToSignificantFigures(value: number, figures: number): number {
  if (value === 0) return 0;
  
  const magnitude = Math.floor(Math.log10(Math.abs(value)));
  const factor = Math.pow(10, figures - magnitude - 1);
  
  return Math.round(value * factor) / factor;
}

/**
 * Format number for display with appropriate precision
 */
export function formatNumber(
  value: number,
  type: 'count' | 'concentration' | 'percentage' | 'decimal' = 'decimal'
): string {
  switch (type) {
    case 'count':
      return Math.round(value).toString();
    
    case 'concentration':
      if (value >= 1e6) {
        return `${(value / 1e6).toFixed(2)}M`;
      } else if (value >= 1e3) {
        return `${(value / 1e3).toFixed(1)}K`;
      }
      return value.toFixed(0);
    
    case 'percentage':
      return `${value.toFixed(1)}%`;
    
    case 'decimal':
      if (value >= 100) {
        return value.toFixed(0);
      } else if (value >= 10) {
        return value.toFixed(1);
      } else if (value >= 1) {
        return value.toFixed(2);
      } else {
        return value.toFixed(3);
      }
    
    default:
      return value.toString();
  }
}
