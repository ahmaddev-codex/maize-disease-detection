# Chapter 2: Literature Review

## 2.1 Introduction

This chapter reviews prior work on maize disease detection using image processing and artificial intelligence. The review covers CNN-based classification approaches, OCR integration in agricultural systems, edge deployment strategies for resource-constrained environments, and the broader landscape of smart precision agriculture. The aim is to understand where the field currently stands, identify the limitations that persist across the literature, and establish the gaps that MaizeGuard was designed to address.

The review draws on thirty primary studies alongside several authoritative surveys. Published findings are examined critically, with particular attention to whether high-accuracy results were obtained under controlled conditions or in actual field environments — a distinction that is decisive when evaluating the practical value of existing systems.

### 2.1.1 Project Overview

Real-time maize disease detection refers to the automated classification of disease from leaf images at the point of capture, delivering a result to the user within seconds rather than requiring laboratory analysis or expert consultation. The agricultural value of this capability depends on two things: the classification must be accurate enough to be trusted, and it must be fast enough to be acted upon before disease spreads further.

Convolutional Neural Networks are the dominant technical approach. Their architecture is well suited to this task: early convolutional layers detect low-level visual primitives such as edges and colour gradients; intermediate layers combine these into texture patterns; deep layers assemble texture patterns into representations of specific lesion morphologies. The network learns these representations from labelled examples rather than from hand-programmed rules, which means it can generalise to disease presentations that vary across lighting conditions, leaf orientations, and camera hardware — provided the training data reflects that variability.

Where image classification alone falls short is contextual reasoning. A leaf image encodes current visual symptoms. It carries nothing about the crop variety planted, the stage of the growing season, the agrochemicals already applied, or the disease history of the field. All of these factors influence both the most probable diagnosis and the most appropriate treatment. Integrating them requires a second data channel, and OCR-based metadata extraction from seed label photographs provides a practical mechanism for collecting that channel at field level without imposing meaningful additional burden on the farmer.

MaizeGuard combines real-time CNN classification with on-device OCR extraction in a fully offline Flutter mobile application. The remainder of this chapter reviews the research that informed that design.

## 2.2 Maize Diseases and Their Economic Impact

### 2.2.1 Common Maize Diseases in Nigeria

Maize production across Nigeria faces a recurring set of fungal and viral pathogens whose distribution reflects the country's agro-ecological diversity.

**Northern Corn Leaf Blight (NCLB)** is caused by *Exserohilum turcicum* and is characterised by elongated, tan or grey-green lesions ranging from 2.5 to 15 cm in length. The pathogen spreads by wind-dispersed conidia and develops most aggressively under 18–27°C with sustained leaf wetness — conditions common during Nigeria's main rainy season. Yield losses in susceptible varieties under moderate to heavy infection regularly reach 50% (Badu-Apraku & Fakorede, 2017; Mahlein, 2016). NCLB is prevalent across the middle belt and humid southern states.

**Common Rust** (*Puccinia sorghi*) produces circular to elongated, brick-red to cinnamon-brown uredia that rupture the leaf epidermis as pustules enlarge. It develops rapidly between 20–28°C and can appear at any crop growth stage. Under early infection in susceptible hybrids, rust severely reduces grain weight, though it is generally less destructive than NCLB or GLS at typical Nigerian field-level infection densities (Patil & Kumar, 2020).

**Gray Leaf Spot (GLS)**, caused by *Cercospora zeae-maydis*, produces narrow, rectangular lesions with parallel margins running between leaf veins, turning grey as they mature, often with a yellow halo. It thrives in humid, high-rainfall environments and can cause complete canopy senescence in heavily infected fields. Documented yield losses range from 30–40% in severe outbreak years (Mahlein, 2016; Zhang et al., 2019). GLS is a persistent problem in the southern states and high-humidity zones of the middle belt.

**Maize Streak Virus (MSV)**, transmitted by leafhopper species (*Cicadulina* spp.), produces pale yellow streaks along leaf veins and causes stunted growth and tasselling failure in young plants. It is more prevalent in the drier northern savannas and can cause 20–50% yield loss in susceptible varieties (Martin & Shepherd, 2009). Unlike the fungal diseases, MSV requires insect vector management rather than fungicide application, making it a distinct diagnostic category.

The geographic distribution matters for system design. The present study focuses on the three fungal diseases that constitute the primary agronomic threat represented in the PlantVillage training dataset — NCLB, Common Rust, and GLS — alongside a Healthy class. This four-class scope covers the classification categories most relevant to the planting systems and agro-ecological zones that dominate Nigerian maize production.

### 2.2.2 Traditional Disease Detection Methods

Detection in most Nigerian farming communities depends on farmer observation and, intermittently, on agricultural extension officer visits.

Farmer self-diagnosis relies on accumulated experience acquired over many growing seasons. It produces reasonable results for advanced infections where symptoms are unambiguous, but it is unreliable for early-stage detection and for distinguishing diseases with similar early symptom profiles. The visual overlap between early NCLB and GLS lesions is well-documented as a source of diagnostic error even among trained observers (Mahlein, 2016). A farmer who misidentifies NCLB as GLS and applies the wrong fungicide achieves neither disease control nor cost efficiency.

Extension officers provide a higher-quality diagnostic service but are structurally unable to meet demand. Nigeria's agricultural extension system operates at a farmer-to-officer ratio far exceeding the internationally recommended 400:1 target. In many farming communities, the effective ratio approaches 3,000:1, and the geographic distances involved mean that even an experienced officer cannot reach individual farms within the early-intervention window (Aker, 2011).

The practical result of these limitations is that diseases are identified late, misidentified, or not identified at all until damage has already accumulated.

### 2.2.3 Economic Impact of Maize Diseases

Yield losses attributed to NCLB, Common Rust, and GLS translate directly into income losses for households that depend on maize sales. The FAO estimates that plant diseases across all crops cause global food production losses valued at hundreds of billions of dollars annually, with sub-Saharan Africa disproportionately affected (FAO, 2021). For Nigerian maize specifically, the combination of 20–40% average annual yield loss with market price volatility imposes severe economic strain on affected smallholder households.

Beyond direct yield losses, late detection forces reactive pesticide expenditure at higher dosage rates. A farmer who does not detect disease until it has visibly spread across the canopy requires multiple high-dose applications to achieve the control that a single early-stage application would have achieved at lower cost and with lower environmental loading (Badu-Apraku & Fakorede, 2017).

## 2.3 Review of Technical Concepts

**Deep Learning for Image-Based Disease Detection.** CNNs process images through hierarchical feature extraction that progresses from simple edge detectors to complex disease-specific pattern recognisers. The architecture is well-suited to plant disease classification because disease symptoms manifest as specific combinations of colour, texture, and shape features that CNNs are designed to capture. Reviews confirm that CNN-based systems achieve high accuracy on plant disease benchmarks, but performance on field-collected images is substantially lower than on controlled datasets (Upadhyay et al., 2025; Raju & Thasleema, 2025).

**Transfer Learning.** Training a large CNN from random initialisation on a small agricultural dataset produces overfitting — the model memorises training examples rather than learning generalisable disease representations. Transfer learning addresses this by initialising the convolutional backbone from weights learned on ImageNet-1K, then fine-tuning on the target agricultural data. The pretrained weights provide a rich general-purpose feature initialisation; fine-tuning adapts higher-level representations to the specific visual characteristics of maize disease lesions. This strategy consistently improves accuracy on small agricultural datasets compared to training from scratch (Too et al., 2019; Ferentinos, 2018).

**Optical Character Recognition for Agricultural Metadata.** OCR converts text in images to machine-readable form. In agricultural applications, it extracts information from seed labels, fertiliser bags, and handwritten field records. When integrated with image-based classification, the extracted metadata allows the system to reason about contextual factors invisible from leaf images alone (Katharria et al., 2025). The principal challenge is that agricultural documents are frequently photographed under suboptimal conditions — glare from laminated surfaces, partial occlusion, oblique angles — that degrade recognition accuracy relative to clean document scans (Sharma et al., 2024).

**Multimodal Feature Fusion.** Combining CNN visual features with structured metadata from a second source is called feature fusion. In late-fusion architectures, each modality is processed independently to a compact feature vector and the vectors are concatenated before the final classification layer. This approach is robust to missing metadata: when OCR returns no result, the metadata vector defaults to zeros and the visual branch carries full classification weight. Late fusion consistently outperforms early fusion in multi-source agricultural classification tasks because it allows each modality to be independently normalised before combination (Ibrahim et al., 2025).

**Edge Deployment and Model Quantisation.** Post-training quantisation reduces weight precision from 32-bit float to 8-bit integer (INT8), cutting model size approximately fourfold and inference latency twofold to fourfold on ARM processors with NEON SIMD support, with accuracy degradation typically below one percentage point. TFLite provides the runtime for this compressed inference on Android and iOS without a Python environment or network connection (Junaidi et al., 2025; Ahmad & Nabi, 2021).

**Real-Time Processing Requirements.** For disease detection to be usable in a field context, inference time from image capture to displayed result must be short enough that a farmer waits for it. Studies indicate that latency above two to three seconds measurably reduces user acceptance in mobile agricultural applications (Ibrahim et al., 2025). This constraint drives model selection toward architectures that achieve competitive accuracy with fewer parameters rather than maximising accuracy regardless of computational cost.

**Field Validation.** A model evaluated only on held-out images from the same controlled dataset used for training has not been validated for field deployment. Field validation requires testing under real operating conditions: variable natural lighting, actual farm backgrounds, images captured by farmers rather than researchers (Hashem et al., 2024; Hati & Singh, 2021).

## 2.4 Review of Articles

### 2.4.1 Key Findings from Thirty Articles on AI in Agriculture

**High accuracy is achievable but context-dependent.** CNN-based and hybrid architectures including YOLOv8, ResNet variants, and Vision Transformers consistently report test accuracy exceeding 95% in recent publications (Upadhyay et al., 2025; Jiang et al., 2025; Ibrahim et al., 2025). Multispectral and hyperspectral imaging enables detection before visual symptoms appear. These results are produced under controlled conditions, and the same papers acknowledge that field performance is lower without always quantifying the gap.

**Automation reduces labour dependency.** AI-driven crop monitoring replaces manual scouting for disease signs, reducing labour hours and the inconsistency introduced by varying human expertise (Mohyuddin et al., 2024; Aziz et al., 2025). UAV-based surveys extend this automation to field-scale monitoring, enabling disease distribution mapping that is practically impossible through manual means alone (Abdel-Basset et al., 2024; Mesias-Ruiz et al., 2023).

**Dataset quality is the primary technical constraint.** Across all thirty reviewed studies, training data quality and diversity constitute the most commonly cited bottleneck. Most datasets are small, regionally biased, or captured under controlled conditions. Researchers address this through transfer learning, data augmentation, and few-shot learning, but the underlying limitations remain (Ngongoma et al., 2023; Mohyuddin et al., 2024; Upadhyay et al., 2025).

**CNN architectures remain dominant; transformer models are emerging.** EfficientNet, ResNet, and MobileNet variants dominate the plant disease classification literature for their proven accuracy-to-parameter ratios. Vision Transformers are gaining traction for capturing long-range spatial dependencies but require substantially more data and computation (Upadhyay et al., 2025; Jiang et al., 2025).

**Multimodal integration improves ambiguous-case accuracy.** Fusing RGB images with thermal, hyperspectral, or structured metadata improves diagnostic accuracy over single-modality systems. The value is greatest when the additional modality resolves visually ambiguous early-stage cases — for example, variety-specific susceptibility data disambiguating similar lesion morphologies between NCLB and GLS (Hati & Singh, 2021; Upadhyay et al., 2025).

**Edge and IoT deployment is increasingly prioritised.** Recent work demonstrates successful deployment on Raspberry Pi, Jetson Nano, and mid-range Android devices using lightweight models and TFLite conversion. The practical barrier to offline operation is now model optimisation rather than hardware availability (Ibrahim et al., 2025; Abdel-Basset et al., 2024).

**Field performance consistently lags laboratory benchmarks.** Variable sunlight, overlapping leaves, camera autofocus variation, and soil contamination on leaf surfaces each reduce accuracy below controlled-environment results (Lebrini & Gotor, 2024; Ngongoma et al., 2023). This is the single most important unresolved challenge in deploying plant disease AI at scale.

**Model interpretability is an emerging concern.** Black-box predictions reduce farmer trust and limit adoption. Gradient-weighted class activation mapping and attention visualisation are beginning to appear in agricultural classification work but are not yet standard practice (Upadhyay et al., 2025; Lebrini & Gotor, 2024).

### 2.4.2 Summary of Reviewed Articles

| Year | Author(s) | Title | Problem Addressed | Approach | Key Results | Limitations |
|------|-----------|-------|------------------|----------|-------------|-------------|
| 2025 | Upadhyay et al. | Deep Learning and Computer Vision in Plant Disease Detection: A Comprehensive Review | Yield loss from plant disease | Review of DL and CV methods; 278 papers | High accuracy in early detection | Needs real-farm validation |
| 2024 | Mohyuddin et al. | Evaluation of ML Approaches for Precision Farming | Poor detection causing crop loss | Review of ML and AI techniques | ML effective for detection and resource optimisation | Empirical validation across diverse conditions needed |
| 2024 | Rani et al. | Role of AI in Agriculture: Analysis with Focus on Plant Diseases | Manual detection inefficiency | Survey of AI applications | AI improves detection efficiency | Larger, more diverse datasets needed |
| 2022 | Nkwocha et al. | End-to-End Digital Framework for Precision Crop Disease Diagnosis | Slow and unreliable traditional methods | Review of sensors and integration | Integrative framework with edge computing | Real-world testing required; economic feasibility uncertain |
| 2025 | Katharria et al. | Information Fusion in Smart Agriculture: ML Applications | Lack of multi-source data integration | Bibliometric review and analysis | ML applications growing | Ecosystem-specific fusion needed |
| 2024 | Batool Anwar Omer et al. | Toward Precision Agriculture: Integrating ML for Smart Farming | Inefficient farming and resource waste | Five-stage ML pipeline | 99%+ accuracy in rice seedling classification | Real-time adaptation to varied conditions needed |
| 2024 | Mohamed Abdel-Basset et al. | Artificial Intelligence and IoT in Smart Farming | Resource waste and inefficiency | Review of AI and IoT | Increased yield; reduced cost | Data security and high investment costs |
| 2022 | Normaisharah Mamat et al. | Deep Learning in Agriculture: Image Annotation and Applications | Inefficient image annotation | Review of DL architectures | DL improves annotation accuracy and decision-making | Dependent on large datasets |
| 2025 | Apri Junaidi et al. | Advancements in DL and Edge Computing for Rice Disease Detection | Inefficient traditional detection | Systematic review of DL and edge computing | YOLOv7 at 99% accuracy; real-time edge monitoring | Lightweight model diversity needed |
| 2025 | Amin S. Ibrahim et al. | Integration of AI and IoT for Smart Agriculture | Water, pest, and disease challenges | AI-IoT architecture with ResNet50 | 99.8% accuracy; real-time monitoring | Dataset diversity required |
| 2025 | Aashu Katharria et al. | Analysis of ML and Data Fusion in Smart Agriculture | Food demand, climate, resource scarcity | Survey and bibliometric analysis | ML and fusion improves decision-making | Model interpretability challenges |
| 2024 | Himanshu Jindal et al. | Smart Agriculture Crop Disease Detection using DL | Ineffective traditional detection | CNN with images and environmental data | Early detection; real-time alerts | Dataset coverage and robustness issues |
| 2025 | Danishta Aziz et al. | Remote Sensing and AI in Sustainable Pest Management | Pest detection delays and environmental harm | Remote sensing with AI analysis | Improved precision; reduced pesticide use | Data quality and integration challenges |
| 2021 | Ahmad Almadhor et al. | AI-Driven Framework for Guava Plant Disease Recognition | Difficulty diagnosing guava diseases | High-resolution imaging and ML classifiers | 99% accuracy for 4 diseases | Dataset diversity limited |
| 2023 | Gustavo Mesías-Ruiz et al. | Precision Crop Protection Towards Agriculture 5.0 via ML | Sustainable and efficient crop protection | Review of ML and emerging tech; bibliometric analysis | 39 technologies identified; ML adoption rising | Data heterogeneity and interpretability challenges |
| 2023 | Mbulelo Ngongoma et al. | A Review of Plant Disease Detection Systems | Traditional detection inefficiencies | Review of ML detection models | ML models promising; real-time gap remains | Integration and real-time capabilities limited |
| 2024 | Youssef Lebrini & Alicia Gotor | Crop Disease Detection Using AI and Remote Sensing | Effective disease management and chemical overuse | Review of AI and remote sensing | Leaf-scale detection improved | Scalability and field condition challenges |
| 2024 | Insha Zahoor et al. | AI in the Food Industry: Enhancing Quality and Safety | Inefficiencies and safety concerns | Review of AI, ML, DL in food production | AI improves quality; reduces waste | Data privacy and regulatory issues |
| 2025 | Sandipamu Raju & Thasleema | Advancements in Automated Plant Disease Detection | Detection across imaging technologies | Review of imaging and DL | Wide applicability confirmed | Field testing needed |
| 2023 | Alexander Uzhinskiy | Advanced Technologies and AI in Agriculture | Food production and labour shortages | Mini-review of IoT, UAVs, AI | Technology improves efficiency and productivity | Adoption barriers persist |
| 2024 | Rohan Kumar Raman et al. | AI and ML Applications in Agriculture | Food demand and climate impacts | Systematic review of AI and ML | Optimises resources; improves productivity | Smallholder adoption costs limit impact |
| 2024 | Abbas Jafar et al. | Revolutionizing Agriculture with AI: Plant Disease Detection | Economic losses from disease | Review of ML and DL detection methods | High accuracy; automation improves management | Larger diverse datasets needed |
| 2024 | Hashem, Joudeh & Zamil | Smart Farming for Pest and Disease Detection | Pest and disease detection challenges | AI-driven smart farming review | Improved detection and management | Integration costs |
| 2021 | Ahmad and Nabi | Agriculture 5.0: AI, IoT and Machine Learning | Technology adoption in agriculture | Review of AI and IoT techniques | Broad framework for precision agriculture | High investment needed |
| 2023 | Orchi, Sadik & Khaldoun | AI and IoT for Crop Disease Detection | Limitations in current detection | Contemporary survey | Comprehensive overview of methods | Standardisation needed |
| 2025 | Basu & Narayan | ML in Transforming Agricultural Practices | Crop yield and disease challenges | Review of ML applications | ML transforms precision agriculture | Accessibility and cost concerns |
| 2024 | Jalal Uddin Akbar et al. | DL Assisted CV for Smart Greenhouse Agriculture | Traditional farming inefficiency | Review of DL and CV in greenhouses | Improved monitoring and disease detection | Small datasets limit generalisability |
| 2024 | Binoy Sasmal et al. | Advancements and Challenges in Agriculture Using ML and IoT | Increasing agricultural productivity | Review of ML and IoT applications | ML and IoT improve water, soil, disease detection | High costs and technology barriers |
| 2025 | Aria Dolatabadian et al. | Image-based Crop Disease Detection Using ML | Effective disease management | Imaging and ML for detection | Rapid and accurate detection; adapts to environment | Accessibility for smallholder farmers |
| 2025 | Sandipamu Raahalya & Saravanan Raj | Leveraging AI for Agricultural Advancement | Need to boost agricultural productivity | Review of AI in crop management | AI improves efficiency and decision-making | Uneven AI access; scalable solutions needed |

## 2.5 Current Challenges Identified in Literature

**Limited and imbalanced datasets.** The PlantVillage repository underpins a large proportion of the plant disease classification literature but was collected under controlled conditions. It does not represent the diversity of image quality, lighting, and background complexity encountered in field use. Within the maize subset used in this study, class sizes are unbalanced — GLS has 574 training images compared to 1,306 for Common Rust — which biases models toward better performance on majority classes unless explicitly counteracted through class weighting or oversampling (Basu & Narayan, 2025; Junaidi et al., 2025).

**Field-condition variability.** Real farm images differ from benchmark images in lighting intensity and direction, leaf position and occlusion, background complexity, and image resolution. Models trained exclusively on clean benchmark images learn representations calibrated to that distribution and may not generalise to field conditions. This is not theoretical: it is the most commonly cited real-world deployment failure across the reviewed literature (Ahmad & Nabi, 2021; Hati & Singh, 2021; Lebrini & Gotor, 2024).

**OCR reliability under field conditions.** OCR performs well on high-resolution, flat, well-lit document scans. Seed labels photographed in the field may have laminated surfaces causing glare, be printed in small fonts, suffer partial occlusion from soil or physical damage, or be captured at an angle. Each of these conditions reduces character recognition accuracy, and errors in OCR output propagate directly to errors in extracted metadata (Sharma et al., 2024; Katharria et al., 2025).

**Computational constraints of edge deployment.** INT8 quantisation achieves the size and latency reduction needed for smartphone deployment, but it is not lossless. The calibration dataset used during quantisation influences how well the quantised model preserves accuracy on out-of-distribution inputs. GPU delegate availability also varies across Android device models, introducing latency variation that the application layer must handle gracefully (Ibrahim et al., 2025; Junaidi et al., 2025).

**Absence of standardised evaluation.** Studies use different datasets, train-test splits, augmentation strategies, and evaluation metrics. This makes direct accuracy comparison across papers unreliable: a system reporting 99.5% accuracy on a binary task with balanced data is not comparable to one reporting 90% on a four-class imbalanced dataset with field images (Orchi et al., 2021; Abdel-Basset et al., 2024).

**Practical deployment gaps.** Researchers developing plant disease AI systems rarely involve farmers in the design process and rarely test deployment in representative operating environments. Systems that appear complete in a laboratory consistently reveal usability problems when tested with actual users under field conditions (Ahmad & Nabi, 2021; Hashem et al., 2024).

## 2.6 Research Gap

The literature establishes that CNN-based plant disease classification achieves high accuracy on clean benchmark datasets and that edge deployment of compressed models on mobile devices is technically feasible. It does not establish that these capabilities have been successfully combined with contextual metadata integration, offline operation, and Nigerian-market-specific recommendations in a single system designed specifically for maize disease detection in sub-Saharan Africa.

Three specific gaps are identified.

First, no published system for maize disease classification combines edge deployment, offline operation, OCR-based metadata extraction, and field-validated performance in a single integrated mobile application. Systems addressing one or two of these requirements consistently leave others unaddressed. Section 4.7 maps this gap explicitly against the published literature in a comparative feature table.

Second, regional relevance is absent from most existing work. The majority of high-performing plant disease systems use datasets, product catalogues, and seasonal calendars derived from North American or European agricultural contexts. Treatment recommendations referencing products and rates appropriate to Nigerian conditions require deliberate, localised design effort that generic systems do not provide.

Third, the contextual dimension of disease diagnosis is systematically neglected. Visual symptoms alone are insufficient to distinguish between diseases that share early-stage presentations. Seed variety metadata provides a structured prior that allows the model to resolve ambiguous cases more reliably, but this integration has not been demonstrated in a deployed system for maize disease detection.

MaizeGuard was designed to address all three gaps.

## 2.7 Conceptual Positioning of the Proposed System

MaizeGuard occupies the intersection of four capabilities that existing systems have addressed individually but have not previously combined for maize disease detection in Nigerian smallholder farming:

1. **On-device CNN inference** — eliminating the internet dependency that makes cloud-based systems unreliable in rural environments.
2. **OCR-based metadata extraction** — providing a low-friction mechanism for capturing contextual information that improves both diagnostic accuracy and recommendation specificity.
3. **Locally grounded recommendations** — translating a classification result into actionable treatment advice referencing products available in Nigerian agro-dealer markets and accounting for Nigerian seasonal conditions.
4. **Geospatial scan history** — aggregating GPS-tagged scan records to support farm-level and extension-level disease distribution monitoring.

The system does not position itself as a replacement for agricultural extension services. It is a tool that extends the reach and timeliness of those services, giving farmers access to a reliable diagnostic capability that reduces the cost of waiting for an expert.

## 2.8 Future Trends

The literature points toward several developments likely to shape the next generation of agricultural disease detection systems.

Real-time edge inference on progressively smaller, more capable device hardware is making it feasible to run larger, more accurate models offline without network dependency. As ARM processors include wider SIMD units and dedicated neural processing units, the accuracy-latency trade-off that currently requires significant model compression will ease.

Federated learning — training model updates on farm devices without centralising raw data — offers a path toward models that improve from real-world deployment experience without requiring farmers to share sensitive farm data with a central server. This is particularly valuable for closing the domain gap between PlantVillage and Nigerian field conditions through continuous model improvement.

Multi-label classification, which identifies multiple simultaneous diseases on a single plant, reflects the agronomic reality that maize fields frequently present with co-occurring infections. Current single-label architectures cannot capture co-occurrence, and extending to multi-label output is a direct next step for systems that have demonstrated reliable single-disease performance.

Explainable AI techniques — specifically gradient-weighted class activation mapping — are beginning to appear in agricultural classification applications. Providing a visual overlay showing which leaf regions drove the prediction would substantially increase farmer trust in automated diagnoses.

Voice interfaces in local languages — Hausa, Yoruba, Igbo — have the potential to extend the reach of agricultural AI systems to the significant proportion of Nigerian smallholder farmers with low English literacy. MaizeGuard has delivered this capability in the present version: the application implements a four-language display system (English, Yoruba, Igbo, Hausa) through which AI advisory responses are generated directly in the farmer's chosen language, on-device recommendation text can be translated on request, and diagnosis results are read aloud using authentic Nigerian-language voices via the YarnGPT API — Idera (Yoruba), Chinenye (Igbo), and Zainab (Hausa) — with English handled by the device-native text-to-speech engine. This positions MaizeGuard as an early concrete implementation of a capability that the wider literature has so far treated as a future aspiration. The principal open questions are expanding coverage to additional languages, improving prosody and medical/agronomic vocabulary in synthesised speech, and adding voice-based input for farmers who find screen interaction challenging.
