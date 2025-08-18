import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '₹500 Note Authenticity Detector',
      theme: ThemeData(
        primarySwatch: Colors.green,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          elevation: 2,
        ),
      ),
      home: const DetectScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class DetectScreen extends StatefulWidget {
  const DetectScreen({Key? key}) : super(key: key);

  @override
  State<DetectScreen> createState() => _DetectScreenState();
}

class _DetectScreenState extends State<DetectScreen> {
  final ImagePicker _picker = ImagePicker();
  Interpreter? _interpreter;
  File? _image;
  String? _result;
  bool _isLoading = false;
  bool _isModelLoaded = false;
  Color _resultColor = Colors.black;

  // Model input dimensions (adjust based on your trained model)
  static const int inputSize = 224;

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  @override
  void dispose() {
    _interpreter?.close();
    super.dispose();
  }

  Future<void> _loadModel() async {
    try {
      setState(() {
        _isLoading = true;
        _result = 'Loading AI model...';
      });
      
      _interpreter = await Interpreter.fromAsset('model.tflite');
      
      // Print model input/output details for debugging
      print('Model loaded successfully');
      print('Input shape: ${_interpreter!.getInputTensor(0).shape}');
      print('Output shape: ${_interpreter!.getOutputTensor(0).shape}');
      
      setState(() {
        _isModelLoaded = true;
        _isLoading = false;
        _result = 'Model loaded successfully! Ready to detect ₹500 notes.';
        _resultColor = Colors.green;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _result = 'Error loading model: $e';
        _resultColor = Colors.red;
      });
      print('Model loading error: $e');
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    if (!_isModelLoaded) {
      _showSnackBar('Please wait for the model to load first!');
      return;
    }

    try {
      // Request permissions
      if (source == ImageSource.camera) {
        final cameraStatus = await Permission.camera.request();
        if (!cameraStatus.isGranted) {
          _showSnackBar('Camera permission is required to take photos');
          return;
        }
      }

      final pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      
      if (pickedFile != null) {
        setState(() {
          _image = File(pickedFile.path);
          _result = 'Analyzing the ₹500 note...';
          _isLoading = true;
          _resultColor = Colors.orange;
        });
        
        await _runModelOnImage(_image!);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _result = 'Error picking image: $e';
        _resultColor = Colors.red;
      });
    }
  }

  Future<void> _runModelOnImage(File image) async {
    if (_interpreter == null) {
      setState(() {
        _result = 'Model not loaded properly';
        _isLoading = false;
        _resultColor = Colors.red;
      });
      return;
    }

    try {
      // Read and decode image
      final imageBytes = await image.readAsBytes();
      final decodedImage = img.decodeImage(imageBytes);
      
      if (decodedImage == null) {
        throw Exception('Failed to decode image');
      }

      // Resize image to model's expected input size
      final resizedImage = img.copyResize(
        decodedImage,
        width: inputSize,
        height: inputSize,
      );

      // Convert image to Float32List normalized to [0,1]
      var input = _imageToByteListFloat32(resizedImage, inputSize);
      
      // Prepare output buffer - adjust based on your model's output
      var output = List.filled(1 * 2, 0.0).reshape([1, 2]);
      
      // Run inference
      _interpreter!.run(input, output);

      // Process results
      double realScore = output[0][0].toDouble();
      double fakeScore = output[0][1].toDouble();

      // Apply softmax to get probabilities
      double realProb = _softmax(realScore, fakeScore, true);
      double fakeProb = _softmax(realScore, fakeScore, false);

      setState(() {
        _isLoading = false;
        if (realProb > fakeProb) {
          _result = '✅ AUTHENTIC ₹500 Note\nConfidence: ${(realProb * 100).toStringAsFixed(1)}%';
          _resultColor = Colors.green;
        } else {
          _result = '❌ SUSPECTED FAKE ₹500 Note\nConfidence: ${(fakeProb * 100).toStringAsFixed(1)}%\n⚠️ Please verify with experts';
          _resultColor = Colors.red;
        }
      });

    } catch (e) {
      setState(() {
        _isLoading = false;
        _result = 'Error analyzing image: $e';
        _resultColor = Colors.red;
      });
      print('Inference error: $e');
    }
  }

  // Helper method to convert image to normalized Float32List
  Float32List _imageToByteListFloat32(img.Image image, int inputSize) {
    var convertedBytes = Float32List(1 * inputSize * inputSize * 3);
    var buffer = Float32List.view(convertedBytes.buffer);
    int pixelIndex = 0;
    
    for (int y = 0; y < inputSize; y++) {
      for (int x = 0; x < inputSize; x++) {
        var pixel = image.getPixel(x, y);
        // Normalize pixel values to [0,1]
        buffer[pixelIndex++] = (pixel.r / 255.0);
        buffer[pixelIndex++] = (pixel.g / 255.0);
        buffer[pixelIndex++] = (pixel.b / 255.0);
      }
    }
    return convertedBytes;
  }

  // Apply softmax function for probability calculation
  double _softmax(double realScore, double fakeScore, bool isReal) {
    double expReal = math.exp(realScore);
    double expFake = math.exp(fakeScore);
    double sum = expReal + expFake;
    return isReal ? (expReal / sum) : (expFake / sum);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('₹500 Note Authenticity Detector'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Header section
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Icon(Icons.security, size: 48, color: Colors.green),
                    SizedBox(height: 8),
                    Text(
                      'AI-Powered Currency Authentication',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Specialized for ₹500 denomination notes',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Image display section
            Container(
              width: double.infinity,
              height: 300,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300, width: 2),
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey.shade50,
              ),
              child: _image != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(
                        _image!,
                        width: double.infinity,
                        height: 300,
                        fit: BoxFit.contain,
                      ),
                    )
                  : const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.camera_alt,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No image selected',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Take a photo or select from gallery',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
            ),
            
            const SizedBox(height: 20),
            
            // Result section
            if (_result != null)
              Card(
                elevation: 4,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      if (_isLoading)
                        const Column(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 12),
                          ],
                        ),
                      Text(
                        _result!,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _resultColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            
            const SizedBox(height: 30),
            
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Scan Note'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Gallery'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Tips section
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📝 Tips for Better Detection:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text('• Ensure good lighting conditions'),
                    Text('• Keep the note flat and fully visible'),
                    Text('• Avoid shadows and reflections'),
                    Text('• Focus on the front side of the note'),
                    SizedBox(height: 8),
                    Text(
                      '⚠️ This is an AI-based detection tool. For official verification, please consult banking authorities.',
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
