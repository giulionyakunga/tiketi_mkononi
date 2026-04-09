import 'package:flutter/material.dart';

class RideScreen extends StatelessWidget {
  const RideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Custom top bar replacing AppBar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Colors.grey, width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  // Back button
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                    },
                    child: const Icon(Icons.arrow_back, color: Colors.black87),
                  ),
                  const SizedBox(width: 12),
                  // Location info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.circle, size: 12, color: Colors.green),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Kijitonyama',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.location_on, size: 12, color: Colors.red),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Riverside Hall',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Forward arrow
                  const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                ],
              ),
            ),
            // Rest of the content (ride options)
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Arrival time chip
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Arrive by 17:27',
                        style: TextStyle(fontSize: 13, color: Colors.black54),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Woodcavers and locations row
                  const Text(
                    'WOODCAVERS...',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: const [
                      LocationChip(label: 'Kisinia Restaurant'),
                      LocationChip(label: 'Village'),
                      LocationChip(label: 'MWENGE'),
                      LocationChip(label: 'SamNujomari'),
                      LocationChip(label: 'Sekilang'),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // National Institute of Transport
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.business, size: 20, color: Colors.black54),
                        SizedBox(width: 12),
                        Text(
                          'National Institute of Transport',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Ride options
                  const Text(
                    'RIDE OPTIONS',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54),
                  ),
                  const SizedBox(height: 12),

                  // Bajaji option
                  RideOptionCard(
                    icon: Icons.car_crash,
                    title: 'Bajaji',
                    price: 'TZS 5,000',
                    duration: '4 min',
                    distance: '🚗 3',
                    subtitle: '3-wheel rides',
                    isSelected: true,
                  ),
                  const SizedBox(height: 12),

                  // Basic option
                  RideOptionCard(
                    icon: Icons.directions_car,
                    title: 'Basic',
                    price: 'TZS 8,000',
                    duration: '3 min',
                    distance: '🚗 4',
                    subtitle: null,
                    isSelected: false,
                  ),
                  const SizedBox(height: 12),

                  // Boda option
                  RideOptionCard(
                    icon: Icons.motorcycle,
                    title: 'Boda',
                    price: 'TZS 3,500',
                    duration: null,
                    distance: null,
                    subtitle: null,
                    isSelected: false,
                  ),
                  const SizedBox(height: 24),

                  // Cash indicator
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.money, size: 18, color: Colors.black54),
                            SizedBox(width: 8),
                            Text('Cash', style: TextStyle(fontSize: 14)),
                          ],
                        ),
                        Icon(Icons.arrow_drop_down, color: Colors.black54),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Select Bajaji button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Select Bajaji',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LocationChip extends StatelessWidget {
  final String label;
  const LocationChip({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, color: Colors.black87),
      ),
    );
  }
}

class RideOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String price;
  final String? duration;
  final String? distance;
  final String? subtitle;
  final bool isSelected;

  const RideOptionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.price,
    this.duration,
    this.distance,
    this.subtitle,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: isSelected ? Colors.green : Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12),
        color: isSelected ? Colors.green[50] : Colors.white,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.green[100] : Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: isSelected ? Colors.green[700] : Colors.black54),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.green[800] : Colors.black87,
              ),
            ),
            Text(
              price,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.green[800] : Colors.black87,
              ),
            ),
          ],
        ),
        subtitle: subtitle != null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(subtitle!, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                  if (duration != null)
                    Text('$duration  $distance', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                ],
              )
            : (duration != null && distance != null
                ? Text('$duration  $distance', style: const TextStyle(fontSize: 12, color: Colors.black54))
                : null),
      ),
    );
  }
}