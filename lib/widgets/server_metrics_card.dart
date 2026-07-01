import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tiketi_mkononi/models/server_metrics.dart'; // For date formatting

class ServerMetricsCard extends StatelessWidget {
  final ServerMetrics serverMetrics;
  final Function refreshMethod;
  
  const ServerMetricsCard({super.key, required this.serverMetrics, required this.refreshMethod});

  @override
  Widget build(BuildContext context) {
    var formattedDate = DateFormat('MMM dd, yyyy - hh:mm a').format(
      DateTime.parse(serverMetrics.timestamp).toLocal()
    );
    
    final uptime = Duration(seconds: int.parse(serverMetrics.uptimeSeconds));
    final uptimeString = '${uptime.inHours}h ${uptime.inMinutes.remainder(60)}m ${uptime.inSeconds.remainder(60)}s';

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Server Metrics',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                ActionChip(
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  onPressed: () async {
                    await refreshMethod();
                    formattedDate = DateFormat('MMM dd, yyyy - hh:mm a').format(
                      DateTime.parse(serverMetrics.timestamp).toLocal()
                    );
                  },
                  label: Text(
                    'Refresh',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Updated: $formattedDate', 
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
            const Divider(height: 24),
            
            // Metrics Grid
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 1.5,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                _buildMetricItem(
                  context,
                  'Requests',
                  '${serverMetrics.requestCount}',
                  Icons.http,
                ),
                _buildMetricItem(
                  context,
                  'Avg Duration',
                  '${serverMetrics.avgRequestDurationMs}ms',
                  Icons.timer,
                ),
                _buildMetricItem(
                  context,
                  'Errors',
                  '${serverMetrics.errorCount}',
                  Icons.warning,
                  isError: serverMetrics.errorCount > 0,
                ),
                _buildMetricItem(
                  context,
                  'Uptime',
                  uptimeString,
                  Icons.timelapse,
                ),
                _buildMetricItem(
                  context,
                  'DNS',
                  serverMetrics.dnsResolution ? "OK" : "FAILED" ,
                  Icons.dns,
                  isError: serverMetrics.dnsResolution ? false : true,
                ),
                _buildMetricItem(
                  context,
                  'Active Users',
                  '${serverMetrics.dailyActiveUsers}',
                  Icons.people,
                ),
                _buildMetricItem(
                  context,
                  'SMS Count',
                  '${serverMetrics.smsBalance}',
                  Icons.dns,
                  isError: serverMetrics.dnsResolution ? false : true,
                ),
                _buildMetricItem(
                  context,
                  'SMS in TSH',
                  '${serverMetrics.smsBalance2}',
                  Icons.money,
                  isError: serverMetrics.dnsResolution ? false : true, 
                ),
                _buildMetricItem(
                  context,
                  'MT Tx',
                  'TZS${NumberFormat('#,##0').format(serverMetrics.monthyTotalTransactions)}',
                  Icons.money,
                  isError: serverMetrics.dnsResolution ? false : true,
                ),
                _buildMetricItem(
                  context,
                  'LMT Tx',
                  'TZS${NumberFormat('#,##0').format(serverMetrics.lastMonthyTotalTransactions)}',
                  Icons.money,
                  isError: serverMetrics.dnsResolution ? false : true,
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Memory Section
            _buildSectionHeader(context, 'Memory Usage (MB)'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildCircularMetric(
                    context,
                    'RSS',
                    serverMetrics.memoryUsageMB.rss,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildCircularMetric(
                    context,
                    'Heap Used',
                    serverMetrics.memoryUsageMB.heapUsed,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildCircularMetric(
                    context,
                    'Heap Total',
                    serverMetrics.memoryUsageMB.heapTotal,
                    Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // CPU Section
            _buildSectionHeader(context, 'CPU Load Average'),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildCpuLoadItem(context, '1 min', serverMetrics.cpuLoadAvg.m1),
                _buildCpuLoadItem(context, '5 min', serverMetrics.cpuLoadAvg.m5),
                _buildCpuLoadItem(context, '15 min', serverMetrics.cpuLoadAvg.m15),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.secondary,
      ),
    );
  }

  Widget _buildMetricItem(
    BuildContext context,
    String title,
    String value,
    IconData icon, {
    bool isError = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
      ),
      padding:
      const EdgeInsets.symmetric(
        vertical: 12,
        horizontal: 8,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: isError 
              ? Colors.red 
              : Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
              Text(
                value,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: (isError || ((title == 'SMS Count') && (int.parse(value) < 200)))
                    ? Colors.red 
                    : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCircularMetric(
    BuildContext context,
    String title,
    String value,
    Color color,
  ) {
    return Column(
      children: [
        SizedBox(
          height: 50,
          width: 50,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: double.parse(value) / 100, // Adjust denominator based on expected max
                backgroundColor: color.withOpacity(0.2),
                color: color,
                strokeWidth: 6,
              ),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildCpuLoadItem(BuildContext context, String title, double value) {
    final color = value > 0.7 
      ? Colors.red 
      : value > 0.4 
        ? Colors.orange 
        : Colors.green;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.2),
          ),
          child: Icon(
            Icons.memory,
            size: 24,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Text(
          value.toStringAsFixed(2),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}