import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;

class CameraCaptureScreen extends StatefulWidget {
  final bool isVideo;
  
  const CameraCaptureScreen({
    super.key,
    this.isVideo = false,
  });

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isRecording = false;
  XFile? _capturedFile;
  
  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }
  
  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        _controller = CameraController(
          _cameras![0],
          ResolutionPreset.medium,
          enableAudio: widget.isVideo,
        );
        
        await _controller!.initialize();
        
        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
        }
      }
    } catch (e) {
      print('Error initializing camera: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Camera initialization failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
  
  Future<void> _capturePhoto() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    
    try {
      final XFile photo = await _controller!.takePicture();
      setState(() {
        _capturedFile = photo;
      });
      
      // Return the captured photo
      if (mounted) {
        Navigator.of(context).pop(photo);
      }
    } catch (e) {
      print('Error capturing photo: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to capture photo: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _startVideoRecording() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    
    try {
      await _controller!.startVideoRecording();
      setState(() {
        _isRecording = true;
      });
      
      // Auto-stop after 30 seconds
      Future.delayed(const Duration(seconds: 30), () {
        if (_isRecording) {
          _stopVideoRecording();
        }
      });
    } catch (e) {
      print('Error starting video recording: $e');
    }
  }
  
  Future<void> _stopVideoRecording() async {
    if (_controller == null || !_controller!.value.isRecordingVideo) return;
    
    try {
      final XFile video = await _controller!.stopVideoRecording();
      setState(() {
        _isRecording = false;
        _capturedFile = video;
      });
      
      // Return the captured video
      if (mounted) {
        Navigator.of(context).pop(video);
      }
    } catch (e) {
      print('Error stopping video recording: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(widget.isVideo ? 'Record Video' : 'Take Photo'),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          if (_isInitialized && _controller != null)
            Center(
              child: AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: CameraPreview(_controller!),
              ),
            )
          else
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          
          // Capture button
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: () {
                  if (widget.isVideo) {
                    if (_isRecording) {
                      _stopVideoRecording();
                    } else {
                      _startVideoRecording();
                    }
                  } else {
                    _capturePhoto();
                  }
                },
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isRecording ? Colors.red : Colors.white,
                    border: Border.all(
                      color: Colors.white,
                      width: 3,
                    ),
                  ),
                  child: _isRecording
                      ? const Icon(Icons.stop, color: Colors.white, size: 30)
                      : widget.isVideo
                          ? const Icon(Icons.videocam, color: Colors.black, size: 30)
                          : const Icon(Icons.camera_alt, color: Colors.black, size: 30),
                ),
              ),
            ),
          ),
          
          if (_isRecording)
            Positioned(
              top: 100,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Recording... (max 30s)',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}