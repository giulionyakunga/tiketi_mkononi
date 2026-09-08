// models/ad_model.dart
class AdModel {
  final int id;
  final int userId;
  final String title;
  final String description;
  final String imageUrl;
  final String buttonText;
  final String? linkUrl;
  final String backgroundColor;
  final String accentColor;
  final int priority;
  final bool isActive;
  final DateTime? startDate;
  final DateTime? endDate;
  final Map<String, dynamic>? targetAudience;

  AdModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.buttonText,
    this.linkUrl,
    required this.backgroundColor,
    required this.accentColor,
    required this.priority,
    required this.isActive,
    this.startDate,
    this.endDate,
    this.targetAudience,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'description': description,
      'image_url': imageUrl,
      'button_text': buttonText,
      'link_url': linkUrl,
      'background_color': backgroundColor,
      'accent_color': accentColor,
      'priority': priority,
      'is_active': isActive,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'target_audience': targetAudience,
    };
  }

  factory AdModel.fromJson(Map<String, dynamic> json) {
    return AdModel(
      id: json['id']?.toInt() ?? 0,
      userId: json['user_id']?.toInt() ?? 0,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      imageUrl: json['image_url'] ?? '',
      buttonText: json['button_text'] ?? 'Learn More',
      linkUrl: json['link_url'],
      backgroundColor: json['background_color'] ?? '#FF6B6B',
      accentColor: json['accent_color'] ?? '#FFFFFF',
      priority: json['priority'] ?? 0,
      isActive: json['is_active'] ?? true,
      startDate: json['start_date'] != null 
          ? DateTime.parse(json['start_date']) 
          : null,
      endDate: json['end_date'] != null 
          ? DateTime.parse(json['end_date']) 
          : null,
      targetAudience: json['target_audience'],
    );
  }
}