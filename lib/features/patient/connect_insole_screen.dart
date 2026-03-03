
import 'package:flutter/material.dart';

class _Device {
  final String name;
  final String address;
  _Device({required this.name, required this.address});
}

class ConnectInsoleScreen extends StatefulWidget {
  const ConnectInsoleScreen({super.key});

  @override
  State<ConnectInsoleScreen> createState() => _ConnectInsoleScreenState();
}

class _ConnectInsoleScreenState extends State<ConnectInsoleScreen> {
  int selectedDevice = 0;
  final List<_Device> devices = [
    _Device(name: "Noura's Device", address: 'A2:B3:C4:D5:E6:F7'),
    _Device(name: "Lama's Device", address: '00:1A:2B:3C:4D:5E'),
    _Device(name: "Asma's Device", address: 'B9:8A:7B:6C:5D:4E'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF64ADB3), Color(0xFF3D6A99)],
              ),
            ),
            padding: const EdgeInsets.only(top: 60, bottom: 24),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Color(0xFF85B1D2), width: 7),
                    color: Color(0xFF2F4A5F),
                  ),
                  child: const Icon(Icons.bluetooth, size: 70, color: Colors.white),
                ),
                const SizedBox(height: 18),
                const Text(
                  'CONNECT INSOLE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          // Devices
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            child: Column(
              children: List.generate(devices.length, (i) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedDevice = i;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      decoration: BoxDecoration(
                        color: selectedDevice == i ? Color(0xFF64ADB3) : Color(0xFF85B1D2),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: selectedDevice == i
                            ? [
                                BoxShadow(
                                  color: Color(0xFF3D6A99).withOpacity(0.15),
                                  blurRadius: 8,
                                  offset: Offset(0, 4),
                                ),
                              ]
                            : [],
                      ),
                      child: ListTile(
                        title: Text(
                          devices[i].name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Text(
                          devices[i].address,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: selectedDevice == i ? Color(0xFF3D6A99) : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: selectedDevice == i ? Color(0xFF3D6A99) : Color(0xFF64ADB3),
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            selectedDevice == i ? 'Connected' : 'Connect',
                            style: TextStyle(
                              color: selectedDevice == i ? Colors.white : Color(0xFF3D6A99),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          // Start Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3D6A99), Color(0xFF2F4A5F)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: EdgeInsets.zero,
                    elevation: 0,
                  ),
                  onPressed: () {
                    final device = devices[selectedDevice];
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Color(0xFF64ADB3)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'تم الاتصال بنجاح بـ ${device.name}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                        backgroundColor: const Color(0xFF3D6A99),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        elevation: 8,
                      ),
                    );
                  },
                  child: const Center(
                    child: Text(
                      "LET'S START!",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}






