/**
 * Unit tests for mathematical utilities
 */
import {
  median,
  medianAbsoluteDeviation,
  mean,
  standardDeviation,
  coefficientOfVariation,
  detectOutliers,
  confidenceInterval,
  poissonConfidenceInterval,
  formatNumber,
  roundToSignificantFigures,
} from '../math';

describe('Mathematical Utilities', () => {
  describe('median', () => {
    it('should calculate median of odd-length array', () => {
      expect(median([1, 3, 5, 7, 9])).toBe(5);
    });

    it('should calculate median of even-length array', () => {
      expect(median([1, 2, 3, 4])).toBe(2.5);
    });

    it('should handle empty array', () => {
      expect(median([])).toBe(0);
    });

    it('should handle single element', () => {
      expect(median([42])).toBe(42);
    });
  });

  describe('medianAbsoluteDeviation', () => {
    it('should calculate MAD correctly', () => {
      const values = [1, 1, 2, 2, 4, 6, 9];
      const mad = medianAbsoluteDeviation(values);
      expect(mad).toBe(1);
    });

    it('should handle empty array', () => {
      expect(medianAbsoluteDeviation([])).toBe(0);
    });
  });

  describe('mean', () => {
    it('should calculate mean correctly', () => {
      expect(mean([1, 2, 3, 4, 5])).toBe(3);
    });

    it('should handle empty array', () => {
      expect(mean([])).toBe(0);
    });

    it('should handle decimal values', () => {
      expect(mean([1.5, 2.5, 3.5])).toBeCloseTo(2.5);
    });
  });

  describe('standardDeviation', () => {
    it('should calculate standard deviation correctly', () => {
      const values = [2, 4, 4, 4, 5, 5, 7, 9];
      const std = standardDeviation(values);
      expect(std).toBeCloseTo(2.0, 1);
    });

    it('should handle empty array', () => {
      expect(standardDeviation([])).toBe(0);
    });

    it('should handle identical values', () => {
      expect(standardDeviation([5, 5, 5, 5])).toBe(0);
    });
  });

  describe('coefficientOfVariation', () => {
    it('should calculate CV correctly', () => {
      const values = [10, 12, 14, 16, 18];
      const cv = coefficientOfVariation(values);
      expect(cv).toBeGreaterThan(0);
      expect(cv).toBeLessThan(1);
    });

    it('should handle zero mean', () => {
      expect(coefficientOfVariation([0, 0, 0])).toBe(0);
    });
  });

  describe('detectOutliers', () => {
    it('should detect outliers using MAD method', () => {
      const values = [1, 2, 3, 4, 5, 100]; // 100 is clearly an outlier
      const { outliers, indices } = detectOutliers(values, 2.5);
      
      expect(outliers).toContain(100);
      expect(indices).toContain(5);
    });

    it('should handle arrays with no outliers', () => {
      const values = [1, 2, 3, 4, 5];
      const { outliers, indices } = detectOutliers(values, 2.5);
      
      expect(outliers).toHaveLength(0);
      expect(indices).toHaveLength(0);
    });

    it('should handle small arrays', () => {
      const { outliers } = detectOutliers([1, 2], 2.5);
      expect(outliers).toHaveLength(0);
    });
  });

  describe('confidenceInterval', () => {
    it('should calculate confidence interval', () => {
      const values = [10, 12, 14, 16, 18];
      const ci = confidenceInterval(values, 0.95);
      
      expect(ci.lower).toBeLessThan(ci.upper);
      expect(ci.margin).toBeGreaterThan(0);
    });

    it('should handle empty array', () => {
      const ci = confidenceInterval([]);
      expect(ci.lower).toBe(0);
      expect(ci.upper).toBe(0);
      expect(ci.margin).toBe(0);
    });
  });

  describe('poissonConfidenceInterval', () => {
    it('should calculate Poisson CI for positive counts', () => {
      const ci = poissonConfidenceInterval(25);
      
      expect(ci.lower).toBeLessThan(25);
      expect(ci.upper).toBeGreaterThan(25);
    });

    it('should handle zero count', () => {
      const ci = poissonConfidenceInterval(0);
      
      expect(ci.lower).toBe(0);
      expect(ci.upper).toBeGreaterThan(0);
    });
  });

  describe('formatNumber', () => {
    it('should format counts as integers', () => {
      expect(formatNumber(123.7, 'count')).toBe('124');
    });

    it('should format concentrations with units', () => {
      expect(formatNumber(1500000, 'concentration')).toBe('1.5M');
      expect(formatNumber(2500, 'concentration')).toBe('2.5K');
      expect(formatNumber(150, 'concentration')).toBe('150');
    });

    it('should format percentages', () => {
      expect(formatNumber(75.678, 'percentage')).toBe('75.7%');
    });

    it('should format decimals with appropriate precision', () => {
      expect(formatNumber(123.456, 'decimal')).toBe('123');
      expect(formatNumber(12.345, 'decimal')).toBe('12.3');
      expect(formatNumber(1.2345, 'decimal')).toBe('1.23');
      expect(formatNumber(0.12345, 'decimal')).toBe('0.123');
    });
  });

  describe('roundToSignificantFigures', () => {
    it('should round to specified significant figures', () => {
      expect(roundToSignificantFigures(123.456, 3)).toBe(123);
      expect(roundToSignificantFigures(0.00123456, 3)).toBeCloseTo(0.00123, 5);
    });

    it('should handle zero', () => {
      expect(roundToSignificantFigures(0, 3)).toBe(0);
    });

    it('should handle negative numbers', () => {
      expect(roundToSignificantFigures(-123.456, 3)).toBe(-123);
    });
  });
});
