# A-MULTIMODAL-SYSTEM-FOR-AUTOMATED-CORN-DISEASE-DETECTION-AND-FARMER-CENTRIC-KNOWLEDGE-SHARING
## Project Overview

Agriculture plays a vital role in ensuring food security and economic sustainability, particularly in developing countries such as Sri Lanka. Corn (maize) is one of the most widely cultivated crops; however, farmers frequently encounter challenges due to plant diseases, pest infestations, nutrient deficiencies, and fluctuating environmental conditions. In many cases, early identification of these issues relies on manual inspection or expert consultation, which can be time-consuming, subjective, and inaccessible to small-scale farmers.

Existing technological solutions often address these problems in isolation, focusing solely on disease detection, pest identification, or yield estimation. This fragmented approach limits the effectiveness of decision-making, as crop health is influenced by multiple interconnected factors. Furthermore, many available systems lack farmer-centric design and practical deployment through accessible platforms such as mobile applications.

This research proposes **a multimodal system for automated corn disease detection and farmer-centric knowledge sharing**, integrating image-based analysis and field-level environmental data to provide a comprehensive agricultural decision-support solution. The term *multimodal* refers to the combined use of visual data (corn leaf images) and structured numerical data (environmental and agronomic parameters) to improve prediction accuracy and system reliability.

The proposed system consists of four core components:
- **Corn leaf disease detection**, utilizing convolutional neural networks to classify common diseases such as rust, blight, and gray leaf spot from RGB images.
- **Pest detection**, enabling the identification of pest presence and pest-related damage through image-based analysis.
- **Nutrient deficiency detection**, focusing on deficiencies such as nitrogen, phosphorus, potassium, and zinc, based on visual symptom patterns in corn leaves.
- **Machine learning–based corn yield prediction**, leveraging historical yield data and environmental parameters including soil quality, rainfall, temperature, fertilizer usage, planting density, and farm size.

These components are designed to function within an integrated architecture and will be deployed through a mobile application to ensure usability and accessibility for farmers. In addition to automated detection and prediction, the system emphasizes knowledge sharing by providing interpretable outputs and actionable insights that support informed decision-making.

The primary objective of this research is to demonstrate the effectiveness of multimodal machine learning techniques in agricultural applications, with the aim of enhancing crop monitoring, reducing yield losses, and bridging the knowledge gap between agricultural experts and farming communities.

## System Architecture Diagram
<img width="3959" height="4965" alt="System_overview_diagram_updated04 1" src="https://github.com/user-attachments/assets/9168372f-a397-421c-a48a-29d1334e23eb" />

## Project Dependencies

The development and experimentation of the proposed multimodal system rely on the following technologies and tools. These dependencies support data processing, machine learning model development, system integration, and deployment planning.

### Programming Languages
- Python – primary language for machine learning model development and data analysis
- Dart – programming language used for mobile application development

### Machine Learning and Data Processing Libraries
- TensorFlow / Keras – deep learning framework for training image-based models
- Scikit-learn – preprocessing, evaluation metrics, and classical machine learning models
- NumPy – numerical computations
- Pandas – structured data handling and preprocessing
- OpenCV – image preprocessing and augmentation
- Matplotlib / Seaborn – data visualization and analysis

### Explainable Artificial Intelligence (XAI)
- SHAP (SHapley Additive exPlanations)
- LIME (Local Interpretable Model-Agnostic Explanations)
- Grad-CAM – visualization of CNN-based model decisions

### Development and Experimentation Tools
- Google Colab – model training and experimentation environment
- Jupyter Notebook – exploratory data analysis and prototyping
- Git and GitHub – version control and collaborative development

### Mobile and Deployment Technologies
- Flutter – cross-platform mobile application framework
- TensorFlow Lite (TFLite) – deployment of trained models on mobile devices
- REST APIs (planned) – communication between application components

### External Data Sources and Services (Planned)
- Weather data APIs – rainfall and temperature information
- Soil datasets / APIs – soil quality parameters
- SMS and push notification services – farmer alerts and recommendations

