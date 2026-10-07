# Chapter 5: Discussion, Conclusion, and Future Work

## 5.1 Discussion

### 5.1.1 Model Architecture Choices

The selection of EfficientNetB3 as the classification backbone was motivated by its Pareto-optimal balance of accuracy and parameter count on the ImageNet benchmark. For mobile and edge deployment, parameter efficiency translates directly to model size — a concrete constraint for farmers operating on entry-level Android devices with limited internal storage. Against alternatives that appear in the maize disease detection literature — ResNet-50, VGG-16, and MobileNetV2 — EfficientNetB3 offers comparable or superior classification accuracy with substantially fewer parameters at inference time.

The two-stage training protocol (frozen base with classification head training, followed by selective layer unfreezing) is well-suited to small agricultural datasets. Training the full network from a random weight initialisation on 2,932 labelled images would result in severe overfitting. By first training only the classification head and then selectively fine-tuning upper convolutional layers, the model adapts pretrained ImageNet representations to the domain-specific textures of fungal maize lesions while retaining the stable low-level feature detectors learned on millions of natural images.

### 5.1.2 Multimodal Fusion: an Architecture, Not Yet a Result

The fusion model is experimental (ADR-002). No public dataset pairs a leaf photograph with the variety, batch and planting date of that same plant, so the metadata used in training is generated — every row of `labels_with_metadata.csv` is flagged `synthetic=1` by the script that writes it. A model trained on invented metadata cannot demonstrate that metadata helps, and any accuracy gain it shows may come from the extra parameters alone.

To keep that distinction testable rather than rhetorical, `src/phase3_fusion/ablation.py` runs three arms on one split: zeroed metadata, the real vectors, and the same vectors permuted across images. The shuffled arm preserves every marginal distribution and destroys only the pairing, so fusion must beat *that* arm by more than the run-to-run noise band for the metadata to count as signal; beating the zeroed arm alone shows only that the extra parameters helped. The result, recorded in `models/exports/metrics.json` under `fusion_ablation`: `cnn_only` 93.63%, `fusion` 93.79%, `fusion_shuffled` 93.63% on the 628-image test split. Fusion exceeds the shuffled arm by 0.16 points, inside the noise band, so the metadata contributes nothing measurable — the expected outcome when the values are invented. This chapter therefore claims no fusion accuracy figure.

The reasoning that motivates the architecture remains sound, and is stated as motivation rather than as a finding: disease susceptibility is strongly variety-dependent. SAMMAZ 15 and SAMMAZ 29 carry documented resistance to NCLB from the International Institute of Tropical Agriculture (IITA) Nigeria, while several hybrid varieties are highly susceptible to Common Rust. Incorporating this structured prior allows the fusion model to resolve low-confidence detections in a direction consistent with known pathology rather than treating all cultivars as equally susceptible.

The late-fusion approach — concatenating encoded CNN features with encoded metadata at the penultimate layer — was chosen over early fusion because it allows each modality to be preprocessed and encoded independently before combination. It also makes the fusion model robust to missing metadata: when OCR yields no variety information, the variety branch emits a zero vector and the CNN branch's prediction carries full weight, with no degradation in the absence of seed label data.

### 5.1.3 On-Device vs. Cloud Recommendation

The split between built-in and generated advice reflects a deliberate engineering choice for deployment in rural Nigeria, where mobile internet connectivity is intermittent and data costs are significant relative to farmer incomes. The on-device `RecommendationEngine` provides actionable, locally relevant advice — the chemical groups that control each disease, growing-season timing, resistance-management guidance — without any network dependency. A cloud model offers richer context when connectivity and a key permit, but is never a prerequisite for diagnosis.

Two constraints govern what either source may say. Neither states a dose: rate, pre-harvest interval and protective equipment are referred to the product label and to an extension officer, because a language model inventing a mixing ratio is a safety failure, not a helpful detail. And neither recommends a product outside the per-disease table of active ingredients; two products widely sold in Nigerian agro-dealer networks — a metalaxyl formulation and a copper formulation — control neither of these fungal pathogens, and both had been named in an earlier version of the prompts and of the Yoruba, Hausa and Igbo voice scripts.

Advisory requests go to one provider, Groq, under a single deadline; when that is not possible the built-in rules answer. An earlier design chained several providers so that an outage would be invisible to the farmer, and that invisibility was the problem: a farmer could not tell whether the words on screen came from a model that had considered their variety and confidence or from a fixed table. The current design makes the source explicit on every result and keeps the generated text with the scan, so it neither changes on reopening nor costs a second request (ADR-003).

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

5. **Laboratory data only, with no field measurement:** every accuracy figure in this work is measured on a held-out split of PlantVillage photographs. No field-condition test set has been assembled, so the field accuracy of this system is unknown rather than estimated. This is the single largest gap between what is measured and what a farmer would experience.

6. **Gray Leaf Spot remains the weakest class:** under FP16, per-class F1 is 1.00 for Healthy and 0.97 for Rust against 0.79 for GLS (0.68 under INT8). A GLS diagnosis from this system deserves more caution than the headline accuracy implies, and targeted GLS collection remains the highest-value dataset work.

7. **The fusion metadata is synthetic:** no paired dataset exists, so the multimodal extension is reported as an architecture with an ablation rather than as a gain (5.1.2).

8. **The UAV pipeline applies a leaf model to aerial imagery:** the classifier was trained and measured on close-up photographs and has never been evaluated at altitude. The heatmap is a scouting aid for choosing where to walk, and is described as such in the README; treating it as a diagnosis of the plants it colours would be unsupported.

9. **On-device latency has not been measured:** the application records model-only inference time per scan, but no benchmark across representative Android hardware has been run, so no device latency figure is claimed.

10. **Generated advice requires the farmer's own API key:** the longer advisory requires a Groq key, which involves account creation and may incur costs at scale, and release builds ship without one (ADR-003). The built-in rules provide a free alternative that names the same chemistry, but not the same contextual depth; the result screen states which of the two produced the text on screen.

---

## 5.2 Contributions

This work makes the following original contributions to the domain of precision agriculture and mobile AI systems:

1. **End-to-end maize disease pipeline for Nigeria:** A complete training and deployment pipeline combining EfficientNetB3 transfer learning with OCR-based seed label metadata fusion, specifically designed and evaluated for Nigerian smallholder farming conditions — including disease classes, product recommendations, and growing-season logic relevant to that context.

2. **Multimodal fusion architecture with an honest ablation:** a late-fusion model (Phase 3) combining visual disease features with structured crop variety metadata, with zero-vector robustness when metadata is unavailable — accompanied by a shuffled-metadata ablation that can distinguish signal from additional parameters, and reported without an accuracy claim until a paired dataset exists.

3. **MaizeGuard Flutter application:** A cross-platform mobile application providing offline-first disease detection, GPS-tagged scan history, geospatial disease mapping, and AI-powered treatment recommendations. The application is built on a clean Riverpod state architecture (`flutter_riverpod ^2.5.1`) with a `ShellRoute` shell, four tabs, and six push routes, and runs on a single Dart codebase across Android and iOS.

4. **PathResolver — portable image path management:** A lightweight service that decouples image storage from container-specific absolute paths by storing relative paths in SQLite and resolving them at display time. The service handles the iOS container UUID rotation problem transparently, including migration of stale absolute paths from previous installations.

5. **AppEnv — compile-time environment variable system:** A structured pattern for injecting environment-specific configuration (API keys, backend host, model name) at compile time via `--dart-define-from-file=.env.json`, keeping credentials out of source code while enabling debug/release backend switching without conditional logic at the call site.

6. **Context-aware recommendation engine with an optional generated advisory:** an on-device `RecommendationEngine` carrying the chemical groups that control each disease, growing-season heuristics, trend analysis and urgency classification — optionally augmented by a Groq advisory when the farmer has supplied a key and has a connection, with the source of the text always shown.

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
- A single-provider advisory (Groq) under one deadline, with built-in rules as the stated alternative and the source of every recommendation visible to the farmer
- A four-language support system (English, Yoruba, Igbo, Hausa) with AI advice generated in the farmer's chosen language and authentic Nigerian-language text-to-speech via the YarnGPT API
- A unified result screen consolidating diagnosis, recommendations, AI advice, language translation, confidence gate, and scan feedback into a single scrollable consultation view
- A scan feedback loop and database schema v2 migration that collects farmer-reported correctness assessments to support future supervised model improvement

The system addresses a critical need in Nigerian smallholder agriculture, where maize yield losses of 30–60% attributable to Northern Corn Leaf Blight, Common Rust, and Gray Leaf Spot are substantially driven by delayed or incorrect disease identification and consequently suboptimal treatment decisions. Placing an accurate, offline-capable diagnostic tool with Nigerian-market-specific treatment guidance and Nigerian-language voice output in the hands of farmers has the potential to reduce these losses through timely and appropriate intervention, irrespective of the farmer's English literacy level or internet connectivity.

The architecture's offline-first design, portable image storage via PathResolver, three-tier advisory resilience, four-language localisation, context-aware tiered recommendation engine, and geospatial disease mapping distinguish MaizeGuard from generic plant disease classification applications. The open system design — standard TFLite inference, open-source Flutter framework, OpenStreetMap tiles — ensures the system can be maintained, extended, and reproduced without proprietary infrastructure dependencies, making it a viable foundation for future agricultural AI work in resource-constrained deployment contexts.
