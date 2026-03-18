import 'package:flutter/material.dart';
import 'package:tiketi_mkononi/models/event.dart';
import 'package:tiketi_mkononi/screens/add_consignment_page.dart';
import 'package:tiketi_mkononi/screens/apply_to_be_cargo_transporter_page.dart';
import 'package:tiketi_mkononi/screens/category_events_page.dart';
import 'package:tiketi_mkononi/screens/offices_page.dart';

class Category {
  final String name;
  final IconData icon;
  final Color color;

  Category({required this.name, required this.icon, required this.color});
}

class CategoryGrid2 extends StatelessWidget {
  final List<Event> events;
  final int userId;
  final String role;
  final int companyId;
  final int officeId;
  final String companyName;
  final String userName;
  final String userPhoneNumber;

  const CategoryGrid2({super.key, required this.events, required this.userId, required this.role, required this.companyId,  required this.officeId,  required this.companyName,  required this.userName, required this.userPhoneNumber});


    void _showCargoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Access Restricted'),
        content: const Text(
          'This feature is available only to registered Tiketi Mkononi cargo transporters. '
          'If you would like to offer cargo transportation services, please submit an application to become an approved transporter.'
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ApplyToBeCargoTransporterPage(userId: userId),
                ),
              );
            },
            child: const Text(
              'Apply Now',
              style: TextStyle(color: Colors.green),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isLargeScreen = MediaQuery.of(context).size.width > 768;

    final List<Category> categories = [
      Category(
        name: 'Concerts', 
        icon: Icons.music_note, 
        color: Colors.blue.shade700,
      ),
      Category(
        name: 'Sports', 
        icon: Icons.sports_soccer, 
        color: Colors.red.shade700,
      ),
      Category(
        name: 'Cargo', icon: 
        Icons.local_shipping, 
        color: Colors.teal
      ),
      Category(
        name: 'Comedy', 
        icon: Icons.theater_comedy, 
        color: Colors.brown.shade700,
      ),
      Category(
        name: 'Fun', 
        icon: Icons.emoji_emotions, 
        color: Colors.amber.shade700,
      ),
      Category(
        name: 'Bars & Grills', 
        icon: Icons.local_bar, 
        color: Colors.pink.shade600,
      ),
      Category(
        name: 'Training', 
        icon: Icons.school, 
        color: Colors.green.shade700,
      ),
      Category(
        name: 'Theater', 
        icon: Icons.theaters, 
        color: Colors.deepPurple.shade700,
      ),
      Category(
        name: 'Wedding', 
        icon: Icons.favorite, 
        color: Colors.red
      ),
    ];

    // Calculate event counts for each category
    final categoryCounts = Map.fromIterable(
      categories,
      key: (category) => category.name,
      value: (category) => events.where((e) => e.category == category.name).length,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = _calculateCrossAxisCount(constraints.maxWidth);
        final aspectRatio = _calculateAspectRatio(constraints.maxWidth);

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: isLargeScreen ? 24 : 16,
            vertical: 8,
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: isLargeScreen ? 20 : 16,
            mainAxisSpacing: isLargeScreen ? 20 : 16,
            childAspectRatio: aspectRatio,
          ),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final category = categories[index];
            final eventCount = categoryCounts[category.name] ?? 0;

            return Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  if(categories[index].name == 'Cargo'){
                    if(role == 'cargo_office_attendant'){
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddConsignmentPage(userId: userId, companyId: companyId, companyName:companyName, officeId: officeId, userName: userName, userPhoneNumber: userPhoneNumber),
                        ),
                      );
                    } else if(role == 'cargo_transporter'){
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => OfficesPage(userId: userId, companyId: companyId, companyName: companyName, userName: userName, userPhoneNumber: userPhoneNumber, role: role),
                        ),
                      );

                    } else {
                      _showCargoDialog(context);
                    }

                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CategoryEventsPage(
                          category: category.name,
                          userId: userId,
                        ),
                      ),
                    );
                  }
                },
                splashColor: category.color.withOpacity(0.2),
                highlightColor: category.color.withOpacity(0.1),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        category.color.withOpacity(0.1),
                        category.color.withOpacity(0.05),
                      ],
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: category.color.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          category.icon,
                          size: isLargeScreen ? 40 : 36,
                          color: category.color,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        category.name,
                        style: TextStyle(
                          fontSize: isLargeScreen ? 18 : 16,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$eventCount events',
                        style: TextStyle(
                          fontSize: isLargeScreen ? 14 : 12,
                          color: colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  int _calculateCrossAxisCount(double screenWidth) {
    if (screenWidth > 1000) return 4;
    if (screenWidth > 768) return 3;
    if (screenWidth > 480) return 2;
    return 2;
  }

  double _calculateAspectRatio(double screenWidth) {
    if (screenWidth > 1000) return 1.0;
    if (screenWidth > 768) return 0.9;
    return 0.8;
  }
}