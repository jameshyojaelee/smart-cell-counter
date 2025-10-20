# Imaging Pipeline Diagram

```mermaid
flowchart LR
    A[Capture / Import] --> B[Rectangle Detection]
    B --> C[Perspective Correction]
    C --> D[Segmentation]
    D --> E[Connected Components]
    E --> F[Feature Extraction]
    F --> G[Per-Square Tallies]
    G --> H[Review & Results]

    subgraph Settings
    S1[Segmentation Strategy]
    S2[Threshold Method]
    S3[Block Size / C offset]
    S4[Cell Size Limits]
    S5[Dilution Factor]
    end

    S1 --> D
    S2 --> D
    S3 --> D
    S4 --> E
    S5 --> H
```

- **Capture / Import**: `CaptureViewModel` or mock injection seeds raw images.
- **Rectangle Detection**: `ImagingPipeline.detectGrid` locates hemocytometer boundaries.
- **Perspective Correction**: `ImagingPipeline.perspectiveCorrect` normalizes orientation.
- **Segmentation**: `ImagingPipeline.segmentCells` (classical/CoreML) guided by Settings parameters.
- **Connected Components & Features**: `CellDetector` + helper functions compute areas, centroids, etc.
- **Per-Square Tallies**: `CountingService` maps objects to the Neubauer grid.
- **Review & Results**: `ReviewViewModel` draws overlays; `ResultsViewModel` calculates concentration/viability and exports artifacts.

Use this diagram alongside `docs/ARCHITECTURE.md` for the big-picture flow.
