/**
 * History Screen - View and manage previous analyses
 */
import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  FlatList,
  Alert,
  TextInput,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { router } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { Sample } from '../src/types';
import { SampleRepository } from '../src/data/repositories/SampleRepository';
import { shareMultipleSamples } from '../src/utils/share';
import { formatNumber } from '../src/imaging/math';
import { logUserInteraction } from '../src/utils/logger';
import { AdBanner } from '../src/components/AdBanner';
import { useShouldShowAds, useProFeatures } from '../src/hooks/usePurchase';

interface SampleItemProps {
  sample: Sample;
  onPress: () => void;
  onShare: () => void;
  onDelete: () => void;
}

function SampleItem({ sample, onPress, onShare, onDelete }: SampleItemProps): JSX.Element {
  return (
    <TouchableOpacity style={styles.sampleItem} onPress={onPress}>
      <View style={styles.sampleHeader}>
        <Text style={styles.sampleId}>{sample.id}</Text>
        <Text style={styles.sampleDate}>
          {new Date(sample.timestamp).toLocaleDateString()}
        </Text>
      </View>
      
      <View style={styles.sampleInfo}>
        <Text style={styles.sampleOperator}>{sample.operator}</Text>
        <Text style={styles.sampleProject}>{sample.project}</Text>
      </View>
      
      <View style={styles.sampleResults}>
        <View style={styles.resultItem}>
          <Text style={styles.resultLabel}>Concentration</Text>
          <Text style={styles.resultValue}>
            {formatNumber(sample.concentration, 'concentration')} cells/mL
          </Text>
        </View>
        <View style={styles.resultItem}>
          <Text style={styles.resultLabel}>Viability</Text>
          <Text style={styles.resultValue}>
            {formatNumber(sample.viability, 'percentage')}
          </Text>
        </View>
      </View>
      
      <View style={styles.sampleActions}>
        <TouchableOpacity style={styles.actionButton} onPress={onShare}>
          <Ionicons name="share" size={16} color="#007AFF" />
        </TouchableOpacity>
        <TouchableOpacity style={styles.actionButton} onPress={onDelete}>
          <Ionicons name="trash" size={16} color="#FF3B30" />
        </TouchableOpacity>
      </View>
    </TouchableOpacity>
  );
}

export default function HistoryScreen(): JSX.Element {
  const [samples, setSamples] = useState<Sample[]>([]);
  const [filteredSamples, setFilteredSamples] = useState<Sample[]>([]);
  const [searchQuery, setSearchQuery] = useState('');
  const [isLoading, setIsLoading] = useState(true);
  const [selectedSamples, setSelectedSamples] = useState<string[]>([]);
  const [isSelectionMode, setIsSelectionMode] = useState(false);

  const sampleRepository = new SampleRepository();
  const shouldShowAds = useShouldShowAds();
  const { canUseBatchExport } = useProFeatures();

  useEffect(() => {
    loadSamples();
  }, []);

  useEffect(() => {
    filterSamples();
  }, [samples, searchQuery]);

  const loadSamples = async (): Promise<void> => {
    try {
      setIsLoading(true);
      const loadedSamples = await sampleRepository.getSamples({ limit: 100 });
      setSamples(loadedSamples);
    } catch (error) {
      console.error('Failed to load samples:', error);
      Alert.alert('Error', 'Failed to load sample history.');
    } finally {
      setIsLoading(false);
    }
  };

  const filterSamples = (): void => {
    if (!searchQuery.trim()) {
      setFilteredSamples(samples);
      return;
    }

    const query = searchQuery.toLowerCase();
    const filtered = samples.filter(sample =>
      sample.id.toLowerCase().includes(query) ||
      sample.operator.toLowerCase().includes(query) ||
      sample.project.toLowerCase().includes(query)
    );
    
    setFilteredSamples(filtered);
  };

  const handleSamplePress = (sample: Sample): void => {
    if (isSelectionMode) {
      toggleSampleSelection(sample.id);
    } else {
      // Navigate to sample details or show modal
      logUserInteraction('History', 'ViewSampleDetails', { sampleId: sample.id });
    }
  };

  const toggleSampleSelection = (sampleId: string): void => {
    setSelectedSamples(prev =>
      prev.includes(sampleId)
        ? prev.filter(id => id !== sampleId)
        : [...prev, sampleId]
    );
  };

  const handleShareSample = async (sample: Sample): Promise<void> => {
    try {
      await shareMultipleSamples([sample], 'csv');
      logUserInteraction('History', 'ShareSample', { sampleId: sample.id });
    } catch (error) {
      Alert.alert('Share Error', 'Failed to share sample.');
    }
  };

  const handleDeleteSample = (sample: Sample): void => {
    Alert.alert(
      'Delete Sample',
      `Are you sure you want to delete sample "${sample.id}"? This action cannot be undone.`,
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Delete',
          style: 'destructive',
          onPress: async () => {
            try {
              await sampleRepository.deleteSample(sample.id);
              await loadSamples();
              logUserInteraction('History', 'DeleteSample', { sampleId: sample.id });
            } catch (error) {
              Alert.alert('Delete Error', 'Failed to delete sample.');
            }
          },
        },
      ]
    );
  };

  const handleBulkShare = async (): Promise<void> => {
    if (selectedSamples.length === 0) {
      Alert.alert('No Selection', 'Please select samples to share.');
      return;
    }

    // Check if user has Pro for batch export
    if (!canUseBatchExport) {
      Alert.alert(
        'Pro Feature',
        'Batch export is a Pro feature. Upgrade to export multiple samples at once.',
        [
          { text: 'Cancel', style: 'cancel' },
          { text: 'Upgrade', onPress: () => router.push('/paywall') },
        ]
      );
      return;
    }

    try {
      const samplesToShare = samples.filter(s => selectedSamples.includes(s.id));
      await shareMultipleSamples(samplesToShare, 'csv');
      setIsSelectionMode(false);
      setSelectedSamples([]);
      logUserInteraction('History', 'BulkShare', { count: selectedSamples.length });
    } catch (error) {
      Alert.alert('Share Error', 'Failed to share samples.');
    }
  };

  const handleBulkDelete = (): void => {
    if (selectedSamples.length === 0) {
      Alert.alert('No Selection', 'Please select samples to delete.');
      return;
    }

    Alert.alert(
      'Delete Samples',
      `Are you sure you want to delete ${selectedSamples.length} sample(s)? This action cannot be undone.`,
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Delete',
          style: 'destructive',
          onPress: async () => {
            try {
              await Promise.all(
                selectedSamples.map(id => sampleRepository.deleteSample(id))
              );
              await loadSamples();
              setIsSelectionMode(false);
              setSelectedSamples([]);
              logUserInteraction('History', 'BulkDelete', { count: selectedSamples.length });
            } catch (error) {
              Alert.alert('Delete Error', 'Failed to delete samples.');
            }
          },
        },
      ]
    );
  };

  const renderSample = ({ item }: { item: Sample }): JSX.Element => (
    <SampleItem
      sample={item}
      onPress={() => handleSamplePress(item)}
      onShare={() => handleSamplePress(item)}
      onDelete={() => handleDeleteSample(item)}
    />
  );

  return (
    <SafeAreaView style={styles.container}>
      {/* Search Bar */}
      <View style={styles.searchContainer}>
        <Ionicons name="search" size={20} color="#666" style={styles.searchIcon} />
        <TextInput
          style={styles.searchInput}
          placeholder="Search samples..."
          value={searchQuery}
          onChangeText={setSearchQuery}
        />
        {searchQuery.length > 0 && (
          <TouchableOpacity onPress={() => setSearchQuery('')}>
            <Ionicons name="close-circle" size={20} color="#666" />
          </TouchableOpacity>
        )}
      </View>

      {/* Selection Mode Header */}
      {isSelectionMode && (
        <View style={styles.selectionHeader}>
          <TouchableOpacity
            onPress={() => {
              setIsSelectionMode(false);
              setSelectedSamples([]);
            }}
          >
            <Text style={styles.cancelText}>Cancel</Text>
          </TouchableOpacity>
          
          <Text style={styles.selectionCount}>
            {selectedSamples.length} selected
          </Text>
          
          <View style={styles.selectionActions}>
            <TouchableOpacity
              style={styles.selectionButton}
              onPress={handleBulkShare}
            >
              <Ionicons name="share" size={20} color="#007AFF" />
            </TouchableOpacity>
            <TouchableOpacity
              style={styles.selectionButton}
              onPress={handleBulkDelete}
            >
              <Ionicons name="trash" size={20} color="#FF3B30" />
            </TouchableOpacity>
          </View>
        </View>
      )}

      {/* Sample List */}
      <FlatList
        data={filteredSamples}
        renderItem={renderSample}
        keyExtractor={(item) => item.id}
        contentContainerStyle={styles.listContainer}
        refreshing={isLoading}
        onRefresh={loadSamples}
        ListEmptyComponent={
          <View style={styles.emptyContainer}>
            <Ionicons name="flask-outline" size={64} color="#ccc" />
            <Text style={styles.emptyTitle}>No Samples Found</Text>
            <Text style={styles.emptyText}>
              {searchQuery
                ? 'No samples match your search criteria.'
                : 'Start analyzing samples to see them here.'}
            </Text>
          </View>
        }
        ListFooterComponent={
          <AdBanner visible={shouldShowAds} style={styles.adBanner} />
        }
      />

      {/* Floating Action Button */}
      {!isSelectionMode && samples.length > 0 && (
        <TouchableOpacity
          style={styles.fab}
          onPress={() => setIsSelectionMode(true)}
        >
          <Ionicons name="checkmark-done" size={24} color="#fff" />
        </TouchableOpacity>
      )}
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f8f9fa',
  },
  searchContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    margin: 20,
    paddingHorizontal: 16,
    paddingVertical: 12,
    backgroundColor: '#fff',
    borderRadius: 12,
    elevation: 2,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.05,
    shadowRadius: 4,
  },
  searchIcon: {
    marginRight: 12,
  },
  searchInput: {
    flex: 1,
    fontSize: 16,
  },
  selectionHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 20,
    paddingVertical: 12,
    backgroundColor: '#007AFF',
  },
  cancelText: {
    color: '#fff',
    fontSize: 16,
  },
  selectionCount: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
  },
  selectionActions: {
    flexDirection: 'row',
  },
  selectionButton: {
    marginLeft: 16,
  },
  listContainer: {
    padding: 20,
  },
  sampleItem: {
    backgroundColor: '#fff',
    borderRadius: 12,
    padding: 16,
    marginBottom: 12,
    elevation: 2,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.05,
    shadowRadius: 4,
  },
  sampleHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 8,
  },
  sampleId: {
    fontSize: 16,
    fontWeight: '600',
    color: '#333',
  },
  sampleDate: {
    fontSize: 14,
    color: '#666',
  },
  sampleInfo: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 12,
  },
  sampleOperator: {
    fontSize: 14,
    color: '#007AFF',
  },
  sampleProject: {
    fontSize: 14,
    color: '#666',
  },
  sampleResults: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 12,
  },
  resultItem: {
    flex: 1,
  },
  resultLabel: {
    fontSize: 12,
    color: '#666',
    marginBottom: 2,
  },
  resultValue: {
    fontSize: 14,
    fontWeight: '500',
    color: '#333',
  },
  sampleActions: {
    flexDirection: 'row',
    justifyContent: 'flex-end',
  },
  actionButton: {
    padding: 8,
    marginLeft: 8,
  },
  emptyContainer: {
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 60,
  },
  emptyTitle: {
    fontSize: 20,
    fontWeight: '600',
    color: '#333',
    marginTop: 16,
  },
  emptyText: {
    fontSize: 14,
    color: '#666',
    textAlign: 'center',
    marginTop: 8,
    lineHeight: 20,
  },
  fab: {
    position: 'absolute',
    bottom: 20,
    right: 20,
    width: 56,
    height: 56,
    borderRadius: 28,
    backgroundColor: '#007AFF',
    alignItems: 'center',
    justifyContent: 'center',
    elevation: 8,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.2,
    shadowRadius: 8,
  },
  adBanner: {
    marginTop: 20,
    marginBottom: 20,
  },
});
