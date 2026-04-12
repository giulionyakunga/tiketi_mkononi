import 'package:flutter/material.dart';
import 'package:tiketi_mkononi/l10n/app_localizations.dart';
import 'package:tiketi_mkononi/models/category.dart';
import 'package:tiketi_mkononi/models/event.dart';
import 'package:tiketi_mkononi/screens/add_consignment_page.dart';
import 'package:tiketi_mkononi/screens/apply_to_be_cargo_transporter_page.dart';
import 'package:tiketi_mkononi/screens/apply_to_be_transporter_page.dart';
import 'package:tiketi_mkononi/screens/auth/login_screen.dart';
import 'package:tiketi_mkononi/screens/category_events_page.dart';
import 'package:tiketi_mkononi/screens/find_bus_routes_page.dart';
import 'package:tiketi_mkononi/screens/offices_page.dart';

class CategoryGrid2 extends StatelessWidget {
  final List<Event> events;
  final int userId;
  final String role;
  final int companyId;
  final int officeId;
  final String companyName;
  final String userName;
  final String userPhoneNumber;
  final Function refreshMethod;

  const CategoryGrid2({super.key, required this.events, required this.userId, required this.role, required this.companyId,  required this.officeId,  required this.companyName,  required this.userName, required this.userPhoneNumber, required this.refreshMethod});


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

  void _showBusesDialog2(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Access Restricted'),
        content: const Text(
          'This feature is available only to registered Tiketi Mkononi transporters. '
          'If you would like to offer transportation services, please submit an application to become an approved transporter.'
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
                      ApplyToBeTransporterPage(userId: userId),
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
      Category(name: AppLocalizations.of(context)!.concerts, value: 'Concerts', icon: Icons.music_note, color: Colors.blue),
      if ((role == 'transporter') || (role == 'transport_office_attendant'))
      Category(name: AppLocalizations.of(context)!.buses, value: 'Buses', icon: Icons.directions_bus, color: Colors.teal),
      if ((role == 'transporter') || (role == 'cargo_transporter') || (role == 'transport_office_attendant') || (role == 'cargo_office_attendant'))
      Category(name: AppLocalizations.of(context)!.cargo, value: 'Cargo', icon: Icons.local_shipping, color: Colors.teal),
      Category(name: AppLocalizations.of(context)!.sports, value: 'Sports', icon: Icons.sports_basketball, color: Colors.red),
      Category(name: AppLocalizations.of(context)!.comedy, value: 'Comedy', icon: Icons.theater_comedy, color: Colors.brown),
      Category(name: AppLocalizations.of(context)!.fun, value: 'Fun', icon: Icons.beach_access, color: Colors.amber[500]!),
      // Category(name: AppLocalizations.of(context)!.festivals, value: 'Festivals', icon: Icons.festival, color: Colors.blue),
      Category(name: AppLocalizations.of(context)!.barsAndGrills, value: 'Bars & Grills', icon: Icons.wine_bar, color: Colors.pink),
      Category(name: AppLocalizations.of(context)!.training, value: 'Training', icon: Icons.cast_for_education, color: Colors.green[600]!),
      Category(name: AppLocalizations.of(context)!.theater, value: 'Theater', icon: Icons.theaters, color: Colors.black),
      Category(name: AppLocalizations.of(context)!.wedding, value: 'Wedding', icon: Icons.favorite, color: Colors.red),
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
                onTap: () async {
                  if(categories[index].value == 'Cargo'){
                    if((role == 'transport_office_attendant') || (role == 'cargo_office_attendant')){
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddConsignmentPage(userId: userId, companyId: companyId, companyName:companyName, officeId: officeId, userName: userName, userPhoneNumber: userPhoneNumber, isReplacableScreen: false),
                        ),
                      );
                    } else if((role == 'transporter') || (role == 'cargo_transporter')){
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => OfficesPage(userId: userId, companyId: companyId, companyName: companyName, userName: userName, userPhoneNumber: userPhoneNumber, role: role),
                        ),
                      );

                      refreshMethod();
                    }
                  } else if(categories[index].value == 'Buses'){
                    if(!(userId > 0)) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => LoginScreen(),
                        ),
                      );
                    } else {
                      if(role == 'transporter'){
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => OfficesPage(userId: userId, companyId: companyId, companyName: companyName, userName: userName, userPhoneNumber: userPhoneNumber, role: role),
                          ),
                        );

                        refreshMethod();
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FindBusRoutesPage(userId: userId, officeId: officeId, companyId: companyId, companyName: companyName, userName: userName, userPhoneNumber: userPhoneNumber, role: role),
                          ),
                        );
                      }
                    }
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CategoryEventsPage(
                          category: category.value,
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