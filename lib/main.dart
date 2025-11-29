import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_background_remover/image_background_remover.dart';
import 'package:file_saver/file_saver.dart';

void main() {
  runApp(const BackgroundRemoverApp());
}

class BackgroundRemoverApp extends StatelessWidget {
  const BackgroundRemoverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Background Remover',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const BackgroundRemoverScreen(),
    );
  }
}

class BackgroundRemoverScreen extends StatefulWidget {
  const BackgroundRemoverScreen({super.key});

  @override
  State<BackgroundRemoverScreen> createState() =>
      _BackgroundRemoverScreenState();
}

class _BackgroundRemoverScreenState extends State<BackgroundRemoverScreen> {
  final ImagePicker _picker = ImagePicker();
  Uint8List? _originalImageBytes;
  Uint8List? _processedImageBytes;
  bool _isLoading = false;
  Color _backgroundColor = Colors.transparent;
  String? _imagePath;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeBackgroundRemover();
  }

  Future<void> _initializeBackgroundRemover() async {
    try {
      await BackgroundRemover.instance.initializeOrt();
      setState(() {
        _isInitialized = true;
      });
      print('Background remover initialized successfully');
    } catch (e) {
      print('Error initializing background remover: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing: $e')),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _originalImageBytes = bytes;
        _imagePath = image.path;
        _processedImageBytes = null; // Reset processed image
        _backgroundColor = Colors.transparent; // Reset background
      });
    }
  }

  Future<void> _removeBackground() async {
    if (_originalImageBytes == null) return;

    if (!_isInitialized) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Background remover is still initializing...')),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Use the ONNX-based background remover
      final processedImage = await BackgroundRemover.instance.removeBg(
        _originalImageBytes!,
      );
      
      // Convert ui.Image to Uint8List
      final byteData = await processedImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Failed to convert image to bytes');
      }
      
      final processed = byteData.buffer.asUint8List();
      
      // Debug: Check if we got data back
      print('Original image size: ${_originalImageBytes!.length} bytes');
      print('Processed image size: ${processed.length} bytes');
      
      setState(() {
        _processedImageBytes = processed;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Background removed successfully!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error details: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error removing background: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _setBackgroundColor(Color color) {
    setState(() {
      _backgroundColor = color;
    });
  }

  Future<void> _saveImage() async {
    if (_processedImageBytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No processed image to save')),
        );
      }
      return;
    }

    try {
      final fileName = 'bg_removed_${DateTime.now().millisecondsSinceEpoch}';
      await FileSaver.instance.saveFile(
        name: fileName,
        bytes: _processedImageBytes!,
        mimeType: MimeType.png,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Image saved as $fileName.png')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving image: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Background Remover'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                  color: _backgroundColor == Colors.transparent
                      ? Colors.grey[200] // Checkerboard placeholder
                      : _backgroundColor,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (_processedImageBytes != null)
                        Image.memory(
                          _processedImageBytes!,
                          fit: BoxFit.contain,
                        )
                      else if (_originalImageBytes != null)
                        Image.memory(
                          _originalImageBytes!,
                          fit: BoxFit.contain,
                        )
                      else
                        const Center(child: Text('No image selected')),
                      if (_isLoading)
                        const Center(child: CircularProgressIndicator()),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.image),
                        label: const Text('Pick Image'),
                      ),
                      ElevatedButton.icon(
                        onPressed:
                            _originalImageBytes != null && !_isLoading
                                ? _removeBackground
                                : null,
                        icon: const Icon(Icons.auto_fix_high),
                        label: const Text('Remove BG'),
                      ),
                      ElevatedButton.icon(
                        onPressed:
                            _processedImageBytes != null && !_isLoading
                                ? _saveImage
                                : null,
                        icon: const Icon(Icons.save),
                        label: const Text('Save'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Select Background:'),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _ColorButton(
                        color: Colors.white,
                        label: 'White',
                        onPressed: () => _setBackgroundColor(Colors.white),
                        isSelected: _backgroundColor == Colors.white,
                      ),
                      const SizedBox(width: 16),
                      _ColorButton(
                        color: Colors.blue,
                        label: 'Blue',
                        onPressed: () => _setBackgroundColor(Colors.blue),
                        isSelected: _backgroundColor == Colors.blue,
                      ),
                      const SizedBox(width: 16),
                      _ColorButton(
                        color: Colors.transparent,
                        label: 'None',
                        onPressed: () =>
                            _setBackgroundColor(Colors.transparent),
                        isSelected: _backgroundColor == Colors.transparent,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorButton extends StatelessWidget {
  final Color color;
  final String label;
  final VoidCallback onPressed;
  final bool isSelected;

  const _ColorButton({
    required this.color,
    required this.label,
    required this.onPressed,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onPressed,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.black : Colors.grey,
                width: isSelected ? 3 : 1,
              ),
              boxShadow: [
                if (color == Colors.white)
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.5),
                    spreadRadius: 1,
                    blurRadius: 3,
                  ),
              ],
            ),
            child: color == Colors.transparent
                ? const Icon(Icons.block, color: Colors.red)
                : null,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
