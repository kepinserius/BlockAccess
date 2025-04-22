import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/access_provider.dart';
import '../providers/blockchain_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _refreshData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final accessProvider = Provider.of<AccessProvider>(context, listen: false);
      final blockchainProvider = Provider.of<BlockchainProvider>(context, listen: false);
      
      // Check connectivity
      await blockchainProvider.checkConnectivity();
      
      // Refresh access data
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

  void _showQRScanner() {
    Navigator.of(context).pushNamed('/qr_scanner');
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final accessProvider = Provider.of<AccessProvider>(context);
    final blockchainProvider = Provider.of<BlockchainProvider>(context);
    
    final user = authProvider.currentUser;
    final isAdmin = authProvider.isAdmin;
    final isConnected = blockchainProvider.isConnected;

    return Scaffold(
      appBar: AppBar(
        title: const Text('BlockAccess'),
        actions: [
          // Connection status indicator
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Icon(
              isConnected ? Icons.wifi : Icons.wifi_off,
              color: isConnected ? Colors.green : Colors.red,
            ),
          ),
          // Admin panel button
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings),
              onPressed: () => Navigator.of(context).pushNamed('/admin'),
              tooltip: 'Admin Panel',
            ),
          // Logout button
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authProvider.logout();
              if (mounted) {
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
            tooltip: 'Logout',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'My Access', icon: Icon(Icons.vpn_key)),
            Tab(text: 'Doors', icon: Icon(Icons.door_front_door)),
            Tab(text: 'History', icon: Icon(Icons.history)),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabController,
                children: [
                  // My Access Tab
                  _buildMyAccessTab(accessProvider, user),
                  
                  // Doors Tab
                  _buildDoorsTab(accessProvider),
                  
                  // History Tab
                  _buildHistoryTab(accessProvider, user),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showQRScanner,
        label: const Text('Scan QR'),
        icon: const Icon(Icons.qr_code_scanner),
      ),
    );
  }

  Widget _buildMyAccessTab(AccessProvider accessProvider, User? user) {
    final myAccessRights = accessProvider.accessRights
        .where((right) => right.userId == user?.id)
        .toList();

    if (myAccessRights.isEmpty) {
      return const Center(
        child: Text(
          'You don\'t have any access rights yet.',
          style: TextStyle(fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: myAccessRights.length,
      itemBuilder: (context, index) {
        final accessRight = myAccessRights[index];
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
                      child: Text(
                        door.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
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
                const SizedBox(height: 8),
                Text(
                  'Location: ${door.location}',
                  style: const TextStyle(
                    color: Colors.grey,
                  ),
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
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDoorsTab(AccessProvider accessProvider) {
    final doors = accessProvider.doors;

    if (doors.isEmpty) {
      return const Center(
        child: Text(
          'No doors available.',
          style: TextStyle(fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: doors.length,
      itemBuilder: (context, index) {
        final door = doors[index];
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.door_front_door,
                    color: Theme.of(context).primaryColor,
                    size: 32,
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
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Location: ${door.location}',
                        style: const TextStyle(
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Device ID: ${door.deviceId}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
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

  Widget _buildHistoryTab(AccessProvider accessProvider, User? user) {
    final accessLogs = accessProvider.accessLogs
        .where((log) => log.userId == user?.id)
        .toList();

    if (accessLogs.isEmpty) {
      return const Center(
        child: Text(
          'No access history yet.',
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
                        'Location: ${door.location}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
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
