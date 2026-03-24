import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/firebase_service.dart';
import '../utils/app_colors.dart';

class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  List<Map<String, dynamic>> _data = [];
  Map<String, int> _counts = {};
  bool _loading = true;
  bool _showUnique = true; // true: unique users, false: session opens

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        FirebaseService.fetchAnalytics(days: 30),
        FirebaseService.fetchPostCounts(),
      ]);
      if (mounted) {
        setState(() {
          _data = results[0] as List<Map<String, dynamic>>;
          _counts = results[1] as Map<String, int>;
        });
      }
    } catch (e) {
      debugPrint('[AdminAnalytics] load failed: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('App Analytics',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Content counts
                  _ContentCountsRow(counts: _counts),
                  const SizedBox(height: 16),
                  // Activity summary
                  _SummaryRow(data: _data),
                  const SizedBox(height: 20),
                  _ToggleBar(
                    showUnique: _showUnique,
                    onChanged: (v) => setState(() => _showUnique = v),
                  ),
                  const SizedBox(height: 12),
                  _ChartCard(data: _data, showUnique: _showUnique),
                  const SizedBox(height: 20),
                  _DataTable(data: _data),
                ],
              ),
            ),
    );
  }
}

// ─── Content Counts ─────────────────────────────────────────────────────────

class _ContentCountsRow extends StatelessWidget {
  final Map<String, int> counts;
  const _ContentCountsRow({required this.counts});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Content',
          style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _CountCard(
              icon: Icons.chat_bubble_outline,
              label: 'Tweets',
              value: '${counts['tweetCount'] ?? 0}',
              color: AppColors.accent,
            ),
            const SizedBox(width: 8),
            _CountCard(
              icon: Icons.description_outlined,
              label: 'Reports',
              value: '${counts['reportCount'] ?? 0}',
              color: AppColors.primary,
            ),
            const SizedBox(width: 8),
            _CountCard(
              icon: Icons.menu_book_outlined,
              label: 'Dictionary',
              value: '${counts['dictCount'] ?? 0}',
              color: AppColors.primaryDark,
            ),
            const SizedBox(width: 8),
            _CountCard(
              icon: Icons.people_outline,
              label: 'Users',
              value: '${counts['userCount'] ?? 0}',
              color: Colors.blueGrey,
            ),
          ],
        ),
      ],
    );
  }
}

class _CountCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _CountCard(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color)),
            Text(label,
                style: const TextStyle(
                    fontSize: 10, color: AppColors.textSecondary),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ─── Activity Summary ────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  const _SummaryRow({required this.data});

  @override
  Widget build(BuildContext context) {
    final totalOpens = data.fold<int>(0, (s, d) => s + (d['openCount'] as int));
    final peakUnique = data.fold<int>(0, (s, d) {
      final v = d['uniqueUsers'] as int;
      return v > s ? v : s;
    });
    final todayOpens = data.isNotEmpty ? (data.last['openCount'] as int) : 0;
    final todayUnique = data.isNotEmpty ? (data.last['uniqueUsers'] as int) : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Activity (30 days)',
          style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _StatCard(label: "Today's opens", value: '$todayOpens'),
            const SizedBox(width: 8),
            _StatCard(label: "Today's users", value: '$todayUnique'),
            const SizedBox(width: 8),
            _StatCard(label: '30-day opens', value: '$totalOpens'),
            const SizedBox(width: 8),
            _StatCard(label: 'Peak DAU', value: '$peakUnique'),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    fontSize: 10, color: AppColors.textSecondary),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ─── Toggle ──────────────────────────────────────────────────────────────────

class _ToggleBar extends StatelessWidget {
  final bool showUnique;
  final ValueChanged<bool> onChanged;
  const _ToggleBar({required this.showUnique, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ToggleBtn(
          label: 'Unique Users',
          active: showUnique,
          onTap: () => onChanged(true),
        ),
        const SizedBox(width: 8),
        _ToggleBtn(
          label: 'Session Opens',
          active: !showUnique,
          onTap: () => onChanged(false),
        ),
      ],
    );
  }
}

class _ToggleBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _ToggleBtn(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active ? AppColors.primary : AppColors.divider),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: active ? Colors.white : AppColors.textSecondary,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

// ─── Chart ───────────────────────────────────────────────────────────────────

class _ChartCard extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final bool showUnique;
  const _ChartCard({required this.data, required this.showUnique});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(
            child: Text('No data',
                style:
                    TextStyle(color: AppColors.textSecondary, fontSize: 13))),
      );
    }

    final values = data
        .map((d) =>
            (showUnique ? d['uniqueUsers'] : d['openCount']) as int)
        .toList();
    final maxY = (values.fold<int>(0, (s, v) => v > s ? v : s) * 1.3)
        .ceilToDouble()
        .clamp(4.0, double.infinity);

    final spots = List.generate(
        data.length, (i) => FlSpot(i.toDouble(), values[i].toDouble()));

    return Container(
      height: 220,
      padding: const EdgeInsets.fromLTRB(0, 16, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                const FlLine(color: AppColors.divider, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (v, _) => Text(
                  v.toInt().toString(),
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.textSecondary),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: (data.length / 6).ceilToDouble(),
                getTitlesWidget: (v, _) {
                  final idx = v.toInt();
                  if (idx < 0 || idx >= data.length) return const SizedBox();
                  final date = data[idx]['date'] as String;
                  final parts = date.split('-');
                  return Text(
                    '${parts[1]}/${parts[2]}',
                    style: const TextStyle(
                        fontSize: 9, color: AppColors.textSecondary),
                  );
                },
              ),
            ),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: AppColors.primary,
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.primary.withOpacity(0.08),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => spots.map((s) {
                final idx = s.spotIndex;
                final date = data[idx]['date'] as String;
                final parts = date.split('-');
                return LineTooltipItem(
                  '${parts[1]}/${parts[2]}\n${s.y.toInt()} ${showUnique ? 'users' : 'opens'}',
                  const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Data Table ──────────────────────────────────────────────────────────────

class _DataTable extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  const _DataTable({required this.data});

  @override
  Widget build(BuildContext context) {
    final recent = data.reversed.take(14).toList();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: Text('Last 14 days',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary)),
          ),
          const Divider(height: 1, color: AppColors.divider),
          ...recent.map((d) {
            final parts = (d['date'] as String).split('-');
            return Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(
                    children: [
                      Text('${parts[1]}/${parts[2]}',
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.textPrimary)),
                      const Spacer(),
                      _Chip(
                          label: 'Users',
                          value: '${d['uniqueUsers']}',
                          color: AppColors.primary),
                      const SizedBox(width: 8),
                      _Chip(
                          label: 'Opens',
                          value: '${d['openCount']}',
                          color: AppColors.accent),
                    ],
                  ),
                ),
                if (d != recent.last)
                  const Divider(
                      height: 1, color: AppColors.divider, indent: 14),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Chip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
                text: '$label: ',
                style: TextStyle(fontSize: 11, color: color.withOpacity(0.8))),
            TextSpan(
                text: value,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color)),
          ],
        ),
      ),
    );
  }
}
