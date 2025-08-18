# ₹500 Note Authenticity Detector

A Flutter mobile application that uses AI/ML to detect fake ₹500 denomination currency notes through image analysis.

## Features

- **AI-Powered Detection**: Uses TensorFlow Lite for on-device machine learning inference
- **Dual Input Methods**: 
  - Camera scan for real-time detection
  - Gallery upload for existing images
- **User-Friendly Interface**: Clean, intuitive design with clear results
- **Real-time Analysis**: Fast processing with confidence scores
- **Privacy-Focused**: All processing happens on-device

## How to Use

1. **Launch the app** - The AI model will automatically load
2. **Choose input method**:
   - **Scan Note**: Use camera to capture the currency note
   - **Gallery**: Select an existing image from your device
3. **Position the note**: Ensure the ₹500 note is well-lit and fully visible
4. **Get results**: The app will display whether the note is authentic or suspected fake with confidence percentage

## Tips for Best Results

- Ensure good lighting conditions
- Keep the note flat and fully visible
- Avoid shadows and reflections
- Focus on the front side of the note
- Hold the camera steady for clear images

## Technical Stack

- **Framework**: Flutter
- **ML Framework**: TensorFlow Lite
- **Language**: Dart
- **Image Processing**: Image package
- **Permissions**: Permission Handler

## Model Information

The app uses a trained TensorFlow Lite model specifically designed for ₹500 denomination note authentication. The model processes images at 224x224 resolution and outputs confidence scores for authentic vs fake classification.

## Installation

1. Clone the repository
2. Run `flutter pub get` to install dependencies
3. Ensure you have the `model.tflite` file in the `assets/` directory
4. Run `flutter run` to launch the app

## Important Disclaimer

⚠️ **This is an AI-based detection tool for educational and preliminary screening purposes only. For official verification of currency authenticity, please consult with banking authorities or financial institutions.**

## Requirements

- Flutter SDK >= 2.17.0
- Android: API level 21+ (Android 5.0+)
- iOS: iOS 11.0+
- Camera and storage permissions

## Model Training

The TensorFlow Lite model should be trained on a dataset of authentic and fake ₹500 notes with proper data augmentation and validation. The model architecture should be optimized for mobile deployment.

## Support

For issues or questions, please refer to the Flutter documentation or create an issue in the repository.
