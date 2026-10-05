import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../widgets/custom_pull_to_refresh.dart';
import '../utils/language_manager.dart';
import '../cubits/insights/insights_cubit.dart';

/// Экран AI-инсайтов.
class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => InsightsCubit()..loadInsights(),
      child: const _InsightsScreenView(),
    );
  }
}

class _InsightsScreenView extends StatelessWidget {
  const _InsightsScreenView();

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
        onRefresh: () => context.read<InsightsCubit>().loadInsights(),
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
              BlocBuilder<InsightsCubit, InsightsState>(
                builder: (context, state) {
                  if (state is InsightsLoaded && state.generatedAt != null) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          Icon(Icons.schedule,
                              size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 6),
                          Text(
                            '${LanguageManager.t('insights_updated_prefix')}: ${LanguageManager.formatDate(state.generatedAt!)}',
                            key: const Key('insights_updated_at'),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
              BlocBuilder<InsightsCubit, InsightsState>(
                builder: (context, state) {
                  bool showCacheHint = false;
                  if (state is InsightsLoaded &&
                      (state.generatedAt != null ||
                          (!state.insights.contains(
                              LanguageManager.t('insight_login_hint'))))) {
                    showCacheHint = true;
                  }
                  if (showCacheHint) {
                    return Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline,
                              size: 15, color: Colors.blueGrey.shade500),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              LanguageManager.t('insights_cache_hint'),
                              key: const Key('insights_cache_hint'),
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Colors.blueGrey.shade700,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
              const SizedBox(height: 12),
              Expanded(
                child: BlocBuilder<InsightsCubit, InsightsState>(
                  builder: (context, state) {
                    if (state is InsightsLoading || state is InsightsInitial) {
                      return const Center(
                          child: CircularProgressIndicator(color: primaryTeal));
                    } else if (state is InsightsNetworkError) {
                      return _buildNoNetworkPlaceholder();
                    } else if (state is InsightsError) {
                      return Center(
                          child: Text(state.message,
                              style: const TextStyle(color: Colors.red)));
                    } else if (state is InsightsUnauthenticated) {
                      return ListView.builder(
                        physics: const ClampingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        itemCount: 1,
                        itemBuilder: (context, index) {
                          return _buildInsightCard(state.hint, primaryTeal);
                        },
                      );
                    } else if (state is InsightsLoaded) {
                      return ListView.builder(
                        physics: const ClampingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        itemCount: state.insights.length,
                        itemBuilder: (context, index) {
                          return _buildInsightCard(
                              state.insights[index], primaryTeal);
                        },
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInsightCard(String text, Color primaryTeal) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome, color: primaryTeal, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                  fontSize: 14, color: Colors.black87, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
