
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

import '/backend/services/api_service.dart';
import '/flutter_flow/flutter_flow_charts.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/utils/refresh_loading_state.dart';
import '/widgets/common/back_chevron.dart';
import 'growth_tracking_page_model.dart';

export 'growth_tracking_page_model.dart';

class GrowthTrackingPageWidget extends StatefulWidget {
  const GrowthTrackingPageWidget({super.key});

  static String routeName = 'GrowthTrackingPage';
  static String routePath = '/growthTracking';

  @override
  State<GrowthTrackingPageWidget> createState() =>
      _GrowthTrackingPageWidgetState();
}

class _GrowthTrackingPageWidgetState extends State<GrowthTrackingPageWidget> {
  late GrowthTrackingPageModel _model;

  bool _loading = true;
  bool _hasCompletedFirstLoad = false;
  String _error = '';
  String _selectedPeriod = 'daily';
  DateTime? _selectedMonth;
  List<double> _values = [];
  List<String> _labels = [];
  double _growth = 0.0;

  double get _chartMaxY =>
      _values.isNotEmpty ? max(72.0, _values.reduce(max) * 1.2) : 72.0;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => GrowthTrackingPageModel());
    _loadGrowth();
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  Future<void> _loadGrowth() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final period = {
        'daily': 7,
        'weekly': 30,
        'monthly': 90,
        'yearly': 365,
      }[_selectedPeriod]!;

      final payload = await ApiService.getGrowthHistory(days: period);
      final history = payload['data'] is List ? payload['data'] as List : <dynamic>[];

      // normalize entries to (date, value)
      final entries = <Map<String, dynamic>>[];
      for (final item in history) {
        if (item is! Map<String, dynamic> && item is! Map) continue;
        final raw = item is Map<String, dynamic> ? item : Map<String, dynamic>.from(item as Map);
        final rawValue = raw['total'] ?? raw['value'] ?? raw['amount'] ?? 0;
        final value = double.tryParse(rawValue.toString()) ?? 0.0;
        final rawDateStr = raw['date']?.toString() ?? raw['day']?.toString() ?? raw['label']?.toString() ?? '';
        DateTime? parsed;
        try {
          parsed = DateTime.tryParse(rawDateStr);
        } catch (_) {
          parsed = null;
        }
        if (parsed == null) {
          final m = RegExp(r"(\d{4})[-/](\d{1,2})[-/](\d{1,2})").firstMatch(rawDateStr);
          if (m != null) {
            parsed = DateTime(int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!));
          }
        }
        if (parsed == null) continue;
        entries.add({'date': parsed.toUtc(), 'value': value});
      }

      entries.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));

      final List<double> values = [];
      final List<String> labels = [];

      if (_selectedPeriod == 'daily') {
        for (final e in entries) {
          values.add(e['value'] as double);
          labels.add(DateFormat('MM-dd').format(e['date'] as DateTime));
        }
      } else if (_selectedPeriod == 'weekly') {
        var weekIndex = 0;
        var accum = 0.0;
        var dayCount = 0;
        for (var i = 0; i < entries.length; i++) {
          accum += entries[i]['value'] as double;
          dayCount++;
          if (dayCount == 7 || i == entries.length - 1) {
            weekIndex++;
            values.add(accum);
            labels.add('Week $weekIndex');
            accum = 0.0;
            dayCount = 0;
          }
        }
      } else if (_selectedPeriod == 'monthly') {
        DateTime selectedMonth = _selectedMonth ?? (entries.isNotEmpty ? (entries.last['date'] as DateTime) : DateTime.now());
        selectedMonth = DateTime(selectedMonth.year, selectedMonth.month, 1).toUtc();
        final monthEntries = entries.where((e) {
          final d = e['date'] as DateTime;
          return d.year == selectedMonth.year && d.month == selectedMonth.month;
        }).toList();

        final buckets = List.generate(4, (_) => <Map<String, dynamic>>[]);
        for (final e in monthEntries) {
          final d = e['date'] as DateTime;
          final day = d.day;
          final bucketIndex = (day <= 7) ? 0 : (day <= 14) ? 1 : (day <= 21) ? 2 : 3;
          buckets[bucketIndex].add(e);
        }
        for (var i = 0; i < 4; i++) {
          final sum = buckets[i].fold<double>(0.0, (p, c) => p + (c['value'] as double));
          values.add(sum);
          labels.add('Week ${i + 1}');
        }
      } else if (_selectedPeriod == 'yearly') {
        final Map<int, double> byYear = {};
        for (final e in entries) {
          final d = e['date'] as DateTime;
          final y = d.year;
          byYear[y] = (byYear[y] ?? 0) + (e['value'] as double);
        }
        final sortedYears = byYear.keys.toList()..sort();
        for (final y in sortedYears) {
          values.add(byYear[y] ?? 0.0);
          labels.add(y.toString());
        }
      }

      final growth = (values.length > 1 && values.isNotEmpty && values.first > 0) ? ((values.last - values.first) / values.first) * 100 : 0.0;

      if (!mounted) return;
      setState(() {
        _values = values;
        _labels = labels;
        _growth = growth;
        _loading = false;
        _hasCompletedFirstLoad = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
        _hasCompletedFirstLoad = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);

    return Scaffold(
      backgroundColor: theme.primaryBackground,
      appBar: AppBar(
        leading: const BackChevron(),
        title: Text('Growth Tracking'),
        backgroundColor: theme.primaryBackground,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadGrowth,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Your growth overview',
                  style:
                      theme.titleMedium.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              // Month selector for monthly view
              if (_selectedPeriod == 'monthly')
                Builder(builder: (context) {
                  final now = DateTime.now();
                  final months = List<DateTime>.generate(12, (i) => DateTime(now.year, now.month - i, 1));
                  final selected = _selectedMonth ?? months.first;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        const Text('Month:'),
                        const SizedBox(width: 8),
                        DropdownButton<DateTime>(
                          value: selected,
                          items: months.map((m) {
                            return DropdownMenuItem<DateTime>(
                              value: m,
                              child: Text(DateFormat.yMMM().format(m)),
                            );
                          }).toList(),
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => _selectedMonth = v);
                            _loadGrowth();
                          },
                        ),
                      ],
                    ),
                  );
                }),
              Wrap(
                spacing: 8,
                children: [
                  _periodChip('Daily', 'daily'),
                  _periodChip('Weekly', 'weekly'),
                  _periodChip('Monthly', 'monthly'),
                  _periodChip('Yearly', 'yearly'),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                color: theme.primaryBackground,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text('Performance',
                                style: theme.titleMedium
                                    .copyWith(fontWeight: FontWeight.w700)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: theme.success.withAlpha(32),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${_growth.toStringAsFixed(1)}%',
                              style: theme.labelLarge.override(
                                fontWeight: FontWeight.w700,
                                color: theme.success,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (RefreshLoadingState.shouldShowInitialLoading(
                            isLoading: _loading,
                            hasCompletedFirstLoad: _hasCompletedFirstLoad,
                            hasContent: _values.isNotEmpty,
                          ))
                        Center(
                            child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 24),
                                child: CircularProgressIndicator()))
                      else if (_error.isNotEmpty)
                        Text(_error,
                            style:
                                theme.bodyMedium.override(color: theme.error))
                      else if (_values.isEmpty)
                        Text('No growth data available yet.',
                            style: theme.bodyMedium)
                      else
                        SizedBox(
                          height: 220,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: FlutterFlowLineChart(
                              data: [
                                FFLineChartData(
                                  xData: List.generate(_values.length,
                                      (index) => index.toDouble()),
                                  yData: _values,
                                  settings: LineChartBarData(
                                    color: theme.primary,
                                    barWidth: 2.5,
                                    isCurved: true,
                                    dotData: const FlDotData(show: false),
                                    belowBarData: BarAreaData(
                                        show: true, color: theme.primary10),
                                  ),
                                )
                              ],
                              chartStylingInfo: ChartStylingInfo(
                                backgroundColor: theme.primaryBackground,
                                showBorder: false,
                              ),
                              axisBounds: AxisBounds(
                                minX: 0,
                                minY: 0,
                                maxX: _values.isNotEmpty
                                    ? max(6.0, (_values.length - 1).toDouble())
                                    : 6.0,
                                maxY: _chartMaxY,
                              ),
                              xLabels: _labels,
                              xAxisLabelInfo: AxisLabelInfo(
                                showLabels: true,
                                labelTextStyle: theme.bodySmall.override(
                                    font: GoogleFonts.inter(),
                                    color: theme.secondaryText),
                                labelInterval: 1.0,
                                reservedSize: 26.0,
                              ),
                              yAxisLabelInfo: AxisLabelInfo(
                                showLabels: true,
                                labelTextStyle: theme.bodySmall.override(
                                    font: GoogleFonts.inter(),
                                    color: theme.secondaryText),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _periodChip('Daily', 'daily'),
                          const SizedBox(width: 8),
                          _periodChip('Weekly', 'weekly'),
                          const SizedBox(width: 8),
                          _periodChip('Monthly', 'monthly'),
                          const SizedBox(width: 8),
                          _periodChip('Yearly', 'yearly'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _periodChip(String label, String value) {
    final selected = _selectedPeriod == value;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    const selectedFillColor = AppTheme.accent;
    const selectedTextColor = AppTheme.onAccent;
    final unselectedTextColor = isDarkMode ? Colors.white : Colors.black87;

    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: selected ? selectedTextColor : unselectedTextColor,
          fontWeight: FontWeight.w600,
        ),
      ),
      selected: selected,
      onSelected: (_) {
        setState(() => _selectedPeriod = value);
        _loadGrowth();
      },
      backgroundColor: isDarkMode ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
      selectedColor: selectedFillColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(
          color: selected ? selectedFillColor : (isDarkMode ? Colors.white24 : Colors.black12),
          width: 1.2,
        ),
      ),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }
}
