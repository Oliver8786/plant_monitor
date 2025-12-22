import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login.dart';
import 'firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const PlantMonitorApp());
}

class PlantMonitorApp extends StatelessWidget {
  const PlantMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Plant Monitor',
      theme: ThemeData(
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.grey.shade300,
          brightness: Brightness.light,
          primary: Colors.grey.shade900,
          onPrimary: Colors.white,
          background: Colors.white,
          surface: Colors.white,
          onSurface: Colors.grey.shade900,
        ),
        scaffoldBackgroundColor: Colors.white,
        cardColor: Colors.white,
        textTheme: const TextTheme(
          titleMedium: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 18,
            letterSpacing: 0.15,
          ),
          bodyMedium: TextStyle(
            color: Colors.black54,
            fontSize: 14,
            letterSpacing: 0.25,
          ),
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.grey.shade800,
          brightness: Brightness.dark,
          primary: Colors.grey.shade100,
          onPrimary: Colors.black,
          background: Colors.grey.shade900,
          surface: Colors.grey.shade800,
          onSurface: Colors.grey.shade100,
        ),
        scaffoldBackgroundColor: Colors.grey.shade900,
        cardColor: Colors.grey.shade800,
        textTheme: const TextTheme(
          titleMedium: TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.w600,
            fontSize: 18,
            letterSpacing: 0.15,
          ),
          bodyMedium: TextStyle(
            color: Colors.white60,
            fontSize: 14,
            letterSpacing: 0.25,
          ),
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const AuthGate(),
    );
  }
}

class PlantMonitorPage extends StatefulWidget {
  const PlantMonitorPage({super.key});

  @override
  State<PlantMonitorPage> createState() => _PlantMonitorPageState();
}

enum TimeRange { daily, monthly, yearly }

class _PlantMonitorPageState extends State<PlantMonitorPage> {
  TimeRange _selectedRange = TimeRange.daily;

  final List<String> _tips = [
    "Water your plant early in the morning or late in the evening.",
    "Ensure your plant gets at least 6 hours of indirect sunlight daily.",
    "Use well-draining soil to prevent root rot.",
    "Prune dead leaves regularly to encourage growth.",
    "Fertilize monthly with balanced nutrients during growing season.",
  ];

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

  Widget _buildChart() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lineColor = isDark ? Colors.grey.shade300 : Colors.grey.shade900;
    final belowBarColor = isDark
        ? Colors.grey.shade700.withOpacity(0.3)
        : Colors.grey.shade300.withOpacity(0.3);
    final gridColor = isDark ? Colors.grey.shade700 : Colors.grey.shade300;
    final borderColor = isDark ? Colors.grey.shade700 : Colors.grey.shade300;

    final query = _readingsQueryForRange(_selectedRange);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text(
              'No data yet',
              style: TextStyle(color: lineColor.withOpacity(0.7)),
            ),
          );
        }

        final docs = snapshot.data!.docs;

        // Build points: x is time since first point (hours/days/months-ish), y is % moisture.
        final firstTs = (docs.first.data()['timestamp'] as Timestamp?) ?? Timestamp.now();
        final firstMs = firstTs.toDate().millisecondsSinceEpoch;

        double xScaleDivisor;
        switch (_selectedRange) {
          case TimeRange.daily:
            xScaleDivisor = 1000.0 * 60.0 * 60.0; // hours
            break;
          case TimeRange.monthly:
            xScaleDivisor = 1000.0 * 60.0 * 60.0 * 24.0; // days
            break;
          case TimeRange.yearly:
            xScaleDivisor = 1000.0 * 60.0 * 60.0 * 24.0 * 30.0; // ~months
            break;
        }

        final spots = <FlSpot>[];
        for (final d in docs) {
          final data = d.data();
          final ts = data['timestamp'] as Timestamp?;
          final raw = data['moisture'];
          if (ts == null || raw == null) continue;

          final ms = ts.toDate().millisecondsSinceEpoch;
          final x = (ms - firstMs) / xScaleDivisor;

          // Your server stores raw ADC in the field named "moisture".
          final rawInt = raw is int ? raw : (raw is num ? raw.toInt() : null);
          if (rawInt == null) continue;
          final y = _rawToPercent(rawInt);

          spots.add(FlSpot(x, y));
        }

        if (spots.isEmpty) {
          return Center(
            child: Text(
              'No valid points yet',
              style: TextStyle(color: lineColor.withOpacity(0.7)),
            ),
          );
        }

        final minX = spots.first.x;
        final maxX = spots.last.x;

        String xLabel(double v) {
          switch (_selectedRange) {
            case TimeRange.daily:
              return '${v.toInt()}h';
            case TimeRange.monthly:
              return '${v.toInt()}d';
            case TimeRange.yearly:
              return '${v.toInt()}m';
          }
        }

        final xInterval = (maxX - minX) <= 0 ? 1.0 : (maxX - minX) / 4.0;

        return LineChart(
          LineChartData(
            minX: minX,
            maxX: maxX,
            minY: 0,
            maxY: 100,
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  interval: 20,
                  getTitlesWidget: (value, meta) {
                    return Text(
                      '${value.toInt()}%',
                      style: TextStyle(fontSize: 12, color: lineColor),
                    );
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: xInterval,
                  getTitlesWidget: (value, meta) {
                    return Text(
                      xLabel(value),
                      style: TextStyle(fontSize: 12, color: lineColor),
                    );
                  },
                ),
              ),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: true,
              horizontalInterval: 20,
              verticalInterval: xInterval,
              getDrawingHorizontalLine: (value) =>
                  FlLine(color: gridColor, strokeWidth: 0.5),
              getDrawingVerticalLine: (value) =>
                  FlLine(color: gridColor, strokeWidth: 0.5),
            ),
            borderData: FlBorderData(
              show: true,
              border: Border(
                bottom: BorderSide(color: borderColor, width: 1),
                left: BorderSide(color: borderColor, width: 1),
                top: const BorderSide(color: Colors.transparent),
                right: const BorderSide(color: Colors.transparent),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: lineColor,
                barWidth: 3,
                dotData: FlDotData(show: false),
                belowBarData: BarAreaData(show: true, color: belowBarColor),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWaterStatus() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = theme.cardColor;
    final textColor = theme.textTheme.titleMedium?.color ?? Colors.black87;
    final progressColor = isDark ? Colors.grey.shade300 : Colors.grey.shade900;
    final backgroundProgressColor =
        isDark ? Colors.grey.shade700 : Colors.grey.shade300;
    final statusTextColor = isDark ? Colors.white70 : Colors.black87;
    final bodyTextColor = isDark ? Colors.white60 : Colors.black54;

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

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
          elevation: 3,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          color: cardColor,
          shadowColor: isDark ? Colors.black45 : Colors.grey.shade300,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 28),
            child: Row(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 72,
                      height: 72,
                      child: CircularProgressIndicator(
                        value: percent / 100,
                        strokeWidth: 8,
                        color: progressColor,
                        backgroundColor: backgroundProgressColor,
                      ),
                    ),
                    Text(
                      '${percent.toInt()}%',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                        color: statusTextColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 28),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Water Status',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(color: textColor)),
                      const SizedBox(height: 6),
                      Text(
                        percent > 70
                            ? 'Your plant is well hydrated.'
                            : percent > 40
                                ? 'Consider watering soon.'
                                : 'Water your plant now!',
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: bodyTextColor,
                            fontWeight: FontWeight.w400),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLastWatered() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = theme.cardColor;
    final iconColor = isDark ? Colors.grey.shade300 : Colors.grey.shade700;
    final titleColor = theme.textTheme.titleMedium?.color ?? Colors.black87;
    final subtitleColor = theme.textTheme.bodyMedium?.color ?? Colors.black54;

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

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
          elevation: 3,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          color: cardColor,
          shadowColor: isDark ? Colors.black45 : Colors.grey.shade300,
          child: ListTile(
            leading: Icon(Icons.water_drop_outlined,
                color: iconColor, size: 32),
            title: Text('Last Reading',
                style: theme.textTheme.titleMedium?.copyWith(color: titleColor)),
            subtitle: Text(subtitle,
                style:
                    theme.textTheme.bodyMedium?.copyWith(color: subtitleColor)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            horizontalTitleGap: 8,
          ),
        );
      },
    );
  }

  Widget _buildPlantTips() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = theme.cardColor;
    final titleColor = theme.textTheme.titleMedium?.color ?? Colors.black87;
    final bodyColor = theme.textTheme.bodyMedium?.color ?? Colors.black54;
    final iconColor = isDark ? Colors.grey.shade300 : Colors.grey.shade800;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: cardColor,
      shadowColor: isDark ? Colors.black45 : Colors.grey.shade300,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Plant Care Tips', style: theme.textTheme.titleMedium?.copyWith(color: titleColor)),
            const SizedBox(height: 14),
            ..._tips.map((tip) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle_outline, color: iconColor, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text(tip, style: theme.textTheme.bodyMedium?.copyWith(color: bodyColor))),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildRangeSelector() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final selectedColor = isDark ? Colors.grey.shade100 : Colors.grey.shade900;
    final backgroundColor = isDark ? Colors.grey.shade800 : Colors.grey.shade200;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: TimeRange.values.map((range) {
          final isSelected = _selectedRange == range;
          final label = range.name[0].toUpperCase() + range.name.substring(1);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: ChoiceChip(
              label: Text(label),
              selected: isSelected,
              selectedColor: selectedColor,
              backgroundColor: backgroundColor,
              labelStyle: TextStyle(
                color: isSelected ? (isDark ? Colors.black : Colors.white) : (isDark ? Colors.grey.shade300 : Colors.black87),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
              side: BorderSide(color: isSelected ? selectedColor : backgroundColor),
              onSelected: (_) {
                setState(() {
                  _selectedRange = range;
                });
              },
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              showCheckmark: false,
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final titleColor = theme.textTheme.titleMedium?.color ?? Colors.black87;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                offset: const Offset(0, 1),
                blurRadius: 4,
                spreadRadius: 0,
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Center(
              child: Text(
                'Plant Monitor',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                  color: titleColor,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ),
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
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
                  final double containerWidth = isDesktop ? 900 : double.infinity;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
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
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  child: Text(
                                    'Soil Moisture Readings ($_rangeLabel)',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: titleColor,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  height: 220,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 20),
                                    child: _buildChart(),
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
        ],
      ),
    );
  }
}

/// Shows appropriate page depending on FirebaseAuth state.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Show loading indicator while checking auth state
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData && snapshot.data != null) {
          // User is signed in
          return PlantMonitorPage();
        } else {
          // User is NOT signed in
          return LoginPage();
        }
      },
    );
  }
}