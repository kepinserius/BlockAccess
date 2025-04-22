import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/access_provider.dart';
import '../providers/blockchain_provider.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({Key? key}) : super(key: key);

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  String? _selectedUserId;
  String? _selectedDoorId;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 30));
  final TextEditingController _userIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _refreshData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _userIdController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final accessProvider = Provider.of<AccessProvider>(context, listen: false);
      await accessProvider.initialize();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error refreshing data: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _grantAccess() async {
    if (_selectedUserId == null || _selectedDoorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a user and a door')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final accessProvider = Provider.of<AccessProvider>(context, listen: false);
      final blockchainProvider = Provider.of<BlockchainProvider>(context, listen: false);
      
      // Grant access in local database
      final success = await accessProvider.grantAccess(
        _selectedUserId!,
        _selectedDoorId!,
        _startDate,
        _endDate,
      );
      
      // Grant access on blockchain if connected
      if (success && blockchainProvider.isConnected) {
        await blockchainProvider.grantAccess(
          _selectedUserId!,
          _selectedDoorId!,
          _startDate,
          _endDate,
        );
      }
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Access granted successfully')),
        );
        
        // Reset selection
        setState(() {
          _selectedUserId = null;
          _selectedDoorId = null;
          _userIdController.clear();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to grant access')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _revokeAccess(String accessRightId) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final accessProvider = Provider.of<AccessProvider>(context, listen: false);
      final blockchainProvider = Provider.of<BlockchainProvider>(context, listen: false);
      
      // Revoke access in local database
      final success = await accessProvider.revokeAccess(accessRightId);
      
      // Revoke access on blockchain if connected
      if (success && blockchainProvider.isConnected) {
        await blockchainProvider.revokeAccess(accessRightId);
      }
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Access revoked successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to revoke access')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final accessProvider = Provider.of<AccessProvider>(context);
    final blockchainProvider = Provider.of<BlockchainProvider>(context);
    
    // Check if user is admin
    if (!authProvider.isAdmin) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Admin Panel'),
        ),
        body: const Center(
          child: Text(
            'You do not have admin privileges',
            style: TextStyle(fontSize: 18),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        actions: [
          // Connection status indicator
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Icon(
              blockchainProvider.isConnected ? Icons.wifi : Icons.wifi_off,
              color: blockchainProvider.isConnected ? Colors.green : Colors.red,
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Grant Access', icon: Icon(Icons.add)),
            Tab(text: 'Manage Access', icon: Icon(Icons.edit)),
            Tab(text: 'Access Logs', icon: Icon(Icons.history)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // Grant Access Tab
                _buildGrantAccessTab(accessProvider),
                
                // Manage Access Tab
                _buildManageAccessTab(accessProvider),
                
                // Access Logs Tab
                _buildAccessLogsTab(accessProvider),
              ],
            ),
    );
  }

  Widget _buildGrantAccessTab(AccessProvider accessProvider) {
    final doors = accessProvider.doors;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Grant New Access',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          
          // User ID input
          TextField(
            controller: _userIdController,
            decoration: InputDecoration(
              labelText: 'User ID',
              hintText: 'Enter user ID',
              prefixIcon: const Icon(Icons.person),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (value) {
              setState(() {
                _selectedUserId = value.isNotEmpty ? value : null;
              });
            },
          ),
          const SizedBox(height: 16),
          
          // Door selection
          const Text(
            'Select Door:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: doors.length,
              itemBuilder: (context, index) {
                final door = doors[index];
                return RadioListTile<String>(
                  title: Text(door.name),
                  subtitle: Text(door.location),
                  value: door.id,
                  groupValue: _selectedDoorId,
                  onChanged: (value) {
                    setState(() {
                      _selectedDoorId = value;
                    });
                  },
                );
              },
            ),
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
                    decoration: InputDecoration(
                      labelText: 'Start Date',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      DateFormat('MMM d, yyyy').format(_startDate),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: InkWell(
                  onTap: () => _selectDate(context, false),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'End Date',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      DateFormat('MMM d, yyyy').format(_endDate),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          
          // Grant access button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _grantAccess,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Grant Access',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          
          // Demo button
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: _isLoading
                  ? null
                  : () {
                      setState(() {
                        _selectedUserId = '1';
                        _selectedDoorId = '3';
                        _userIdController.text = '1';
                      });
                    },
              child: const Text('Use Demo User (ID: 1)'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManageAccessTab(AccessProvider accessProvider) {
    final accessRights = accessProvider.accessRights;

    if (accessRights.isEmpty) {
      return const Center(
        child: Text(
          'No access rights found.',
          style: TextStyle(fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: accessRights.length,
      itemBuilder: (context, index) {
        final accessRight = accessRights[index];
        final door = accessProvider.doors.firstWhere(
          (door) => door.id == accessRight.doorId,
          orElse: () => Door(
            id: 'unknown',
            name: 'Unknown Door',
            location: 'Unknown',
            deviceId: 'unknown',
          ),
        );

        final now = DateTime.now();
        final isActive = accessRight.isActive;
        final isExpired = now.isAfter(accessRight.endTime);
        final isNotStarted = now.isBefore(accessRight.startTime);

        Color statusColor;
        String statusText;

        if (!isActive) {
          statusColor = Colors.red;
          statusText = 'Revoked';
        } else if (isExpired) {
          statusColor = Colors.orange;
          statusText = 'Expired';
        } else if (isNotStarted) {
          statusColor = Colors.blue;
          statusText = 'Pending';
        } else {
          statusColor = Colors.green;
          statusText = 'Active';
        }

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            door.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'User ID: ${accessRight.userId}',
                            style: const TextStyle(
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(
                      Icons.access_time,
                      size: 16,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Valid from ${DateFormat('MMM d, yyyy').format(accessRight.startTime)} to ${DateFormat('MMM d, yyyy').format(accessRight.endTime)}',
                        style: const TextStyle(
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (isActive)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _isLoading
                          ? null
                          : () => _revokeAccess(accessRight.id),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Revoke Access'),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAccessLogsTab(AccessProvider accessProvider) {
    final accessLogs = accessProvider.accessLogs;

    if (accessLogs.isEmpty) {
      return const Center(
        child: Text(
          'No access logs found.',
          style: TextStyle(fontSize: 16),
        ),
      );
    }

    // Sort logs by timestamp (newest first)
    accessLogs.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: accessLogs.length,
      itemBuilder: (context, index) {
        final log = accessLogs[index];
        final door = accessProvider.doors.firstWhere(
          (door) => door.id == log.doorId,
          orElse: () => Door(
            id: 'unknown',
            name: 'Unknown Door',
            location: 'Unknown',
            deviceId: 'unknown',
          ),
        );

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: log.wasSuccessful ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    log.wasSuccessful ? Icons.check : Icons.close,
                    color: log.wasSuccessful ? Colors.green : Colors.red,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        door.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'User ID: ${log.userId}',
                        style: const TextStyle(
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time,
                            size: 14,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('MMM d, yyyy - HH:mm').format(log.timestamp),
                            style: const TextStyle(
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      if (log.transactionHash != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.link,
                              size: 14,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'TX: ${log.transactionHash}',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
