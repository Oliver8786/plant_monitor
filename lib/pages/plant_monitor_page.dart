import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../widgets/moisture_chart.dart';

class PlantMonitorPage extends StatefulWidget {
  const PlantMonitorPage({super.key});

  @override
  State<PlantMonitorPage> createState() => _PlantMonitorPageState();
}

class _PlantMonitorPageState extends State<PlantMonitorPage> {
  TimeRange _selectedRange = TimeRange.daily;

  final List<String> _tips = [
    "Water your plant early in the morning or late in the evening.",
    "Ensure your plant gets at least 6 hours of indirect sunlight daily.",
    "Use well-draining soil to prevent root rot.",
    "Prune dead leaves regularly to encourage growth.",
    "Fertilize monthly with balanced nutrients during growing season.",
  ];

  // --- Shared “glass” styling (same in light & dark mode) ---
  static const double _glassRadius = 18;
  static const double _glassBorderWidth = 1.2;

  static final Color _glassFill = Colors.white.withOpacity(0.14);
  static final Color _glassFillStrong = Colors.white.withOpacity(0.18);
  static final Color _glassBorder = Colors.white.withOpacity(0.22);
  static final Color _glassShadow = Colors.black.withOpacity(0.18);

  static final Color _textPrimary = Colors.white.withOpacity(0.92);
  static final Color _textSecondary = Colors.white.withOpacity(0.72);
  static final Color _textTertiary = Colors.white.withOpacity(0.60);

  static final Color _iconColor = Colors.white.withOpacity(0.85);
  static final Color _divider = Colors.white.withOpacity(0.12);

  Widget _glassCard({required Widget child, EdgeInsets? padding}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      decoration: BoxDecoration(
        color: _glassFillStrong,
        borderRadius: BorderRadius.circular(_glassRadius),
        border: Border.all(color: _glassBorder, width: _glassBorderWidth),
        boxShadow: [
          BoxShadow(
            color: _glassShadow,
            blurRadius: 14,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
        child: child,
      ),
    );
  }

  TextStyle get _hStyle => TextStyle(
        color: _textPrimary,
        fontWeight: FontWeight.w700,
        fontSize: 16,
        letterSpacing: 0.2,
      );

  TextStyle get _bStyle => TextStyle(
        color: _textSecondary,
        fontWeight: FontWeight.w500,
        fontSize: 13,
        height: 1.35,
      );

  TextStyle get _subtleStyle => TextStyle(
        color: _textTertiary,
        fontWeight: FontWeight.w500,
        fontSize: 12,
      );

  // Calibrate these two values from your real sensor readings.
  // DRY_RAW should be the typical raw value when the soil is dry.
  // WET_RAW should be the typical raw value right after watering.
  static const int DRY_RAW = 51000;
  static const int WET_RAW = 47500;

  double _rawToPercent(int raw) {
    // Map raw -> 0..100 (wet -> 100, dry -> 0)
    final denom = (DRY_RAW - WET_RAW);
    if (denom == 0) return 0;
    final v = (DRY_RAW - raw) / denom;
    final clamped = v.clamp(0.0, 1.0);
    return clamped * 100.0;
  }

  String _formatTimestamp(Timestamp ts) {
    final dt = ts.toDate().toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.day}/${dt.month}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
  }

  String get _rangeLabel {
    switch (_selectedRange) {
      case TimeRange.daily:
        return "Today";
      case TimeRange.monthly:
        return "This Month";
      case TimeRange.yearly:
        return "This Year";
    }
  }

  Query<Map<String, dynamic>> _readingsQueryForRange(TimeRange range) {
    final now = DateTime.now();
    DateTime start;
    switch (range) {
      case TimeRange.daily:
        start = now.subtract(const Duration(hours: 24));
        break;
      case TimeRange.monthly:
        start = now.subtract(const Duration(days: 30));
        break;
      case TimeRange.yearly:
        start = now.subtract(const Duration(days: 365));
        break;
    }

    return FirebaseFirestore.instance
        .collection('plant_readings')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .orderBy('timestamp', descending: false);
  }

  Widget _buildWaterStatus() {
    final latestQuery = FirebaseFirestore.instance
        .collection('plant_readings')
        .orderBy('timestamp', descending: true)
        .limit(1);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: latestQuery.snapshots(),
      builder: (context, snapshot) {
        double percent = 0;
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          final d = snapshot.data!.docs.first.data();
          final raw = d['moisture'];
          final rawInt = raw is int ? raw : (raw is num ? raw.toInt() : null);
          if (rawInt != null) {
            percent = _rawToPercent(rawInt);
          }
        }

        return _glassCard(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
          child: Row(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 74,
                    height: 74,
                    child: CircularProgressIndicator(
                      value: percent / 100,
                      strokeWidth: 8,
                      color: Colors.white.withOpacity(0.95),
                      backgroundColor: Colors.white.withOpacity(0.20),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${percent.toInt()}%',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: _textPrimary,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text('moist', style: _subtleStyle),
                    ],
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.water_drop_outlined, color: _iconColor, size: 18),
                        const SizedBox(width: 8),
                        Text('Water Status', style: _hStyle),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      percent > 70
                          ? 'Your plant is well hydrated.'
                          : percent > 40
                              ? 'Consider watering soon.'
                              : 'Water your plant now!',
                      style: _bStyle,
                    ),
                    const SizedBox(height: 10),
                    Container(height: 1, color: _divider),
                    const SizedBox(height: 10),
                    Text('Tip: Aim for 45–75% for most houseplants.', style: _subtleStyle),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLastWatered() {
    final latestQuery = FirebaseFirestore.instance
        .collection('plant_readings')
        .orderBy('timestamp', descending: true)
        .limit(1);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: latestQuery.snapshots(),
      builder: (context, snapshot) {
        String subtitle = 'No readings yet';
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          final data = snapshot.data!.docs.first.data();
          final ts = data['timestamp'] as Timestamp?;
          if (ts != null) {
            subtitle = _formatTimestamp(ts);
          }
        }

        return _glassCard(
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _glassBorder, width: 1),
                ),
                child: Icon(Icons.schedule, color: _iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Last Reading', style: _hStyle),
                    const SizedBox(height: 6),
                    Text(subtitle, style: _bStyle),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlantTips() {
    return _glassCard(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.eco_outlined, color: _iconColor, size: 18),
              const SizedBox(width: 8),
              Text('Plant Care Tips', style: _hStyle),
            ],
          ),
          const SizedBox(height: 12),
          ..._tips.map(
            (tip) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle_outline, color: _iconColor, size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Text(tip, style: _bStyle)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRangeSelector() {
    final labels = <TimeRange, String>{
      TimeRange.daily: 'Daily',
      TimeRange.monthly: 'Monthly',
      TimeRange.yearly: 'Yearly',
    };

    final items = TimeRange.values;
    final selectedIndex = items.indexOf(_selectedRange);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _glassFill,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: _glassBorder, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: _glassShadow,
                    blurRadius: 12,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final totalW = constraints.maxWidth;
                  final segW = totalW / items.length;

                  return SizedBox(
                    height: 42,
                    child: Stack(
                      children: [
                        // Sliding selected pill
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          left: segW * selectedIndex,
                          top: 0,
                          bottom: 0,
                          width: segW,
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: Container(
                              decoration: BoxDecoration(
                                color: _glassFillStrong,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.22),
                                  width: 1,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Tap targets + labels
                        Row(
                          children: [
                            for (final range in items)
                              Expanded(
                                child: _GlassSegment(
                                  label: labels[range] ?? range.name,
                                  selected: range == _selectedRange,
                                  onTap: () {
                                    if (_selectedRange == range) return;
                                    setState(() => _selectedRange = range);
                                  },
                                  textPrimary: _textPrimary,
                                  textSecondary: _textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingTitlePill() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Align(
          alignment: Alignment.topCenter,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: _glassFillStrong,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: _glassBorder, width: _glassBorderWidth),
                  boxShadow: [
                    BoxShadow(
                      color: _glassShadow,
                      blurRadius: 14,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.spa_outlined, color: _iconColor, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Plant Monitor',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: _textPrimary,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/Login_Background.jpeg',
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            child: Center(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final bool isDesktop = constraints.maxWidth >= 1000;
                  final double containerWidth =
                      isDesktop ? 900 : double.infinity;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 64, 24, 24),
                    child: Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                          child: Container(
                            width: containerWidth,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.25),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 16,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ListView(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              padding: const EdgeInsets.only(bottom: 28),
                              children: [
                                _buildWaterStatus(),
                                _buildLastWatered(),
                                _buildRangeSelector(),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 12),
                                  child: Text(
                                    'Soil Moisture Readings ($_rangeLabel)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: _textPrimary,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  height: 220,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20),
                                    child: MoistureChart(
                                      range: _selectedRange,
                                      query:
                                          _readingsQueryForRange(_selectedRange),
                                      rawToPercent: _rawToPercent,
                                    ),
                                  ),
                                ),
                                _buildPlantTips(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          _buildFloatingTitlePill(),
        ],
      ),
    );
  }
}
class _GlassSegment extends StatelessWidget {
  const _GlassSegment({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.textPrimary,
    required this.textSecondary,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color textPrimary;
  final Color textSecondary;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        splashColor: Colors.white.withOpacity(0.08),
        highlightColor: Colors.white.withOpacity(0.04),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? textPrimary : textSecondary,
              fontWeight: FontWeight.w800,
              fontSize: 13,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}