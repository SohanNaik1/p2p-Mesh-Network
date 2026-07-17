import 'dart:typed_data';
import 'dart:io' as io;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:bonsoir/bonsoir.dart';

void main() => runApp(const FluxApp());

class FluxApp extends StatelessWidget {
  const FluxApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flux Share',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F0F13),
        primaryColor: const Color(0xFF3B82F6),
        cardColor: const Color(0xFF1C1C22),
      ),
      home: const DiscoveryScreen(),
    );
  }
}

class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key});
  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  BonsoirDiscovery? _bonsoirDiscovery;
  List<BonsoirService> _peers = []; 
  String statusMessage = "Scanning Wi-Fi network...";
  bool _isScanning = false;

  List<String> _myIps = [];

  @override
  void initState() {
    super.initState();
    // Fetch our own IPs first, then start scanning
    _fetchMyIps().then((_) {
      _startScanning();
    });
  }

  Future<void> _fetchMyIps() async {
    try {
      final interfaces = await io.NetworkInterface.list(type: io.InternetAddressType.IPv4);
      for (var interface in interfaces) {
        // 🛑 SKIP loopback interface cards
        if (interface.name == 'lo' || interface.name == 'loopback') continue;
        
        for (var addr in interface.addresses) {
          // 🛑 SKIP the loopback IP itself
          if (addr.address == '127.0.0.1') continue;
          _myIps.add(addr.address);
        }
      }
      print("My Device IPs (Filtered): $_myIps");
    } catch (e) {
      print("Error getting local IPs: $e");
    }
  }

  Future<void> _startScanning() async {
    if (_bonsoirDiscovery != null) return;

    setState(() {
      _peers.clear();
      statusMessage = "Scanning Wi-Fi network...";
      _isScanning = true;
    });

    try {
      _bonsoirDiscovery = BonsoirDiscovery(type: '_fluxshare._tcp');
      await _bonsoirDiscovery!.initialize();

      // THIS is where the event listening actually happens
      _bonsoirDiscovery!.eventStream!.listen((event) {
        
        // 1. Handle SERVICE FOUND
        if (event is BonsoirDiscoveryServiceFoundEvent) {
          print('Found service: ${event.service!.name}, resolving...');
          event.service!.resolve(_bonsoirDiscovery!.serviceResolver);
        } 
        
        // 2. Handle SERVICE RESOLVED
        else if (event is BonsoirDiscoveryServiceResolvedEvent) {
          // Add ! to guarantee it's not null
          final service = event.service!; 
          
          print('\n==================================');
          print('✅ RESOLVED: ${service.name}');
          print('📡 Its IPs: ${service.hostAddresses}');
          print('💻 My IPs: $_myIps');
          
          // Check if the discovered IP belongs to us
          bool isMyOwnDevice = false;
          if (service.hostAddresses != null) {
            for (String ip in service.hostAddresses!) {
              // 🛑 IGNORE loopback addresses during cross-comparison
              if (ip == '127.0.0.1') continue;
              
              if (_myIps.contains(ip)) {
                isMyOwnDevice = true;
                break;
              }
            }
          }

          print('🛑 Is My Own Device? $isMyOwnDevice');
          print('==================================\n');

          setState(() {
            // ONLY add if it's NOT us, and NOT already in the list
            if (!isMyOwnDevice && !_peers.any((p) => p.name == service.name)) {
              _peers.add(service);
            }
            statusMessage = "Devices found Nearby";
          });
        } 
        
        // 3. Handle SERVICE LOST
        else if (event is BonsoirDiscoveryServiceLostEvent) {
          setState(() {
            _peers.removeWhere((p) => p.name == event.service!.name);
            if (_peers.isEmpty) statusMessage = "Scanning Wi-Fi network...";
          });
        }
      });

      await _bonsoirDiscovery!.start();
      print("Scanning started...");
    } catch (e) {
      setState(() {
        statusMessage = "Discovery Error: $e";
      });
    }
  }

  Future<void> stopDiscovery() async {
    if (_bonsoirDiscovery != null) {
      await _bonsoirDiscovery!.stop();
      _bonsoirDiscovery = null;
    }
    setState(() {
      _isScanning = false;
    });
  }

  @override
  void dispose() {
    stopDiscovery();
    super.dispose();
  }

  void _connectToPeer(BonsoirService peer) {
    if (peer.hostAddresses == null || peer.hostAddresses!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error: Cannot resolve target IP address")),
      );
      return;
    }

    final String ipAddress = peer.hostAddresses!.first;
    final String wsUrl = 'ws://$ipAddress:${peer.port}/ws';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TransferScreen(
          serverUri: wsUrl,
          peerName: peer.name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Nearby Devices", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(_isScanning ? Icons.radar : Icons.refresh),
            onPressed: _startScanning,
          )
        ],
      ),
      body: _peers.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Color(0xFF3B82F6)),
                  const SizedBox(height: 24),
                  Text("Scanning Wi-Fi network...", style: TextStyle(color: Colors.grey.shade400, fontSize: 16)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _peers.length,
              itemBuilder: (context, index) {
                final peer = _peers[index];
                
                final ipDisplay = (peer.hostAddresses != null && peer.hostAddresses!.isNotEmpty)
                    ? peer.hostAddresses!.first
                    : "Unknown IP";

                return Card(
                  elevation: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF3B82F6).withOpacity(0.2),
                      child: const Icon(Icons.laptop_mac, color: Color(0xFF3B82F6)),
                    ),
                    title: Text(peer.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    subtitle: Text("Tap to connect • $ipDisplay", style: const TextStyle(color: Colors.grey)),
                    trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                    onTap: () => _connectToPeer(peer),
                  ),
                );
              },
            ),
    );
  }
}

class TransferScreen extends StatefulWidget {
  final String serverUri;
  final String peerName;
  const TransferScreen({super.key, required this.serverUri, required this.peerName});

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  late WebSocketChannel channel;
  bool isConnected = false;
  double progress = 0.0;
  String statusMessage = 'Establishing secure link...';

  @override
  void initState() {
    super.initState();
    _connect();
  }

  void _connect() {
    try {
      channel = WebSocketChannel.connect(Uri.parse(widget.serverUri));
      channel.stream.listen(
        (message) {
          final String data = message.toString();
          setState(() {
            if (data.startsWith('HANDSHAKE:')) {
              isConnected = true;
              statusMessage = 'Ready to send files';
            } else if (data.startsWith('PROGRESS:')) {
              progress = double.parse(data.split(':')[1]) / 100;
              statusMessage = progress == 1.0 ? 'Transfer Complete!' : 'Sending... ${(progress * 100).toInt()}%';
            }
          });
        },
        onError: (_) => setState(() { statusMessage = "Connection Lost"; isConnected = false; }),
      );
    } catch (_) {
      setState(() { statusMessage = "Failed to connect"; isConnected = false; });
    }
  }

  Future<void> pickAndSendFile() async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result == null || result.files.isEmpty) return;

      final String fileName = result.files.single.name;
      final String? filePath = result.files.single.path;
      
      if (filePath == null) {
        setState(() { statusMessage = "Error: Invalid file path."; });
        return;
      }

      if (!mounted) return;
      setState(() { statusMessage = "Sending $fileName..."; });

      channel.sink.add("METADATA:$fileName");
      await Future.delayed(const Duration(milliseconds: 50));

      final io.File file = io.File(filePath);
      final Stream<List<int>> fileStream = file.openRead();

      await for (List<int> chunk in fileStream) {
        channel.sink.add(chunk);
      }

      if (!mounted) return;
      setState(() { statusMessage = "Transfer Complete!"; });

    } catch (e) {
      if (mounted) {
        setState(() { statusMessage = "Error sending file: $e"; });
      }
    }
  }

  @override
  void dispose() {
    channel.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          children: [
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isConnected ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
              ),
              child: Icon(
                isConnected ? Icons.check_circle : Icons.sync,
                size: 80,
                color: isConnected ? Colors.greenAccent : Colors.orangeAccent,
              ),
            ),
            const SizedBox(height: 32),
            Text(isConnected ? "Connected to" : "Connecting to...", style: const TextStyle(color: Colors.grey, fontSize: 16)),
            const SizedBox(height: 8),
            Text(widget.peerName, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            
            if (progress > 0) ...[
              const SizedBox(height: 24),
              LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                borderRadius: BorderRadius.circular(10),
                backgroundColor: Colors.grey.shade800,
                color: progress == 1.0 ? Colors.greenAccent : const Color(0xFF3B82F6),
              ),
            ],
            
            const SizedBox(height: 16),
            Text(statusMessage, style: const TextStyle(color: Colors.grey, fontSize: 16)),
            const Spacer(),
            
            SizedBox(
              width: double.infinity,
              height: 64,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isConnected ? const Color(0xFF3B82F6) : Colors.grey.shade800,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: isConnected ? pickAndSendFile : null,
                icon: const Icon(Icons.send_rounded, color: Colors.white, size: 28),
                label: const Text("Send File", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
