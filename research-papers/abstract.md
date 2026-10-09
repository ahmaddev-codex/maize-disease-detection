# Abstract

## MaizeGuard: Real-Time Maize Disease Detection for Nigerian Smallholder Farmers Using Deep Learning, Multimodal Fusion, and Offline-First Mobile AI

---

Maize is Nigeria's most widely cultivated cereal, yet Northern Corn Leaf Blight (*Exserohilum turcicum*), Common Rust (*Puccinia sorghi*) and Gray Leaf Spot (*Cercospora zeae-maydis*) are associated with yield losses of 20–40%. These losses stem less from a lack of effective treatments than from late or inaccurate diagnosis: extension coverage is sparse, and published detection models that perform well on laboratory images tend to degrade under field conditions. This study presents MaizeGuard, an offline-first mobile system for in-field diagnosis of these diseases.

An EfficientNetB3 classifier was trained on 4,186 PlantVillage maize images (four classes, 70/15/15 split) using two-stage transfer learning with class weighting to offset imbalance. After conversion to TensorFlow Lite, the FP16 model (23.4 MB) achieved 97.61% accuracy on the 628-image held-out test set and the INT8 model (13.5 MB) 96.82%; FP16 was therefore adopted as the primary on-device model. Per-class F1 ranged from 1.00 for healthy leaves to 0.94 for Gray Leaf Spot (Rust 0.99, NCLB 0.96). A late-fusion branch incorporating seed-label metadata yielded no gain beyond noise (+0.16 percentage points) in a controlled ablation; because no dataset pairs leaf images with the variety of the same plant, this metadata was synthetic.

The classifier is deployed in a Flutter application that performs diagnosis, rule-based treatment guidance, GPS-tagged scan history and disease mapping without network access. Predictions below 0.60 confidence prompt a retake and withhold chemical recommendations. When a connection and a user-supplied API key are available, the application generates extended advice through a cloud language model and synthesises speech in Yoruba, Igbo and Hausa, and it always indicates whether the displayed advice came from the model or from the built-in rules. A UAV module applies the same classifier to drone orthomosaics to produce disease heatmaps, which are offered as scouting aids only, since the model has not been evaluated on aerial imagery.

---

**Keywords:** maize disease detection, EfficientNetB3, TensorFlow Lite, edge inference, multimodal fusion, offline-first mobile AI, multilingual advisory, Nigerian smallholder agriculture
