# Chapter 5: Discussion, Conclusion, and Future Work

## 5.1 Discussion

### 5.1.1 Model Architecture Choices

The selection of EfficientNetB3 as the classification backbone was motivated by its Pareto-optimal balance of accuracy and parameter count on the ImageNet benchmark. For mobile and edge deployment, parameter efficiency translates directly to model size — a concrete constraint for farmers operating on entry-level Android devices with limited internal storage. Against alternatives that appear in the maize disease detection literature — ResNet-50, VGG-16, and MobileNetV2 — EfficientNetB3 offers comparable or superior classification accuracy with substantially fewer parameters at inference time.

The two-stage training protocol (frozen base with classification head training, followed by selective layer unfreezing) is well-suited to small agricultural datasets. Training the full network from a random weight initialisation on 2,932 labelled images would result in severe overfitting. By first training only the classification head and then selectively fine-tuning upper convolutional layers, the model adapts pretrained ImageNet representations to the domain-specific textures of fungal maize lesions while retaining the stable low-level feature detectors learned on millions of natural images.

### 5.1.2 Multimodal Fusion Impact

The integration of OCR-extracted seed variety metadata as a second input modality reflects the agronomic reality that disease susceptibility is strongly variety-dependent. SAMMAZ 15 and SAMMAZ 29 carry documented resistance to NCLB from the International Institute of Tropical Agriculture (IITA) Nigeria, while several hybrid varieties are highly susceptible to Common Rust. Incorporating this structured prior allows the fusion model to resolve low-confidence detections in a direction consistent with known pathology rather than treating all cultivars as equally susceptible.

The late-fusion approach — concatenating encoded CNN features with encoded metadata at the penultimate layer — was chosen over early fusion because it allows each modality to be preprocessed and encoded independently before combination. It also makes the fusion model robust to missing metadata: when OCR yields no variety information, the variety branch emits a zero vector and the CNN branch's prediction carries full weight, with no degradation in the absence of seed label data.

### 5.1.3 On-Device vs. Cloud Recommendation

The three-tier recommendation architecture reflects a deliberate engineering choice for deployment in rural Nigeria, where mobile internet connectivity is intermittent and data costs are significant relative to farmer incomes. The on-device `RecommendationEngine` provides actionable, locally relevant advice — Nigerian product brands, growing-season timing, FRAC resistance management codes — without any network dependency. Cloud providers offer richer contextual advice when connectivity permits, but are never a prerequisite for the application's core diagnostic functionality.

In release builds, advisory requests follow the chain: Gemini 2.0 Flash → Groq (`llama-3.3-70b-versatile`) → on-device engine. Groq serves as an automatic secondary cloud provider, inserted specifically to address the scenario where Gemini API rate limits or temporary outages would otherwise cause silent degradation to the on-device engine. With Groq in the chain, a single cloud provider outage is invisible to the farmer: the advisory simply arrives from the secondary provider, with no user interaction or error message. In debug builds, the chain is Groq → Ollama, keeping development traffic off Gemini quota entirely.

This three-tier degradation model is consistent with offline-first design principles for agricultural ICT systems in low-resource environments, where assuming connectivity has consistently caused adoption failure in deployment. The full chain ensures that every scan produces the best available recommendation at that moment — cloud-enhanced when possible, on-device when necessary.

### 5.1.4 Geospatial Disease Mapping

The integration of GPS coordinates with scan records addresses a gap in existing disease detection applications, which typically report per-scan results without spatial context. For extension officers managing multiple farms, the Map Screen provides a farm-level spatial overview of disease distribution — colour-coded markers by class across the real geography of the scanning area — that supports intervention prioritisation without requiring GIS expertise or specialist hardware.

The geometric-centroid map centre ensures that the initial map view is appropriate for the farmer's actual scanning area as it grows over time, rather than being anchored to the first scan ever recorded. The implementation computes the arithmetic mean of all recorded latitudes and longitudes, recentring the view as new scans are added in different field locations.

The UAV integration layer extends this capability from individual plant scans to field-scale aerial surveys, enabling the detection of disease hotspots from orthomosaic imagery before visual spread becomes apparent to the naked eye.

### 5.1.5 Image Path Portability

The `PathResolver` service addresses a mobile platform portability challenge that arises specifically on iOS: the application container UUID embedded in the absolute Documents directory path changes each time the app is reinstalled. Storing absolute paths in SQLite causes every image to become inaccessible after a reinstall. The solution — storing only the relative path component (`scans/<filename>.jpg`) and resolving to the current absolute path at display time via a cached `getApplicationDocumentsDirectory()` result — makes all scan records portable across reinstalls on both iOS and Android.

`PathResolver.resolve()` also handles the migration case for records that were persisted with stale absolute paths from a previous installation, by extracting the filename and reconstructing the path under the current container, without requiring a database migration.

### 5.1.6 Limitations

1. **Dataset Domain Shift:** The PlantVillage dataset was collected under controlled conditions with plain backgrounds and consistent lighting. Field conditions in Nigeria involve cluttered backgrounds, variable sunlight, phone camera diversity, and soil or dust on leaf surfaces. The augmentation pipeline partially addresses this gap, but fine-tuning on locally collected field images would likely yield further accuracy improvements under real-world conditions.

2. **Class Imbalance:** The under-representation of GLS (574 training images against 1,306 for Rust) limits the model's sensitivity to early-stage GLS lesions. Class weighting mitigates this imbalance but does not eliminate it. Targeted data collection for GLS would be the highest-value dataset improvement.

3. **Single-Leaf Inference:** The model classifies one leaf per scan. Disease symptoms may be distributed non-uniformly across a plant, and a single-leaf sample may not represent overall plant health. A multi-leaf aggregation protocol — scanning three to five leaves per plant and taking the modal class — would reduce diagnostic uncertainty for borderline cases.

4. **iOS Physical Device Testing:** The application was validated on an iPhone 17 Pro simulator (iOS 26.2) and a full iOS build passes codesigning checks. Testing on physical iPhone hardware and submitting to TestFlight for field distribution remained outside the scope of this project and represent a concrete next step toward App Store deployment.

5. **Gemini API Key Requirement for Enhanced Recommendations:** AI-enhanced agronomic advice requires a Google Cloud API key, which involves account creation and may incur costs at scale. The on-device engine provides a fully functional free alternative, but the contextual depth of Gemini's responses is not fully replicable offline.

---

## 5.2 Contributions

This work makes the following original contributions to the domain of precision agriculture and mobile AI systems:

1. **End-to-end maize disease pipeline for Nigeria:** A complete training and deployment pipeline combining EfficientNetB3 transfer learning with OCR-based seed label metadata fusion, specifically designed and evaluated for Nigerian smallholder farming conditions — including disease classes, product recommendations, and growing-season logic relevant to that context.

2. **Multimodal fusion architecture:** A late-fusion model (Phase 3) combining visual disease features with structured crop variety metadata to resolve low-confidence single-modality detections, with zero-vector robustness when metadata is unavailable.

3. **MaizeGuard Flutter application:** A cross-platform mobile application providing offline-first disease detection, GPS-tagged scan history, geospatial disease mapping, and AI-powered treatment recommendations. The application is built on a clean Riverpod state architecture (`flutter_riverpod ^2.5.1`) with a `ShellRoute` shell, four tabs, and six push routes, and runs on a single Dart codebase across Android and iOS.

4. **PathResolver — portable image path management:** A lightweight service that decouples image storage from container-specific absolute paths by storing relative paths in SQLite and resolving them at display time. The service handles the iOS container UUID rotation problem transparently, including migration of stale absolute paths from previous installations.

5. **AppEnv — compile-time environment variable system:** A structured pattern for injecting environment-specific configuration (API keys, backend host, model name) at compile time via `--dart-define-from-file=.env.json`, keeping credentials out of source code while enabling debug/release backend switching without conditional logic at the call site.

6. **Context-aware tiered recommendation engine with Groq fallback:** An on-device `RecommendationEngine` with Nigerian agro-dealer fungicide data, growing-season heuristics, FRAC code rotation guidance, trend analysis, and urgency classification — augmented by automatic Gemini 2.0 Flash API routing in release builds, with automatic Groq secondary fallback and final silent fallback to the on-device engine, ensuring uninterrupted advisory delivery regardless of cloud provider availability.

7. **Language and translation system:** A four-language display system (English, Yoruba, Igbo, Hausa) in which AI advisory responses are generated directly in the farmer's chosen language via a language instruction appended to the cloud provider prompt, and on-device recommendation text can be translated on demand via `AiAdvisor.translateResult()`. Language preference is managed by `displayLanguageProvider` and persisted across application sessions.

8. **YarnGPT text-to-speech integration:** A dual-engine TTS system (`YarnTtsService`) that delivers device-native synthesis for English via `flutter_tts` and authentic Nigerian-language speech for Yoruba (Idera), Igbo (Chinenye), and Hausa (Zainab) via the YarnGPT API, with MP3 playback via `audioplayers`. Speaker buttons on the verdict card, translated sections card, and AI advice card give farmers audio access to diagnosis results without requiring literacy in any language.

9. **Unified result and advisory screen:** A `ConsumerStatefulWidget` `ResultScreen` that consolidates the diagnostic verdict, class scores, on-device recommendations, translate button, AI advice, scan feedback prompt, confidence gate, and collapsible disease background into a single scrollable view, eliminating the multi-screen navigation previously required to complete a consultation.

10. **Scan feedback loop and confidence gate:** A per-scan feedback mechanism through which farmers can indicate diagnostic correctness (correct / incorrect / unsure), with responses stored in a `feedback` column added to `scan_records` in database schema version 2 via a non-destructive `ALTER TABLE` migration. A confidence gate displays an amber retake-guidance banner when top-class confidence falls below 60%, providing actionable image capture advice without suppressing the diagnosis result.

11. **OCR inline correction:** Editable `TextField` widgets pre-filled with OCR extraction output on `OcrScreen`, allowing farmers to correct recognition errors before seed label metadata propagates to the scan record. The corrected controller values — not the raw OCR output — are used when attaching metadata to the next scan.

12. **INT8 TFLite edge model:** An INT8-quantised EfficientNetB3 artefact (13 MB) achieving sub-1% accuracy degradation at 2–4× lower inference latency on ARM hardware, suitable for deployment on Raspberry Pi 4 and entry-level Android smartphones with no network dependency.

13. **UAV integration pipeline:** A Phase 5 aerial survey pipeline processing drone orthomosaic images with sliding-window inference, generating interactive HTML and static PNG disease heatmaps for field-scale spatial monitoring.

---

## 5.3 Future Work

1. **Field Data Collection and Domain Adaptation:** Partner with IITA Nigeria or the Lake Chad Research Institute (LCRI) to collect and label maize disease images captured under Nigerian farming conditions using farmer-owned smartphones. Fine-tuning on this data would close the domain gap between PlantVillage's controlled imagery and real-world field variation.

2. **Federated Learning:** As MaizeGuard is deployed across multiple farms, scan records with user-confirmed labels could participate in a federated learning protocol to improve the shared model incrementally without centralising farmer data or compromising privacy.

3. **Disease Severity Staging:** Extend the classification task from class identification to a four-level severity scale (none / mild / moderate / severe). This would provide more precise treatment dosage guidance and is likely to be more actionable for farmers making spray timing decisions. A labelled severity dataset and a revised regression or ordinal classification head would be required.

4. **Multi-Disease Co-occurrence:** Nigerian maize crops frequently present with multiple simultaneous diseases on the same plant. The current single-label softmax architecture cannot model co-occurrence. A multi-label classification head with per-class sigmoid outputs and binary cross-entropy loss would address this.

5. **Extended Voice Interface and Voice Input:** MaizeGuard has implemented text-to-speech output for Yoruba, Igbo, and Hausa via the YarnGPT API in the current version, delivering authentic Nigerian-language speech for diagnosis results, translated recommendations, and AI advisory text. Remaining directions include expanding TTS coverage to additional Nigerian languages such as Fulfulde and Kanuri, improving prosodic quality and agricultural vocabulary in synthesised speech, and introducing voice-based input — allowing farmers to describe symptoms or confirm actions by speaking rather than typing — which would further reduce the literacy barrier for application use.

6. **iOS Physical Device Distribution:** Complete the physical iPhone hardware validation, obtain Apple Developer Program provisioning, and distribute MaizeGuard through TestFlight for structured field trials before App Store submission.

7. **Offline Map Tiles:** Pre-cache OpenStreetMap tiles for key maize farming corridors (Benue, Kano, Kaduna, Oyo) to enable full Map Screen functionality in the absence of internet connectivity, consistent with the application's offline-first design principle.

8. **Integration with Agricultural Extension Services:** Develop a server-side API endpoint to receive aggregated, anonymised disease heatmap data from the MaizeGuard user base, enabling national-scale early-warning systems for disease outbreak detection in coordination with platforms such as FMARD's AgroMoni.

---

## 5.4 Conclusion

This dissertation has presented MaizeGuard — a complete, multi-phase AI system for the detection and management of maize leaf diseases in Nigerian smallholder agriculture. Beginning from a raw PlantVillage image dataset, the project designed and implemented the following interconnected components:

- A training pipeline for an EfficientNetB3 convolutional neural network with two-stage transfer learning and class-weighted training
- An adaptive OCR system for extracting structured crop metadata from seed label photographs, with editable inline correction for farmer-reviewed accuracy
- A late-fusion multimodal model combining visual and agronomic features
- INT8 TFLite quantisation for edge deployment on mobile and single-board hardware
- A cross-platform Flutter mobile application integrating all components with GPS-tagged scan history, geospatial disease mapping, and AI-powered agronomic recommendations
- A three-tier AI advisory fallback chain (Gemini 2.0 Flash → Groq → on-device engine in release; Groq → Ollama in debug) ensuring uninterrupted advisory delivery regardless of cloud provider availability
- A four-language support system (English, Yoruba, Igbo, Hausa) with AI advice generated in the farmer's chosen language and authentic Nigerian-language text-to-speech via the YarnGPT API
- A unified result screen consolidating diagnosis, recommendations, AI advice, language translation, confidence gate, and scan feedback into a single scrollable consultation view
- A scan feedback loop and database schema v2 migration that collects farmer-reported correctness assessments to support future supervised model improvement

The system addresses a critical need in Nigerian smallholder agriculture, where maize yield losses of 30–60% attributable to Northern Corn Leaf Blight, Common Rust, and Gray Leaf Spot are substantially driven by delayed or incorrect disease identification and consequently suboptimal treatment decisions. Placing an accurate, offline-capable diagnostic tool with Nigerian-market-specific treatment guidance and Nigerian-language voice output in the hands of farmers has the potential to reduce these losses through timely and appropriate intervention, irrespective of the farmer's English literacy level or internet connectivity.

The architecture's offline-first design, portable image storage via PathResolver, three-tier advisory resilience, four-language localisation, context-aware tiered recommendation engine, and geospatial disease mapping distinguish MaizeGuard from generic plant disease classification applications. The open system design — standard TFLite inference, open-source Flutter framework, OpenStreetMap tiles — ensures the system can be maintained, extended, and reproduced without proprietary infrastructure dependencies, making it a viable foundation for future agricultural AI work in resource-constrained deployment contexts.
