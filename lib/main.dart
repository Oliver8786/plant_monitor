import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login.dart';
import 'firebase_options.dart';

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

  final Map<TimeRange, List<FlSpot>> _fakeData = {
    TimeRange.daily: [
      FlSpot(0, 20),
      FlSpot(4, 50),
      FlSpot(8, 30),
      FlSpot(12, 70),
      FlSpot(16, 55),
      FlSpot(20, 65),
      FlSpot(24, 40),
    ],
    TimeRange.monthly: [
      FlSpot(1, 40),
      FlSpot(5, 60),
      FlSpot(10, 55),
      FlSpot(15, 80),
      FlSpot(20, 75),
      FlSpot(25, 90),
      FlSpot(30, 70),
    ],
    TimeRange.yearly: [
      FlSpot(1, 30),
      FlSpot(3, 50),
      FlSpot(6, 60),
      FlSpot(9, 70),
      FlSpot(12, 55),
    ],
  };

  final List<String> _tips = [
    "Water your plant early in the morning or late in the evening.",
    "Ensure your plant gets at least 6 hours of indirect sunlight daily.",
    "Use well-draining soil to prevent root rot.",
    "Prune dead leaves regularly to encourage growth.",
    "Fertilize monthly with balanced nutrients during growing season.",
  ];

  String get _lastWatered => "Today at 7:30 AM";

  double get _waterStatus => 75; // percentage

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

  Widget _buildChart() {
    final spots = _fakeData[_selectedRange]!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lineColor = isDark ? Colors.grey.shade300 : Colors.grey.shade900;
    final belowBarColor = isDark ? Colors.grey.shade700.withOpacity(0.3) : Colors.grey.shade300.withOpacity(0.3);
    final gridColor = isDark ? Colors.grey.shade700 : Colors.grey.shade300;
    final borderColor = isDark ? Colors.grey.shade700 : Colors.grey.shade300;

    return LineChart(
      LineChartData(
        minX: spots.first.x,
        maxX: spots.last.x,
        minY: 0,
        maxY: 100,
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: 20,
              getTitlesWidget: (value, meta) {
                return Text('${value.toInt()}%', style: TextStyle(fontSize: 12, color: lineColor));
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: (spots.last.x - spots.first.x) / 4,
              getTitlesWidget: (value, meta) {
                String label;
                switch (_selectedRange) {
                  case TimeRange.daily:
                    label = '${value.toInt()}h';
                    break;
                  case TimeRange.monthly:
                    label = '${value.toInt()}d';
                    break;
                  case TimeRange.yearly:
                    label = '${value.toInt()}m';
                    break;
                }
                return Text(label, style: TextStyle(fontSize: 12, color: lineColor));
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
          verticalInterval: (spots.last.x - spots.first.x) / 4,
          getDrawingHorizontalLine: (value) => FlLine(color: gridColor, strokeWidth: 0.5),
          getDrawingVerticalLine: (value) => FlLine(color: gridColor, strokeWidth: 0.5),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            bottom: BorderSide(color: borderColor, width: 1),
            left: BorderSide(color: borderColor, width: 1),
            top: BorderSide(color: Colors.transparent),
            right: BorderSide(color: Colors.transparent),
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
  }

  Widget _buildWaterStatus() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = theme.cardColor;
    final textColor = theme.textTheme.titleMedium?.color ?? Colors.black87;
    final progressColor = isDark ? Colors.grey.shade300 : Colors.grey.shade900;
    final backgroundProgressColor = isDark ? Colors.grey.shade700 : Colors.grey.shade300;
    final statusTextColor = isDark ? Colors.white70 : Colors.black87;
    final bodyTextColor = isDark ? Colors.white60 : Colors.black54;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                    value: _waterStatus / 100,
                    strokeWidth: 8,
                    color: progressColor,
                    backgroundColor: backgroundProgressColor,
                  ),
                ),
                Text(
                  '${_waterStatus.toInt()}%',
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
                  Text('Water Status', style: theme.textTheme.titleMedium?.copyWith(color: textColor)),
                  const SizedBox(height: 6),
                  Text(
                    _waterStatus > 70
                        ? 'Your plant is well hydrated.'
                        : _waterStatus > 40
                            ? 'Consider watering soon.'
                            : 'Water your plant now!',
                    style: theme.textTheme.bodyMedium?.copyWith(color: bodyTextColor, fontWeight: FontWeight.w400),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLastWatered() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = theme.cardColor;
    final iconColor = isDark ? Colors.grey.shade300 : Colors.grey.shade700;
    final titleColor = theme.textTheme.titleMedium?.color ?? Colors.black87;
    final subtitleColor = theme.textTheme.bodyMedium?.color ?? Colors.black54;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: cardColor,
      shadowColor: isDark ? Colors.black45 : Colors.grey.shade300,
      child: ListTile(
        leading: Icon(Icons.water_drop_outlined, color: iconColor, size: 32),
        title: Text('Last Watered', style: theme.textTheme.titleMedium?.copyWith(color: titleColor)),
        subtitle: Text(_lastWatered, style: theme.textTheme.bodyMedium?.copyWith(color: subtitleColor)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        horizontalTitleGap: 8,
      ),
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
                                    'Soil Moisture ($_rangeLabel)',
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