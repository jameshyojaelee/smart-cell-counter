/**
 * Advanced corner editor with gesture-based manipulation
 */
import React, { useState, useEffect, useCallback } from 'react';
import {
  View,
  StyleSheet,
  Dimensions,
  TouchableOpacity,
  Text,
  Alert,
  Platform,
} from 'react-native';
// Use RN Image to ensure onLoad has nativeEvent.source
import { Image as RNImage } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import {
  GestureHandlerRootView,
  PanGestureHandler,
  PinchGestureHandler,
  TapGestureHandler,
  State,
  PanGestureHandlerGestureEvent,
  PinchGestureHandlerGestureEvent,
  TapGestureHandlerGestureEvent,
} from 'react-native-gesture-handler';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  useAnimatedGestureHandler,
  runOnJS,
  withSpring,
  interpolate,
  Extrapolate,
} from 'react-native-reanimated';
import Svg, { Polygon, Line, Circle } from 'react-native-svg';
import { useAppStore } from '../state/store';

const { width: screenWidth, height: screenHeight } = Dimensions.get('window');

// Lightweight haptics shim: avoid requiring expo-haptics (not always installed)
function triggerLightHaptic(): void {
  try {
    if (Platform.OS === 'web') {
      // Use browser vibration API if available
      if (typeof navigator !== 'undefined' && 'vibrate' in navigator) {
        // @ts-ignore - web API
        navigator.vibrate?.(10);
      }
    } else {
      // No-op on native if haptics lib isn't present
      // Optional: integrate expo-haptics when available
    }
  } catch {}
}

export interface Corner {
  x: number;
  y: number;
}

interface CornerEditorProps {
  imageUri: string;
  initialCorners: Corner[];
  largeHandles?: boolean;
  onChange: (corners: Corner[]) => void;
  onConfirm: (corners: Corner[]) => void;
  onCancel: () => void;
  onAutoDetect?: () => void;
}

interface ImageDimensions {
  width: number;
  height: number;
}

export function CornerEditor({
  imageUri,
  initialCorners,
  largeHandles = false,
  onChange,
  onConfirm,
  onCancel,
  onAutoDetect,
}: CornerEditorProps): JSX.Element {
  const [corners, setCorners] = useState<Corner[]>(initialCorners);
  const [selectedCorner, setSelectedCorner] = useState<number | null>(null);
  const [dragMode, setDragMode] = useState<'corner' | 'box'>('corner');
  const [imageDimensions, setImageDimensions] = useState<ImageDimensions>({ width: 0, height: 0 });
  const { settings } = useAppStore();

  // Zoom and pan state
  const scale = useSharedValue(1);
  const translateX = useSharedValue(0);
  const translateY = useSharedValue(0);
  const baseScale = useSharedValue(1);
  const baseTranslateX = useSharedValue(0);
  const baseTranslateY = useSharedValue(0);

  // Corner animation values
  const cornerAnimations = corners.map(() => ({
    x: useSharedValue(0),
    y: useSharedValue(0),
  }));

  const handleSize = largeHandles ? 48 : 36;

  // Initialize corner positions
  useEffect(() => {
    corners.forEach((corner, index) => {
      if (cornerAnimations[index]) {
        cornerAnimations[index].x.value = corner.x;
        cornerAnimations[index].y.value = corner.y;
      }
    });
  }, [corners, imageDimensions]);

  // Check if polygon is self-intersecting
  const isPolygonValid = useCallback((testCorners: Corner[]): boolean => {
    if (testCorners.length !== 4) return false;
    
    // Simple check: ensure corners maintain TL, TR, BR, BL ordering
    const [tl, tr, br, bl] = testCorners;
    return (
      tl.x < tr.x && tl.y < bl.y &&
      tr.x > tl.x && tr.y < br.y &&
      br.x > bl.x && br.y > tr.y &&
      bl.x < br.x && bl.y > tl.y
    );
  }, []);

  // Snap to alignment
  const snapToAlignment = useCallback((corner: Corner, otherCorners: Corner[]): Corner => {
    const snapThreshold = settings.snapThreshold ?? 6;
    let snappedCorner = { ...corner };

    // Check for horizontal alignment
    for (const other of otherCorners) {
      if (Math.abs(corner.y - other.y) < snapThreshold) {
        snappedCorner.y = other.y;
        break;
      }
    }

    // Check for vertical alignment
    for (const other of otherCorners) {
      if (Math.abs(corner.x - other.x) < snapThreshold) {
        snappedCorner.x = other.x;
        break;
      }
    }

    return snappedCorner;
  }, [settings.snapThreshold]);

  // Update corner position
  const updateCorner = useCallback((index: number, newPosition: Corner) => {
    const newCorners = [...corners];

    // Constrain to image bounds
    const constrainedPosition = {
      x: Math.max(0, Math.min(imageDimensions.width, newPosition.x)),
      y: Math.max(0, Math.min(imageDimensions.height, newPosition.y)),
    };

    // Apply snapping
    const otherCorners = corners.filter((_, i) => i !== index);
    const snappedPosition = snapToAlignment(constrainedPosition, otherCorners);

    newCorners[index] = snappedPosition;

    // Validate polygon
    if (isPolygonValid(newCorners)) {
      setCorners(newCorners);
      onChange(newCorners);

      // Update animation value
      if (cornerAnimations[index]) {
        cornerAnimations[index].x.value = snappedPosition.x;
        cornerAnimations[index].y.value = snappedPosition.y;
      }

      // Haptic feedback on snap
      if (Math.abs(snappedPosition.x - constrainedPosition.x) > 0 ||
          Math.abs(snappedPosition.y - constrainedPosition.y) > 0) {
        triggerLightHaptic();
      }
    }
  }, [corners, imageDimensions, onChange, snapToAlignment, isPolygonValid, cornerAnimations]);

  // Move entire box
  const moveBox = useCallback((deltaX: number, deltaY: number) => {
    const newCorners = corners.map(corner => ({
      x: corner.x + deltaX,
      y: corner.y + deltaY,
    }));

    // Constrain all corners to image bounds
    const constrainedCorners = newCorners.map(corner => ({
      x: Math.max(0, Math.min(imageDimensions.width, corner.x)),
      y: Math.max(0, Math.min(imageDimensions.height, corner.y)),
    }));

    // Validate polygon
    if (isPolygonValid(constrainedCorners)) {
      setCorners(constrainedCorners);
      onChange(constrainedCorners);

      // Update all animation values
      constrainedCorners.forEach((corner, index) => {
        if (cornerAnimations[index]) {
          cornerAnimations[index].x.value = corner.x;
          cornerAnimations[index].y.value = corner.y;
        }
      });

      triggerLightHaptic();
    }
  }, [corners, imageDimensions, onChange, isPolygonValid, cornerAnimations]);

  // Box drag gesture handler
  const boxDragGestureHandler = useAnimatedGestureHandler<PanGestureHandlerGestureEvent>({
    onStart: () => {
      runOnJS(setSelectedCorner)(null);
    },
    onActive: (event) => {
      const baseScaleLocal = Math.min(
        screenWidth * 0.9 / Math.max(1, imageDimensions.width),
        screenHeight * 0.6 / Math.max(1, imageDimensions.height)
      );
      const effectiveScale = Math.max(0.1, baseScaleLocal * (scale.value || 1));
      const sens = settings.handleSensitivity ?? 0.5;
      const dx = (event.translationX / effectiveScale) * sens;
      const dy = (event.translationY / effectiveScale) * sens;

      // Only move if significant movement detected
      if (Math.abs(dx) > 1 || Math.abs(dy) > 1) {
        runOnJS(moveBox)(dx, dy);
      }
    },
  });

  // Corner drag gesture handler
  const createCornerGestureHandler = (cornerIndex: number) =>
    useAnimatedGestureHandler<PanGestureHandlerGestureEvent>({
      onStart: () => {
        runOnJS(setSelectedCorner)(cornerIndex);
      },
      onActive: (event) => {
        const baseScaleLocal = Math.min(
          screenWidth * 0.9 / Math.max(1, imageDimensions.width),
          screenHeight * 0.6 / Math.max(1, imageDimensions.height)
        );
        const effectiveScale = Math.max(0.1, baseScaleLocal * (scale.value || 1));
        // Stronger damping and deadzone for fine control
        const sens = settings.handleSensitivity ?? 0.3;
        const dx = (event.translationX / effectiveScale) * sens;
        const dy = (event.translationY / effectiveScale) * sens;
        const adjX = Math.abs(dx) < 2 ? 0 : dx;
        const adjY = Math.abs(dy) < 2 ? 0 : dy;
        const newX = cornerAnimations[cornerIndex].x.value + adjX;
        const newY = cornerAnimations[cornerIndex].y.value + adjY;

        runOnJS(updateCorner)(cornerIndex, { x: newX, y: newY });
      },
      onEnd: () => {
        runOnJS(setSelectedCorner)(null);
      },
    });

  // Pinch gesture handler for zoom
  const pinchGestureHandler = useAnimatedGestureHandler<PinchGestureHandlerGestureEvent>({
    onStart: () => {
      baseScale.value = scale.value;
    },
    onActive: (event) => {
      scale.value = Math.max(0.5, Math.min(3, baseScale.value * event.scale));
    },
    onEnd: () => {
      baseScale.value = scale.value;
    },
  });

  // Pan gesture handler for image movement
  const panGestureHandler = useAnimatedGestureHandler<PanGestureHandlerGestureEvent>({
    onStart: () => {
      baseTranslateX.value = translateX.value;
      baseTranslateY.value = translateY.value;
    },
    onActive: (event) => {
      translateX.value = baseTranslateX.value + event.translationX;
      translateY.value = baseTranslateY.value + event.translationY;
    },
    onEnd: () => {
      baseTranslateX.value = translateX.value;
      baseTranslateY.value = translateY.value;
    },
  });

  // Double tap to fit
  const doubleTapHandler = useAnimatedGestureHandler<TapGestureHandlerGestureEvent>({
    onActive: () => {
      scale.value = withSpring(1);
      translateX.value = withSpring(0);
      translateY.value = withSpring(0);
      baseScale.value = 1;
      baseTranslateX.value = 0;
      baseTranslateY.value = 0;
    },
  });

  // Animated styles
  const imageAnimatedStyle = useAnimatedStyle(() => ({
    transform: [
      { translateX: translateX.value },
      { translateY: translateY.value },
      { scale: scale.value },
    ],
  }));

  const createCornerAnimatedStyle = (index: number) =>
    useAnimatedStyle(() => {
      const baseScaleLocal = Math.min(
        screenWidth * 0.9 / Math.max(1, imageDimensions.width),
        screenHeight * 0.6 / Math.max(1, imageDimensions.height)
      );
      const effectiveScale = Math.max(0.1, baseScaleLocal * (scale.value || 1));
      const cx = cornerAnimations[index]?.x.value || 0;
      const cy = cornerAnimations[index]?.y.value || 0;

      // Calculate the exact position of the corner handle to match SVG polygon
      const containerWidth = screenWidth * 0.9;
      const containerHeight = screenHeight * 0.6;
      const imageAspectRatio = imageDimensions.width / imageDimensions.height;
      const containerAspectRatio = containerWidth / containerHeight;

      let displayWidth, displayHeight, offsetX, offsetY;

      if (imageAspectRatio > containerAspectRatio) {
        // Image is wider than container
        displayWidth = containerWidth;
        displayHeight = containerWidth / imageAspectRatio;
        offsetX = 0;
        offsetY = (containerHeight - displayHeight) / 2;
      } else {
        // Image is taller than container
        displayHeight = containerHeight;
        displayWidth = containerHeight * imageAspectRatio;
        offsetX = (containerWidth - displayWidth) / 2;
        offsetY = 0;
      }

      const scaledX = (cx / imageDimensions.width) * displayWidth;
      const scaledY = (cy / imageDimensions.height) * displayHeight;

      return {
        position: 'absolute',
        left: offsetX + scaledX * effectiveScale - handleSize / 2,
        top: 100 + offsetY + scaledY * effectiveScale - handleSize / 2,
        transform: [
          { translateX: translateX.value },
          { translateY: translateY.value },
        ],
      };
    });

  // Zoom controls
  const handleZoomIn = () => {
    scale.value = withSpring(Math.min(3, scale.value * 1.2));
    baseScale.value = scale.value;
  };

  const handleZoomOut = () => {
    scale.value = withSpring(Math.max(0.5, scale.value / 1.2));
    baseScale.value = scale.value;
  };

  const handleReset = () => {
    scale.value = withSpring(1);
    translateX.value = withSpring(0);
    translateY.value = withSpring(0);
    baseScale.value = 1;
    baseTranslateX.value = 0;
    baseTranslateY.value = 0;
  };

  const handleAutoDetect = () => {
    if (onAutoDetect) {
      Alert.alert(
        'Auto Detect',
        'Re-run automatic grid detection?',
        [
          { text: 'Cancel', style: 'cancel' },
          { text: 'Detect', onPress: onAutoDetect },
        ]
      );
    }
  };

  const toggleDragMode = () => {
    setDragMode(prev => prev === 'corner' ? 'box' : 'corner');
    setSelectedCorner(null);
    triggerLightHaptic();
  };

  return (
    <GestureHandlerRootView style={styles.container}>
      <View style={styles.imageContainer}>
        {/* Zoomable Image */}
        <PinchGestureHandler onGestureEvent={pinchGestureHandler}>
          <Animated.View style={styles.imageWrapper}>
            {/* Conditional Gesture Handlers */}
            {dragMode === 'box' ? (
              <PanGestureHandler
                onGestureEvent={boxDragGestureHandler}
                minPointers={1}
                maxPointers={1}
              >
                <Animated.View style={StyleSheet.absoluteFill}>
                  <Animated.View style={imageAnimatedStyle}>
                    <TapGestureHandler
                      onGestureEvent={doubleTapHandler}
                      numberOfTaps={2}
                    >
                      <Animated.View>
                    <Animated.Image
                      source={{ uri: imageUri }}
                      style={styles.image}
                      onLoad={(event: any) => {
                        try {
                          const src = event?.nativeEvent?.source || event?.source;
                          if (src?.width && src?.height) {
                            setImageDimensions({ width: src.width, height: src.height });
                          } else if (imageUri) {
                            RNImage.getSize(
                              imageUri,
                              (w, h) => setImageDimensions({ width: w, height: h }),
                              () => {}
                            );
                          }
                        } catch {}
                      }}
                    />
                    {/* Polygon overlay inside the same transform group */}
                    {imageDimensions.width > 0 && imageDimensions.height > 0 && corners.length === 4 && (
                      <Svg
                        width="100%"
                        height="100%"
                        viewBox={`0 0 ${imageDimensions.width} ${imageDimensions.height}`}
                        preserveAspectRatio="xMidYMid meet"
                        style={StyleSheet.absoluteFill}
                      >
                        <Polygon
                          points={corners.map(c => `${c.x},${c.y}`).join(' ')}
                          fill={dragMode === 'box' ? "rgba(255,165,0,0.2)" : "rgba(0,122,255,0.15)"}
                          stroke={dragMode === 'box' ? "#FF9500" : "#0A84FF"}
                          strokeWidth={dragMode === 'box' ? 3 : 2}
                        />
                        {corners.map((c, i) => (
                          <Circle key={i} cx={c.x} cy={c.y} r={5} fill={dragMode === 'box' ? "#FF9500" : "#0A84FF"} />
                        ))}
                      </Svg>
                    )}
                  </Animated.View>
                </TapGestureHandler>
              </Animated.View>
            </Animated.View>
            </PanGestureHandler>
            ) : (
              <PanGestureHandler
                onGestureEvent={panGestureHandler}
                minPointers={2}
                maxPointers={2}
              >
                <Animated.View style={imageAnimatedStyle}>
                  <TapGestureHandler
                    onGestureEvent={doubleTapHandler}
                    numberOfTaps={2}
                  >
                    <Animated.View>
                      <Animated.Image
                        source={{ uri: imageUri }}
                        style={styles.image}
                        onLoad={(event: any) => {
                          try {
                            const src = event?.nativeEvent?.source || event?.source;
                            if (src?.width && src?.height) {
                              setImageDimensions({ width: src.width, height: src.height });
                            } else if (imageUri) {
                              RNImage.getSize(
                                imageUri,
                                (w, h) => setImageDimensions({ width: w, height: h }),
                                () => {}
                              );
                            }
                          } catch {}
                        }}
                      />
                      {/* Polygon overlay inside the same transform group */}
                      {imageDimensions.width > 0 && imageDimensions.height > 0 && corners.length === 4 && (
                        <Svg
                          width="100%"
                          height="100%"
                          viewBox={`0 0 ${imageDimensions.width} ${imageDimensions.height}`}
                          preserveAspectRatio="xMidYMid meet"
                          style={StyleSheet.absoluteFill}
                        >
                          <Polygon
                            points={corners.map(c => `${c.x},${c.y}`).join(' ')}
                            fill={dragMode === 'box' ? "rgba(255,165,0,0.2)" : "rgba(0,122,255,0.15)"}
                            stroke={dragMode === 'box' ? "#FF9500" : "#0A84FF"}
                            strokeWidth={dragMode === 'box' ? 3 : 2}
                          />
                          {corners.map((c, i) => (
                            <Circle key={i} cx={c.x} cy={c.y} r={5} fill={dragMode === 'box' ? "#FF9500" : "#0A84FF"} />
                          ))}
                        </Svg>
                      )}
                    </Animated.View>
                  </TapGestureHandler>
                </Animated.View>
              </PanGestureHandler>
            )}
          </Animated.View>
        </PinchGestureHandler>

        {/* Corner Handles */}
        {corners.map((_, index) => (
          <PanGestureHandler
            key={index}
            onGestureEvent={createCornerGestureHandler(index)}
          >
            <Animated.View
              style={[
                styles.cornerHandle,
                {
                  width: handleSize,
                  height: handleSize,
                },
                createCornerAnimatedStyle(index),
                selectedCorner === index && styles.cornerHandleSelected,
              ]}
            >
              <View style={styles.cornerInner}>
                <Text style={styles.cornerLabel}>{index + 1}</Text>
              </View>
              
              {/* Coordinate display for selected corner */}
              {selectedCorner === index && (
                <View style={styles.coordinateDisplay}>
                  <Text style={styles.coordinateText}>
                    {Math.round(corners[index]?.x || 0)}, {Math.round(corners[index]?.y || 0)}
                  </Text>
                </View>
              )}
            </Animated.View>
          </PanGestureHandler>
        ))}

        {/* Grid Lines */}
        <View style={styles.gridOverlay}>
          {corners.length === 4 && (
            <>
              {/* Top line: TL to TR */}
              <View
                style={[
                  styles.gridLine,
                  {
                    left: (corners[0]?.x / imageDimensions.width) * screenWidth * 0.9,
                    top: (corners[0]?.y / imageDimensions.height) * screenHeight * 0.6 + 100,
                    width: Math.sqrt(
                      Math.pow((corners[1]?.x - corners[0]?.x) * screenWidth * 0.9 / imageDimensions.width, 2) +
                      Math.pow((corners[1]?.y - corners[0]?.y) * screenHeight * 0.6 / imageDimensions.height, 2)
                    ),
                    transform: [
                      {
                        rotate: `${Math.atan2(
                          (corners[1]?.y - corners[0]?.y) * screenHeight * 0.6 / imageDimensions.height,
                          (corners[1]?.x - corners[0]?.x) * screenWidth * 0.9 / imageDimensions.width
                        )}rad`,
                      },
                    ],
                  },
                ]}
              />
              {/* Similar lines for other edges... */}
            </>
          )}
        </View>

        {/* Semi-transparent mask outside quad */}
        {corners.length === 4 && (
          <View style={styles.maskOverlay}>
            {/* This would be implemented with SVG or canvas for proper masking */}
          </View>
        )}
      </View>

      {/* Controls */}
      <View style={styles.controlsContainer}>
        {/* Zoom Controls */}
        <View style={styles.zoomControls}>
          <TouchableOpacity style={styles.zoomButton} onPress={handleZoomOut}>
            <Ionicons name="remove" size={24} color="#007AFF" />
          </TouchableOpacity>
          
          <TouchableOpacity style={styles.resetButton} onPress={handleReset}>
            <Ionicons name="refresh" size={20} color="#666" />
            <Text style={styles.resetText}>Reset View</Text>
          </TouchableOpacity>
          
          <TouchableOpacity style={styles.zoomButton} onPress={handleZoomIn}>
            <Ionicons name="add" size={24} color="#007AFF" />
          </TouchableOpacity>
        </View>

        {/* Drag Mode Toggle */}
        <View style={styles.dragModeContainer}>
          <TouchableOpacity
            style={[
              styles.dragModeButton,
              dragMode === 'corner' && styles.dragModeButtonActive
            ]}
            onPress={() => setDragMode('corner')}
          >
            <Ionicons name="radio-button-on" size={20} color={dragMode === 'corner' ? "#007AFF" : "#666"} />
            <Text style={[styles.dragModeText, dragMode === 'corner' && styles.dragModeTextActive]}>
              Corner Mode
            </Text>
          </TouchableOpacity>

          <TouchableOpacity
            style={[
              styles.dragModeButton,
              dragMode === 'box' && styles.dragModeButtonActive
            ]}
            onPress={() => setDragMode('box')}
          >
            <Ionicons name="move" size={20} color={dragMode === 'box' ? "#FF9500" : "#666"} />
            <Text style={[styles.dragModeText, dragMode === 'box' && styles.dragModeTextActive]}>
              Box Mode
            </Text>
          </TouchableOpacity>
        </View>

        {/* Action Buttons */}
        <View style={styles.actionButtons}>
          {onAutoDetect && (
            <TouchableOpacity style={styles.secondaryButton} onPress={handleAutoDetect}>
              <Ionicons name="scan" size={20} color="#007AFF" />
              <Text style={styles.secondaryButtonText}>Auto Detect</Text>
            </TouchableOpacity>
          )}

          <TouchableOpacity style={styles.secondaryButton} onPress={onCancel}>
            <Ionicons name="close" size={20} color="#FF3B30" />
            <Text style={[styles.secondaryButtonText, { color: '#FF3B30' }]}>Cancel</Text>
          </TouchableOpacity>

          <TouchableOpacity
            style={styles.primaryButton}
            onPress={() => onConfirm(corners)}
          >
            <Ionicons name="checkmark" size={20} color="#fff" />
            <Text style={styles.primaryButtonText}>Apply Correction</Text>
          </TouchableOpacity>
        </View>

        {/* Instructions */}
        <View style={styles.instructionsContainer}>
          <Text style={styles.instructionsText}>
            {dragMode === 'corner'
              ? "• Drag individual corners to adjust grid boundaries"
              : "• Drag anywhere on the box to move the entire grid"
            }
          </Text>
          <Text style={styles.instructionsText}>
            • Pinch to zoom, two-finger pan to move (Corner Mode only)
          </Text>
          <Text style={styles.instructionsText}>
            • Double-tap to reset view
          </Text>
          <Text style={styles.instructionsText}>
            • Use mode toggle to switch between Corner and Box dragging
          </Text>
        </View>
      </View>
    </GestureHandlerRootView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#000',
  },
  imageContainer: {
    flex: 1,
    margin: 20,
    borderRadius: 12,
    overflow: 'hidden',
    backgroundColor: '#000',
  },
  imageWrapper: {
    flex: 1,
  },
  image: {
    width: '100%',
    height: '100%',
    resizeMode: 'contain',
  },
  cornerHandle: {
    position: 'absolute',
    alignItems: 'center',
    justifyContent: 'center',
    zIndex: 10,
  },
  cornerHandleSelected: {
    transform: [{ scale: 1.2 }],
  },
  cornerInner: {
    width: '80%',
    height: '80%',
    borderRadius: 100,
    backgroundColor: '#007AFF',
    borderWidth: 3,
    borderColor: '#fff',
    alignItems: 'center',
    justifyContent: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.5,
    shadowRadius: 4,
    elevation: 8,
  },
  cornerLabel: {
    color: '#fff',
    fontSize: 14,
    fontWeight: 'bold',
  },
  coordinateDisplay: {
    position: 'absolute',
    top: -30,
    backgroundColor: 'rgba(0, 0, 0, 0.8)',
    borderRadius: 8,
    paddingHorizontal: 8,
    paddingVertical: 4,
  },
  coordinateText: {
    color: '#fff',
    fontSize: 12,
    fontWeight: '600',
  },
  gridOverlay: {
    ...StyleSheet.absoluteFillObject,
    pointerEvents: 'none',
  },
  gridLine: {
    position: 'absolute',
    height: 2,
    backgroundColor: '#fff',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.3,
    shadowRadius: 2,
  },
  maskOverlay: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: 'rgba(0, 0, 0, 0.3)',
    pointerEvents: 'none',
  },
  controlsContainer: {
    backgroundColor: '#fff',
    paddingHorizontal: 20,
    paddingVertical: 16,
    borderTopLeftRadius: 20,
    borderTopRightRadius: 20,
  },
  zoomControls: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 16,
    gap: 16,
  },
  zoomButton: {
    width: 44,
    height: 44,
    borderRadius: 22,
    backgroundColor: '#f0f0f0',
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 1,
    borderColor: '#007AFF',
  },
  resetButton: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 20,
    backgroundColor: '#f8f9fa',
    gap: 6,
  },
  resetText: {
    fontSize: 14,
    color: '#666',
    fontWeight: '500',
  },
  actionButtons: {
    flexDirection: 'row',
    gap: 12,
    marginBottom: 16,
  },
  primaryButton: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#007AFF',
    borderRadius: 12,
    paddingVertical: 16,
    gap: 8,
  },
  primaryButtonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
  },
  secondaryButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#f0f0f0',
    borderRadius: 12,
    paddingVertical: 16,
    paddingHorizontal: 20,
    gap: 6,
  },
  secondaryButtonText: {
    color: '#007AFF',
    fontSize: 14,
    fontWeight: '600',
  },
  dragModeContainer: {
    flexDirection: 'row',
    gap: 12,
    marginBottom: 16,
    paddingHorizontal: 4,
  },
  dragModeButton: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#f0f0f0',
    borderRadius: 12,
    paddingVertical: 12,
    paddingHorizontal: 16,
    gap: 8,
    borderWidth: 2,
    borderColor: 'transparent',
  },
  dragModeButtonActive: {
    backgroundColor: '#fff',
    borderColor: '#007AFF',
    shadowColor: '#007AFF',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.2,
    shadowRadius: 4,
    elevation: 4,
  },
  dragModeText: {
    fontSize: 14,
    color: '#666',
    fontWeight: '500',
  },
  dragModeTextActive: {
    color: '#007AFF',
    fontWeight: '600',
  },
  instructionsContainer: {
    backgroundColor: '#f8f9fa',
    borderRadius: 8,
    padding: 12,
  },
  instructionsText: {
    fontSize: 12,
    color: '#666',
    lineHeight: 16,
  },
});
