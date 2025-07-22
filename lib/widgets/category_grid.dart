import 'package:flutter/material.dart';
import 'package:tiketi_mkononi/models/event.dart';
import 'package:tiketi_mkononi/screens/category_events_page.dart';

class Category {
  final String name;
  final IconData icon;
  final Color color; // Add color parameter

  Category({required this.name, required this.icon, required this.color});
}

class CategoryGrid extends StatelessWidget {
  final List<Event> events;
  final int userId;

  const CategoryGrid({super.key, required this.events, required this.userId});
  

  @override
  Widget build(BuildContext context) {

    final List<Category> categories = [
      Category(name: 'Concerts', icon: Icons.music_note, color: Colors.blue),
      Category(name: 'Sports', icon: Icons.sports_basketball, color: Colors.red),
      Category(name: 'Comedy', icon: Icons.theater_comedy, color: Colors.brown),
      Category(name: 'Fun', icon: Icons.beach_access, color: Colors.amber[500]!),
      // Category(name: 'Festivals', icon: Icons.festival, color: Colors.blue),
      Category(name: 'Bars & Grills', icon: Icons.wine_bar, color: Colors.pink),
      Category(name: 'Training', icon: Icons.cast_for_education, color: Colors.green[600]!),
      Category(name: 'Theater', icon: Icons.theaters, color: Colors.black),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        return Card(
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CategoryEventsPage(
                    category: categories[index].name, userId: userId,
                  ),
                ),
              );
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  categories[index].icon,
                  size: 48,
                  color: categories[index].color,
                ),
                const SizedBox(height: 8),
                Text(
                  categories[index].name,
                  style: const TextStyle(
                    fontSize: 16,
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