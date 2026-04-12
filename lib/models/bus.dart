class Bus {
  int id;
  int userId;
  String name;
  String type;
  String registrationNumber;
  int numberOfSeatRows;
  int seatsPerRow;
  bool isHavingToilet;
  int toiletAtRowNumber;
  int numberOfRowsThatToiletSpans;
  bool isToiletAtLeftSide;
  final String status;

  Bus({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    required this.registrationNumber,
    required this.numberOfSeatRows,
    required this.seatsPerRow,
    required this.isHavingToilet,
    required this.toiletAtRowNumber,
    required this.numberOfRowsThatToiletSpans,
    required this.isToiletAtLeftSide,
    required this.status,
  });

  // Factory method to create an Bus from JSON
  factory Bus.fromJson(Map<String, dynamic> json) {    
    return Bus(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      name: json['name'] ?? '',
      type: json['type'] ?? '',
      registrationNumber: json['registration_number'] ?? '',
      numberOfSeatRows: json['number_of_seat_rows'] ?? 0,
      seatsPerRow: json['seats_per_row'] ?? 0,
      isHavingToilet: json['is_having_toilet'] ?? true,
      toiletAtRowNumber: json['toilet_at_row_number'] ?? 7,
      numberOfRowsThatToiletSpans: json['number_of_rows_that_toilet_spans'] ?? 7,
      isToiletAtLeftSide: json['is_toilet_at_left_side'] ?? true,
      status: json['status'] ?? '',
    );
  }
}