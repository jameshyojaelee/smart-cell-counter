/**
 * CSV export utilities for sample data
 */
import * as FileSystem from 'expo-file-system';
import { Sample, DetectionObject, SquareCount } from '../types';
import { formatNumber } from '../imaging/math';

/**
 * Generate CSV content for sample summary
 */
export function generateSampleSummaryCSV(samples: Sample[]): string {
  const headers = [
    'Sample ID',
    'Timestamp',
    'Operator',
    'Project',
    'Chamber Type',
    'Dilution Factor',
    'Stain Type',
    'Live Cells',
    'Dead Cells',
    'Total Cells',
    'Concentration (cells/mL)',
    'Viability (%)',
    'Squares Used',
    'Rejected Squares',
    'Focus Score',
    'Glare Ratio (%)',
    'Notes',
  ];

  const rows = samples.map(sample => [
    sample.id,
    new Date(sample.timestamp).toISOString(),
    sample.operator,
    sample.project,
    sample.chamberType,
    sample.dilutionFactor.toString(),
    sample.stainType,
    sample.liveTotal.toString(),
    sample.deadTotal.toString(),
    (sample.liveTotal + sample.deadTotal).toString(),
    formatNumber(sample.concentration, 'concentration'),
    formatNumber(sample.viability, 'percentage').replace('%', ''),
    sample.squaresUsed.toString(),
    sample.rejectedSquares.toString(),
    sample.focusScore.toFixed(1),
    (sample.glareRatio * 100).toFixed(1),
    sample.notes || '',
  ]);

  return [headers, ...rows]
    .map(row => row.map(cell => `"${cell.toString().replace(/"/g, '""')}"`).join(','))
    .join('\n');
}

/**
 * Generate CSV content for detailed detection data
 */
export function generateDetectionCSV(sample: Sample): string {
  const headers = [
    'Sample ID',
    'Object ID',
    'Square Index',
    'X Position',
    'Y Position',
    'Area (pixels)',
    'Area (μm²)',
    'Circularity',
    'Is Live',
    'Confidence',
    'Hue',
    'Saturation',
    'Value',
    'Lightness',
    'A Component',
    'B Component',
  ];

  const rows = sample.detections.map(detection => [
    sample.id,
    detection.id,
    detection.squareIndex.toString(),
    detection.centroid.x.toFixed(2),
    detection.centroid.y.toFixed(2),
    detection.areaPx.toFixed(1),
    detection.areaUm2.toFixed(1),
    detection.circularity.toFixed(3),
    detection.isLive ? 'TRUE' : 'FALSE',
    detection.confidence.toFixed(3),
    detection.colorStats?.hue.toFixed(1) || '',
    detection.colorStats?.saturation.toFixed(3) || '',
    detection.colorStats?.value.toFixed(3) || '',
    detection.colorStats?.lightness.toFixed(3) || '',
    detection.colorStats?.a.toFixed(2) || '',
    detection.colorStats?.b.toFixed(2) || '',
  ]);

  return [headers, ...rows]
    .map(row => row.map(cell => `"${cell.toString()}"`).join(','))
    .join('\n');
}

/**
 * Generate CSV content for square count data
 */
export function generateSquareCountCSV(sample: Sample, squareCounts: SquareCount[]): string {
  const headers = [
    'Sample ID',
    'Square Index',
    'Live Cells',
    'Dead Cells',
    'Total Cells',
    'Is Selected',
    'Is Outlier',
  ];

  const rows = squareCounts.map(square => [
    sample.id,
    square.index.toString(),
    square.live.toString(),
    square.dead.toString(),
    square.total.toString(),
    square.isSelected ? 'TRUE' : 'FALSE',
    square.isOutlier ? 'TRUE' : 'FALSE',
  ]);

  return [headers, ...rows]
    .map(row => row.map(cell => `"${cell}"`).join(','))
    .join('\n');
}

/**
 * Export sample data as CSV files
 */
export async function exportSampleAsCSV(
  sample: Sample,
  squareCounts: SquareCount[],
  includeDetections: boolean = false
): Promise<{ summaryPath: string; detailsPath?: string; squaresPath: string }> {
  const timestamp = new Date(sample.timestamp).toISOString().replace(/[:.]/g, '-');
  const baseFilename = `${sample.id}_${timestamp}`;
  
  try {
    // Create summary CSV
    const summaryCSV = generateSampleSummaryCSV([sample]);
    const summaryPath = `${FileSystem.documentDirectory}${baseFilename}_summary.csv`;
    await FileSystem.writeAsStringAsync(summaryPath, summaryCSV);

    // Create square counts CSV
    const squaresCSV = generateSquareCountCSV(sample, squareCounts);
    const squaresPath = `${FileSystem.documentDirectory}${baseFilename}_squares.csv`;
    await FileSystem.writeAsStringAsync(squaresPath, squaresCSV);

    let detailsPath: string | undefined;
    
    // Create detailed detections CSV if requested
    if (includeDetections && sample.detections.length > 0) {
      const detectionCSV = generateDetectionCSV(sample);
      detailsPath = `${FileSystem.documentDirectory}${baseFilename}_detections.csv`;
      await FileSystem.writeAsStringAsync(detailsPath, detectionCSV);
    }

    return {
      summaryPath,
      detailsPath,
      squaresPath,
    };
  } catch (error) {
    console.error('Failed to export CSV:', error);
    throw new Error(`CSV export failed: ${error}`);
  }
}

/**
 * Export multiple samples as a single CSV file
 */
export async function exportMultipleSamplesAsCSV(samples: Sample[]): Promise<string> {
  if (samples.length === 0) {
    throw new Error('No samples to export');
  }

  try {
    const csv = generateSampleSummaryCSV(samples);
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    const filename = `cell_counter_export_${timestamp}.csv`;
    const filePath = `${FileSystem.documentDirectory}${filename}`;
    
    await FileSystem.writeAsStringAsync(filePath, csv);
    return filePath;
  } catch (error) {
    console.error('Failed to export multiple samples CSV:', error);
    throw new Error(`Multi-sample CSV export failed: ${error}`);
  }
}

/**
 * Validate CSV data before export
 */
export function validateCSVData(samples: Sample[]): {
  isValid: boolean;
  errors: string[];
  warnings: string[];
} {
  const errors: string[] = [];
  const warnings: string[] = [];

  if (samples.length === 0) {
    errors.push('No samples provided for export');
    return { isValid: false, errors, warnings };
  }

  samples.forEach((sample, index) => {
    if (!sample.id) {
      errors.push(`Sample ${index + 1}: Missing sample ID`);
    }

    if (!sample.operator) {
      warnings.push(`Sample ${sample.id}: Missing operator name`);
    }

    if (!sample.project) {
      warnings.push(`Sample ${sample.id}: Missing project name`);
    }

    if (sample.concentration < 0) {
      errors.push(`Sample ${sample.id}: Invalid concentration (${sample.concentration})`);
    }

    if (sample.viability < 0 || sample.viability > 100) {
      errors.push(`Sample ${sample.id}: Invalid viability (${sample.viability}%)`);
    }

    if (sample.dilutionFactor <= 0) {
      errors.push(`Sample ${sample.id}: Invalid dilution factor (${sample.dilutionFactor})`);
    }
  });

  return {
    isValid: errors.length === 0,
    errors,
    warnings,
  };
}

/**
 * Get CSV file size estimate
 */
export function estimateCSVSize(samples: Sample[], includeDetections: boolean = false): number {
  let totalSize = 0;

  // Summary CSV size
  const summaryHeaderSize = 200; // Approximate header size
  const summaryRowSize = 150; // Approximate row size per sample
  totalSize += summaryHeaderSize + (samples.length * summaryRowSize);

  if (includeDetections) {
    // Detection CSV size
    const detectionHeaderSize = 300;
    const detectionRowSize = 100; // Per detection
    const totalDetections = samples.reduce((sum, sample) => sum + sample.detections.length, 0);
    totalSize += detectionHeaderSize + (totalDetections * detectionRowSize);
  }

  return totalSize;
}

/**
 * Parse CSV content back to objects (for import functionality)
 */
export function parseCSVContent(csvContent: string): {
  headers: string[];
  rows: string[][];
} {
  const lines = csvContent.split('\n').filter(line => line.trim());
  
  if (lines.length === 0) {
    return { headers: [], rows: [] };
  }

  const parseCSVLine = (line: string): string[] => {
    const result: string[] = [];
    let current = '';
    let inQuotes = false;
    let i = 0;

    while (i < line.length) {
      const char = line[i];
      
      if (char === '"') {
        if (inQuotes && line[i + 1] === '"') {
          // Escaped quote
          current += '"';
          i += 2;
        } else {
          // Toggle quote state
          inQuotes = !inQuotes;
          i++;
        }
      } else if (char === ',' && !inQuotes) {
        // Field separator
        result.push(current.trim());
        current = '';
        i++;
      } else {
        current += char;
        i++;
      }
    }
    
    result.push(current.trim());
    return result;
  };

  const headers = parseCSVLine(lines[0]);
  const rows = lines.slice(1).map(parseCSVLine);

  return { headers, rows };
}
