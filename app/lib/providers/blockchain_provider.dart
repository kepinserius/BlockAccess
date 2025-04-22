import 'package:flutter/foundation.dart';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class BlockchainProvider with ChangeNotifier {
  Web3Client? _client;
  DeployedContract? _contract;
  EthereumAddress? _contractAddress;
  Credentials? _credentials;
  bool _isInitialized = false;
  bool _isConnected = false;
  String? _lastError;
  
  // Queue for pending transactions when offline
  final List<Map<String, dynamic>> _pendingTransactions = [];

  bool get isInitialized => _isInitialized;
  bool get isConnected => _isConnected;
  String? get lastError => _lastError;

  // Initialize the blockchain connection
  Future<void> initialize() async {
    try {
      // Check connectivity
      final connectivityResult = await Connectivity().checkConnectivity();
      _isConnected = connectivityResult != ConnectivityResult.none;
      
      if (_isConnected) {
        // Connect to Polygon testnet (Mumbai)
        final rpcUrl = 'https://rpc-mumbai.maticvigil.com/';
        _client = Web3Client(rpcUrl, http.Client());
        
        // Load contract ABI
        final abiFile = await _loadContractABI();
        final contractAbi = ContractAbi.fromJson(abiFile, 'AccessControl');
        
        // Contract address on Polygon testnet
        _contractAddress = EthereumAddress.fromHex('0x0000000000000000000000000000000000000000'); // Replace with actual contract address
        
        // Create contract instance
        _contract = DeployedContract(contractAbi, _contractAddress!);
        
        // Process any pending transactions
        await _processPendingTransactions();
      }
      
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      _lastError = e.toString();
      if (kDebugMode) {
        print('Error initializing blockchain: $e');
      }
    }
  }

  // Load contract ABI from assets
  Future<String> _loadContractABI() async {
    try {
      // In a real app, this would load from assets
      // For demo purposes, we'll return a simplified ABI
      return '''
      [
        {
          "inputs": [
            {"name": "userId", "type": "string"},
            {"name": "doorId", "type": "string"}
          ],
          "name": "checkAccess",
          "outputs": [{"name": "", "type": "bool"}],
          "stateMutability": "view",
          "type": "function"
        },
        {
          "inputs": [
            {"name": "userId", "type": "string"},
            {"name": "doorId", "type": "string"},
            {"name": "startTime", "type": "uint256"},
            {"name": "endTime", "type": "uint256"}
          ],
          "name": "grantAccess",
          "outputs": [],
          "stateMutability": "nonpayable",
          "type": "function"
        },
        {
          "inputs": [
            {"name": "accessId", "type": "string"}
          ],
          "name": "revokeAccess",
          "outputs": [],
          "stateMutability": "nonpayable",
          "type": "function"
        },
        {
          "inputs": [
            {"name": "userId", "type": "string"},
            {"name": "doorId", "type": "string"},
            {"name": "timestamp", "type": "uint256"},
            {"name": "success", "type": "bool"}
          ],
          "name": "logAccess",
          "outputs": [],
          "stateMutability": "nonpayable",
          "type": "function"
        }
      ]
      ''';
    } catch (e) {
      if (kDebugMode) {
        print('Error loading contract ABI: $e');
      }
      rethrow;
    }
  }

  // Set wallet credentials
  Future<void> setCredentials(String privateKey) async {
    try {
      _credentials = EthPrivateKey.fromHex(privateKey);
      notifyListeners();
    } catch (e) {
      _lastError = e.toString();
      if (kDebugMode) {
        print('Error setting credentials: $e');
      }
    }
  }

  // Check access on the blockchain
  Future<bool> checkAccess(String userId, String doorId) async {
    try {
      if (!_isInitialized || _contract == null) {
        return false;
      }

      if (!_isConnected) {
        // Use cached data in offline mode
        return true; // In a real app, check local cache
      }

      final function = _contract!.function('checkAccess');
      final result = await _client!.call(
        contract: _contract!,
        function: function,
        params: [userId, doorId],
      );

      return result[0] as bool;
    } catch (e) {
      _lastError = e.toString();
      if (kDebugMode) {
        print('Error checking access on blockchain: $e');
      }
      return false;
    }
  }

  // Grant access on the blockchain
  Future<String?> grantAccess(String userId, String doorId, DateTime startTime, DateTime endTime) async {
    try {
      if (!_isInitialized || _contract == null || _credentials == null) {
        return null;
      }

      final function = _contract!.function('grantAccess');
      final startTimeUnix = BigInt.from(startTime.millisecondsSinceEpoch ~/ 1000);
      final endTimeUnix = BigInt.from(endTime.millisecondsSinceEpoch ~/ 1000);

      if (!_isConnected) {
        // Queue transaction for later
        _pendingTransactions.add({
          'type': 'grantAccess',
          'userId': userId,
          'doorId': doorId,
          'startTime': startTimeUnix.toString(),
          'endTime': endTimeUnix.toString(),
        });
        await _savePendingTransactions();
        return 'pending';
      }

      final transaction = Transaction.callContract(
        contract: _contract!,
        function: function,
        parameters: [userId, doorId, startTimeUnix, endTimeUnix],
      );

      final txHash = await _client!.sendTransaction(
        _credentials!,
        transaction,
        chainId: 80001, // Mumbai testnet chain ID
      );

      return txHash;
    } catch (e) {
      _lastError = e.toString();
      if (kDebugMode) {
        print('Error granting access on blockchain: $e');
      }
      return null;
    }
  }

  // Revoke access on the blockchain
  Future<String?> revokeAccess(String accessId) async {
    try {
      if (!_isInitialized || _contract == null || _credentials == null) {
        return null;
      }

      final function = _contract!.function('revokeAccess');

      if (!_isConnected) {
        // Queue transaction for later
        _pendingTransactions.add({
          'type': 'revokeAccess',
          'accessId': accessId,
        });
        await _savePendingTransactions();
        return 'pending';
      }

      final transaction = Transaction.callContract(
        contract: _contract!,
        function: function,
        parameters: [accessId],
      );

      final txHash = await _client!.sendTransaction(
        _credentials!,
        transaction,
        chainId: 80001, // Mumbai testnet chain ID
      );

      return txHash;
    } catch (e) {
      _lastError = e.toString();
      if (kDebugMode) {
        print('Error revoking access on blockchain: $e');
      }
      return null;
    }
  }

  // Log access attempt on the blockchain
  Future<String?> logAccess(String userId, String doorId, DateTime timestamp, bool success) async {
    try {
      if (!_isInitialized || _contract == null || _credentials == null) {
        return null;
      }

      final function = _contract!.function('logAccess');
      final timestampUnix = BigInt.from(timestamp.millisecondsSinceEpoch ~/ 1000);

      if (!_isConnected) {
        // Queue transaction for later
        _pendingTransactions.add({
          'type': 'logAccess',
          'userId': userId,
          'doorId': doorId,
          'timestamp': timestampUnix.toString(),
          'success': success,
        });
        await _savePendingTransactions();
        return 'pending';
      }

      final transaction = Transaction.callContract(
        contract: _contract!,
        function: function,
        parameters: [userId, doorId, timestampUnix, success],
      );

      final txHash = await _client!.sendTransaction(
        _credentials!,
        transaction,
        chainId: 80001, // Mumbai testnet chain ID
      );

      return txHash;
    } catch (e) {
      _lastError = e.toString();
      if (kDebugMode) {
        print('Error logging access on blockchain: $e');
      }
      return null;
    }
  }

  // Save pending transactions to local storage
  Future<void> _savePendingTransactions() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/pending_transactions.json');
      await file.writeAsString(jsonEncode(_pendingTransactions));
    } catch (e) {
      if (kDebugMode) {
        print('Error saving pending transactions: $e');
      }
    }
  }

  // Load pending transactions from local storage
  Future<void> _loadPendingTransactions() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/pending_transactions.json');
      if (await file.exists()) {
        final jsonString = await file.readAsString();
        final List<dynamic> transactions = jsonDecode(jsonString);
        _pendingTransactions.clear();
        _pendingTransactions.addAll(
          transactions.map((tx) => tx as Map<String, dynamic>).toList(),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading pending transactions: $e');
      }
    }
  }

  // Process pending transactions
  Future<void> _processPendingTransactions() async {
    try {
      await _loadPendingTransactions();
      if (_pendingTransactions.isEmpty) {
        return;
      }

      // Process each pending transaction
      final processedIndices = <int>[];
      for (int i = 0; i < _pendingTransactions.length; i++) {
        final tx = _pendingTransactions[i];
        bool processed = false;

        switch (tx['type']) {
          case 'grantAccess':
            final startTime = DateTime.fromMillisecondsSinceEpoch(
              int.parse(tx['startTime']) * 1000,
            );
            final endTime = DateTime.fromMillisecondsSinceEpoch(
              int.parse(tx['endTime']) * 1000,
            );
            final result = await grantAccess(
              tx['userId'],
              tx['doorId'],
              startTime,
              endTime,
            );
            processed = result != null && result != 'pending';
            break;
          case 'revokeAccess':
            final result = await revokeAccess(tx['accessId']);
            processed = result != null && result != 'pending';
            break;
          case 'logAccess':
            final timestamp = DateTime.fromMillisecondsSinceEpoch(
              int.parse(tx['timestamp']) * 1000,
            );
            final result = await logAccess(
              tx['userId'],
              tx['doorId'],
              timestamp,
              tx['success'],
            );
            processed = result != null && result != 'pending';
            break;
        }

        if (processed) {
          processedIndices.add(i);
        }
      }

      // Remove processed transactions
      for (int i = processedIndices.length - 1; i >= 0; i--) {
        _pendingTransactions.removeAt(processedIndices[i]);
      }

      // Save updated pending transactions
      await _savePendingTransactions();
    } catch (e) {
      if (kDebugMode) {
        print('Error processing pending transactions: $e');
      }
    }
  }

  // Check connectivity and update status
  Future<void> checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    final wasConnected = _isConnected;
    _isConnected = connectivityResult != ConnectivityResult.none;
    
    // If we just got connected, process pending transactions
    if (!wasConnected && _isConnected) {
      await _processPendingTransactions();
    }
    
    notifyListeners();
  }
}
