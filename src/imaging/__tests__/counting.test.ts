/**
 * Unit tests for counting algorithms
 */
import {
  applyInclusionRule,
  countCellsPerSquare,
  detectOutliers,
  calculateConcentration,
  calculateSeedingVolume,
  validateSquareSelection,
  getRecommendedDilution,
} from '../counting';
import { DetectionObject, SquareCount } from '../../types';

// Mock detection data
const mockDetections: DetectionObject[] = [
  // Square 0 (top-left)
  {
    id: '0-1',
    centroid: { x: 50, y: 50 },
    areaPx: 100,
    areaUm2: 80,
    circularity: 0.8,
    bbox: { x: 40, y: 40, width: 20, height: 20 },
    isLive: true,
    confidence: 0.9,
    squareIndex: 0,
  },
  {
    id: '0-2',
    centroid: { x: 150, y: 150 },
    areaPx: 120,
    areaUm2: 95,
    circularity: 0.75,
    bbox: { x: 140, y: 140, width: 20, height: 20 },
    isLive: false,
    confidence: 0.85,
    squareIndex: 0,
  },
  // Square 1 (top-right)
  {
    id: '1-1',
    centroid: { x: 550, y: 50 },
    areaPx: 110,
    areaUm2: 88,
    circularity: 0.82,
    bbox: { x: 540, y: 40, width: 20, height: 20 },
    isLive: true,
    confidence: 0.92,
    squareIndex: 1,
  },
];

describe('Counting Algorithms', () => {
  describe('applyInclusionRule', () => {
    it('should include cells within square boundaries', () => {
      const detections = [
        {
          ...mockDetections[0],
          centroid: { x: 50, y: 50 }, // Well within square
        },
      ];

      const included = applyInclusionRule(detections, 0, 500, 500);
      expect(included).toHaveLength(1);
    });

    it('should include cells on top and left borders', () => {
      const detections = [
        {
          ...mockDetections[0],
          centroid: { x: 0, y: 50 }, // On left border
        },
        {
          ...mockDetections[0],
          centroid: { x: 50, y: 0 }, // On top border
        },
      ];

      const included = applyInclusionRule(detections, 0, 500, 500);
      expect(included).toHaveLength(2);
    });

    it('should exclude cells on bottom and right borders', () => {
      const detections = [
        {
          ...mockDetections[0],
          centroid: { x: 500, y: 50 }, // On right border
        },
        {
          ...mockDetections[0],
          centroid: { x: 50, y: 500 }, // On bottom border
        },
      ];

      const included = applyInclusionRule(detections, 0, 500, 500);
      expect(included).toHaveLength(0);
    });
  });

  describe('countCellsPerSquare', () => {
    it('should count cells correctly for each square', () => {
      const counts = countCellsPerSquare(mockDetections, 1000, 1000, 4);

      expect(counts).toHaveLength(4);
      expect(counts[0].live).toBe(1);
      expect(counts[0].dead).toBe(1);
      expect(counts[0].total).toBe(2);
      expect(counts[1].total).toBe(1);
    });

    it('should initialize all squares even if empty', () => {
      const counts = countCellsPerSquare([], 1000, 1000, 4);

      expect(counts).toHaveLength(4);
      counts.forEach(count => {
        expect(count.total).toBe(0);
        expect(count.live).toBe(0);
        expect(count.dead).toBe(0);
      });
    });
  });

  describe('detectOutliers', () => {
    it('should detect outlier squares using MAD', () => {
      const squareCounts: SquareCount[] = [
        { index: 0, live: 50, dead: 10, total: 60, isOutlier: false, isSelected: true },
        { index: 1, live: 55, dead: 15, total: 70, isOutlier: false, isSelected: true },
        { index: 2, live: 52, dead: 12, total: 64, isOutlier: false, isSelected: true },
        { index: 3, live: 5, dead: 2, total: 7, isOutlier: false, isSelected: true }, // Outlier
      ];

      const withOutliers = detectOutliers(squareCounts, 2.5);
      expect(withOutliers[3].isOutlier).toBe(true);
      expect(withOutliers[0].isOutlier).toBe(false);
    });

    it('should handle uniform counts without outliers', () => {
      const squareCounts: SquareCount[] = [
        { index: 0, live: 50, dead: 10, total: 60, isOutlier: false, isSelected: true },
        { index: 1, live: 50, dead: 10, total: 60, isOutlier: false, isSelected: true },
        { index: 2, live: 50, dead: 10, total: 60, isOutlier: false, isSelected: true },
        { index: 3, live: 50, dead: 10, total: 60, isOutlier: false, isSelected: true },
      ];

      const withOutliers = detectOutliers(squareCounts);
      expect(withOutliers.every(s => !s.isOutlier)).toBe(true);
    });
  });

  describe('calculateConcentration', () => {
    it('should calculate concentration using hemocytometer formula', () => {
      const squareCounts: SquareCount[] = [
        { index: 0, live: 40, dead: 10, total: 50, isOutlier: false, isSelected: true },
        { index: 1, live: 45, dead: 15, total: 60, isOutlier: false, isSelected: true },
        { index: 2, live: 42, dead: 8, total: 50, isOutlier: false, isSelected: true },
        { index: 3, live: 38, dead: 12, total: 50, isOutlier: false, isSelected: true },
      ];

      const result = calculateConcentration(squareCounts, 2.0, 'neubauer');

      expect(result.concentration).toBeCloseTo(1075000, -3); // ~1.075M cells/mL
      expect(result.viability).toBeCloseTo(78.1, 1);
      expect(result.liveTotal).toBe(165);
      expect(result.deadTotal).toBe(45);
      expect(result.squaresUsed).toBe(4);
    });

    it('should handle no selected squares', () => {
      const squareCounts: SquareCount[] = [
        { index: 0, live: 50, dead: 10, total: 60, isOutlier: false, isSelected: false },
      ];

      const result = calculateConcentration(squareCounts, 1.0);

      expect(result.concentration).toBe(0);
      expect(result.viability).toBe(0);
      expect(result.squaresUsed).toBe(0);
    });

    it('should exclude outlier squares from calculation', () => {
      const squareCounts: SquareCount[] = [
        { index: 0, live: 50, dead: 10, total: 60, isOutlier: false, isSelected: true },
        { index: 1, live: 5, dead: 1, total: 6, isOutlier: true, isSelected: true },
      ];

      const result = calculateConcentration(squareCounts, 1.0);

      expect(result.squaresUsed).toBe(1);
      expect(result.rejectedSquares).toBe(1);
    });
  });

  describe('calculateSeedingVolume', () => {
    it('should calculate correct volume for seeding', () => {
      const result = calculateSeedingVolume(1000000, 500000, 10); // 1M cells/mL, want 500K cells in 10mL

      expect(result.isValid).toBe(true);
      expect(result.volumeToAdd).toBe(0.5);
      expect(result.finalConcentration).toBe(50000);
    });

    it('should handle invalid inputs', () => {
      const result = calculateSeedingVolume(0, 500000, 10);

      expect(result.isValid).toBe(false);
      expect(result.message).toContain('Invalid concentration');
    });

    it('should detect when required volume exceeds final volume', () => {
      const result = calculateSeedingVolume(100000, 5000000, 10); // Need 50mL but only have 10mL final

      expect(result.isValid).toBe(false);
      expect(result.message).toContain('Required volume exceeds');
    });
  });

  describe('validateSquareSelection', () => {
    it('should validate good square selection', () => {
      const squareCounts: SquareCount[] = [
        { index: 0, live: 50, dead: 10, total: 60, isOutlier: false, isSelected: true },
        { index: 1, live: 55, dead: 15, total: 70, isOutlier: false, isSelected: true },
        { index: 2, live: 52, dead: 12, total: 64, isOutlier: false, isSelected: false },
        { index: 3, live: 48, dead: 8, total: 56, isOutlier: false, isSelected: true },
      ];

      const validation = validateSquareSelection(squareCounts, 2);

      expect(validation.isValid).toBe(true);
      expect(validation.suggestions).toHaveLength(0);
    });

    it('should detect no squares selected', () => {
      const squareCounts: SquareCount[] = [
        { index: 0, live: 50, dead: 10, total: 60, isOutlier: false, isSelected: false },
      ];

      const validation = validateSquareSelection(squareCounts);

      expect(validation.isValid).toBe(false);
      expect(validation.message).toContain('No squares selected');
    });

    it('should suggest dilution for overcrowding', () => {
      const squareCounts: SquareCount[] = [
        { index: 0, live: 300, dead: 50, total: 350, isOutlier: false, isSelected: true },
        { index: 1, live: 280, dead: 45, total: 325, isOutlier: false, isSelected: true },
      ];

      const validation = validateSquareSelection(squareCounts);

      expect(validation.suggestions.some(s => s.includes('diluting'))).toBe(true);
    });
  });

  describe('getRecommendedDilution', () => {
    it('should recommend higher dilution for overcrowding', () => {
      const recommendation = getRecommendedDilution(300, 1);

      expect(recommendation.shouldRedilute).toBe(true);
      expect(recommendation.recommendedDilution).toBeGreaterThan(1);
      expect(recommendation.reason).toContain('overcrowded');
    });

    it('should recommend lower dilution for sparse samples', () => {
      const recommendation = getRecommendedDilution(20, 4);

      expect(recommendation.recommendedDilution).toBeLessThan(4);
      expect(recommendation.reason).toContain('sparse');
    });

    it('should approve optimal density', () => {
      const recommendation = getRecommendedDilution(100, 1);

      expect(recommendation.shouldRedilute).toBe(false);
      expect(recommendation.recommendedDilution).toBe(1);
      expect(recommendation.reason).toContain('optimal');
    });
  });
});
