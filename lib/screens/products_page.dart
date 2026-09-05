import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:tiketi_mkononi/env.dart';
import 'package:tiketi_mkononi/l10n/app_localizations.dart';
import 'package:tiketi_mkononi/models/product.dart';
import 'package:tiketi_mkononi/models/shop.dart';
import 'package:tiketi_mkononi/screens/add_products_page.dart';
import 'package:tiketi_mkononi/screens/edit_products_page.dart';

class ProductsPage extends StatefulWidget {
  final int userId;
  final Shop shop;

  const ProductsPage({
    super.key,
    required this.userId,
    required this.shop,
  });

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  bool _isLoading = true;
  String? _error;
  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _isSearchBarVisible = false;
  String _sortOption = 'name'; // name | price_low | price_high | quantity
  bool _isGridView = true;
  Product? _selectedProduct;
  bool _showDetails = false;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchProducts({bool useDNS = true}) async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final uri = useDNS
          ? Uri.parse('${backend_url}api/shop_products/${widget.shop.id}')
          : Uri.parse('${backend_url_with_fallback_ip}shop_products/${widget.shop.id}');

      debugPrint('Fetching products from: $uri');

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        debugPrint("response.body : ${response.body}");
        
        final dynamic responseData = jsonDecode(response.body);
        
        List<Product> productList = [];
        
        if (responseData is List) {
          productList = responseData.map((json) => Product.fromJson(json)).toList();
        } else if (responseData is Map && responseData.containsKey('data')) {
          productList = (responseData['data'] as List)
              .map((json) => Product.fromJson(json))
              .toList();
        }

        setState(() {
          _products = productList;
          _filteredProducts = productList;
          _applyFilters();
        });

        debugPrint('Loaded ${productList.length} products');
      } else {
        _error = 'Failed to load products (${response.statusCode})';
        debugPrint(_error);
      }
    } on SocketException catch (e) {
      if ((e.osError?.errorCode == 7 || e.osError?.errorCode == 11001) && useDNS) {
        await _fetchProducts(useDNS: false);
        return;
      }
      _error = 'Network error. Please check your connection.';
    } catch (e) {
      _error = 'Unexpected error occurred: $e';
      debugPrint('Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    List<Product> filtered = List.from(_products);

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where(
        (product) => (product.name.toLowerCase() + ' ' + product.brand.toLowerCase()).contains(_searchQuery.toLowerCase())
      ).toList();
    }

    // Apply sorting
    switch (_sortOption) {
      case 'name':
        filtered.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'price_low':
        filtered.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'price_high':
        filtered.sort((a, b) => b.price.compareTo(a.price));
        break;
      case 'quantity':
        filtered.sort((a, b) => b.quantity.compareTo(a.quantity));
        break;
    }

    setState(() {
      _filteredProducts = filtered;
    });
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
    });
    _applyFilters();
  }

  bool _isSmallScreen(BuildContext context) {
    return MediaQuery.of(context).size.width < 600;
  }

  bool _isMediumScreen(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= 600 && width < 1000;
  }

  bool _isLargeScreen(BuildContext context) {
    return MediaQuery.of(context).size.width >= 1000;
  }

  @override
  Widget build(BuildContext context) {
    final isLargeScreen = _isLargeScreen(context);
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.products,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              '${widget.shop.name} - ${widget.shop.location}',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 3,
        actions: [
          IconButton(
            icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
            onPressed: () {
              setState(() {
                _isGridView = !_isGridView;
              });
            },
            tooltip: _isGridView ? 'List View' : 'Grid View',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchProducts,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _fetchProducts,
            color: Colors.teal,
            child: _buildBody(),
          ),
          if (_showDetails && _selectedProduct != null) ...[
            ModalBarrier(
              dismissible: true,
              onDismiss: () {
                setState(() {
                  _showDetails = false;
                  _selectedProduct = null;
                });
              },
              color: Colors.black.withOpacity(0.2),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: _buildDetailsPanel(),
            ),
          ],
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Search Button
          FloatingActionButton(
            heroTag: "searchBtn",
            backgroundColor: Colors.grey.shade800,
            mini: true,
            tooltip: "Search Products",
            onPressed: () {
              setState(() {
                _isSearchBarVisible = !_isSearchBarVisible;
                if (!_isSearchBarVisible) {
                  _searchController.clear();
                  _onSearchChanged();
                }
              });
            },
            child: Icon(
              _isSearchBarVisible ? Icons.close : Icons.search,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 5),
          if((widget.userId == widget.shop.userId))
          // Add Button
          FloatingActionButton(
            heroTag: "addBtn",
            backgroundColor: Colors.teal.shade800,
            mini: true,
            tooltip: "Add Products",
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddProductsPage(
                    userId: widget.userId,
                    shop: widget.shop,
                  ),
                ),
              );
              _fetchProducts();
            },
            child: Icon(
              Icons.add,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final isLargeScreen = _isLargeScreen(context);
    final isSmall = _isSmallScreen(context);
    final isMedium = _isMediumScreen(context);
    final isLarge = _isLargeScreen(context);
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    if (_isLoading && _products.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error_outline,
                  size: 60,
                  color: Colors.red.shade300,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _fetchProducts,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.inventory_2_outlined,
                size: 80,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              AppLocalizations.of(context)!.noProductsFound,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context)!.productsYouAddWillAppearHere,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Search Bar
        if (_isSearchBarVisible) _buildSearchBar(isDarkMode, isLargeScreen),
        
        // Stats & Sort Bar
        _buildStatsAndSortBar(),
        
        // Product Grid/List
        Expanded(
          child: _isGridView
              ? _buildProductGrid(
                  isSmall: isSmall,
                  isMedium: isMedium,
                  isLarge: isLarge,
                )
              : _buildProductList(),
        ),
      ],
    );
  }

  Widget _buildSearchBar(bool isDarkMode, bool isLargeScreen) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: 8,
        horizontal: isLargeScreen ? 200 : 16,
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isDarkMode
              ? colorScheme.surfaceContainerHighest.withOpacity(0.8)
              : colorScheme.surface.withOpacity(0.9),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDarkMode ? 0.2 : 0.1),
              blurRadius: 12,
              spreadRadius: 1,
              offset: const Offset(0, 3),
            ),
          ],
          border: Border.all(
            color: isDarkMode
                ? colorScheme.outline.withOpacity(0.3)
                : colorScheme.outline.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search products by name...',
            hintStyle: TextStyle(
              fontSize: isLargeScreen ? 16 : 14,
              color: colorScheme.onSurface.withOpacity(0.6),
            ),
            border: InputBorder.none,
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 12, right: 6),
              child: Icon(
                Icons.search_rounded,
                size: isLargeScreen ? 24 : 20,
                color: isDarkMode ? Colors.white70 : Colors.teal[800],
              ),
            ),
            suffixIcon: _searchQuery.isNotEmpty
                ? Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        size: isLargeScreen ? 24 : 20,
                        color: colorScheme.onSurface.withOpacity(0.6),
                      ),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged();
                        FocusScope.of(context).unfocus();
                      },
                    ),
                  )
                : null,
            contentPadding: EdgeInsets.symmetric(
              vertical: isLargeScreen ? 14 : 10,
              horizontal: 16,
            ),
            isDense: true,
          ),
          style: TextStyle(
            fontSize: isLargeScreen ? 16 : 14,
            color: colorScheme.onSurface,
          ),
          cursorColor: colorScheme.primary,
          cursorWidth: 1.5,
          cursorHeight: isLargeScreen ? 20 : 18,
          onChanged: (value) => _onSearchChanged(),
        ),
      ),
    );
  }

  Widget _buildStatsAndSortBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Stats
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_filteredProducts.length} Products',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal.shade700,
                  ),
                ),
                Text(
                  'Total: ${_calculateTotalValue()}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          // Sort Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButton<String>(
              value: _sortOption,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(
                  value: 'name', 
                  child: Text(
                    'Name A-Z',
                    style: TextStyle(
                      fontSize: 12
                    )
                  )
                ),
                DropdownMenuItem(
                  value: 'price_low', 
                  child: Text(
                    'Price: Low-High',
                    style: TextStyle(
                      fontSize: 12
                    )
                  )
                ),
                DropdownMenuItem(
                  value: 'price_high', 
                  child: Text(
                    'Price: High-Low',
                    style: TextStyle(
                      fontSize: 12
                    )
                  )
                ),
                DropdownMenuItem(
                  value: 'quantity', 
                  child: Text(
                    'Stock: High-Low',
                    style: TextStyle(
                      fontSize: 12
                    )
                  )
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _sortOption = value;
                    _applyFilters();
                  });
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  String _calculateTotalValue() {
    double total = _filteredProducts.fold(0, (sum, product) => sum + (product.price * product.quantity));
    return 'TZS ${NumberFormat('#,##0').format(total)}';
  }

  Widget _buildProductGrid({
    required bool isSmall,
    required bool isMedium,
    required bool isLarge,
  }) {
    int crossAxisCount;

    if (isSmall) {
      crossAxisCount = 2;
    } else if (isMedium) {
      crossAxisCount = 3;
    } else {
      // On very large screens allow 5 columns.
      final width = MediaQuery.of(context).size.width;

      crossAxisCount = width >= 1500 ? 5 : 4;
    }

    // ---------------------------------------------------------------
    // THIS IS THE IMPORTANT PART.
    //
    // Small screens:
    //   Keep cards relatively tall.
    //
    // Medium screens:
    //   Reduce the height.
    //
    // Large screens:
    //   Use a FIXED height instead of childAspectRatio.
    //
    // This prevents cards from becoming unnecessarily tall on
    // desktop/large monitors.
    // ---------------------------------------------------------------

    double cardHeight;

    if (isSmall) {
      cardHeight = 300;
    } else if (isMedium) {
      cardHeight = 260;
    } else {
      cardHeight = 235;
    }

    if(isSmall) {
      return GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: isLarge ? 4 : 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.75,
        ),
        itemCount: _filteredProducts.length,
        itemBuilder: (context, index) {
          final product = _filteredProducts[index];
          return _buildProductCard(product);
        },
      );
    } else {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 1500,
          ),
          child: GridView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              isSmall ? 16 : 24,
              8,
              isSmall ? 16 : 24,
              100,
            ),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: isSmall ? 10 : 14,
              mainAxisSpacing: isSmall ? 10 : 14,

              // Instead of childAspectRatio.
              // This gives us control over the actual card height.
              mainAxisExtent: cardHeight,
            ),
            itemCount: _filteredProducts.length,
            itemBuilder: (context, index) {
              final product = _filteredProducts[index];

              return _buildProductCard2(
                product,
                isSmall: isSmall,
                isMedium: isMedium,
                isLarge: isLarge,
              );
            },
          ),
        ),
      );
    }
  }

  Widget _buildProductList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredProducts.length,
      itemBuilder: (context, index) {
        final product = _filteredProducts[index];
        return _buildProductListItem(product);
      },
    );
  }

  Widget _buildProductCard(Product product) {
    final isSelected = _selectedProduct == product;
    final inStock = product.quantity > 0;

    return Card(
      elevation: isSelected ? 8 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isSelected
            ? BorderSide(color: Colors.teal.shade400, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          setState(() {
            if (_selectedProduct == product) {
              _showDetails = !_showDetails;
            } else {
              _selectedProduct = product;
              _showDetails = true;
            }
          });
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image Placeholder / Icon
            Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Icon(
                      Icons.inventory_2,
                      size: 48,
                      color: Colors.teal.shade200,
                    ),
                  ),
                  // Stock badge
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: inStock ? Colors.green.shade100 : Colors.red.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        inStock ? 'In Stock' : 'Out of Stock',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: inStock ? Colors.green.shade800 : Colors.red.shade800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${product.name.toUpperCase()} ${product.brand.toUpperCase()}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis, 
                        ),
                        Text(
                          'TZS ${NumberFormat('#,##0').format(product.price)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.teal.shade700,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Qty: ${product.quantity}',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EditProductPage(
                                  product: product, // Your Product object
                                  userId: widget.userId, // Current user ID
                                ),
                              ),
                            );

                            _fetchProducts();
                          },
                          child: Icon(
                            Icons.chevron_right,
                            color: Colors.grey.shade400,
                            size: 22,
                          ),
                        )
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PRODUCT CARD
  // ---------------------------------------------------------------------------

  Widget _buildProductCard2(
    Product product, {
    required bool isSmall,
    required bool isMedium,
    required bool isLarge,
  }) {
    final isSelected = _selectedProduct == product;
    final inStock = product.quantity > 0;

    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // Smaller image on larger screens.
    final double imageHeight = isSmall
        ? 120
        : isMedium
            ? 100
            : 90;

    return Card(
      margin: EdgeInsets.zero,
      elevation: isSelected ? 5 : 1.5,
      shadowColor: Colors.black.withOpacity(0.12),
      color: isDarkMode
          ? theme.colorScheme.surfaceContainerHighest
          : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          isSmall ? 15 : 13,
        ),
        side: isSelected
            ? BorderSide(
                color: Colors.teal.shade400,
                width: 1.5,
              )
            : BorderSide(
                color: isDarkMode
                    ? Colors.white.withOpacity(0.05)
                    : Colors.grey.shade200,
                width: 1,
              ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          setState(() {
            if (_selectedProduct == product) {
              _showDetails = !_showDetails;
            } else {
              _selectedProduct = product;
              _showDetails = true;
            }
          });
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // -------------------------------------------------------------
            // IMAGE / ICON AREA
            // -------------------------------------------------------------

            SizedBox(
              height: imageHeight,
              width: double.infinity,
              child: Container(
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.teal.shade900.withOpacity(0.35)
                      : Colors.teal.shade50,
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Icon(
                        Icons.inventory_2_rounded,
                        size: isSmall ? 48 : 40,
                        color: isDarkMode
                            ? Colors.teal.shade300
                            : Colors.teal.shade200,
                      ),
                    ),

                    // -----------------------------------------------------
                    // STOCK BADGE
                    // -----------------------------------------------------

                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isSmall ? 8 : 7,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: inStock
                              ? Colors.green.shade100
                              : Colors.red.shade100,
                          borderRadius:
                              BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: inStock
                                    ? Colors.green.shade700
                                    : Colors.red.shade700,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              inStock
                                  ? 'In Stock'
                                  : 'Out of Stock',
                              style: TextStyle(
                                fontSize: isSmall ? 9 : 8,
                                fontWeight: FontWeight.w700,
                                color: inStock
                                    ? Colors.green.shade800
                                    : Colors.red.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // -------------------------------------------------------------
            // PRODUCT INFORMATION
            // -------------------------------------------------------------

            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  isSmall ? 10 : 9,
                  isSmall ? 8 : 7,
                  isSmall ? 10 : 9,
                  isSmall ? 8 : 7,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    // Product name
                    Text(
                      '${product.name.toUpperCase()} ${product.brand.toUpperCase()}',
                      style: TextStyle(
                        fontSize: isSmall ? 12 : 11,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                        color: isDarkMode
                            ? Colors.white
                            : Colors.grey.shade900,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 3),

                    // Price
                    Text(
                      'TZS ${NumberFormat('#,##0').format(product.price)}',
                      style: TextStyle(
                        fontSize: isSmall ? 14 : 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.teal.shade700,
                      ),
                    ),

                    const Spacer(),

                    // Bottom row
                    Row(
                      children: [
                        // Quantity
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: isDarkMode
                                  ? Colors.white.withOpacity(0.06)
                                  : Colors.grey.shade100,
                              borderRadius:
                                  BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Qty: ${product.quantity}',
                              style: TextStyle(
                                fontSize: isSmall ? 10 : 9,
                                color: isDarkMode
                                    ? Colors.grey.shade300
                                    : Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),

                        const Spacer(),

                        // Edit button
                        InkWell(
                          borderRadius:
                              BorderRadius.circular(20),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    EditProductPage(
                                  product: product,
                                  userId: widget.userId,
                                ),
                              ),
                            );
                            
                            _fetchProducts();
                          },
                          child: Container(
                            width: isSmall ? 30 : 28,
                            height: isSmall ? 30 : 28,
                            decoration: BoxDecoration(
                              color: Colors.teal.withOpacity(0.08),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.edit_outlined,
                              size: isSmall ? 16 : 15,
                              color: Colors.teal.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildProductListItem(Product product) {
    final isSelected = _selectedProduct == product;
    final inStock = product.quantity > 0;

    return Card(
      elevation: isSelected ? 6 : 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: isSelected
            ? BorderSide(color: Colors.teal.shade400, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          setState(() {
            if (_selectedProduct == product) {
              _showDetails = !_showDetails;
            } else {
              _selectedProduct = product;
              _showDetails = true;
            }
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Product Icon
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.inventory_2,
                  color: Colors.teal,
                ),
              ),
              const SizedBox(width: 12),
              // Product Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${product.name.toUpperCase()} - ${product.brand.toUpperCase()}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          'TZS ${NumberFormat('#,##0').format(product.price)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.teal.shade700,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: inStock ? Colors.green.shade100 : Colors.red.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Qty: ${product.quantity}',
                            style: TextStyle(
                              fontSize: 10,
                              color: inStock ? Colors.green.shade800 : Colors.red.shade800,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditProductPage(
                        product: product, // Your Product object
                        userId: widget.userId, // Current user ID
                      ),
                    ),
                  );

                  _fetchProducts();
                },
                child: Icon(
                  Icons.chevron_right,
                  color: Colors.grey.shade400,
                  size: 22,
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsPanel() {
    final product = _selectedProduct;
    if (product == null) return const SizedBox();

    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.inventory_2,
                          size: 30,
                          color: Colors.teal.shade700,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${product.name.toUpperCase()} - ${product.brand.toUpperCase()}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Product ID: #${product.id}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildDetailSection(
                    title: 'Pricing & Stock',
                    icon: Icons.attach_money,
                    children: [
                      _buildDetailRow('Price', 'TZS ${NumberFormat('#,##0').format(product.price)}'),
                      _buildDetailRow('Quantity in Stock', '${product.quantity}'),
                      _buildDetailRow(
                        'Status',
                        product.quantity > 0 ? 'In Stock' : 'Out of Stock',
                        valueColor: product.quantity > 0 ? Colors.green : Colors.red,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildDetailSection(
                    title: 'Shop Information',
                    icon: Icons.store,
                    children: [
                      _buildDetailRow('Shop ID', '${product.shopId}'),
                      _buildDetailRow('Shop Name', widget.shop.name),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildDetailSection(
                    title: 'Timestamps',
                    icon: Icons.schedule,
                    children: [
                      _buildDetailRow('Created', DateFormat('dd/MM/yyyy HH:mm').format(product.createdAt)),
                      _buildDetailRow('Last Updated', DateFormat('dd/MM/yyyy HH:mm').format(product.updatedAt)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(icon, size: 18, color: Colors.teal.shade700),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal.shade700,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 0),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: valueColor ?? Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}