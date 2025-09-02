/**
 * Review Screen - Interactive cell detection review and editing
 */
import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  ScrollView,
  Alert,
  ActivityIndicator,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { router } from 'expo-router';
import { Image } from 'expo-image';
import { Ionicons } from '@expo/vector-icons';
import { useAppStore } from '../src/state/store';
import { segmentCells } from '../src/imaging/segmentation';
import { classifyViability, calculateViabilityStats } from '../src/imaging/viability';
import { countCellsPerSquare, detectOutliers } from '../src/imaging/counting';
import { StatCard } from '../src/components/StatCard';
import { logUserInteraction, logError } from '../src/utils/logger';

export default function ReviewScreen(): JSX.Element {
  const [isProcessing, setIsProcessing] = useState(false);
  const [processingStep, setProcessingStep] = useState('');
  const [squareCounts, setSquareCounts] = useState<any[]>([]);

  const {
    correctedImageUri,
    maskImageUri,
    detections,
    setDetections,
    currentSample,
    updateCurrentSample,
    settings,
    selectedSquares,
    setSelectedSquares,
  } = useAppStore();

  useEffect(() => {
    if (correctedImageUri && detections.length === 0) {
      processImage();
    }
  }, [correctedImageUri]);

  useEffect(() => {
    if (detections.length > 0) {
      calculateSquareCounts();
    }
  }, [detections, selectedSquares]);

  const processImage = async (): Promise<void> => {
    if (!correctedImageUri) return;

    setIsProcessing(true);
    logUserInteraction('Review', 'StartProcessing');

    try {
      // Step 1: Segment cells
      setProcessingStep('Segmenting cells...');
      const segmentationResult = await segmentCells(
        correctedImageUri,
        settings.processingParams,
        10.5, // Mock pixels per micron
        (step, progress) => {
          setProcessingStep(step);
        }
      );

      // Step 2: Classify viability
      setProcessingStep('Classifying viability...');
      const classifiedDetections = classifyViability(
        segmentationResult.detections,
        currentSample?.stainType || 'trypan_blue',
        settings.viabilityThresholds
      );

      setDetections(classifiedDetections);

      // Update sample with basic info
      const stats = calculateViabilityStats(classifiedDetections);
      updateCurrentSample({
        liveTotal: stats.live,
        deadTotal: stats.dead,
        detections: classifiedDetections,
      });

    } catch (error) {
      logError('Review', error as Error, { context: 'processImage' });
      Alert.alert('Processing Error', 'Failed to process image. Please try again.');
    } finally {
      setIsProcessing(false);
      setProcessingStep('');
    }
  };

  const calculateSquareCounts = (): void => {
    const counts = countCellsPerSquare(detections, 1000, 1000, 4);
    const countsWithOutliers = detectOutliers(counts, settings.qcThresholds.maxVarianceMAD);
    setSquareCounts(countsWithOutliers);
  };

  const toggleSquareSelection = (squareIndex: number): void => {
    const newSelection = selectedSquares.includes(squareIndex)
      ? selectedSquares.filter(i => i !== squareIndex)
      : [...selectedSquares, squareIndex];
    
    setSelectedSquares(newSelection);
    logUserInteraction('Review', 'ToggleSquareSelection', { squareIndex, selected: !selectedSquares.includes(squareIndex) });
  };

  const toggleCellViability = (cellId: string): void => {
    const updatedDetections = detections.map(detection => 
      detection.id === cellId 
        ? { ...detection, isLive: !detection.isLive }
        : detection
    );
    setDetections(updatedDetections);
    logUserInteraction('Review', 'ToggleCellViability', { cellId });
  };

  const handleProceedToResults = (): void => {
    if (selectedSquares.length === 0) {
      Alert.alert('No Squares Selected', 'Please select at least one square for counting.');
      return;
    }

    logUserInteraction('Review', 'ProceedToResults');
    router.push('/results');
  };

  const stats = calculateViabilityStats(detections);

  if (isProcessing) {
    return (
      <SafeAreaView style={styles.container}>
        <View style={styles.loadingContainer}>
          <ActivityIndicator size="large" color="#007AFF" />
          <Text style={styles.loadingTitle}>Processing Image</Text>
          <Text style={styles.loadingText}>{processingStep}</Text>
        </View>
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView style={styles.container}>
      <ScrollView style={styles.scrollView}>
        {/* Image with overlays */}
        <View style={styles.imageContainer}>
          {correctedImageUri && (
            <Image source={{ uri: correctedImageUri }} style={styles.image} />
          )}
          
          {/* Detection overlay would be rendered here */}
          <View style={styles.detectionOverlay}>
            <Text style={styles.overlayText}>
              {detections.length} cells detected
            </Text>
          </View>
        </View>

        {/* Statistics Cards */}
        <View style={styles.statsContainer}>
          <StatCard
            title="Total Cells"
            value={stats.total}
            icon="cellular"
            color="#007AFF"
          />
          <StatCard
            title="Viability"
            value={stats.viability.toFixed(1)}
            unit="%"
            icon="heart"
            color="#34C759"
          />
        </View>

        <View style={styles.statsContainer}>
          <StatCard
            title="Live Cells"
            value={stats.live}
            icon="checkmark-circle"
            color="#34C759"
          />
          <StatCard
            title="Dead Cells"
            value={stats.dead}
            icon="close-circle"
            color="#FF3B30"
          />
        </View>

        {/* Square Selection */}
        <View style={styles.squareSelectionContainer}>
          <Text style={styles.sectionTitle}>Square Selection</Text>
          <Text style={styles.sectionSubtitle}>
            Select which squares to include in the final count
          </Text>
          
          <View style={styles.squareGrid}>
            {squareCounts.map((square, index) => (
              <TouchableOpacity
                key={index}
                style={[
                  styles.squareCard,
                  selectedSquares.includes(index) && styles.squareCardSelected,
                  square.isOutlier && styles.squareCardOutlier,
                ]}
                onPress={() => toggleSquareSelection(index)}
              >
                <Text style={styles.squareTitle}>Square {index + 1}</Text>
                <Text style={styles.squareCount}>{square.total}</Text>
                <Text style={styles.squareBreakdown}>
                  {square.live} live, {square.dead} dead
                </Text>
                {square.isOutlier && (
                  <View style={styles.outlierBadge}>
                    <Text style={styles.outlierText}>Outlier</Text>
                  </View>
                )}
              </TouchableOpacity>
            ))}
          </View>
        </View>

        {/* Instructions */}
        <View style={styles.instructionsContainer}>
          <Text style={styles.instructionsTitle}>Review Instructions</Text>
          <Text style={styles.instructionsText}>
            • Tap cells in the image to toggle live/dead classification
          </Text>
          <Text style={styles.instructionsText}>
            • Use pinch-to-zoom for detailed inspection
          </Text>
          <Text style={styles.instructionsText}>
            • Select squares to include in final count
          </Text>
          <Text style={styles.instructionsText}>
            • Outlier squares are automatically excluded
          </Text>
        </View>
      </ScrollView>

      {/* Controls */}
      <View style={styles.controlsContainer}>
        <TouchableOpacity
          style={styles.secondaryButton}
          onPress={() => router.back()}
        >
          <Ionicons name="arrow-back" size={20} color="#666" />
          <Text style={styles.secondaryButtonText}>Back</Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={styles.primaryButton}
          onPress={handleProceedToResults}
        >
          <Text style={styles.primaryButtonText}>Calculate Results</Text>
          <Ionicons name="calculator" size={20} color="#fff" />
        </TouchableOpacity>
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f8f9fa',
  },
  scrollView: {
    flex: 1,
  },
  loadingContainer: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    padding: 20,
  },
  loadingTitle: {
    fontSize: 20,
    fontWeight: '600',
    color: '#333',
    marginTop: 20,
  },
  loadingText: {
    fontSize: 16,
    color: '#666',
    marginTop: 8,
  },
  imageContainer: {
    margin: 20,
    borderRadius: 12,
    overflow: 'hidden',
    backgroundColor: '#000',
    elevation: 4,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 8,
  },
  image: {
    width: '100%',
    aspectRatio: 1,
  },
  detectionOverlay: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    backgroundColor: 'rgba(0, 0, 0, 0.7)',
    padding: 12,
  },
  overlayText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
    textAlign: 'center',
  },
  statsContainer: {
    flexDirection: 'row',
    paddingHorizontal: 12,
  },
  squareSelectionContainer: {
    padding: 20,
  },
  sectionTitle: {
    fontSize: 20,
    fontWeight: '600',
    color: '#333',
    marginBottom: 8,
  },
  sectionSubtitle: {
    fontSize: 14,
    color: '#666',
    marginBottom: 16,
  },
  squareGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    justifyContent: 'space-between',
  },
  squareCard: {
    width: '48%',
    backgroundColor: '#fff',
    borderRadius: 12,
    padding: 16,
    marginBottom: 12,
    borderWidth: 2,
    borderColor: '#E5E5EA',
    elevation: 2,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.05,
    shadowRadius: 4,
  },
  squareCardSelected: {
    borderColor: '#007AFF',
    backgroundColor: '#F0F8FF',
  },
  squareCardOutlier: {
    borderColor: '#FF3B30',
    backgroundColor: '#FFF5F5',
  },
  squareTitle: {
    fontSize: 14,
    fontWeight: '600',
    color: '#333',
    marginBottom: 8,
  },
  squareCount: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#007AFF',
    marginBottom: 4,
  },
  squareBreakdown: {
    fontSize: 12,
    color: '#666',
  },
  outlierBadge: {
    position: 'absolute',
    top: 8,
    right: 8,
    backgroundColor: '#FF3B30',
    paddingHorizontal: 6,
    paddingVertical: 2,
    borderRadius: 4,
  },
  outlierText: {
    color: '#fff',
    fontSize: 10,
    fontWeight: '600',
  },
  instructionsContainer: {
    padding: 20,
    backgroundColor: '#fff',
    margin: 20,
    borderRadius: 12,
  },
  instructionsTitle: {
    fontSize: 16,
    fontWeight: '600',
    color: '#333',
    marginBottom: 12,
  },
  instructionsText: {
    fontSize: 14,
    color: '#666',
    marginBottom: 8,
    lineHeight: 20,
  },
  controlsContainer: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: 20,
    backgroundColor: '#fff',
    borderTopWidth: 1,
    borderTopColor: '#E5E5EA',
  },
  secondaryButton: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingVertical: 12,
    borderRadius: 8,
    backgroundColor: '#f0f0f0',
  },
  secondaryButtonText: {
    fontSize: 16,
    color: '#666',
    marginLeft: 8,
  },
  primaryButton: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 24,
    paddingVertical: 12,
    borderRadius: 8,
    backgroundColor: '#007AFF',
  },
  primaryButtonText: {
    fontSize: 16,
    fontWeight: '600',
    color: '#fff',
    marginRight: 8,
  },
});
