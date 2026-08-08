import 'package:flutter/material.dart';

import 'managed_config/managed_config_reader.dart';
import 'ui/managed_config_debug_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RoamKitDeviceApp());
}

class RoamKitDeviceApp extends StatelessWidget {
  const RoamKitDeviceApp({super.key, this.reader});

  final ManagedConfigReader? reader;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RoamKit Device',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0B3D2E)),
        useMaterial3: true,
      ),
      home: ManagedConfigDebugPage(
        reader: reader ?? ChannelManagedConfigReader(),
      ),
    );
  }
}
