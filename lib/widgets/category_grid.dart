import 'package:flutter/material.dart';
import 'package:tiketi_mkononi/screens/add_consignment_page.dart';
import 'package:tiketi_mkononi/screens/apply_to_be_cargo_transporter_page.dart';
import 'package:tiketi_mkononi/screens/auth/login_screen.dart';
import 'package:tiketi_mkononi/screens/category_events_page.dart';
import 'package:tiketi_mkononi/screens/offices_page.dart';

class Category {
  final String name;
  final IconData icon;
  final Color color; // Add color parameter

  Category({required this.name, required this.icon, required this.color});
}

class CategoryGrid extends StatelessWidget {
  final int userId;
  final String role;
  final int companyId;
  final int officeId;
  final String companyName;
  final String userName;
  final String userPhoneNumber;
  final Function refreshMethod;

  const CategoryGrid({super.key, required this.userId, required this.role, required this.companyId,  required this.officeId,  required this.companyName,  required this.userName, required this.userPhoneNumber, required this.refreshMethod});
  
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

    final List<Category> categories = [
      Category(name: 'Concerts', icon: Icons.music_note, color: Colors.blue),
      Category(name: 'Sports', icon: Icons.sports_basketball, color: Colors.red),
      Category(name: 'Cargo', icon: Icons.local_shipping, color: Colors.teal),
      Category(name: 'Comedy', icon: Icons.theater_comedy, color: Colors.brown),
      Category(name: 'Fun', icon: Icons.beach_access, color: Colors.amber[500]!),
      // Category(name: 'Festivals', icon: Icons.festival, color: Colors.blue),
      Category(name: 'Bars & Grills', icon: Icons.wine_bar, color: Colors.pink),
      Category(name: 'Training', icon: Icons.cast_for_education, color: Colors.green[600]!),
      Category(name: 'Theater', icon: Icons.theaters, color: Colors.black),
      Category(name: 'Wedding', icon: Icons.favorite, color: Colors.red),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 5,
        mainAxisSpacing: 5,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        return Card(
          // elevation: 0, // removes shadow
          // color: Colors.transparent, // same as parent
          child: InkWell(
            onTap: () async {
              if(categories[index].name == 'Cargo'){
                if(!(userId > 0)) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LoginScreen(),
                    ),
                  );
                } else {
                  if(role == 'cargo_office_attendant'){
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddConsignmentPage(userId: userId, companyId: companyId, companyName:companyName, officeId: officeId, userName: userName, userPhoneNumber: userPhoneNumber, isReplacableScreen: false),
                      ),
                    );
                  } else if(role == 'cargo_transporter'){
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => OfficesPage(userId: userId, companyId: companyId, companyName: companyName, userName: userName, userPhoneNumber: userPhoneNumber, role: role),
                      ),
                    );

                    refreshMethod();
                  } else {
                    _showCargoDialog(context);
                  }
                }
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CategoryEventsPage(
                      category: categories[index].name, userId: userId, 
                    ),
                  ),
                );
              }
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  categories[index].icon,
                  size: 39,
                  color: categories[index].color,
                ),
                const SizedBox(height: 8),
                Text(
                  categories[index].name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}