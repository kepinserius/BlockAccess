import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/access_provider.dart';
import '../animations/fade_animation.dart';
import '../animations/slide_animation.dart';
import '../theme/app_theme.dart';

class AccessHistoryScreen extends StatefulWidget {
  const AccessHistoryScreen({Key? key}) : super(key: key);

  @override
  State<AccessHistoryScreen> createState() => _AccessHistoryScreenState();
}

class _AccessHistoryScreenState extends State<AccessHistoryScreen> {
  bool _isLoading = false;
  String _filterDoorId = 'all';
  bool _showSuccessfulOnly = false;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _refreshData();
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
        SnackBar(content: Text('Error refreshing data: $e')),
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
      initialDate: isStartDate 
          ? _startDate ?? DateTime.now().subtract(const Duration(days: 30))
          : _endDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: isStartDate ? (_endDate ?? DateTime.now()) : DateTime.now(),
    );
    
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  void _clearFilters() {
    setState(() {
      _filterDoorId = 'all';
      _showSuccessfulOnly = false;
      _startDate = null;
      _endDate = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final accessProvider = Provider.of<AccessProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;
    
    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text('User not logged in'),
        ),
      );
    }

    // Get all access logs for the current user
    List<AccessLog> accessLogs = accessProvider.accessLogs
        .where((log) => log.userId == user.id)
        .toList();
    
    // Apply filters
    if (_filterDoorId != 'all') {
      accessLogs = accessLogs.where((log) => log.doorId == _filterDoorId).toList();
    }
    
    if (_showSuccessfulOnly) {
      accessLogs = accessLogs.where((log) => log.wasSuccessful).toList();
    }
    
    if (_startDate != null) {
      accessLogs = accessLogs.where((log) => log.timestamp.isAfter(_startDate!)).toList();
    }
    
    if (_endDate != null) {
      final endOfDay = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
      accessLogs = accessLogs.where((log) => log.timestamp.isBefore(endOfDay)).toList();
    }
    
    // Sort logs by timestamp (newest first)
    accessLogs.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Access History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter',
            onPressed: () {
              _showFilterDialog(context, accessProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // Filter indicators
                  if (_filterDoorId != 'all' || _showSuccessfulOnly || _startDate != null || _endDate != null)
                    FadeAnimation(
                      delay: 0.1,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        color: AppTheme.primaryColor.withOpacity(0.05),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.filter_list,
                              size: 16,
                              color: AppTheme.primaryColor,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Filters:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _getFilterDescription(accessProvider),
                                style: const TextStyle(
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.clear,
                                size: 16,
                                color: AppTheme.primaryColor,
                              ),
                              onPressed: _clearFilters,
                              tooltip: 'Clear filters',
                            ),
                          ],
                        ),
                      ),
                    ),
                  
                  // Access logs list
                  Expanded(
                    child: accessLogs.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.history_toggle_off,
                                  size: 64,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No access history found',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                if (_filterDoorId != 'all' || _showSuccessfulOnly || _startDate != null || _endDate != null)
                                  TextButton(
                                    onPressed: _clearFilters,
                                    child: const Text('Clear filters'),
                                  ),
                              ],
                            ),
                          )
                        : ListView.builder(
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

                              return SlideAnimation(
                                delay: index * 0.05,
                                direction: SlideDirection.fromRight,
                                child: Card(
                                  elevation: 2,
                                  margin: const EdgeInsets.only(bottom: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            // Status icon
                                            Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: log.wasSuccessful
                                                    ? AppTheme.successColor.withOpacity(0.1)
                                                    : AppTheme.errorColor.withOpacity(0.1),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                log.wasSuccessful ? Icons.check : Icons.close,
                                                color: log.wasSuccessful
                                                    ? AppTheme.successColor
                                                    : AppTheme.errorColor,
                                                size: 20,
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            
                                            // Access details
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
                                                    style: TextStyle(
                                                      color: Colors.grey.shade600,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Row(
                                                    children: [
                                                      Icon(
                                                        Icons.access_time,
                                                        size: 14,
                                                        color: Colors.grey.shade600,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        DateFormat('MMM d, yyyy - HH:mm').format(log.timestamp),
                                                        style: TextStyle(
                                                          color: Colors.grey.shade600,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        
                                        // Transaction hash if available
                                        if (log.transactionHash != null) ...[
                                          const Divider(height: 24),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.link,
                                                size: 14,
                                                color: Colors.grey.shade600,
                                              ),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  'TX: ${log.transactionHash}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.open_in_new,
                                                  size: 16,
                                                ),
                                                onPressed: () {
                                                  // Open blockchain explorer
                                                },
                                                tooltip: 'View on blockchain explorer',
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  String _getFilterDescription(AccessProvider accessProvider) {
    final List<String> filters = [];
    
    if (_filterDoorId != 'all') {
      final door = accessProvider.doors.firstWhere(
        (door) => door.id == _filterDoorId,
        orElse: () => Door(
          id: 'unknown',
          name: 'Unknown Door',
          location: 'Unknown',
          deviceId: 'unknown',
        ),
      );
      filters.add('Door: ${door.name}');
    }
    
    if (_showSuccessfulOnly) {
      filters.add('Successful only');
    }
    
    if (_startDate != null) {
      filters.add('From: ${DateFormat('MMM d, yyyy').format(_startDate!)}');
    }
    
    if (_endDate != null) {
      filters.add('To: ${DateFormat('MMM d, yyyy').format(_endDate!)}');
    }
    
    return filters.join(' • ');
  }

  void _showFilterDialog(BuildContext context, AccessProvider accessProvider) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Filter Access History'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Door filter
                const Text(
                  'Door:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  value: _filterDoorId,
                  items: [
                    const DropdownMenuItem(
                      value: 'all',
                      child: Text('All Doors'),
                    ),
                    ...accessProvider.doors.map((door) {
                      return DropdownMenuItem(
                        value: door.id,
                        child: Text(door.name),
                      );
                    }).toList(),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _filterDoorId = value ?? 'all';
                    });
                  },
                ),
                
                const SizedBox(height: 16),
                
                // Success filter
                CheckboxListTile(
                  title: const Text('Show successful access only'),
                  value: _showSuccessfulOnly,
                  onChanged: (value) {
                    setState(() {
                      _showSuccessfulOnly = value ?? false;
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                
                const SizedBox(height: 16),
                
                // Date range
                const Text(
                  'Date Range:',
                  style: TextStyle(
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
                            labelText: 'From',
                            border: OutlineInputBorder(),
                          ),
                          child: Text(
                            _startDate != null
                                ? DateFormat('MMM d, yyyy').format(_startDate!)
                                : 'Any',
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
                            labelText: 'To',
                            border: OutlineInputBorder(),
                          ),
                          child: Text(
                            _endDate != null
                                ? DateFormat('MMM d, yyyy').format(_endDate!)
                                : 'Any',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _clearFilters();
                },
                child: const Text('Clear All'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // The filters are already applied via setState
                  this.setState(() {});
                },
                child: const Text('Apply'),
              ),
            ],
          );
        },
      ),
    );
  }
}
