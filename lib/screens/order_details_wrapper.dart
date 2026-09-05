import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:tiketi_mkononi/env.dart';
import 'package:tiketi_mkononi/models/shop.dart';
import 'package:tiketi_mkononi/screens/add_order_page.dart';
import 'package:tiketi_mkononi/screens/add_remote_order_page.dart';
import 'package:tiketi_mkononi/screens/home_page.dart';
import 'package:tiketi_mkononi/screens/order_page.dart';

class OrderDetailsWrapper extends StatefulWidget {
  final int shopId;
  final String? orderId;

  const OrderDetailsWrapper({super.key, required this.shopId, this.orderId});

  @override
  State<OrderDetailsWrapper> createState() => _OrderDetailsWrapperState();
}

class _OrderDetailsWrapperState extends State<OrderDetailsWrapper> {
  Shop? shop;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchShop();
  }

  Future<void> _fetchShop({bool useDNS = true}) async {
    try {

      final uri = useDNS ? Uri.parse('${backend_url}api/shop/${widget.shopId}')
      : Uri.parse('${backend_url_with_fallback_ip}shop/${widget.shopId}');

      final response = await http.get(uri);
      debugPrint("response.body : ${response.body}");

      if (response.statusCode == 200) {
        final dynamic responseData = jsonDecode(response.body);

        if (responseData is Map<String, dynamic>) {
          setState(() {
            shop = Shop.fromJson(responseData);
            isLoading = false; 
          });
        } else {
          throw Exception("Invalid response format");
        }
      }

    } on SocketException catch (e) {
      if ((e.osError?.errorCode == 7 || e.osError?.errorCode == 11001) && useDNS) {
        await _fetchShop(useDNS: false);
        return;
      }
    } catch (e) {
      debugPrint('An error occurred: ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (shop == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Shop not found'),
              ElevatedButton.icon(
                icon: const Icon(Icons.logout),
                label: Text('See Other Shops', style: TextStyle(
                  fontSize: 14,
                )
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.orange[800],
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                onPressed: () {
                  context.push('/home');
                },
              )
            ],
          ),
        )
      );
    }

    if (shop != null) {
      debugPrint("adding order ${widget.orderId}");

      if (widget.orderId == 'add') {
        debugPrint("adding order");

        return AddRemoteOrderPage(
          userId: 0,
          shopId: shop!.id,
          shopName: shop!.name,
          shopLocation: shop!.location,
          userName: '',
          userPhoneNumber: '',
          isReplacableScreen: true
        );
      }

      if (widget.orderId?.isNotEmpty ?? false) {
        return OrderPage(
          shop: shop!,
          orderId: widget.orderId!,
        );
      }

      return AddRemoteOrderPage(
        userId: 0,
        shopId: shop!.id,
        shopName: shop!.name,
        shopLocation: shop!.location,
        userName: '',
        userPhoneNumber: '',
        isReplacableScreen: true
      );
    }

    return HomePage();
  }
}
