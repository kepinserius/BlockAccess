import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import '../providers/auth_provider.dart';
import '../providers/access_provider.dart';
import '../animations/fade_animation.dart';
import '../animations/slide_animation.dart';
import '../widgets/gradient_button.dart';
import '../theme/app_theme.dart';

class ShareAccessScreen extends StatefulWidget {
  const ShareAccessScreen({Key? key}) : super(key: key);

  @override
  State<ShareAccessScreen> createState() => _ShareAccessScreenState();
}

class _ShareAccessScreenState extends State<ShareAccessScreen> {
  final GlobalKey _qrKey = GlobalKey();
  String? _selectedDoorId;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 7));
  String? _recipientId;
  bool _isGenerating = false;
  bool _isSharing = false;
  String? _qrData;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate : _endDate,
      firstDate: isStartDate ? DateTime.now() : _startDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          // Ensure end date is after start date
          if (_endDate.isBefore(_startDate)) {
            _endDate = _startDate.add(const Duration(days: 1));
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _generateQRCode() async {
    if (_selectedDoorId == null || _recipientId == null || _recipientId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
    });

    try {
      // Generate QR data
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser;
      
      if (user == null) {
        throw Exception('User not logged in');
      }

      // Format: doorId:recipientId:startTime:endTime:issuerId
      final qrData = '$_selectedDoorId:$_recipientId:${_startDate.millisecondsSinceEpoch}:${_endDate.millisecondsSinceEpoch}:${user.id}';
      
      // In a real app, you would encrypt this data or use a signed token
      
      setState(() {
        _qrData = qrData;
        _isGenerating = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating QR code: $e')),
      );
      setState(() {
        _isGenerating = false;
      });
    }
  }

  Future<void> _shareQRCode() async {
    if (_qrData == null) return;

    setState(() {
      _isSharing = true;
    });

    try {
      // Capture QR code as image
      RenderRepaintBoundary boundary = _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData == null) {
        throw Exception('Failed to convert QR code to image');
      }
      
      // Save image to temporary file
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/blockaccess_qr.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());
      
      // Share the file
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Here is your BlockAccess QR code. Valid from ${_startDate.toString().split(' ')[0]} to ${_endDate.toString().split(' ')[0]}',
        subject: 'BlockAccess Invitation',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing QR code: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSharing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final accessProvider = Provider.of<AccessProvider>(context);
    final doors = accessProvider.doors;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Share Access'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            FadeAnimation(
              delay: 0.1,
              child: const Text(
                'Grant Access to Others',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Subtitle
            FadeAnimation(
              delay: 0.2,
              child: Text(
                'Create a QR code that allows others to access specific doors for a limited time.',
                style: TextStyle(
                  color: Colors.grey.shade600,
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Form
            SlideAnimation(
              delay: 0.3,
              direction: SlideDirection.fromLeft,
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Door selection
                      const Text(
                        'Select Door:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.door_front_door),
                          border: OutlineInputBorder(),
                        ),
                        hint: const Text('Select a door'),
                        value: _selectedDoorId,
                        items: doors.map((door) {
                          return DropdownMenuItem<String>(
                            value: door.id,
                            child: Text('${door.name} (${door.location})'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedDoorId = value;
                          });
                        },
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Recipient ID
                      const Text(
                        'Recipient ID:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.person),
                          hintText: 'Enter recipient ID',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _recipientId = value;
                          });
                        },
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Date range selection
                      const Text(
                        'Access Period:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => _selectDate(context, true),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Start Date',
                                  prefixIcon: Icon(Icons.calendar_today),
                                  border: OutlineInputBorder(),
                                ),
                                child: Text(
                                  _startDate.toString().split(' ')[0],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: InkWell(
                              onTap: () => _selectDate(context, false),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'End Date',
                                  prefixIcon: Icon(Icons.calendar_today),
                                  border: OutlineInputBorder(),
                                ),
                                child: Text(
                                  _endDate.toString().split(' ')[0],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Generate button
                      GradientButton(
                        text: 'Generate QR Code',
                        onPressed: _generateQRCode,
                        isLoading: _isGenerating,
                        icon: Icons.qr_code,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // QR Code display
            if (_qrData != null)
              SlideAnimation(
                delay: 0.4,
                direction: SlideDirection.fromBottom,
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Text(
                          'Access QR Code',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // QR Code
                        RepaintBoundary(
                          key: _qrKey,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: QrImageView(
                              data: _qrData!,
                              version: QrVersions.auto,
                              size: 200,
                              backgroundColor: Colors.white,
                              embeddedImage: const AssetImage('assets/images/app_icon.png'),
                              embeddedImageStyle: const QrEmbeddedImageStyle(
                                size: Size(40, 40),
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Access details
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              _buildDetailRow(
                                icon: Icons.door_front_door,
                                label: 'Door',
                                value: doors.firstWhere(
                                  (door) => door.id == _selectedDoorId,
                                  orElse: () => Door(
                                    id: 'unknown',
                                    name: 'Unknown Door',
                                    location: 'Unknown',
                                    deviceId: 'unknown',
                                  ),
                                ).name,
                              ),
                              const SizedBox(height: 8),
                              _buildDetailRow(
                                icon: Icons.person,
                                label: 'Recipient',
                                value: _recipientId!,
                              ),
                              const SizedBox(height: 8),
                              _buildDetailRow(
                                icon: Icons.date_range,
                                label: 'Valid',
                                value: '${_startDate.toString().split(' ')[0]} to ${_endDate.toString().split(' ')[0]}',
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Share button
                        GradientButton(
                          text: 'Share QR Code',
                          onPressed: _shareQRCode,
                          isLoading: _isSharing,
                          icon: Icons.share,
                          gradientColors: [
                            AppTheme.secondaryColor,
                            AppTheme.accentColor,
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: AppTheme.primaryColor,
        ),
        const SizedBox(width: 8),
        Text(
          '$label:',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}
