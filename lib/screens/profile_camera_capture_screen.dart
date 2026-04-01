import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class ProfileCameraCaptureScreen extends StatefulWidget {
  const ProfileCameraCaptureScreen({super.key});

  @override
  State<ProfileCameraCaptureScreen> createState() =>
      _ProfileCameraCaptureScreenState();
}

class _ProfileCameraCaptureScreenState extends State<ProfileCameraCaptureScreen> {
  CameraController? _controller;
  bool _initializing = true;
  bool _capturing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _setupCamera();
  }

  Future<void> _setupCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _error = 'No camera is available on this device.';
          _initializing = false;
        });
        return;
      }

      final front = cameras.where((c) => c.lensDirection == CameraLensDirection.front);
      final selected = front.isNotEmpty ? front.first : cameras.first;

      final controller = CameraController(
        selected,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _initializing = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Unable to start camera. Please check permissions and try again.';
        _initializing = false;
      });
    }
  }

  Future<void> _capturePhoto() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _capturing) {
      return;
    }

    setState(() {
      _capturing = true;
    });

    try {
      final xFile = await controller.takePicture();
      final bytes = await xFile.readAsBytes();
      if (!mounted) return;
      Navigator.of(context).pop<Uint8List>(bytes);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to capture photo. Please try again.')),
      );
      setState(() {
        _capturing = false;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Scaffold(
      appBar: AppBar(title: const Text('Take a profile photo')),
      backgroundColor: Colors.black,
      body: _initializing
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                )
              : controller == null
                  ? const SizedBox.shrink()
                  : Stack(
                      children: [
                        Center(
                          child: AspectRatio(
                            aspectRatio: controller.value.aspectRatio,
                            child: CameraPreview(controller),
                          ),
                        ),
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                            child: SizedBox(
                              width: 72,
                              height: 72,
                              child: FloatingActionButton(
                                onPressed: _capturing ? null : _capturePhoto,
                                child: _capturing
                                    ? const CircularProgressIndicator(strokeWidth: 2)
                                    : const Icon(Icons.camera_alt),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
    );
  }
}
