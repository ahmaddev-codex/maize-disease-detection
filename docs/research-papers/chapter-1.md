# Chapter 1: Introduction

## 1.1 Background of the Study

Agriculture is not merely an economic sector in Nigeria — it is the foundation on which roughly 70% of the rural population builds its livelihood. The country ranks among the top ten global maize producers, with annual output exceeding 11 million metric tons, and maize (*Zea mays*) sits at the centre of that agricultural identity (FAO, 2024). It is the most widely cultivated cereal, a dietary staple consumed in dozens of forms across every region, and the principal cash crop for smallholder farmers who typically farm less than two hectares of land. When maize production fails, the consequences extend well beyond the farm gate: household food security deteriorates, rural incomes collapse, and national food prices rise.

Crop disease is one of the most consistent drivers of maize production failure. Three fungal pathogens — Northern Corn Leaf Blight (NCLB, *Exserohilum turcicum*), Common Rust (*Puccinia sorghi*), and Gray Leaf Spot (GLS, *Cercospora zeae-maydis*) — collectively cause annual yield losses estimated between 20% and 40% of Nigeria's national maize harvest (Adedeji et al., 2023). In an individual field, a moderate NCLB outbreak in a susceptible variety can reduce yield by up to 50% when the disease progresses beyond the vegetative stage without intervention (Badu-Apraku & Fakorede, 2017). These are not rare events. The humid southern regions, the middle belt, and the northern savannas each carry distinct disease pressure profiles, and every growing season brings outbreaks somewhere.

The damage these diseases cause is, in large part, a detection problem. All three pathogens are most effectively managed in the early stages of infection, before they have colonised enough leaf area to substantially impair photosynthesis. By the time symptoms become obvious to the naked eye, effective intervention is more expensive and less complete. Early detection matters enormously — and early detection is precisely what the current system of manual inspection struggles to deliver.

Farmers who notice something wrong with a leaf are confronting a genuinely difficult visual classification task. NCLB produces elongated tan or grey-green lesions; GLS produces narrower, rectangular grey lesions; Common Rust produces small reddish-brown pustules. The distinction between NCLB and GLS in early infection is subtle enough that even trained extension officers sometimes disagree on identification. A farmer without plant pathology training is working from intuition, and intuition regularly leads to the wrong fungicide choice. Mancozeb is the appropriate response to NCLB; chlorothalonil is more effective against GLS; applying the wrong product wastes money and allows the disease to progress (Mamat et al., 2022).

The structural problem is that expertise is scarce and unevenly distributed. Nigeria's agricultural extension system is chronically understaffed: a single extension officer may serve several thousand smallholders across dispersed villages, and many farmers go an entire growing season without a single professional consultation (Anwar Omer et al., 2024). By the time a qualified diagnosis reaches a farmer who has noticed early symptoms, the intervention window may have closed. The result is a predictable pattern — delayed detection, late treatment, reduced efficacy, avoidable yield loss — that repeats across millions of farms every year.

The convergence of deep learning and mobile computing offers a practical route out of this pattern. Convolutional Neural Networks (CNNs) learn to recognise disease-specific patterns in leaf images — the shape, colour, and texture signatures that distinguish NCLB from GLS, or Rust from both — directly from labelled training data, without requiring manual feature engineering. Once trained, these models execute a complete classification in under a second on a mid-range smartphone. They do not tire, they do not vary across inspectors, and they are available at any hour without an appointment. Research across multiple crops consistently demonstrates classification accuracy exceeding 90% on benchmark datasets (Ibrahim et al., 2025; Junaidi et al., 2025).

That benchmark caveat, however, is critical. Most published plant disease classifiers were developed and tested on images from the PlantVillage repository — a carefully curated dataset captured under controlled indoor lighting against clean backgrounds using professional camera equipment. Photographs taken on Nigerian farms look fundamentally different: leaves photographed under harsh midday equatorial sunlight, partially occluded by adjacent plants, streaked with harmattan dust, and captured on 8-megapixel smartphone cameras. Models achieving 99% accuracy on clean benchmark images frequently degrade to substantially lower performance in field conditions (Lebrini & Gotor, 2024). The accuracy numbers in the literature are real, but they describe laboratory performance, not farm performance.

A second practical barrier is computational. The architectures that achieve the highest reported accuracy — dense ResNets, large Vision Transformers — are too large to run efficiently on a smartphone without a network connection to a cloud server. In rural Nigeria, where electricity supply is erratic and mobile data coverage is patchy, a disease detection system that depends on cloud inference is precisely the kind of tool that fails when it is most needed. Edge deployment — running the complete inference pipeline on the device itself — is the only architecture that is actually reliable under Nigerian field conditions, but it requires significant model compression to fit within the memory and battery constraints of affordable handsets.

A third gap is contextual. A leaf image contains visual information about present symptoms. It contains nothing about the crop variety being grown, the planting date, the agrochemicals already applied, or whether the same field suffered a similar outbreak the previous season. All of that information is directly relevant to both diagnosis and treatment decisions: a crop variety with documented NCLB susceptibility presenting with ambiguous early lesions should be treated with higher urgency than the same symptoms on a resistant variety. Seed bags sold through Nigerian agro-dealer networks carry this contextual information on printed labels. Optical Character Recognition (OCR) technology can extract that text from a photograph and convert it into structured data the detection system can use.

This study addresses all three gaps through MaizeGuard — a complete, field-deployable system for real-time maize disease detection. The system combines an EfficientNetB3 CNN trained to classify NCLB, Common Rust, GLS, and healthy leaves with an on-device OCR pipeline that extracts crop variety, batch number, and planting date from seed label photographs. The trained model is compressed to INT8 TFLite format and embedded in a cross-platform Flutter mobile application that operates fully offline. A context-aware recommendation engine translates detection results into specific, actionable treatment advice tied to Nigerian agro-dealer product lines and the Nigerian growing calendar. Where connectivity is available, the application routes the advisory request through a layered cloud engine: Gemini 2.0 Flash as the primary provider, with automatic failover to Groq (`llama-3.3-70b-versatile`) if the primary endpoint is rate-limited or unavailable, ensuring that farmers always receive an enhanced response without manual intervention. The system also supports four Nigerian languages — English, Yoruba, Igbo, and Hausa — with authentic text-to-speech delivery via the YarnGPT API for local-language output.

## 1.2 Problem Statement

Maize disease imposes a direct and quantifiable cost on Nigerian smallholder farmers. Annual yield losses of 20–40% attributable to NCLB, Common Rust, and GLS represent not only foregone production but foregone income for households with limited financial resilience (Upadhyay et al., 2025). The technological capability to detect these diseases early now exists in the deep learning literature. The problem is that this capability has not been translated into tools that function reliably under Nigerian field conditions and are accessible to farmers who lack specialist training, reliable internet, and advanced hardware.

The specific failures in the current state of the art are identified below.

**Subjective and inconsistent diagnosis.** NCLB, GLS, and Common Rust produce overlapping early-stage symptoms on maize leaves. Accurate differential diagnosis requires pathology training that the majority of Nigerian smallholder farmers do not have. Diagnosis by visual inspection alone is unreliable and inconsistent across individuals, leading to wrong treatment choices (Mamat et al., 2022).

**Inadequate extension coverage.** The ratio of agricultural extension officers to smallholder farmers in Nigeria makes timely, farm-level expert support structurally impossible for most growers. Farmers in remote areas may wait weeks for a consultation, well beyond the early intervention window (Omer et al., 2024).

**Delayed intervention.** The combination of uncertain self-diagnosis and limited access to expertise means that disease management decisions are routinely made after infection has advanced beyond the stage at which treatment is most effective and cost-efficient.

**Poor real-world model performance.** Existing AI plant disease detection systems are developed and evaluated under controlled laboratory conditions. When these models are deployed in field environments characterised by variable natural light, leaf occlusion, complex backgrounds, and consumer-grade cameras, their performance degrades substantially (Mamat et al., 2022; Lebrini & Gotor, 2024).

**Single-source data.** Published systems classify leaf images and return a label. They make no use of contextual metadata — crop variety, planting date, treatment history — that is directly relevant to both the diagnosis and the appropriate treatment response (Junaidi et al., 2025).

**Connectivity and hardware requirements.** Systems that depend on cloud inference or high-end devices are inaccessible to rural smallholders who own basic Android smartphones and have limited or no internet access (Omer et al., 2024).

**Absence of field validation.** Most studies report model accuracy on held-out test sets drawn from the same controlled dataset used for training. Very few validate performance under actual farm conditions with real farmers and real disease variation (Lebrini & Gotor, 2024).

Together, these failures define the gap between what AI-based disease detection can theoretically deliver and what it currently delivers to Nigerian smallholder maize farmers.

## 1.3 Aim and Objectives of the Study

**Aim**

The aim of this study is to develop MaizeGuard: a real-time maize disease detection system that combines deep learning image classification with OCR-based seed label metadata extraction, operates fully offline on commodity smartphones, and provides Nigerian smallholder farmers with specific, locally grounded treatment guidance.

**Objectives**

1. To develop and train a CNN-based image classifier for four-class maize disease detection — NCLB, Common Rust, Gray Leaf Spot, and Healthy — achieving a target test accuracy of 90% or above on the PlantVillage maize benchmark, using EfficientNetB3 with two-stage transfer learning and class-weighted training to address dataset imbalance.

2. To build an on-device OCR pipeline using Google ML Kit Text Recognition that extracts crop variety, batch number, and planting date from photographs of Nigerian seed packaging and encodes the extracted fields as a structured metadata vector for downstream fusion.

3. To design a multimodal late-fusion architecture that combines the CNN's visual feature representation with the OCR-derived metadata vector and measures the resulting accuracy improvement over the image-only baseline.

4. To compress the trained model to INT8 TFLite format, achieving a model size under 20 MB and inference latency below two seconds on a mid-range Android smartphone, with FP16 as a fallback for devices without INT8 acceleration.

5. To implement a cross-platform Flutter mobile application that integrates live-camera leaf capture, on-device disease classification, OCR seed label scanning, GPS-tagged scan history, geospatial disease mapping on OpenStreetMap, and AI-powered agronomic recommendations — all functional without an internet connection.

6. To deliver treatment recommendations that account for Nigerian growing seasons, known variety-specific resistance profiles, and fungicide products available in Nigerian agro-dealer networks, with automatic enhancement via Gemini 2.0 Flash when connectivity is available, and automatic Groq fallback to ensure uninterrupted advisory service when the primary cloud endpoint is unavailable.

7. To implement a four-language support system — English, Yoruba, Igbo, and Hausa — enabling AI advisory responses and on-device recommendation text to be delivered in the farmer's chosen language, with authentic Nigerian-language text-to-speech output via the YarnGPT API for non-English languages and device-native synthesis for English.

8. To provide a scan feedback mechanism through which farmers can indicate whether a diagnosis was correct, storing responses in the scan database to support future model improvement, and to incorporate a confidence gate that warns farmers when model confidence is low and provides guidance on retaking the scan under better conditions.

## 1.4 Research Questions

1. Can an EfficientNetB3 classifier trained with two-stage transfer learning and class weighting achieve 90% or higher accuracy on the four-class PlantVillage maize disease benchmark?

2. Does a late-fusion multimodal architecture incorporating OCR-extracted seed variety metadata improve classification accuracy over the image-only baseline, and in which disease classes is the improvement most pronounced?

3. Can INT8 post-training quantisation reduce the trained model to under 20 MB and achieve sub-two-second inference latency on a mid-range Android device with accuracy degradation below one percentage point relative to the full-precision baseline?

4. Does the on-device recommendation engine produce treatment guidance that practising agronomists assess as accurate, complete, and applicable to Nigerian farming conditions?

5. What practical challenges in image capture quality, metadata extraction reliability, and offline operation affect system performance and farmer acceptance during field use?

## 1.5 Significance of the Study

**Earlier, more accurate detection reduces yield losses.** MaizeGuard identifies disease at first symptom expression rather than after visual spread. For NCLB in a susceptible variety, treatment applied at early lesion formation can limit yield loss to under 10%; the same infection left untreated for two additional weeks can reduce yield by 40–50% (Badu-Apraku & Fakorede, 2017).

**Offline operation is not a convenience — it is a prerequisite.** The entire MaizeGuard pipeline runs on-device without a network connection. This design decision reflects the reality that farms in the highest-risk disease corridors are typically the least connected, and a system that fails in those environments provides no benefit where it is most needed.

**Contextual recommendations replace generic advice.** MaizeGuard does not return a class label. It produces treatment plans referencing specific fungicide brands available in Nigerian agro-dealer markets, application rates appropriate for West African conditions, and timing adjusted for the current growing season and, where OCR has captured a planting date, for the crop's growth stage.

**OCR removes the metadata entry burden.** Photographing a seed bag takes three seconds. The OCR pipeline converts that photograph into structured variety, batch, and planting date fields without any manual typing, which means the contextual data that improves diagnostic accuracy is captured as a natural extension of the farmer's existing workflow.

**Geospatial mapping supports extension prioritisation.** GPS-tagged scan records provide extension officers with a spatial view of disease distribution across farms that would require weeks of manual scouting to compile. Clustered red markers on the map indicate a localised outbreak that warrants immediate field attention.

**Open architecture ensures maintainability.** The system depends entirely on open standards: TFLite for inference, Flutter for the mobile framework, OpenStreetMap for map tiles. There are no proprietary infrastructure dependencies that could create licensing barriers to maintenance or extension.

## 1.6 Methodology Overview

The study was conducted in six sequential phases.

The first phase surveyed published work on CNN-based plant disease detection, TFLite edge deployment, agricultural OCR applications, and mobile precision agriculture systems, establishing the performance benchmarks against which MaizeGuard was evaluated.

The second phase prepared the training dataset. The PlantVillage maize subset — 4,188 images distributed across four classes — was stratified into 70:15:15 training, validation, and test splits. A data augmentation pipeline covering random flips, rotation, zoom, translation, brightness variation, and contrast variation was applied on-the-fly during training to improve robustness to field-condition image variability.

The third phase trained the CNN classifier. EfficientNetB3, pre-trained on ImageNet-1K, was selected as the convolutional backbone. Training proceeded in two stages: head-only training on frozen base weights for twenty epochs using AdamW at a learning rate of 1×10⁻³, followed by selective fine-tuning of the upper EfficientNetB3 layers for thirty epochs at 1×10⁻⁵. Class weights were applied throughout to compensate for Gray Leaf Spot's under-representation in the training set.

The fourth phase developed the OCR subsystem. Google ML Kit Text Recognition was integrated for on-device character recognition on Android and iOS. A rule-based extraction layer parsed raw OCR output to recover crop variety against a list of thirteen Nigerian maize varieties, along with batch number and planting date.

The fifth phase converted the trained Keras model to TFLite format in INT8 and FP16 variants using post-training quantisation with a 200-image calibration set, and implemented the ClassifierService in Dart for model lifecycle management and inference.

The sixth phase assembled all components into the MaizeGuard Flutter application: live camera capture, OCR scan flow, disease detection pipeline, sqflite-backed scan history, OpenStreetMap geospatial display, on-device recommendation engine, and AI advisory integration. The advisory subsystem implements a three-tier fallback chain: in release builds, requests are routed to Gemini 2.0 Flash first, then automatically to Groq (`llama-3.3-70b-versatile`) if Gemini fails or returns an empty response, with silent fallback to the on-device engine as a final guarantee. Debug builds route to Groq first, then to Ollama. A four-language system (English, Yoruba, Igbo, Hausa) enables advice generation in the farmer's chosen language, with YarnGPT-powered text-to-speech for Nigerian languages and device-native synthesis for English. A unified result screen presents the diagnosis, on-device recommendations, AI advice, a confidence gate, and a scan feedback prompt on a single scrollable view. The application was validated on an iPhone 17 Pro simulator (iOS 26.2) and on Android hardware.

## 1.7 Definition of Terms

**Maize** (*Zea mays*): A cereal crop cultivated worldwide for human food, livestock feed, and industrial use. Nigeria's annual maize output exceeds 11 million metric tons, making it the country's most important grain crop and the primary income source for millions of smallholder farmers.

**Northern Corn Leaf Blight (NCLB)**: A fungal disease caused by *Exserohilum turcicum*, characterised by elongated, cigar-shaped tan or grey-green lesions. Spreads by wind-borne conidia under cool, humid conditions and can reduce yield by up to 50% in susceptible varieties when uncontrolled.

**Common Rust**: A fungal disease caused by *Puccinia sorghi*, producing small, brick-red uredia on both leaf surfaces. Less aggressive than NCLB at low infection density but capable of severely limiting photosynthetic capacity under early, widespread infection.

**Gray Leaf Spot (GLS)**: A fungal disease caused by *Cercospora zeae-maydis*, producing narrow, rectangular grey lesions oriented parallel to leaf veins. Lesions merge under heavy infection, leading to premature leaf death and yield losses of 30–40% in severely affected fields.

**Convolutional Neural Network (CNN)**: A deep learning architecture specialised for image analysis. Successive convolutional layers apply learned filters to extract spatial features — edges, textures, lesion shapes — that are combined in deeper layers to form high-level object representations.

**EfficientNetB3**: A CNN architecture introduced by Tan and Le (2019) that scales network depth, width, and input resolution simultaneously using a fixed set of compound scaling coefficients. Accepts 300 × 300-pixel inputs and achieves state-of-the-art accuracy with fewer parameters than architectures of comparable depth.

**Transfer Learning**: Adapting a model pre-trained on a large general dataset (ImageNet-1K) to a specific task (maize disease classification) using a smaller domain dataset. Pre-trained weights provide a rich feature initialisation that reduces the training data required to achieve good performance.

**INT8 Quantisation**: A compression technique that stores neural network weights as 8-bit integers instead of 32-bit floats. Reduces model size approximately 4× and inference latency 2–4× on ARM processors with SIMD acceleration, with typical accuracy degradation below one percentage point.

**TFLite (TensorFlow Lite)**: A lightweight TensorFlow runtime designed for inference on mobile and embedded devices. Models in `.tflite` format are substantially smaller and faster than their Keras counterparts and run without a Python environment.

**Optical Character Recognition (OCR)**: Technology that converts text present in an image into machine-readable characters. In MaizeGuard, OCR extracts crop variety, batch number, and planting date from seed bag label photographs.

**Edge Computing**: Performing computation on a local device rather than transmitting data to a remote server. In MaizeGuard, the entire inference pipeline runs on the farmer's smartphone, eliminating any dependency on internet connectivity.

**sqflite**: A Flutter package providing a binding to the SQLite embedded relational database engine. MaizeGuard uses sqflite to persist scan records, GPS coordinates, OCR-extracted metadata, and per-class confidence scores across application sessions.

**Riverpod**: A reactive state management library for Flutter. MaizeGuard uses Riverpod to manage application state — current scan result, scan history, theme, Gemini API key, classifier readiness, and display language selection — across screens without passing data through widget constructors.

**Field Validation**: Testing a system under actual operating conditions on real farms with real users, as distinct from controlled laboratory or simulator-based evaluation.
