/**
 * Home screen - Main navigation hub
 */
import React from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  ScrollView,
  Alert,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { router } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { LinearGradient } from 'expo-linear-gradient';
import { useAppStore } from '../src/state/store';
import { logUserInteraction } from '../src/utils/logger';

interface MenuItemProps {
  icon: keyof typeof Ionicons.glyphMap;
  title: string;
  subtitle: string;
  onPress: () => void;
  color: string;
  disabled?: boolean;
}

function MenuItem({ icon, title, subtitle, onPress, color, disabled = false }: MenuItemProps): JSX.Element {
  return (
    <TouchableOpacity
      style={[styles.menuItem, disabled && styles.menuItemDisabled]}
      onPress={onPress}
      disabled={disabled}
      activeOpacity={0.7}
    >
      <LinearGradient
        colors={disabled ? ['#f0f0f0', '#e0e0e0'] : [color, `${color}CC`]}
        style={styles.menuItemGradient}
        start={{ x: 0, y: 0 }}
        end={{ x: 1, y: 1 }}
      >
        <View style={styles.menuItemIcon}>
          <Ionicons
            name={icon}
            size={32}
            color={disabled ? '#999' : '#fff'}
          />
        </View>
        <View style={styles.menuItemContent}>
          <Text style={[styles.menuItemTitle, disabled && styles.menuItemTitleDisabled]}>
            {title}
          </Text>
          <Text style={[styles.menuItemSubtitle, disabled && styles.menuItemSubtitleDisabled]}>
            {subtitle}
          </Text>
        </View>
        <View style={styles.menuItemArrow}>
          <Ionicons
            name="chevron-forward"
            size={24}
            color={disabled ? '#999' : '#fff'}
          />
        </View>
      </LinearGradient>
    </TouchableOpacity>
  );
}

export default function HomeScreen(): JSX.Element {
  const { resetSession, currentSample } = useAppStore();

  const handleNewAnalysis = (): void => {
    logUserInteraction('Home', 'StartNewAnalysis');
    
    if (currentSample) {
      Alert.alert(
        'Current Analysis',
        'You have an analysis in progress. Starting a new one will discard the current session.',
        [
          { text: 'Cancel', style: 'cancel' },
          {
            text: 'Start New',
            style: 'destructive',
            onPress: () => {
              resetSession();
              router.push('/capture');
            },
          },
        ]
      );
    } else {
      resetSession();
      router.push('/capture');
    }
  };

  const handleContinueAnalysis = (): void => {
    logUserInteraction('Home', 'ContinueAnalysis');
    
    if (!currentSample) {
      Alert.alert('No Analysis', 'No analysis in progress.');
      return;
    }

    // Determine which screen to continue from based on current sample state
    if (!currentSample.imagePath) {
      router.push('/capture');
    } else if (!currentSample.detections || currentSample.detections.length === 0) {
      router.push('/crop');
    } else {
      router.push('/review');
    }
  };

  const handleViewHistory = (): void => {
    logUserInteraction('Home', 'ViewHistory');
    router.push('/history');
  };

  const handleSettings = (): void => {
    logUserInteraction('Home', 'OpenSettings');
    router.push('/settings');
  };

  const handleHelp = (): void => {
    logUserInteraction('Home', 'OpenHelp');
    router.push('/help');
  };

  return (
    <SafeAreaView style={styles.container}>
      <ScrollView contentContainerStyle={styles.scrollContent}>
        {/* Header */}
        <View style={styles.header}>
          <LinearGradient
            colors={['#007AFF', '#5856D6']}
            style={styles.headerGradient}
            start={{ x: 0, y: 0 }}
            end={{ x: 1, y: 1 }}
          >
            <Ionicons name="microscope" size={48} color="#fff" />
            <Text style={styles.headerTitle}>Smart Cell Counter</Text>
            <Text style={styles.headerSubtitle}>
              AI-powered hemocytometer analysis
            </Text>
          </LinearGradient>
        </View>

        {/* Current Session Status */}
        {currentSample && (
          <View style={styles.sessionStatus}>
            <View style={styles.sessionStatusHeader}>
              <Ionicons name="flask" size={20} color="#007AFF" />
              <Text style={styles.sessionStatusTitle}>Analysis in Progress</Text>
            </View>
            <Text style={styles.sessionStatusText}>
              Sample ID: {currentSample.id || 'New Sample'}
            </Text>
            <Text style={styles.sessionStatusText}>
              Operator: {currentSample.operator || 'Not set'}
            </Text>
          </View>
        )}

        {/* Menu Items */}
        <View style={styles.menuContainer}>
          <MenuItem
            icon="camera"
            title="New Analysis"
            subtitle="Start counting cells from a new image"
            onPress={handleNewAnalysis}
            color="#007AFF"
          />

          <MenuItem
            icon="play-circle"
            title="Continue Analysis"
            subtitle="Resume your current cell counting session"
            onPress={handleContinueAnalysis}
            color="#34C759"
            disabled={!currentSample}
          />

          <MenuItem
            icon="time"
            title="History"
            subtitle="View and export previous analyses"
            onPress={handleViewHistory}
            color="#FF9500"
          />

          <MenuItem
            icon="settings"
            title="Settings"
            subtitle="Configure counting parameters and preferences"
            onPress={handleSettings}
            color="#5856D6"
          />

          <MenuItem
            icon="help-circle"
            title="Help & Tutorial"
            subtitle="Learn how to use the app effectively"
            onPress={handleHelp}
            color="#FF3B30"
          />
        </View>

        {/* Quick Stats */}
        <View style={styles.quickStats}>
          <Text style={styles.quickStatsTitle}>Quick Tips</Text>
          <View style={styles.tipContainer}>
            <Ionicons name="lightbulb" size={16} color="#FF9500" />
            <Text style={styles.tipText}>
              Ensure good lighting and focus for accurate results
            </Text>
          </View>
          <View style={styles.tipContainer}>
            <Ionicons name="checkmark-circle" size={16} color="#34C759" />
            <Text style={styles.tipText}>
              Mix samples thoroughly before loading hemocytometer
            </Text>
          </View>
          <View style={styles.tipContainer}>
            <Ionicons name="warning" size={16} color="#FF3B30" />
            <Text style={styles.tipText}>
              Check for proper dilution to avoid overcrowding
            </Text>
          </View>
        </View>
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f8f9fa',
  },
  scrollContent: {
    paddingBottom: 20,
  },
  header: {
    margin: 20,
    borderRadius: 16,
    overflow: 'hidden',
    elevation: 4,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 8,
  },
  headerGradient: {
    padding: 30,
    alignItems: 'center',
  },
  headerTitle: {
    fontSize: 28,
    fontWeight: 'bold',
    color: '#fff',
    marginTop: 16,
    textAlign: 'center',
  },
  headerSubtitle: {
    fontSize: 16,
    color: '#fff',
    opacity: 0.9,
    marginTop: 8,
    textAlign: 'center',
  },
  sessionStatus: {
    margin: 20,
    marginTop: 0,
    padding: 16,
    backgroundColor: '#e3f2fd',
    borderRadius: 12,
    borderLeftWidth: 4,
    borderLeftColor: '#007AFF',
  },
  sessionStatusHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 8,
  },
  sessionStatusTitle: {
    fontSize: 16,
    fontWeight: '600',
    color: '#007AFF',
    marginLeft: 8,
  },
  sessionStatusText: {
    fontSize: 14,
    color: '#666',
    marginBottom: 4,
  },
  menuContainer: {
    paddingHorizontal: 20,
  },
  menuItem: {
    marginBottom: 16,
    borderRadius: 16,
    overflow: 'hidden',
    elevation: 3,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 6,
  },
  menuItemDisabled: {
    opacity: 0.6,
  },
  menuItemGradient: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 20,
  },
  menuItemIcon: {
    width: 60,
    height: 60,
    borderRadius: 30,
    backgroundColor: 'rgba(255, 255, 255, 0.2)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  menuItemContent: {
    flex: 1,
    marginLeft: 16,
  },
  menuItemTitle: {
    fontSize: 18,
    fontWeight: '600',
    color: '#fff',
    marginBottom: 4,
  },
  menuItemTitleDisabled: {
    color: '#999',
  },
  menuItemSubtitle: {
    fontSize: 14,
    color: '#fff',
    opacity: 0.9,
  },
  menuItemSubtitleDisabled: {
    color: '#999',
  },
  menuItemArrow: {
    marginLeft: 16,
  },
  quickStats: {
    margin: 20,
    padding: 20,
    backgroundColor: '#fff',
    borderRadius: 16,
    elevation: 2,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.05,
    shadowRadius: 4,
  },
  quickStatsTitle: {
    fontSize: 18,
    fontWeight: '600',
    color: '#333',
    marginBottom: 16,
  },
  tipContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 12,
  },
  tipText: {
    fontSize: 14,
    color: '#666',
    marginLeft: 12,
    flex: 1,
  },
});
