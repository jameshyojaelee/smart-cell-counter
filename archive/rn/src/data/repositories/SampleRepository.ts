/**
 * Repository for Sample CRUD operations
 */
import { getDatabase, rowToSample, rowToDetection } from '../db';
import { Sample, DetectionObject } from '../../types';

export class SampleRepository {
  /**
   * Save a sample with its detections
   */
  async saveSample(sample: Sample): Promise<void> {
    const db = getDatabase();
    
    try {
      await db.withTransactionAsync(async () => {
        // Insert or update sample
        await db.runAsync(`
          INSERT OR REPLACE INTO samples (
            id, timestamp, operator, project, chamber_type, dilution_factor,
            stain_type, live_total, dead_total, concentration, viability,
            squares_used, rejected_squares, focus_score, glare_ratio,
            image_path, mask_path, pdf_path, notes
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        `, [
          sample.id,
          sample.timestamp,
          sample.operator,
          sample.project,
          sample.chamberType,
          sample.dilutionFactor,
          sample.stainType,
          sample.liveTotal,
          sample.deadTotal,
          sample.concentration,
          sample.viability,
          sample.squaresUsed,
          sample.rejectedSquares,
          sample.focusScore,
          sample.glareRatio,
          sample.imagePath,
          sample.maskPath,
          sample.pdfPath || null,
          sample.notes || null,
        ]);

        // Delete existing detections
        await db.runAsync('DELETE FROM detections WHERE sample_id = ?;', [sample.id]);

        // Insert new detections
        if (sample.detections.length > 0) {
          for (const detection of sample.detections) {
            await db.runAsync(`
              INSERT INTO detections (
                sample_id, object_id, x, y, area, circularity,
                is_live, confidence, square_index
              ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
            `, [
              sample.id,
              detection.id,
              detection.centroid.x,
              detection.centroid.y,
              detection.areaPx,
              detection.circularity,
              detection.isLive ? 1 : 0,
              detection.confidence,
              detection.squareIndex,
            ]);
          }
        }
      });
    } catch (error) {
      console.error('Failed to save sample:', error);
      throw error;
    }
  }

  /**
   * Get a sample by ID with its detections
   */
  async getSampleById(id: string): Promise<Sample | null> {
    const db = getDatabase();
    
    try {
      // Get sample
      const sampleRow = await db.getFirstAsync(`
        SELECT * FROM samples WHERE id = ?;
      `, [id]);

      if (!sampleRow) {
        return null;
      }

      // Get detections
      const detectionRows = await db.getAllAsync(`
        SELECT * FROM detections WHERE sample_id = ? ORDER BY object_id;
      `, [id]);

      const detections = detectionRows.map(rowToDetection);
      return rowToSample(sampleRow, detections);
    } catch (error) {
      console.error('Failed to get sample:', error);
      throw error;
    }
  }

  /**
   * Get all samples with pagination and optional filters
   */
  async getSamples(options: {
    limit?: number;
    offset?: number;
    operator?: string;
    project?: string;
    startDate?: number;
    endDate?: number;
  } = {}): Promise<Sample[]> {
    const db = getDatabase();
    const { limit = 50, offset = 0, operator, project, startDate, endDate } = options;
    
    try {
      let query = 'SELECT * FROM samples WHERE 1=1';
      const params: any[] = [];

      if (operator) {
        query += ' AND operator LIKE ?';
        params.push(`%${operator}%`);
      }

      if (project) {
        query += ' AND project LIKE ?';
        params.push(`%${project}%`);
      }

      if (startDate) {
        query += ' AND timestamp >= ?';
        params.push(startDate);
      }

      if (endDate) {
        query += ' AND timestamp <= ?';
        params.push(endDate);
      }

      query += ' ORDER BY timestamp DESC LIMIT ? OFFSET ?';
      params.push(limit, offset);

      const sampleRows = await db.getAllAsync(query, params);
      
      // For list view, we don't need to load all detections
      return sampleRows.map(row => rowToSample(row));
    } catch (error) {
      console.error('Failed to get samples:', error);
      throw error;
    }
  }

  /**
   * Delete a sample and its detections
   */
  async deleteSample(id: string): Promise<void> {
    const db = getDatabase();
    
    try {
      await db.runAsync('DELETE FROM samples WHERE id = ?;', [id]);
      // Detections will be deleted by CASCADE
    } catch (error) {
      console.error('Failed to delete sample:', error);
      throw error;
    }
  }

  /**
   * Get sample count with optional filters
   */
  async getSampleCount(options: {
    operator?: string;
    project?: string;
    startDate?: number;
    endDate?: number;
  } = {}): Promise<number> {
    const db = getDatabase();
    const { operator, project, startDate, endDate } = options;
    
    try {
      let query = 'SELECT COUNT(*) as count FROM samples WHERE 1=1';
      const params: any[] = [];

      if (operator) {
        query += ' AND operator LIKE ?';
        params.push(`%${operator}%`);
      }

      if (project) {
        query += ' AND project LIKE ?';
        params.push(`%${project}%`);
      }

      if (startDate) {
        query += ' AND timestamp >= ?';
        params.push(startDate);
      }

      if (endDate) {
        query += ' AND timestamp <= ?';
        params.push(endDate);
      }

      const result = await db.getFirstAsync<{ count: number }>(query, params);
      return result?.count || 0;
    } catch (error) {
      console.error('Failed to get sample count:', error);
      throw error;
    }
  }

  /**
   * Get unique operators
   */
  async getOperators(): Promise<string[]> {
    const db = getDatabase();
    
    try {
      const rows = await db.getAllAsync<{ operator: string }>(`
        SELECT DISTINCT operator FROM samples 
        WHERE operator != '' 
        ORDER BY operator;
      `);
      
      return rows.map(row => row.operator);
    } catch (error) {
      console.error('Failed to get operators:', error);
      throw error;
    }
  }

  /**
   * Get unique projects
   */
  async getProjects(): Promise<string[]> {
    const db = getDatabase();
    
    try {
      const rows = await db.getAllAsync<{ project: string }>(`
        SELECT DISTINCT project FROM samples 
        WHERE project != '' 
        ORDER BY project;
      `);
      
      return rows.map(row => row.project);
    } catch (error) {
      console.error('Failed to get projects:', error);
      throw error;
    }
  }
}
