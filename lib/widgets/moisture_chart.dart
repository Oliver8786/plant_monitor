import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum TimeRange { daily, monthly, yearly } // move this to a shared place later

typedef RawToPercent = double Function(int raw);

class MoistureChart extends StatelessWidget {
  const MoistureChart({
    super.key,
    required this.range,
    required this.query,
    required this.rawToPercent,
  });

  final TimeRange range;
  final Query<Map<String, dynamic>> query;
  final RawToPercent rawToPercent;

  @override
  Widget build(BuildContext context) {
    // Fixed styling (same in light & dark mode) to match the glass UI.
    final lineColor = Colors.white.withOpacity(0.90);
    final belowBarColor = Colors.white.withOpacity(0.10);
    final gridColor = Colors.white.withOpacity(0.12);
    final borderColor = Colors.white.withOpacity(0.14);

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
        final firstTs =
            (docs.first.data()['timestamp'] as Timestamp?) ?? Timestamp.now();
        final firstMs = firstTs.toDate().millisecondsSinceEpoch;

        double xScaleDivisor;
        switch (range) {
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

          final rawInt = raw is int ? raw : (raw is num ? raw.toInt() : null);
          if (rawInt == null) continue;

          final y = rawToPercent(rawInt);
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
          switch (range) {
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
                  getTitlesWidget: (value, meta) => Text(
                    '${value.toInt()}%',
                    style: TextStyle(fontSize: 12, color: lineColor),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: xInterval,
                  getTitlesWidget: (value, meta) => Text(
                    xLabel(value),
                    style: TextStyle(fontSize: 12, color: lineColor),
                  ),
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
}