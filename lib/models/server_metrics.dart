class ServerMetrics {
  final String timestamp;
  final int requestCount;
  final int dailyActiveUsers;
  final double monthyTotalTransactions;
  final double lastMonthyTotalTransactions;
  final String avgRequestDurationMs;
  final int errorCount;
  final MemoryUsage memoryUsageMB;
  final CpuLoad cpuLoadAvg;
  final String uptimeSeconds;
  bool dnsResolution;
  final int smsBalance;
  final String smsBalance2;

  ServerMetrics({
    required this.timestamp,
    required this.requestCount,
    required this.dailyActiveUsers,
    required this.monthyTotalTransactions,
    required this.lastMonthyTotalTransactions,
    required this.avgRequestDurationMs,
    required this.errorCount,
    required this.memoryUsageMB,
    required this.cpuLoadAvg,
    required this.uptimeSeconds,
    required this.dnsResolution,
    required this.smsBalance,
    required this.smsBalance2,
  });

  factory ServerMetrics.fromJson(Map<String, dynamic> json) {
    return ServerMetrics(
      timestamp: json['timestamp'],
      requestCount: json['requestCount'],
      dailyActiveUsers: json['daily_active_users'],
      monthyTotalTransactions: json['monthy_total_transactions'] ?? 0.0,
      lastMonthyTotalTransactions: json['last_monthy_total_transactions'] ?? 0.0,
      avgRequestDurationMs: json['avgRequestDurationMs'],
      errorCount: json['errorCount'],
      memoryUsageMB: MemoryUsage.fromJson(json['memoryUsageMB']),
      cpuLoadAvg: CpuLoad.fromJson(json['cpuLoadAvg']),
      uptimeSeconds: json['uptimeSeconds'],
      dnsResolution: json['dns_resolution'] ?? true,
      smsBalance: json['sms_balance'] ?? 0,
      smsBalance2: json['sms_balance_2'] ?? '',
    );
  }
}

class MemoryUsage {
  final String rss;
  final String heapUsed;
  final String heapTotal;

  MemoryUsage({
    required this.rss,
    required this.heapUsed,
    required this.heapTotal,
  });

  factory MemoryUsage.fromJson(Map<String, dynamic> json) {
    return MemoryUsage(
      rss: json['rss'],
      heapUsed: json['heapUsed'],
      heapTotal: json['heapTotal'],
    );
  }
}

class CpuLoad {
  final double m1;
  final double m5;
  final double m15;

  CpuLoad({
    required this.m1,
    required this.m5,
    required this.m15,
  });

  factory CpuLoad.fromJson(Map<String, dynamic> json) {
    return CpuLoad(
      m1: json['1m'],
      m5: json['5m'],
      m15: json['15m'],
    );
  }
}