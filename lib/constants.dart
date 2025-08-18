// constants.dart
class AppConstants {
  // Model configuration
  static const int modelInputSize = 224;
  static const String modelAssetPath = 'assets/model.tflite';
  
  // UI strings
  static const String appTitle = '₹500 Note Authenticity Detector';
  static const String loadingModelMessage = 'Loading AI model...';
  static const String modelLoadedMessage = 'Model loaded successfully! Ready to detect ₹500 notes.';
  static const String analysisMessage = 'Analyzing the ₹500 note...';
  
  // Result messages
  static const String authenticResult = '✅ AUTHENTIC ₹500 Note';
  static const String fakeResult = '❌ SUSPECTED FAKE ₹500 Note';
  static const String verificationWarning = '⚠️ Please verify with experts';
  
  // Error messages
  static const String modelLoadError = 'Error loading model: ';
  static const String imagePickError = 'Error picking image: ';
  static const String analysisError = 'Error analyzing image: ';
  static const String cameraPermissionError = 'Camera permission is required to take photos';
  static const String modelNotLoadedError = 'Please wait for the model to load first!';
  
  // Tips
  static const List<String> detectionTips = [
    '• Ensure good lighting conditions',
    '• Keep the note flat and fully visible',
    '• Avoid shadows and reflections',
    '• Focus on the front side of the note',
  ];
  
  static const String disclaimer = 
      '⚠️ This is an AI-based detection tool. For official verification, please consult banking authorities.';
}
