import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/api_service.dart';
import '../widgets/custom_pull_to_refresh.dart';
import '../utils/app_error_handler.dart';
import '../utils/language_manager.dart';

/// Экран AI-инсайтов.
class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  bool _isLoading = false;
  List<String> _insights = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInsights();
  }

  Future<void> _loadInsights() async {
    if (!ApiService.instance.isAuthenticated) {
      setState(() {
        _insights = [
          LanguageManager.t('insight_login_hint'),
        ];
      });
      return;
    }

    // Проверка наличия интернета перед запросом
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      setState(() {
        _error = 'network_error';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (kDebugMode) debugPrint('[Insights] Loading insights via pull-to-refresh');
      final data = await ApiService.instance.getInsights();
      setState(() {
        _insights = List<String>.from(data['insights'] ?? []);
        if (_insights.isEmpty) {
          _insights = [LanguageManager.t('insight_no_data')];
        }
      });
    } catch (e) {
      if (mounted) {
        AppErrorHandler.show(context, e, title: LanguageManager.t('insights_header_title'));
        setState(() {
          _error = AppErrorHandler.getMessage(e);
        });
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildNoNetworkPlaceholder() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.wifi_off, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  LanguageManager.t('no_network_title'),
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    LanguageManager.t('no_network_desc'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black54),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryTeal = Color(0xFF0F766E);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(LanguageManager.t('insights_header_title'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: CustomPullToRefresh(
        onRefresh: _loadInsights,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lightbulb, color: Colors.white, size: 36),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        LanguageManager.t('insights_header_subtitle'),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                LanguageManager.t('personal_recs_title'),
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: primaryTeal))
                    : _error != null
                        ? _error == 'network_error'
                            ? _buildNoNetworkPlaceholder()
                            : Center(
                                child: Text(_error!,
                                    style: const TextStyle(color: Colors.red)))
                        : ListView.builder(
                            physics: const ClampingScrollPhysics(
                              parent: AlwaysScrollableScrollPhysics(),
                            ),
                            itemCount: _insights.length,
                            itemBuilder: (context, index) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border:
                                      Border.all(color: Colors.grey.shade200),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.auto_awesome,
                                        color: primaryTeal, size: 24),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Text(
                                        _insights[index],
                                        style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.black87,
                                            height: 1.4),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
