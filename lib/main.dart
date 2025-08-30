import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  bool _isModelLoading = false; // Prevent multiple loading attempts
  Color _resultColor = Colors.black;

  // Model input dimensions (adjust based on your trained model)
  static const int inputSize = 224;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // First check if the model asset exists
    bool assetExists = await _checkModelAssetExists();
    if (!assetExists) {
      setState(() {
        _result = 'Error: model.tflite not found in assets. Please check your pubspec.yaml configuration.';
        _resultColor = Colors.red;
      });
      return;
    }
    
    // Proceed with model loading
    await _loadModel();
  }

  Future<bool> _checkModelAssetExists() async {
    try {
      final ByteData data = await rootBundle.load('assets/model.tflite');
      print('Model asset found: ${data.lengthInBytes} bytes');
      return true;
    } catch (e) {
      print('Model asset not found: $e');
      return false;
    }
  }

  @override
  void dispose() {
    // Ensure proper cleanup of resources
    try {
      _interpreter?.close();
      _interpreter = null;
    } catch (e) {
      print('Error disposing interpreter: $e');
    }
    super.dispose();
  }

  Future<void> _loadModel() async {
    // Prevent multiple simultaneous loading attempts
    if (_isModelLoading) {
      print('Model loading already in progress');
      return;
    }

    try {
      setState(() {
        _isModelLoading = true;
        _isLoading = true;
        _result = 'Loading AI model...';
      });
      
      // Dispose existing interpreter if any
      if (_interpreter != null) {
        try {
          _interpreter!.close();
        } catch (e) {
          print('Error closing existing interpreter: $e');
        }
        _interpreter = null;
      }
      
      // Force garbage collection to free memory
      await Future.delayed(const Duration(milliseconds: 200));
      
      // Load the model with enhanced retry mechanism
      _interpreter = await _loadModelWithEnhancedRetry();
      
      // Verify the interpreter is properly loaded
      if (_interpreter == null) {
        throw Exception('Failed to create interpreter instance');
      }
      
      // Test the interpreter with a dummy inference to ensure it's working
      await _testModelInference();
      
      // Print model input/output details for debugging
      print('Model loaded and tested successfully');
      print('Input shape: ${_interpreter!.getInputTensor(0).shape}');
      print('Output shape: ${_interpreter!.getOutputTensor(0).shape}');
      
      setState(() {
        _isModelLoaded = true;
        _isLoading = false;
        _isModelLoading = false;
        _result = 'Model loaded successfully! Ready to detect ₹500 notes.';
        _resultColor = Colors.green;
      });
    } catch (e) {
      // Clean up on failure
      try {
        _interpreter?.close();
      } catch (closeError) {
        print('Error during cleanup: $closeError');
      }
      _interpreter = null;
      
      setState(() {
        _isLoading = false;
        _isModelLoading = false;
        _isModelLoaded = false;
        _result = 'Error loading model: $e\n\nTap "Reload AI Model" to try again.';
        _resultColor = Colors.red;
      });
      print('Model loading error: $e');
    }
  }

  Future<Interpreter> _loadModelWithEnhancedRetry() async {
    const int maxRetries = 5;
    const Duration baseDelay = Duration(milliseconds: 500);
    
    Exception? lastException;
    
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print('Loading model attempt $attempt/$maxRetries');
        
        Interpreter interpreter;
        
        if (attempt == 1) {
          // Primary: Load via ByteData (most reliable approach)
          interpreter = await _loadModelFromByteData();
        } else {
          // Fallback: Standard asset loading
          interpreter = await Interpreter.fromAsset('model.tflite');
        }
        
        return interpreter;
        
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
        print('Model loading attempt $attempt failed: $e');
        
        if (attempt < maxRetries) {
          // Exponential backoff with some randomization
          final delay = Duration(
            milliseconds: baseDelay.inMilliseconds * attempt + 
                         (math.Random().nextInt(200))
          );
          await Future.delayed(delay);
          
          // Force garbage collection between attempts
          print('Attempting garbage collection...');
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }
    }
    
    throw lastException ?? Exception('Failed to load model after $maxRetries attempts');
  }

  Future<Interpreter> _loadModelFromByteData() async {
    try {
      print('Loading model using ByteData approach...');
      
      // Load the asset as ByteData
      final ByteData assetData = await rootBundle.load('assets/model.tflite');
      final Uint8List modelBytes = assetData.buffer.asUint8List();
      
      print('Model bytes loaded: ${modelBytes.length} bytes');
      
      // Create interpreter from bytes
      return await Interpreter.fromBuffer(modelBytes);
    } catch (e) {
      print('ByteData loading failed: $e');
      rethrow;
    }
  }

  Future<void> _testModelInference() async {
    if (_interpreter == null) return;
    
    try {
      // Create a dummy input tensor with the expected shape
      final inputShape = _interpreter!.getInputTensor(0).shape;
      final input = List.generate(
        inputShape.reduce((a, b) => a * b),
        (index) => 0.5, // Neutral values
      ).reshape(inputShape);
      
      final outputShape = _interpreter!.getOutputTensor(0).shape;
      final output = List.filled(
        outputShape.reduce((a, b) => a * b),
        0.0,
      ).reshape(outputShape);
      
      // Run a test inference
      _interpreter!.run(input, output);
      print('Test inference successful');
    } catch (e) {
      print('Test inference failed: $e');
      throw Exception('Model failed test inference: $e');
    }
  }

  void _showRetryOption() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Model Loading Failed'),
          content: const Text(
            'The AI model failed to load. This can happen due to:\n\n'
            '• Memory limitations\n'
            '• Temporary system issues\n'
            '• Asset loading conflicts\n\n'
            'Would you like to retry loading the model?'
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _loadModel();
              },
              child: const Text('Retry'),
            ),
          ],
        );
      },
    );
  }

  // Method to force garbage collection and free memory
  Future<void> _forceMemoryCleanup() async {
    try {
      // Close interpreter if exists
      _interpreter?.close();
      _interpreter = null;
      
      // Wait for cleanup
      await Future.delayed(const Duration(milliseconds: 300));
      
      print('Memory cleanup forced');
    } catch (e) {
      print('Error during memory cleanup: $e');
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
    print('=== Starting model inference ===');
    print('Model loaded status: $_isModelLoaded');
    print('Interpreter null status: ${_interpreter == null}');
    
    if (_interpreter == null || !_isModelLoaded) {
      setState(() {
        _result = 'Model not loaded properly. Please retry loading the model.';
        _isLoading = false;
        _resultColor = Colors.red;
      });
      _showRetryOption();
      return;
    }

    Uint8List? imageBytes;
    img.Image? decodedImage;
    img.Image? resizedImage;
    
    try {
      print('Reading image file...');
      // Read and decode image
      imageBytes = await image.readAsBytes();
      print('Image bytes read: ${imageBytes.length}');
      
      decodedImage = img.decodeImage(imageBytes);
      print('Image decoded: ${decodedImage != null}');
      
      if (decodedImage == null) {
        throw Exception('Failed to decode image. Please try with a different image.');
      }

      print('Resizing image to ${inputSize}x$inputSize...');
      // Resize image to model's expected input size
      resizedImage = img.copyResize(
        decodedImage,
        width: inputSize,
        height: inputSize,
      );

      print('Converting image to input tensor...');
      // Convert image to Float32List normalized to [0,1]
      var input = _imageToByteListFloat32(resizedImage, inputSize);
      print('Input tensor created: ${input.length} elements');
      
      // Get the actual model input and output shapes
      final inputTensor = _interpreter!.getInputTensor(0);
      final outputTensor = _interpreter!.getOutputTensor(0);
      
      print('Model input shape: ${inputTensor.shape}');
      print('Model output shape: ${outputTensor.shape}');
      print('Model input type: ${inputTensor.type}');
      print('Model output type: ${outputTensor.type}');
      
      // Validate input tensor shape
      final expectedInputSize = inputTensor.shape[1] * inputTensor.shape[2] * inputTensor.shape[3];
      if (input.length != expectedInputSize) {
        throw Exception('Input tensor size mismatch. Expected: $expectedInputSize, Got: ${input.length}');
      }
      
      // Reshape input to match model expectations [1, height, width, channels]
      var reshapedInput = input.reshape([1, inputSize, inputSize, 3]);
      print('Input reshaped to: ${reshapedInput}');
      
      // Prepare output buffer based on actual output shape
      final outputShape = outputTensor.shape;
      var output = List.filled(outputShape.reduce((a, b) => a * b), 0.0).reshape(outputShape);
      print('Output buffer prepared with shape: $outputShape');
      
      // Verify interpreter is still valid before running
      if (_interpreter == null) {
        throw Exception('Interpreter became null during processing');
      }
      
      // Validate interpreter state
      try {
        _interpreter!.getInputTensor(0);
        _interpreter!.getOutputTensor(0);
      } catch (e) {
        throw Exception('Interpreter is in invalid state: $e');
      }
      
      print('Running model inference...');
      // Run inference with properly shaped tensors
      _interpreter!.run(reshapedInput, output);
      print('Inference completed successfully');

      // Process results - handle different output shapes
      double realScore, fakeScore;
      
      if (output.length == 2) {
        // Direct output [real_score, fake_score]
        realScore = output[0].toDouble();
        fakeScore = output[1].toDouble();
      } else if (output[0] is List && output[0].length == 2) {
        // Nested output [[real_score, fake_score]]
        realScore = output[0][0].toDouble();
        fakeScore = output[0][1].toDouble();
      } else {
        throw Exception('Unexpected output format: ${output.runtimeType}, length: ${output.length}');
      }
      
      print('Raw scores - Real: $realScore, Fake: $fakeScore');

      // Apply softmax to get probabilities
      double realProb = _softmax(realScore, fakeScore, true);
      double fakeProb = _softmax(realScore, fakeScore, false);
      print('Probabilities - Real: $realProb, Fake: $fakeProb');

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
      
      print('=== Inference completed successfully ===');

    } catch (e) {
      print('=== Inference error occurred ===');
      print('Error details: $e');
      print('Error type: ${e.runtimeType}');
      
      setState(() {
        _isLoading = false;
        _result = 'Error analyzing image: $e';
        _resultColor = Colors.red;
      });
      
      // If it's a model-related error, offer to reload the model
      if (e.toString().toLowerCase().contains('interpreter') || 
          e.toString().toLowerCase().contains('model') ||
          e.toString().toLowerCase().contains('tflite') ||
          e.toString().toLowerCase().contains('bad state') ||
          e.toString().toLowerCase().contains('precondition')) {
        print('Model-related error detected, offering reload option');
        
        // Reset model state
        _isModelLoaded = false;
        await _forceMemoryCleanup();
        
        _showRetryOption();
      }
    } finally {
      // Clear references to help with garbage collection
      imageBytes = null;
      decodedImage = null;
      resizedImage = null;
      print('Memory cleanup completed');
    }
  }

  // Helper method to convert image to normalized Float32List
  Float32List _imageToByteListFloat32(img.Image image, int inputSize) {
    try {
      print('Converting image with dimensions: ${image.width}x${image.height}');
      
      var convertedBytes = Float32List(1 * inputSize * inputSize * 3);
      var buffer = Float32List.view(convertedBytes.buffer);
      int pixelIndex = 0;
      
      for (int y = 0; y < inputSize; y++) {
        for (int x = 0; x < inputSize; x++) {
          var pixel = image.getPixel(x, y);
          
          // Ensure pixel values are valid
          final r = pixel.r.clamp(0.0, 255.0);
          final g = pixel.g.clamp(0.0, 255.0);
          final b = pixel.b.clamp(0.0, 255.0);
          
          // Normalize pixel values to [0,1]
          buffer[pixelIndex++] = r / 255.0;
          buffer[pixelIndex++] = g / 255.0;
          buffer[pixelIndex++] = b / 255.0;
        }
      }
      
      print('Image conversion completed. Buffer size: ${convertedBytes.length}');
      return convertedBytes;
    } catch (e) {
      print('Error in image conversion: $e');
      rethrow;
    }
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
            
            // Model reload button (visible when model is not loaded)
            if (!_isModelLoaded)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: ElevatedButton.icon(
                  onPressed: _isModelLoading ? null : _loadModel,
                  icon: _isModelLoading 
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                  label: Text(_isModelLoading ? 'Loading Model...' : 'Reload AI Model'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
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
