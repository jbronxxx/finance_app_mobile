import 'package:flutter/material.dart';

/// Экран AI-инсайтов.
///
/// Пока показывает статичный демонстрационный набор рекомендаций — на
/// бэкенде эндпоинт `/insights` (см. [ApiConfig.insights]) ещё не подключён
/// к этому экрану, тексты нужно будет заменить на реальный запрос к API.
class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryTeal = Color(0xFF0F766E);

    final List<String> insights = [
      'В этом месяце ваши расходы на категорию "Food" выросли на 15% по сравнению с прошлым.',
      'Отличная работа! Вы укладываетесь в месячный лимит по транспорту.',
      'Рекомендуем отложить не менее 10% от текущего баланса для формирования подушки безопасности.',
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('AI-Инсайты и Аналитика', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
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
              child: const Row(
                children: [
                  Icon(Icons.lightbulb, color: Colors.white, size: 36),
                SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Умный анализ ваших финансов на базе ИИ',
                      style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Персональные рекомендации',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: insights.length,
                itemBuilder: (context, index) {
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
                        const Icon(Icons.auto_awesome, color: primaryTeal, size: 24),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            insights[index],
                            style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.4),
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
    );
  }
}
