# Test Fixtures

This directory contains anonymized test images and expected results for validating the cell counting pipeline.

## Structure

```
fixtures/
├── images/
│   ├── sample_001_neubauer.jpg      # Well-focused Neubauer chamber
│   ├── sample_002_disposable.jpg    # Disposable chamber
│   ├── sample_003_overcrowded.jpg   # High cell density
│   ├── sample_004_sparse.jpg        # Low cell density
│   ├── sample_005_poor_focus.jpg    # Out of focus image
│   ├── sample_006_glare.jpg         # Image with glare
│   ├── sample_007_debris.jpg        # Sample with debris
│   ├── sample_008_mixed_viability.jpg # Mixed live/dead cells
│   ├── sample_009_mostly_dead.jpg   # High death rate
│   └── sample_010_mostly_live.jpg   # High viability
├── expected_results.json            # Expected detection results
└── README.md                        # This file
```

## Expected Results Format

The `expected_results.json` file contains expected outcomes for each test image:

```json
{
  "sample_001_neubauer": {
    "gridDetected": true,
    "gridType": "neubauer",
    "focusScore": 145.2,
    "glareRatio": 0.03,
    "expectedCells": {
      "square0": { "live": 45, "dead": 12, "total": 57 },
      "square1": { "live": 52, "dead": 8, "total": 60 },
      "square2": { "live": 48, "dead": 15, "total": 63 },
      "square3": { "live": 50, "dead": 10, "total": 60 }
    },
    "expectedConcentration": 600000,
    "expectedViability": 81.7,
    "qualityScore": 95
  }
}
```

## Usage in Tests

These fixtures are used in integration tests to validate:

1. Grid detection accuracy
2. Cell segmentation performance
3. Viability classification accuracy
4. Counting rule compliance
5. Concentration calculations
6. Quality control thresholds

## Adding New Fixtures

When adding new test images:

1. Ensure images are anonymized (no patient/sample identifiers)
2. Include diverse scenarios (different chambers, cell densities, quality levels)
3. Manually verify ground truth counts using standard protocols
4. Update `expected_results.json` with accurate expected values
5. Consider edge cases and failure modes

## Image Specifications

- Format: JPEG
- Resolution: 1080x1080 minimum
- Color depth: 24-bit RGB
- Compression: High quality (minimal artifacts)
- Lighting: Representative of typical lab conditions

## Validation Protocol

Ground truth values are established by:

1. Manual counting by trained personnel
2. Cross-validation between multiple counters
3. Verification using established counting rules
4. Quality assessment using standard metrics

## Privacy and Ethics

All fixture images are:
- Anonymized and de-identified
- Used with appropriate permissions
- Compliant with relevant privacy regulations
- Sourced from consenting research participants or cell lines
