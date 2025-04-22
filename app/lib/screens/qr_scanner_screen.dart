import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'dart:io';
import '../providers/auth_provider.dart';
import '../providers/access_provider.dart';
import '../providers/blockchain_provider.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({Key? key}) : super(key: key);

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  bool _isProcessing = false;
  String? _resultMessage;
  bool? _accessGranted;

  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid) {
      controller?.pauseCamera();
    } else if (Platform.isIOS) {
      controller?.resumeCamera();
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) {
      if (_isProcessing || scanData.code == null) return;
      _processQRCode(scanData.code!);
    });
  }

  Future<void> _processQRCode(String qrData) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _resultMessage = 'Processing...';
      _accessGranted = null;
    });

    try {
      // Pause camera while processing
      await controller?.pauseCamera();

      // Parse QR code data
      // Expected format: doorId:deviceId
      final parts = qrData.split(':');
      if (parts.length != 2) {
        throw Exception('Invalid QR code format');
      }

      final doorId = parts[0];
      final deviceId = parts[1];

      // Get providers
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final accessProvider = Provider.of<AccessProvider>(context, listen: false);
      final blockchainProvider = Provider.of<BlockchainProvider>(context, listen: false);

      // Check if user is authenticated
      if (!authProvider.isAuthenticated || authProvider.currentUser == null) {
        throw Exception('You must be logged in to access doors');
      }

      final user = authProvider.currentUser!;

      // Verify the door exists
      final door = accessProvider.doors.firstWhere(
        (d) => d.id == doorId && d.deviceId == deviceId,
        orElse: () => throw Exception('Door not found'),
      );

      // Check access on blockchain if connected, otherwise use local cache
      bool hasAccess;
      if (blockchainProvider.isConnected) {
        hasAccess = await blockchainProvider.checkAccess(user.id, doorId);
      } else {
        hasAccess = await accessProvider.checkAccess(user.id, doorId);
      }

      // Log the access attempt on blockchain
      final timestamp = DateTime.now();
      String? txHash;
      
      if (blockchainProvider.isConnected) {
        txHash = await blockchainProvider.logAccess(
          user.id,
          doorId,
          timestamp,
          hasAccess,
        );
      }

      // Set result message
      setState(() {
        _accessGranted = hasAccess;
        if (hasAccess) {
          _resultMessage = 'Access granted to ${door.name}';
        } else {
          _resultMessage = 'Access denied to ${door.name}';
        }
      });

      // Wait a moment before resuming camera
      await Future.delayed(const Duration(seconds: 3));
    } catch (e) {
      setState(() {
        _accessGranted = false;
        _resultMessage = 'Error: ${e.toString()}';
      });
      
      // Wait a moment before resuming camera
      await Future.delayed(const Duration(seconds: 3));
    } finally {
      if (mounted) {
        // Resume camera
        await controller?.resumeCamera();
        
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
      ),
      body: Stack(
        children: [
          // QR Scanner
          QRView(
            key: qrKey,
            onQRViewCreated: _onQRViewCreated,
            overlay: QrScannerOverlayShape(
              borderColor: Theme.of(context).primaryColor,
              borderRadius: 10,
              borderLength: 30,
              borderWidth: 10,
              cutOutSize: MediaQuery.of(context).size.width * 0.8,
            ),
          ),
          
          // Scanning instructions
          Positioned(
            top: 40,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              color: Colors.black54,
              child: const Text(
                'Align the QR code within the frame to scan',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          
          // Result message
          if (_resultMessage != null)
            Positioned(
              bottom: 100,
              left: 0,
              right: 0,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _accessGranted == null
                      ? Colors.black54
                      : _accessGranted!
                          ? Colors.green.withOpacity(0.8)
                          : Colors.red.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _accessGranted == null
                          ? Icons.hourglass_top
                          : _accessGranted!
                              ? Icons.check_circle
                              : Icons.cancel,
                      color: Colors.white,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _resultMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          // Flash toggle button
          Positioned(
            bottom: 30,
            right: 30,
            child: FloatingActionButton(
              heroTag: 'flashButton',
              onPressed: () async {
                await controller?.toggleFlash();
                setState(() {});
              },
              child: FutureBuilder<bool?>(
                future: controller?.getFlashStatus(),
                builder: (context, snapshot) {
                  return Icon(
                    snapshot.data == true ? Icons.flash_on : Icons.flash_off,
                  );
                },
              ),
            ),
          ),
          
          // Camera flip button
          Positioned(
            bottom: 30,
            left: 30,
            child: FloatingActionButton(
              heroTag: 'flipButton',
              onPressed: () async {
                await controller?.flipCamera();
                setState(() {});
              },
              child: const Icon(Icons.flip_camera_ios),
            ),
          ),
        ],
      ),
    );
  }
}
