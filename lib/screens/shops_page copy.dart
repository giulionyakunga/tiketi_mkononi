import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:tiketi_mkononi/models/shop.dart';
import 'package:tiketi_mkononi/screens/add_shop_page.dart';
import 'package:tiketi_mkononi/screens/edit_shop_page.dart';
import 'package:tiketi_mkononi/screens/orders_page.dart';
import 'package:tiketi_mkononi/screens/products_page.dart';
import '../env.dart';

class ShopsPage extends StatefulWidget {
  final int userId;
  final String role;
  final String userName;
  final String userPhoneNumber;

  const ShopsPage({super.key, required this.userId, required this.role, required this.userName, required this.userPhoneNumber});

  @override
  State<ShopsPage> createState() => _ShopsPageState();
}

class _ShopsPageState extends State<ShopsPage> {
  bool _loading = true;
  String? _error;
  List<Shop> _shops = [];
  int orderCount = 0;
  int wingasCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchShops();
  }

  Future<void> _fetchShops({bool useDNS = true}) async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      String dateStr = DateFormat('d-M-yyyy').format(DateTime.now());
      DateTime _orderDate = DateFormat('d-M-yyyy').parse(dateStr);

      final uri = useDNS ? Uri.parse('${backend_url}api/shops/${widget.userId}/${DateFormat('d-M-yyyy').format(_orderDate)}')
      : Uri.parse('${backend_url_with_fallback_ip}shops/${widget.userId}/${DateFormat('d-M-yyyy').format(_orderDate)}');

      final response = await http.get(uri);
      debugPrint("response.body : ${response.body}");

      if (response.statusCode == 200) {

        final dynamic responseData = jsonDecode(response.body);
      
        List<Shop> shops = [];
        
        if (responseData is List) {
          shops = responseData.map((json) => Shop.fromJson(json)).toList();
        } else if (responseData is Map && responseData.containsKey('data')) {
          shops = (responseData['data'] as List)
              .map((json) => Shop.fromJson(json))
              .toList();
        }

        // If there's at least one shop, extract its data
        if (shops.isNotEmpty) {
          setState(() {
            _shops = shops;
          });
        } else {
          setState(() {
            _error = 'No shop data found';
          });
        }

        debugPrint('Loaded ${_shops.length} shops');
      } else {
        _error = 'Failed to load shops';
      }
    } on SocketException catch (e) {
      if ((e.osError?.errorCode == 7 || e.osError?.errorCode == 11001) && useDNS) {
        await _fetchShops(useDNS: false);
        return;
      } 
      _error = 'Network error. Please check your connection.';
    } catch (e) {
      _error = 'An error occurred. Please try again later.';
      debugPrint('An error occurred: ${e.toString()}');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Shops'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchShops,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _errorState()
                : _shops.isEmpty
                    ? _emptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _shops.length,
                        itemBuilder: (_, index) {
                          final Shop shop = _shops[index];
                          return _shopCard(shop);
                        },
                      ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.teal,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddShopPage(userId: widget.userId,),
          ));
        }, // future: add office
        child: const Icon(
          Icons.add,
          color: Colors.white
        ),
      ),
    );
  }

  Widget _shopCard(Shop shop) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OrdersPage(userId: widget.userId, shopId: shop.id, shopName: shop.name, userName: widget.userName, userPhoneNumber: widget.userPhoneNumber, role: widget.role),
          ),
        );

        _fetchShops();
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.indigo.withOpacity(0.1),
                    child: const Icon(
                      Icons.store,
                      color: Colors.teal,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shop.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          shop.location,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            _chip(
                              icon: Icons.inventory,
                              label: '${shop.productCount} Products',
                            ),
                            const SizedBox(width: 5),
                            _chip(
                              icon: Icons.trending_up,
                              label: 'Orders: ${shop.orderCount}',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  if((widget.userId == shop.userId))
                  InkWell(
                    onTap: () {
                      // your action here
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProductsPage(
                            userId: widget.userId,
                            shop: shop,
                          ),
                        ),
                      );
                    },
                    child: const Icon(
                      Icons.chevron_right,
                      // size: 14,
                      color: Colors.grey,
                    ),
                  )
                ],
              ),
            ),
                    
            if((widget.userId == shop.userId))
            Padding(
              padding: const EdgeInsets.only(
                top: 0,
                left: 16,
                right: 16,
                bottom: 4,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    onTap: () async {
                      // your action here
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EditShopPage(
                            userId: widget.userId,
                            shop: shop,
                          ),
                        ),
                      );
                      _fetchShops();
                    },
                    child: const Icon(
                      Icons.edit,
                      size: 14,
                      color: Colors.grey,
                    ),
                  )
                ],
              )
            ),
            const SizedBox(height: 10),
          ]
        )
      ),
    );
  }

  Widget _chip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.indigo.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, size: 12, color: Colors.indigo),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return ListView(
      children: const [
        SizedBox(height: 120),
        Icon(Icons.store_mall_directory, size: 80, color: Colors.grey),
        SizedBox(height: 16),
        Center(
          child: Text(
            'No shops found',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(height: 8),
        Center(
          child: Text(
            'Shops you own will appear here',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      ],
    );
  }

  Widget _errorState() {
    return ListView(
      children: [
        const SizedBox(height: 120),
        const Icon(Icons.error_outline, size: 80, color: Colors.redAccent),
        const SizedBox(height: 16),
        Center(
          child: Text(
            _error!,
            style: const TextStyle(fontSize: 16),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: ElevatedButton.icon(
            onPressed: _fetchShops,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ),
      ],
    );
  }
}
