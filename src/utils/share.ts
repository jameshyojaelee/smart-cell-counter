/**
 * Sharing utilities for exporting and sharing analysis results
 */
import * as Sharing from 'expo-sharing';
import * as FileSystem from 'expo-file-system';
import { Sample, SquareCount, QCAlert } from '../types';
import { exportSampleAsCSV, exportMultipleSamplesAsCSV } from './csv';
import { generatePDFReport, generatePDFWithImages } from './pdf';

export interface ShareOptions {
  includeImages?: boolean;
  includeDetections?: boolean;
  format: 'pdf' | 'csv' | 'both';
}

/**
 * Share a single sample analysis
 */
export async function shareSample(
  sample: Sample,
  squareCounts: SquareCount[],
  qcAlerts: QCAlert[] = [],
  options: ShareOptions = { format: 'pdf' },
  imagePaths?: {
    original?: string;
    corrected?: string;
    overlay?: string;
  }
): Promise<void> {
  try {
    const filesToShare: string[] = [];
    
    if (options.format === 'pdf' || options.format === 'both') {
      let pdfPath: string;
      
      if (options.includeImages && imagePaths) {
        pdfPath = await generatePDFWithImages(sample, squareCounts, qcAlerts, imagePaths);
      } else {
        pdfPath = await generatePDFReport(sample, squareCounts, qcAlerts);
      }
      
      filesToShare.push(pdfPath);
    }
    
    if (options.format === 'csv' || options.format === 'both') {
      const csvFiles = await exportSampleAsCSV(
        sample,
        squareCounts,
        options.includeDetections
      );
      
      filesToShare.push(csvFiles.summaryPath);
      filesToShare.push(csvFiles.squaresPath);
      
      if (csvFiles.detailsPath) {
        filesToShare.push(csvFiles.detailsPath);
      }
    }
    
    // Share files
    if (filesToShare.length === 1) {
      await Sharing.shareAsync(filesToShare[0], {
        mimeType: options.format === 'pdf' ? 'application/pdf' : 'text/csv',
        dialogTitle: `Share ${sample.id} Analysis`,
      });
    } else {
      // For multiple files, create a zip or share individually
      for (const filePath of filesToShare) {
        await Sharing.shareAsync(filePath);
      }
    }
    
  } catch (error) {
    console.error('Failed to share sample:', error);
    throw new Error(`Sharing failed: ${error}`);
  }
}

/**
 * Share multiple samples as CSV
 */
export async function shareMultipleSamples(
  samples: Sample[],
  format: 'csv' | 'pdf' = 'csv'
): Promise<void> {
  try {
    if (format === 'csv') {
      const csvPath = await exportMultipleSamplesAsCSV(samples);
      
      await Sharing.shareAsync(csvPath, {
        mimeType: 'text/csv',
        dialogTitle: `Share ${samples.length} Samples`,
      });
    } else {
      // For PDF, we'd need to create a multi-sample report
      throw new Error('Multi-sample PDF export not yet implemented');
    }
    
  } catch (error) {
    console.error('Failed to share multiple samples:', error);
    throw new Error(`Multi-sample sharing failed: ${error}`);
  }
}

/**
 * Save files to device storage
 */
export async function saveToFiles(
  sample: Sample,
  squareCounts: SquareCount[],
  qcAlerts: QCAlert[] = [],
  options: ShareOptions = { format: 'both' }
): Promise<{ savedFiles: string[]; totalSize: number }> {
  try {
    const savedFiles: string[] = [];
    let totalSize = 0;
    
    if (options.format === 'pdf' || options.format === 'both') {
      const pdfPath = await generatePDFReport(sample, squareCounts, qcAlerts);
      savedFiles.push(pdfPath);
      
      const pdfInfo = await FileSystem.getInfoAsync(pdfPath);
      if (pdfInfo.exists) {
        totalSize += pdfInfo.size || 0;
      }
    }
    
    if (options.format === 'csv' || options.format === 'both') {
      const csvFiles = await exportSampleAsCSV(
        sample,
        squareCounts,
        options.includeDetections
      );
      
      savedFiles.push(csvFiles.summaryPath);
      savedFiles.push(csvFiles.squaresPath);
      
      if (csvFiles.detailsPath) {
        savedFiles.push(csvFiles.detailsPath);
      }
      
      // Calculate CSV file sizes
      for (const csvPath of [csvFiles.summaryPath, csvFiles.squaresPath, csvFiles.detailsPath].filter(Boolean)) {
        const csvInfo = await FileSystem.getInfoAsync(csvPath!);
        if (csvInfo.exists) {
          totalSize += csvInfo.size || 0;
        }
      }
    }
    
    return { savedFiles, totalSize };
    
  } catch (error) {
    console.error('Failed to save files:', error);
    throw new Error(`File saving failed: ${error}`);
  }
}

/**
 * Check if sharing is available
 */
export async function isSharingAvailable(): Promise<boolean> {
  try {
    return await Sharing.isAvailableAsync();
  } catch (error) {
    console.error('Failed to check sharing availability:', error);
    return false;
  }
}

/**
 * Get available sharing options
 */
export function getShareOptions(): ShareOptions[] {
  return [
    {
      format: 'pdf',
      includeImages: false,
      includeDetections: false,
    },
    {
      format: 'pdf',
      includeImages: true,
      includeDetections: false,
    },
    {
      format: 'csv',
      includeImages: false,
      includeDetections: false,
    },
    {
      format: 'csv',
      includeImages: false,
      includeDetections: true,
    },
    {
      format: 'both',
      includeImages: false,
      includeDetections: true,
    },
  ];
}

/**
 * Estimate export size before sharing
 */
export async function estimateExportSize(
  samples: Sample[],
  options: ShareOptions
): Promise<{
  estimatedSize: number;
  breakdown: {
    pdf?: number;
    csv?: number;
    images?: number;
  };
}> {
  const breakdown: { pdf?: number; csv?: number; images?: number } = {};
  let estimatedSize = 0;
  
  if (options.format === 'pdf' || options.format === 'both') {
    // Estimate PDF size: ~50KB base + ~10 bytes per detection
    const pdfSize = samples.reduce((total, sample) => {
      return total + 50000 + (sample.detections.length * 10);
    }, 0);
    
    breakdown.pdf = pdfSize;
    estimatedSize += pdfSize;
    
    if (options.includeImages) {
      // Estimate ~600KB per sample for 3 images
      const imageSize = samples.length * 600000;
      breakdown.images = imageSize;
      estimatedSize += imageSize;
    }
  }
  
  if (options.format === 'csv' || options.format === 'both') {
    // Estimate CSV size: ~150 bytes per sample + ~100 bytes per detection
    const csvSize = samples.reduce((total, sample) => {
      const summarySize = 150;
      const detectionSize = options.includeDetections ? sample.detections.length * 100 : 0;
      return total + summarySize + detectionSize;
    }, 0);
    
    breakdown.csv = csvSize;
    estimatedSize += csvSize;
  }
  
  return {
    estimatedSize,
    breakdown,
  };
}

/**
 * Clean up temporary export files
 */
export async function cleanupTempFiles(filePaths: string[]): Promise<void> {
  try {
    await Promise.all(
      filePaths.map(async (filePath) => {
        try {
          const fileInfo = await FileSystem.getInfoAsync(filePath);
          if (fileInfo.exists) {
            await FileSystem.deleteAsync(filePath);
          }
        } catch (error) {
          console.warn(`Failed to delete temp file ${filePath}:`, error);
        }
      })
    );
  } catch (error) {
    console.warn('Failed to cleanup temp files:', error);
  }
}

/**
 * Format file size for display
 */
export function formatFileSize(bytes: number): string {
  if (bytes === 0) return '0 B';
  
  const k = 1024;
  const sizes = ['B', 'KB', 'MB', 'GB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  
  return `${parseFloat((bytes / Math.pow(k, i)).toFixed(1))} ${sizes[i]}`;
}

/**
 * Get MIME type for file extension
 */
export function getMimeType(filename: string): string {
  const extension = filename.toLowerCase().split('.').pop();
  
  switch (extension) {
    case 'pdf':
      return 'application/pdf';
    case 'csv':
      return 'text/csv';
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'png':
      return 'image/png';
    default:
      return 'application/octet-stream';
  }
}
