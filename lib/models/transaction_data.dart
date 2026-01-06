class TransactionData {
  final int id;
  final int userId;
  final int eventId;
  final bool hasTicket;
  final String description;

  TransactionData({
    required this.id,
    required this.userId,
    required this.eventId,
    required this.description,
    required this.hasTicket,
  });

  // Factory method to create a TransactionData from JSON
  factory TransactionData.fromJson(Map<String, dynamic> json) {
    return TransactionData(
      id: json['transaction_id'] ?? 0,
      userId: json['transaction_user_id'] ?? 0,
      eventId: json['transaction_event_id'] ?? 0,
      description: json['transaction_description'] ?? '',
      hasTicket: json['has_ticket'],
    );
  }
}