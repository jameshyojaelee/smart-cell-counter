/**
 * SQLite database initialization and migration management
 */
import * as SQLite from 'expo-sqlite';
import { Sample, DetectionObject } from '../types';

const DB_NAME = 'cell_counter.db';
const DB_VERSION = 1;

let db: SQLite.SQLiteDatabase | null = null;

/**
 * Initialize database connection and run migrations
 */
export async function initializeDatabase(): Promise<void> {
  try {
    db = await SQLite.openDatabaseAsync(DB_NAME);
    await runMigrations();
  } catch (error) {
    console.error('Failed to initialize database:', error);
    throw error;
  }
}

/**
 * Get database instance
 */
export function getDatabase(): SQLite.SQLiteDatabase {
  if (!db) {
    throw new Error('Database not initialized. Call initializeDatabase() first.');
  }
  return db;
}

/**
 * Run database migrations
 */
async function runMigrations(): Promise<void> {
  if (!db) return;

  try {
    // Create version table if it doesn't exist
    await db.execAsync(`
      CREATE TABLE IF NOT EXISTS schema_version (
        version INTEGER PRIMARY KEY
      );
    `);

    // Check current version
    const result = await db.getFirstAsync<{ version: number }>(`
      SELECT version FROM schema_version LIMIT 1;
    `);
    
    const currentVersion = result?.version || 0;

    // Run migrations
    if (currentVersion < 1) {
      await runMigrationV1();
    }

    // Update version
    if (currentVersion === 0) {
      await db.runAsync('INSERT INTO schema_version (version) VALUES (?);', [DB_VERSION]);
    } else {
      await db.runAsync('UPDATE schema_version SET version = ?;', [DB_VERSION]);
    }
  } catch (error) {
    console.error('Migration failed:', error);
    throw error;
  }
}

/**
 * Migration to version 1: Create initial tables
 */
async function runMigrationV1(): Promise<void> {
  if (!db) return;

  await db.execAsync(`
    CREATE TABLE IF NOT EXISTS samples (
      id TEXT PRIMARY KEY,
      timestamp INTEGER NOT NULL,
      operator TEXT NOT NULL,
      project TEXT NOT NULL,
      chamber_type TEXT NOT NULL,
      dilution_factor REAL NOT NULL,
      stain_type TEXT NOT NULL,
      live_total INTEGER NOT NULL,
      dead_total INTEGER NOT NULL,
      concentration REAL NOT NULL,
      viability REAL NOT NULL,
      squares_used INTEGER NOT NULL,
      rejected_squares INTEGER NOT NULL,
      focus_score REAL NOT NULL,
      glare_ratio REAL NOT NULL,
      image_path TEXT NOT NULL,
      mask_path TEXT NOT NULL,
      pdf_path TEXT,
      notes TEXT
    );
  `);

  await db.execAsync(`
    CREATE TABLE IF NOT EXISTS detections (
      sample_id TEXT NOT NULL,
      object_id TEXT NOT NULL,
      x REAL NOT NULL,
      y REAL NOT NULL,
      area REAL NOT NULL,
      circularity REAL NOT NULL,
      is_live INTEGER NOT NULL,
      confidence REAL NOT NULL,
      square_index INTEGER NOT NULL,
      PRIMARY KEY (sample_id, object_id),
      FOREIGN KEY (sample_id) REFERENCES samples(id) ON DELETE CASCADE
    );
  `);

  // Create indexes for better query performance
  await db.execAsync(`
    CREATE INDEX IF NOT EXISTS idx_samples_timestamp ON samples(timestamp);
    CREATE INDEX IF NOT EXISTS idx_samples_operator ON samples(operator);
    CREATE INDEX IF NOT EXISTS idx_samples_project ON samples(project);
    CREATE INDEX IF NOT EXISTS idx_detections_sample_id ON detections(sample_id);
  `);
}

/**
 * Convert database row to Sample object
 */
export function rowToSample(row: any, detections: DetectionObject[] = []): Sample {
  return {
    id: row.id,
    timestamp: row.timestamp,
    operator: row.operator,
    project: row.project,
    chamberType: row.chamber_type,
    dilutionFactor: row.dilution_factor,
    stainType: row.stain_type,
    liveTotal: row.live_total,
    deadTotal: row.dead_total,
    concentration: row.concentration,
    viability: row.viability,
    squaresUsed: row.squares_used,
    rejectedSquares: row.rejected_squares,
    focusScore: row.focus_score,
    glareRatio: row.glare_ratio,
    imagePath: row.image_path,
    maskPath: row.mask_path,
    pdfPath: row.pdf_path,
    notes: row.notes,
    detections,
  };
}

/**
 * Convert database row to DetectionObject
 */
export function rowToDetection(row: any): DetectionObject {
  return {
    id: row.object_id,
    centroid: { x: row.x, y: row.y },
    areaPx: row.area,
    areaUm2: row.area, // Will be calculated properly in processing
    circularity: row.circularity,
    bbox: { x: 0, y: 0, width: 0, height: 0 }, // Not stored in DB
    isLive: Boolean(row.is_live),
    confidence: row.confidence,
    squareIndex: row.square_index,
  };
}
