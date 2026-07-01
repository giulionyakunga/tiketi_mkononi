import 'package:flutter/material.dart';
import 'package:tiketi_mkononi/l10n/app_localizations.dart';
import 'package:tiketi_mkononi/models/category.dart';
import 'package:tiketi_mkononi/screens/add_consignment_page.dart';
import 'package:tiketi_mkononi/screens/add_order_page.dart';
import 'package:tiketi_mkononi/screens/auth/login_screen.dart';
import 'package:tiketi_mkononi/screens/category_events_page.dart';
import 'package:tiketi_mkononi/screens/find_bus_routes_page.dart';
import 'package:tiketi_mkononi/screens/offices_page.dart';
import 'package:tiketi_mkononi/screens/shops_page.dart';

class CategoryGrid extends StatelessWidget {
  final int userId;
  final String role;
  final int companyId;
  final int? shopId;
  final String shopName;
  final int officeId;
  final String companyName;
  final String userName;
  final String userPhoneNumber;
  final Function refreshMethod;

  const CategoryGrid({super.key, required this.userId, required this.role, required this.companyId, this.shopId,  required this.officeId,  required this.companyName,  required this.shopName,  required this.userName, required this.userPhoneNumber, required this.refreshMethod});
  
  @override
  Widget build(BuildContext context) {

    final List<Category> categories = [
      Category(name: AppLocalizations.of(context)!.concerts, value: 'Concerts', icon: Icons.music_note, color: Colors.blue),
      if ((role == 'transporter') || (role == 'transport_office_attendant'))
      Category(name: AppLocalizations.of(context)!.buses, value: 'Buses', icon: Icons.directions_bus, color: Colors.teal),
      if ((role == 'transporter') || (role == 'cargo_transporter') || (role == 'transport_office_attendant') || (role == 'cargo_office_attendant'))
      Category(name: AppLocalizations.of(context)!.cargo, value: 'Cargo', icon: Icons.local_shipping, color: Colors.teal),
      if ((role == 'shop_owner') || (role == 'shop_attendant'))
      Category(name: AppLocalizations.of(context)!.myOrders, value: 'My Orders', icon: Icons.shopping_cart, color: Colors.teal),
      Category(name: AppLocalizations.of(context)!.sports, value: 'Sports', icon: Icons.sports_basketball, color: Colors.red),
      Category(name: AppLocalizations.of(context)!.comedy, value: 'Comedy', icon: Icons.theater_comedy, color: Colors.brown),
      Category(name: AppLocalizations.of(context)!.fun, value: 'Fun', icon: Icons.beach_access, color: Colors.amber[500]!),
      // Category(name: AppLocalizations.of(context)!.festivals, value: 'Festival', icon: Icons.festival, color: Colors.blue),
      Category(name: AppLocalizations.of(context)!.barsAndGrills, value: 'Bars & Grills', icon: Icons.wine_bar, color: Colors.pink),
      Category(name: AppLocalizations.of(context)!.training, value: 'Training', icon: Icons.cast_for_education, color: Colors.green[600]!),
      Category(name: AppLocalizations.of(context)!.theater, value: 'Theater', icon: Icons.theaters, color: Colors.black),
      Category(name: AppLocalizations.of(context)!.wedding, value: 'Wedding', icon: Icons.favorite, color: Colors.red),
      Category(name: AppLocalizations.of(context)!.celebration, value: 'Celebration', icon: Icons.celebration, color: Colors.yellow),
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
              
              if(categories[index].value == 'Cargo'){
                if((role == 'transport_office_attendant') || (role == 'cargo_office_attendant')){
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddConsignmentPage(userId: userId, companyId: companyId, companyName: companyName, officeId: officeId, userName: userName, userPhoneNumber: userPhoneNumber, isReplacableScreen: false),
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
              } else if(categories[index].value == 'My Orders'){
                if(role == 'shop_attendant'){
                  if (shopId != null) {
                    await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddOrderPage(
                            userId: userId,
                            shopId: shopId!,
                            shopName: shopName,
                            userName: userName,
                            userPhoneNumber: userPhoneNumber,
                            isReplacableScreen: true,
                          ),
                        ),
                    );
                  }
                } else if(role == 'shop_owner'){
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ShopsPage(userId: userId, role: role, userName: userName, userPhoneNumber: userPhoneNumber),
                    ),
                  );

                  refreshMethod();
                }
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CategoryEventsPage(
                      category: categories[index].value, userId: userId, 
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