/**
 * PDF export utilities for sample reports
 */
import * as Print from 'expo-print';
import * as FileSystem from 'expo-file-system';
import { Sample, SquareCount, QCAlert } from '../types';
import { formatNumber } from '../imaging/math';

/**
 * Generate HTML content for PDF report
 */
export function generatePDFHTML(
  sample: Sample,
  squareCounts: SquareCount[],
  qcAlerts: QCAlert[] = []
): string {
  const timestamp = new Date(sample.timestamp).toLocaleString();
  const validSquares = squareCounts.filter(s => s.isSelected && !s.isOutlier);
  
  return `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <title>Cell Count Report - ${sample.id}</title>
      <style>
        body {
          font-family: 'Helvetica', 'Arial', sans-serif;
          line-height: 1.4;
          margin: 20px;
          color: #333;
        }
        
        .header {
          text-align: center;
          border-bottom: 2px solid #007AFF;
          padding-bottom: 20px;
          margin-bottom: 30px;
        }
        
        .header h1 {
          color: #007AFF;
          margin: 0;
          font-size: 24px;
        }
        
        .header .subtitle {
          color: #666;
          margin: 5px 0;
        }
        
        .info-grid {
          display: grid;
          grid-template-columns: 1fr 1fr;
          gap: 20px;
          margin-bottom: 30px;
        }
        
        .info-section {
          background: #f8f9fa;
          padding: 15px;
          border-radius: 8px;
          border-left: 4px solid #007AFF;
        }
        
        .info-section h3 {
          margin: 0 0 10px 0;
          color: #007AFF;
          font-size: 16px;
        }
        
        .info-row {
          display: flex;
          justify-content: space-between;
          margin: 5px 0;
        }
        
        .info-label {
          font-weight: bold;
          color: #666;
        }
        
        .results-summary {
          background: linear-gradient(135deg, #007AFF 0%, #5856D6 100%);
          color: white;
          padding: 20px;
          border-radius: 12px;
          margin: 20px 0;
          text-align: center;
        }
        
        .results-grid {
          display: grid;
          grid-template-columns: repeat(4, 1fr);
          gap: 15px;
          margin-top: 15px;
        }
        
        .result-item {
          text-align: center;
        }
        
        .result-value {
          font-size: 24px;
          font-weight: bold;
          display: block;
        }
        
        .result-label {
          font-size: 12px;
          opacity: 0.9;
          text-transform: uppercase;
          letter-spacing: 0.5px;
        }
        
        .squares-table {
          width: 100%;
          border-collapse: collapse;
          margin: 20px 0;
          background: white;
          border-radius: 8px;
          overflow: hidden;
          box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        
        .squares-table th,
        .squares-table td {
          padding: 12px;
          text-align: center;
          border-bottom: 1px solid #eee;
        }
        
        .squares-table th {
          background: #007AFF;
          color: white;
          font-weight: 600;
        }
        
        .squares-table tr:nth-child(even) {
          background: #f8f9fa;
        }
        
        .outlier {
          background: #ffebee !important;
          color: #c62828;
        }
        
        .excluded {
          background: #fafafa !important;
          color: #999;
          text-decoration: line-through;
        }
        
        .qc-alerts {
          margin: 20px 0;
        }
        
        .alert {
          padding: 10px 15px;
          border-radius: 6px;
          margin: 10px 0;
          border-left: 4px solid;
        }
        
        .alert.warning {
          background: #fff3cd;
          border-color: #ffc107;
          color: #856404;
        }
        
        .alert.error {
          background: #f8d7da;
          border-color: #dc3545;
          color: #721c24;
        }
        
        .formulas {
          background: #f8f9fa;
          padding: 20px;
          border-radius: 8px;
          margin: 20px 0;
        }
        
        .formulas h3 {
          color: #007AFF;
          margin-top: 0;
        }
        
        .formula {
          font-family: 'Courier New', monospace;
          background: white;
          padding: 10px;
          border-radius: 4px;
          margin: 10px 0;
          border-left: 3px solid #007AFF;
        }
        
        .images-section {
          page-break-before: always;
          margin-top: 40px;
        }
        
        .image-container {
          text-align: center;
          margin: 20px 0;
          page-break-inside: avoid;
        }
        
        .image-container img {
          max-width: 100%;
          max-height: 400px;
          border: 1px solid #ddd;
          border-radius: 8px;
        }
        
        .image-caption {
          margin-top: 10px;
          color: #666;
          font-style: italic;
        }
        
        .footer {
          margin-top: 40px;
          padding-top: 20px;
          border-top: 1px solid #ddd;
          text-align: center;
          color: #666;
          font-size: 12px;
        }
        
        @media print {
          body { margin: 0; }
          .page-break { page-break-before: always; }
        }
      </style>
    </head>
    <body>
      <!-- Header -->
      <div class="header">
        <h1>Cell Count Report</h1>
        <div class="subtitle">Smart Cell Counter Analysis</div>
        <div class="subtitle">${timestamp}</div>
      </div>
      
      <!-- Sample Information -->
      <div class="info-grid">
        <div class="info-section">
          <h3>Sample Details</h3>
          <div class="info-row">
            <span class="info-label">Sample ID:</span>
            <span>${sample.id}</span>
          </div>
          <div class="info-row">
            <span class="info-label">Operator:</span>
            <span>${sample.operator}</span>
          </div>
          <div class="info-row">
            <span class="info-label">Project:</span>
            <span>${sample.project}</span>
          </div>
          <div class="info-row">
            <span class="info-label">Chamber Type:</span>
            <span>${sample.chamberType.charAt(0).toUpperCase() + sample.chamberType.slice(1)}</span>
          </div>
        </div>
        
        <div class="info-section">
          <h3>Processing Parameters</h3>
          <div class="info-row">
            <span class="info-label">Stain Type:</span>
            <span>${sample.stainType}</span>
          </div>
          <div class="info-row">
            <span class="info-label">Dilution Factor:</span>
            <span>${sample.dilutionFactor}x</span>
          </div>
          <div class="info-row">
            <span class="info-label">Focus Score:</span>
            <span>${sample.focusScore.toFixed(1)}</span>
          </div>
          <div class="info-row">
            <span class="info-label">Glare Ratio:</span>
            <span>${(sample.glareRatio * 100).toFixed(1)}%</span>
          </div>
        </div>
      </div>
      
      <!-- Results Summary -->
      <div class="results-summary">
        <h2 style="margin: 0 0 15px 0;">Analysis Results</h2>
        <div class="results-grid">
          <div class="result-item">
            <span class="result-value">${formatNumber(sample.concentration, 'concentration')}</span>
            <span class="result-label">Concentration (cells/mL)</span>
          </div>
          <div class="result-item">
            <span class="result-value">${formatNumber(sample.viability, 'percentage')}</span>
            <span class="result-label">Viability</span>
          </div>
          <div class="result-item">
            <span class="result-value">${sample.liveTotal}</span>
            <span class="result-label">Live Cells</span>
          </div>
          <div class="result-item">
            <span class="result-value">${sample.deadTotal}</span>
            <span class="result-label">Dead Cells</span>
          </div>
        </div>
      </div>
      
      <!-- QC Alerts -->
      ${qcAlerts.length > 0 ? `
        <div class="qc-alerts">
          <h3>Quality Control Alerts</h3>
          ${qcAlerts.map(alert => `
            <div class="alert ${alert.severity}">
              <strong>${alert.type.toUpperCase()}:</strong> ${alert.message}
            </div>
          `).join('')}
        </div>
      ` : ''}
      
      <!-- Square Count Table -->
      <h3>Hemocytometer Square Counts</h3>
      <table class="squares-table">
        <thead>
          <tr>
            <th>Square</th>
            <th>Live Cells</th>
            <th>Dead Cells</th>
            <th>Total Cells</th>
            <th>Status</th>
          </tr>
        </thead>
        <tbody>
          ${squareCounts.map(square => `
            <tr class="${square.isOutlier ? 'outlier' : ''} ${!square.isSelected ? 'excluded' : ''}">
              <td>Square ${square.index + 1}</td>
              <td>${square.live}</td>
              <td>${square.dead}</td>
              <td>${square.total}</td>
              <td>
                ${square.isOutlier ? 'Outlier' : ''}
                ${!square.isSelected ? 'Excluded' : ''}
                ${square.isSelected && !square.isOutlier ? 'Used' : ''}
              </td>
            </tr>
          `).join('')}
        </tbody>
      </table>
      
      <!-- Statistics -->
      <div class="info-section">
        <h3>Statistical Summary</h3>
        <div class="info-row">
          <span class="info-label">Squares Used:</span>
          <span>${sample.squaresUsed} of ${squareCounts.length}</span>
        </div>
        <div class="info-row">
          <span class="info-label">Rejected Squares:</span>
          <span>${sample.rejectedSquares}</span>
        </div>
        <div class="info-row">
          <span class="info-label">Average Cells/Square:</span>
          <span>${validSquares.length > 0 ? 
            ((sample.liveTotal + sample.deadTotal) / validSquares.length).toFixed(1) : 'N/A'}</span>
        </div>
      </div>
      
      <!-- Formulas -->
      <div class="formulas">
        <h3>Calculation Formulas</h3>
        <div class="formula">
          <strong>Concentration (cells/mL) =</strong><br>
          Average cells per square × 10⁴ × Dilution factor
        </div>
        <div class="formula">
          <strong>Viability (%) =</strong><br>
          (Live cells / Total cells) × 100
        </div>
        <div class="formula">
          <strong>Inclusion Rule:</strong><br>
          Cells touching top and left borders are included.<br>
          Cells touching bottom and right borders are excluded.
        </div>
      </div>
      
      ${sample.notes ? `
        <div class="info-section">
          <h3>Notes</h3>
          <p>${sample.notes}</p>
        </div>
      ` : ''}
      
      <!-- Footer -->
      <div class="footer">
        <p>Generated by Smart Cell Counter App</p>
        <p>Report generated on ${new Date().toLocaleString()}</p>
      </div>
    </body>
    </html>
  `;
}

/**
 * Generate and save PDF report
 */
export async function generatePDFReport(
  sample: Sample,
  squareCounts: SquareCount[],
  qcAlerts: QCAlert[] = []
): Promise<string> {
  try {
    const html = generatePDFHTML(sample, squareCounts, qcAlerts);
    
    const { uri } = await Print.printToFileAsync({
      html,
      base64: false,
      width: 612, // Letter size width in points
      height: 792, // Letter size height in points
      margins: {
        left: 72,
        top: 72,
        right: 72,
        bottom: 72,
      },
    });
    
    // Move to documents directory with better filename
    const timestamp = new Date(sample.timestamp).toISOString().replace(/[:.]/g, '-');
    const filename = `${sample.id}_${timestamp}_report.pdf`;
    const finalPath = `${FileSystem.documentDirectory}${filename}`;
    
    await FileSystem.moveAsync({
      from: uri,
      to: finalPath,
    });
    
    return finalPath;
  } catch (error) {
    console.error('Failed to generate PDF:', error);
    throw new Error(`PDF generation failed: ${error}`);
  }
}

/**
 * Generate PDF with images included
 */
export async function generatePDFWithImages(
  sample: Sample,
  squareCounts: SquareCount[],
  qcAlerts: QCAlert[] = [],
  imagePaths: {
    original?: string;
    corrected?: string;
    overlay?: string;
  } = {}
): Promise<string> {
  try {
    let imagesHTML = '';
    
    if (Object.keys(imagePaths).length > 0) {
      imagesHTML = `
        <div class="images-section page-break">
          <h2>Images</h2>
      `;
      
      if (imagePaths.original) {
        const base64 = await FileSystem.readAsStringAsync(imagePaths.original, {
          encoding: FileSystem.EncodingType.Base64,
        });
        imagesHTML += `
          <div class="image-container">
            <img src="data:image/jpeg;base64,${base64}" alt="Original Image" />
            <div class="image-caption">Original hemocytometer image</div>
          </div>
        `;
      }
      
      if (imagePaths.corrected) {
        const base64 = await FileSystem.readAsStringAsync(imagePaths.corrected, {
          encoding: FileSystem.EncodingType.Base64,
        });
        imagesHTML += `
          <div class="image-container">
            <img src="data:image/jpeg;base64,${base64}" alt="Corrected Image" />
            <div class="image-caption">Perspective-corrected image</div>
          </div>
        `;
      }
      
      if (imagePaths.overlay) {
        const base64 = await FileSystem.readAsStringAsync(imagePaths.overlay, {
          encoding: FileSystem.EncodingType.Base64,
        });
        imagesHTML += `
          <div class="image-container">
            <img src="data:image/jpeg;base64,${base64}" alt="Detection Overlay" />
            <div class="image-caption">Detected cells with viability classification</div>
          </div>
        `;
      }
      
      imagesHTML += '</div>';
    }
    
    const baseHTML = generatePDFHTML(sample, squareCounts, qcAlerts);
    const htmlWithImages = baseHTML.replace('</body>', `${imagesHTML}</body>`);
    
    const { uri } = await Print.printToFileAsync({
      html: htmlWithImages,
      base64: false,
      width: 612,
      height: 792,
      margins: {
        left: 72,
        top: 72,
        right: 72,
        bottom: 72,
      },
    });
    
    const timestamp = new Date(sample.timestamp).toISOString().replace(/[:.]/g, '-');
    const filename = `${sample.id}_${timestamp}_full_report.pdf`;
    const finalPath = `${FileSystem.documentDirectory}${filename}`;
    
    await FileSystem.moveAsync({
      from: uri,
      to: finalPath,
    });
    
    return finalPath;
  } catch (error) {
    console.error('Failed to generate PDF with images:', error);
    throw new Error(`PDF with images generation failed: ${error}`);
  }
}

/**
 * Validate PDF generation requirements
 */
export function validatePDFRequirements(
  sample: Sample,
  squareCounts: SquareCount[]
): {
  isValid: boolean;
  errors: string[];
  warnings: string[];
} {
  const errors: string[] = [];
  const warnings: string[] = [];
  
  if (!sample.id) {
    errors.push('Sample ID is required for PDF generation');
  }
  
  if (!sample.operator) {
    warnings.push('Operator name is missing');
  }
  
  if (!sample.project) {
    warnings.push('Project name is missing');
  }
  
  if (squareCounts.length === 0) {
    errors.push('No square count data available');
  }
  
  if (sample.concentration < 0) {
    errors.push('Invalid concentration value');
  }
  
  if (sample.viability < 0 || sample.viability > 100) {
    errors.push('Invalid viability percentage');
  }
  
  return {
    isValid: errors.length === 0,
    errors,
    warnings,
  };
}

/**
 * Estimate PDF file size
 */
export function estimatePDFSize(
  sample: Sample,
  includeImages: boolean = false,
  imageCount: number = 0
): number {
  let baseSize = 50000; // ~50KB for basic PDF
  
  // Add size for detection data
  baseSize += sample.detections.length * 10; // ~10 bytes per detection
  
  if (includeImages) {
    baseSize += imageCount * 200000; // ~200KB per image
  }
  
  return baseSize;
}
