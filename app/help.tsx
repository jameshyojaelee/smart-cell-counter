/**
 * Help Screen - Tutorials and guidance
 */
import React from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';

interface HelpSectionProps {
  title: string;
  children: React.ReactNode;
  icon?: keyof typeof Ionicons.glyphMap;
}

function HelpSection({ title, children, icon }: HelpSectionProps): JSX.Element {
  return (
    <View style={styles.section}>
      <View style={styles.sectionHeader}>
        {icon && <Ionicons name={icon} size={24} color="#007AFF" />}
        <Text style={styles.sectionTitle}>{title}</Text>
      </View>
      <View style={styles.sectionContent}>
        {children}
      </View>
    </View>
  );
}

export default function HelpScreen(): JSX.Element {
  return (
    <SafeAreaView style={styles.container}>
      <ScrollView style={styles.scrollView}>
        {/* Getting Started */}
        <HelpSection title="Getting Started" icon="play-circle">
          <Text style={styles.text}>
            Welcome to Smart Cell Counter! This app helps you accurately count cells using a hemocytometer with AI assistance.
          </Text>
          
          <Text style={styles.stepTitle}>Basic Workflow:</Text>
          <Text style={styles.step}>1. Capture or import hemocytometer image</Text>
          <Text style={styles.step}>2. Adjust grid detection and perspective</Text>
          <Text style={styles.step}>3. Review and edit cell detections</Text>
          <Text style={styles.step}>4. Calculate concentration and viability</Text>
          <Text style={styles.step}>5. Save and export results</Text>
        </HelpSection>

        {/* Image Capture Tips */}
        <HelpSection title="Image Capture Tips" icon="camera">
          <Text style={styles.stepTitle}>For Best Results:</Text>
          <Text style={styles.step}>• Use good, even lighting</Text>
          <Text style={styles.step}>• Ensure hemocytometer is clean</Text>
          <Text style={styles.step}>• Focus on the grid lines</Text>
          <Text style={styles.step}>• Avoid glare and reflections</Text>
          <Text style={styles.step}>• Hold camera steady</Text>
          <Text style={styles.step}>• Fill frame with counting area</Text>
          
          <Text style={styles.text}>
            The app will guide you with real-time feedback on focus and glare quality.
          </Text>
        </HelpSection>

        {/* Sample Preparation */}
        <HelpSection title="Sample Preparation" icon="flask">
          <Text style={styles.text}>
            Proper sample preparation is crucial for accurate counting:
          </Text>
          
          <Text style={styles.stepTitle}>Trypan Blue Staining:</Text>
          <Text style={styles.step}>1. Mix equal volumes of cell suspension and 0.4% trypan blue</Text>
          <Text style={styles.step}>2. Let stand for 2-5 minutes</Text>
          <Text style={styles.step}>3. Mix gently before loading hemocytometer</Text>
          
          <Text style={styles.stepTitle}>Loading Hemocytometer:</Text>
          <Text style={styles.step}>1. Clean hemocytometer and coverslip</Text>
          <Text style={styles.step}>2. Place coverslip over counting chambers</Text>
          <Text style={styles.step}>3. Load 10-15 μL of stained sample</Text>
          <Text style={styles.step}>4. Allow cells to settle for 2-3 minutes</Text>
        </HelpSection>

        {/* Counting Rules */}
        <HelpSection title="Counting Rules" icon="grid">
          <Text style={styles.text}>
            The app follows standard hemocytometer counting rules:
          </Text>
          
          <Text style={styles.stepTitle}>Inclusion Rule:</Text>
          <Text style={styles.step}>• Cells touching TOP and LEFT borders: COUNT</Text>
          <Text style={styles.step}>• Cells touching BOTTOM and RIGHT borders: DON'T COUNT</Text>
          <Text style={styles.step}>• This prevents double-counting cells on boundaries</Text>
          
          <Text style={styles.stepTitle}>Cell Density Guidelines:</Text>
          <Text style={styles.step}>• Optimal: 50-200 cells per large square</Text>
          <Text style={styles.step}>• Too crowded (>300): Dilute sample</Text>
          <Text style={styles.step}>• Too sparse (<10): Concentrate sample</Text>
        </HelpSection>

        {/* Viability Assessment */}
        <HelpSection title="Viability Assessment" icon="heart">
          <Text style={styles.text}>
            The app automatically classifies cell viability based on trypan blue uptake:
          </Text>
          
          <Text style={styles.stepTitle}>Live Cells:</Text>
          <Text style={styles.step}>• Exclude trypan blue dye</Text>
          <Text style={styles.step}>• Appear bright/unstained</Text>
          <Text style={styles.step}>• Have intact cell membranes</Text>
          
          <Text style={styles.stepTitle}>Dead Cells:</Text>
          <Text style={styles.step}>• Take up trypan blue dye</Text>
          <Text style={styles.step}>• Appear blue/dark</Text>
          <Text style={styles.step}>• Have compromised membranes</Text>
          
          <Text style={styles.text}>
            You can manually adjust classifications in the review screen if needed.
          </Text>
        </HelpSection>

        {/* Troubleshooting */}
        <HelpSection title="Troubleshooting" icon="help-circle">
          <Text style={styles.stepTitle}>Common Issues:</Text>
          
          <Text style={styles.problemTitle}>Grid not detected:</Text>
          <Text style={styles.step}>• Improve lighting and focus</Text>
          <Text style={styles.step}>• Clean hemocytometer grid</Text>
          <Text style={styles.step}>• Use manual corner adjustment</Text>
          
          <Text style={styles.problemTitle}>Poor cell detection:</Text>
          <Text style={styles.step}>• Check sample preparation</Text>
          <Text style={styles.step}>• Adjust processing parameters in settings</Text>
          <Text style={styles.step}>• Ensure proper staining</Text>
          
          <Text style={styles.problemTitle}>High variance between squares:</Text>
          <Text style={styles.step}>• Mix sample more thoroughly</Text>
          <Text style={styles.step}>• Check for debris or bubbles</Text>
          <Text style={styles.step}>• Reload hemocytometer</Text>
        </HelpSection>

        {/* Calculations */}
        <HelpSection title="Calculations" icon="calculator">
          <Text style={styles.text}>
            The app uses standard hemocytometer formulas:
          </Text>
          
          <View style={styles.formulaBox}>
            <Text style={styles.formulaTitle}>Concentration (cells/mL):</Text>
            <Text style={styles.formula}>
              Average cells per square × 10⁴ × Dilution factor
            </Text>
          </View>
          
          <View style={styles.formulaBox}>
            <Text style={styles.formulaTitle}>Viability (%):</Text>
            <Text style={styles.formula}>
              (Live cells / Total cells) × 100
            </Text>
          </View>
          
          <Text style={styles.text}>
            Each large square of a Neubauer hemocytometer represents 0.1 μL (10⁻⁴ mL).
          </Text>
        </HelpSection>

        {/* Contact */}
        <HelpSection title="Support" icon="mail">
          <Text style={styles.text}>
            Need additional help? Contact our support team:
          </Text>
          
          <TouchableOpacity style={styles.contactButton}>
            <Ionicons name="mail" size={20} color="#007AFF" />
            <Text style={styles.contactButtonText}>support@smartcellcounter.com</Text>
          </TouchableOpacity>
          
          <TouchableOpacity style={styles.contactButton}>
            <Ionicons name="globe" size={20} color="#007AFF" />
            <Text style={styles.contactButtonText}>Documentation & FAQ</Text>
          </TouchableOpacity>
        </HelpSection>
      </ScrollView>
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
  section: {
    backgroundColor: '#fff',
    marginTop: 20,
    marginHorizontal: 20,
    borderRadius: 12,
    overflow: 'hidden',
    elevation: 2,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.05,
    shadowRadius: 4,
  },
  sectionHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 20,
    backgroundColor: '#f8f9fa',
    borderBottomWidth: 1,
    borderBottomColor: '#E5E5EA',
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: '600',
    color: '#333',
    marginLeft: 12,
  },
  sectionContent: {
    padding: 20,
  },
  text: {
    fontSize: 14,
    color: '#666',
    lineHeight: 20,
    marginBottom: 16,
  },
  stepTitle: {
    fontSize: 16,
    fontWeight: '600',
    color: '#333',
    marginBottom: 8,
    marginTop: 8,
  },
  step: {
    fontSize: 14,
    color: '#666',
    lineHeight: 20,
    marginBottom: 4,
  },
  problemTitle: {
    fontSize: 15,
    fontWeight: '500',
    color: '#FF3B30',
    marginBottom: 4,
    marginTop: 12,
  },
  formulaBox: {
    backgroundColor: '#f8f9fa',
    padding: 16,
    borderRadius: 8,
    marginBottom: 12,
    borderLeftWidth: 4,
    borderLeftColor: '#007AFF',
  },
  formulaTitle: {
    fontSize: 14,
    fontWeight: '600',
    color: '#333',
    marginBottom: 8,
  },
  formula: {
    fontSize: 14,
    fontFamily: 'monospace',
    color: '#007AFF',
    backgroundColor: '#fff',
    padding: 8,
    borderRadius: 4,
  },
  contactButton: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 12,
    paddingHorizontal: 16,
    backgroundColor: '#f0f8ff',
    borderRadius: 8,
    marginBottom: 8,
  },
  contactButtonText: {
    fontSize: 14,
    color: '#007AFF',
    marginLeft: 8,
    fontWeight: '500',
  },
});
