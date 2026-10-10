import 'package:flutter/material.dart';
import 'package:talker_flutter/talker_flutter.dart';
import '../config/environment.dart';
import '../utils/app_logger.dart';
import '../services/services.dart';

class DebugMenuScreen extends StatefulWidget {
  const DebugMenuScreen({super.key});

  @override
  State<DebugMenuScreen> createState() => _DebugMenuScreenState();
}

class _DebugMenuScreenState extends State<DebugMenuScreen> {
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    final version = await AppInfoService.instance.getVersionString();
    if (!mounted) return;
    setState(() {
      _appVersion = version;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Debug Menu')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Environment',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 8),
          DropdownButton<Environment>(
            value: EnvironmentConfig.current,
            isExpanded: true,
            items: Environment.values.map((env) {
              return DropdownMenuItem(
                value: env,
                child: Text(env.name.toUpperCase()),
              );
            }).toList(),
            onChanged: (val) async {
              if (val != null) {
                await EnvironmentConfig.setEnvironment(val);
                setState(() {});
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Environment changed to ${val.name.toUpperCase()}. Session reset.'),
                  ),
                );
              }
            },
          ),
          const Divider(height: 32),
          const Text('App Info',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 8),
          Text('Version: $_appVersion'),
          Text('Base URL: ${EnvironmentConfig.baseUrl}'),
          const Divider(height: 32),
          const Text('Tools',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TalkerScreen(talker: talker),
                ),
              );
            },
            child: const Text('Open Logs (Talker)'),
          ),
          ElevatedButton(
            onPressed: () async {
              await ApiService.instance.clearAllUserData();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cache & Tokens cleared')),
              );
            },
            child: const Text('Clear Cache & Tokens'),
          ),
        ],
      ),
    );
  }
}
