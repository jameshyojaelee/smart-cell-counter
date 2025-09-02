/**
 * Logging and performance monitoring utilities
 */
import { MMKV } from 'react-native-mmkv';

// Separate storage for logs to avoid cluttering main storage
const logStorage = new MMKV({ id: 'app_logs' });

export interface LogEntry {
  timestamp: number;
  level: 'debug' | 'info' | 'warn' | 'error';
  category: string;
  message: string;
  data?: any;
  duration?: number;
}

export interface PerformanceMetric {
  operation: string;
  startTime: number;
  endTime: number;
  duration: number;
  metadata?: any;
}

class Logger {
  private maxLogEntries = 1000;
  private performanceMetrics: PerformanceMetric[] = [];
  private activeTimers: Map<string, number> = new Map();

  /**
   * Log a debug message
   */
  debug(category: string, message: string, data?: any): void {
    this.log('debug', category, message, data);
  }

  /**
   * Log an info message
   */
  info(category: string, message: string, data?: any): void {
    this.log('info', category, message, data);
  }

  /**
   * Log a warning message
   */
  warn(category: string, message: string, data?: any): void {
    this.log('warn', category, message, data);
    console.warn(`[${category}] ${message}`, data);
  }

  /**
   * Log an error message
   */
  error(category: string, message: string, data?: any): void {
    this.log('error', category, message, data);
    console.error(`[${category}] ${message}`, data);
  }

  /**
   * Start timing an operation
   */
  startTimer(operation: string): void {
    this.activeTimers.set(operation, Date.now());
  }

  /**
   * End timing an operation and log the duration
   */
  endTimer(operation: string, metadata?: any): number {
    const startTime = this.activeTimers.get(operation);
    if (!startTime) {
      this.warn('Logger', `Timer not found for operation: ${operation}`);
      return 0;
    }

    const endTime = Date.now();
    const duration = endTime - startTime;

    const metric: PerformanceMetric = {
      operation,
      startTime,
      endTime,
      duration,
      metadata,
    };

    this.performanceMetrics.push(metric);
    this.activeTimers.delete(operation);

    this.info('Performance', `${operation} completed in ${duration}ms`, metadata);
    
    return duration;
  }

  /**
   * Log with timing information
   */
  timeOperation<T>(operation: string, fn: () => Promise<T>, metadata?: any): Promise<T> {
    this.startTimer(operation);
    
    return fn()
      .then((result) => {
        this.endTimer(operation, metadata);
        return result;
      })
      .catch((error) => {
        this.endTimer(operation, { ...metadata, error: error.message });
        throw error;
      });
  }

  /**
   * Get performance metrics
   */
  getPerformanceMetrics(operation?: string): PerformanceMetric[] {
    if (operation) {
      return this.performanceMetrics.filter(m => m.operation === operation);
    }
    return [...this.performanceMetrics];
  }

  /**
   * Get performance statistics
   */
  getPerformanceStats(operation: string): {
    count: number;
    averageDuration: number;
    minDuration: number;
    maxDuration: number;
    totalDuration: number;
  } {
    const metrics = this.getPerformanceMetrics(operation);
    
    if (metrics.length === 0) {
      return {
        count: 0,
        averageDuration: 0,
        minDuration: 0,
        maxDuration: 0,
        totalDuration: 0,
      };
    }

    const durations = metrics.map(m => m.duration);
    const totalDuration = durations.reduce((sum, d) => sum + d, 0);

    return {
      count: metrics.length,
      averageDuration: totalDuration / metrics.length,
      minDuration: Math.min(...durations),
      maxDuration: Math.max(...durations),
      totalDuration,
    };
  }

  /**
   * Clear performance metrics
   */
  clearPerformanceMetrics(): void {
    this.performanceMetrics = [];
  }

  /**
   * Get recent log entries
   */
  getRecentLogs(limit: number = 100): LogEntry[] {
    try {
      const logsJson = logStorage.getString('log_entries');
      if (!logsJson) return [];

      const logs: LogEntry[] = JSON.parse(logsJson);
      return logs.slice(-limit);
    } catch (error) {
      console.error('Failed to retrieve logs:', error);
      return [];
    }
  }

  /**
   * Export logs as text
   */
  exportLogs(): string {
    const logs = this.getRecentLogs();
    
    return logs
      .map(log => {
        const timestamp = new Date(log.timestamp).toISOString();
        const dataStr = log.data ? ` | ${JSON.stringify(log.data)}` : '';
        const durationStr = log.duration ? ` (${log.duration}ms)` : '';
        
        return `[${timestamp}] ${log.level.toUpperCase()} [${log.category}] ${log.message}${durationStr}${dataStr}`;
      })
      .join('\n');
  }

  /**
   * Clear all logs
   */
  clearLogs(): void {
    logStorage.delete('log_entries');
  }

  /**
   * Internal logging method
   */
  private log(level: LogEntry['level'], category: string, message: string, data?: any, duration?: number): void {
    const entry: LogEntry = {
      timestamp: Date.now(),
      level,
      category,
      message,
      data,
      duration,
    };

    try {
      const existingLogsJson = logStorage.getString('log_entries');
      const existingLogs: LogEntry[] = existingLogsJson ? JSON.parse(existingLogsJson) : [];
      
      existingLogs.push(entry);
      
      // Keep only the most recent entries
      if (existingLogs.length > this.maxLogEntries) {
        existingLogs.splice(0, existingLogs.length - this.maxLogEntries);
      }
      
      logStorage.set('log_entries', JSON.stringify(existingLogs));
    } catch (error) {
      console.error('Failed to store log entry:', error);
    }

    // Also log to console in development
    if (__DEV__) {
      const logFn = console[level] || console.log;
      logFn(`[${category}] ${message}`, data);
    }
  }
}

// Export singleton instance
export const logger = new Logger();

/**
 * Log image processing pipeline steps
 */
export function logImageProcessingStep(
  step: string,
  inputUri: string,
  outputUri?: string,
  metadata?: any
): void {
  logger.info('ImageProcessing', `${step} completed`, {
    inputUri: inputUri.split('/').pop(), // Log only filename for privacy
    outputUri: outputUri?.split('/').pop(),
    ...metadata,
  });
}

/**
 * Log detection results
 */
export function logDetectionResults(
  detectionCount: number,
  liveCount: number,
  deadCount: number,
  processingTimeMs: number
): void {
  logger.info('Detection', 'Cell detection completed', {
    totalDetections: detectionCount,
    liveCount,
    deadCount,
    viability: detectionCount > 0 ? (liveCount / detectionCount * 100).toFixed(1) : 0,
    processingTimeMs,
  });
}

/**
 * Log QC alerts
 */
export function logQCAlert(
  type: string,
  severity: 'warning' | 'error',
  message: string,
  metadata?: any
): void {
  const level = severity === 'error' ? 'error' : 'warn';
  logger[level]('QC', `${type}: ${message}`, metadata);
}

/**
 * Log user interactions
 */
export function logUserInteraction(
  screen: string,
  action: string,
  metadata?: any
): void {
  logger.info('UserInteraction', `${screen}: ${action}`, metadata);
}

/**
 * Log errors with context
 */
export function logError(
  category: string,
  error: Error,
  context?: any
): void {
  logger.error(category, error.message, {
    stack: error.stack,
    name: error.name,
    ...context,
  });
}

/**
 * Performance monitoring decorator
 */
export function withPerformanceLogging<T extends (...args: any[]) => Promise<any>>(
  operation: string,
  fn: T
): T {
  return (async (...args: any[]) => {
    return logger.timeOperation(operation, () => fn(...args));
  }) as T;
}

/**
 * Get app performance summary
 */
export function getAppPerformanceSummary(): {
  imageProcessing: ReturnType<typeof logger.getPerformanceStats>;
  detection: ReturnType<typeof logger.getPerformanceStats>;
  export: ReturnType<typeof logger.getPerformanceStats>;
  database: ReturnType<typeof logger.getPerformanceStats>;
} {
  return {
    imageProcessing: logger.getPerformanceStats('ImageProcessing'),
    detection: logger.getPerformanceStats('Detection'),
    export: logger.getPerformanceStats('Export'),
    database: logger.getPerformanceStats('Database'),
  };
}
