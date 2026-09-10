import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:tiketi_mkononi/env.dart';
import 'package:url_launcher/url_launcher.dart';

class ConsignmentInfoPage extends StatefulWidget {
  final int userId;

  const ConsignmentInfoPage({
    super.key,
    required this.userId,
  });

  @override
  State<ConsignmentInfoPage> createState() => _ConsignmentInfoPageState();
}

class _ConsignmentInfoPageState extends State<ConsignmentInfoPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _idController = TextEditingController();
  final FocusNode _idFocusNode = FocusNode();

  bool _isLoading = false;
  String? _error;
  dynamic _consignment;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _idController.dispose();
    _idFocusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  // API
  // ─────────────────────────────────────────────────────────────
  Future<void> _fetchConsignment({bool useDNS = true}) async {
    final id = _idController.text.trim();
    if (id.isEmpty) {
      setState(() => _error = 'Please enter a Consignment ID');
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _error = null;
      _consignment = null;
    });
    _animationController.reset();

    try {
      final uri = useDNS
          ? Uri.parse('${backend_url}api/consignment/$id')
          : Uri.parse('${backend_url_with_fallback_ip}consignment/$id');

      debugPrint('Fetching consignment from: $uri');

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        debugPrint('response.body: ${response.body}');

        final dynamic decoded = jsonDecode(response.body);

        dynamic data;
        if (decoded is Map && decoded.containsKey('data')) {
          data = decoded['data'];
        } else {
          data = decoded;
        }

        if (data == null || (data is List && data.isEmpty)) {
          setState(() => _error = 'No consignment found with ID: $id');
          return;
        }

        setState(() {
          _consignment = data is List ? data.first : data;
        });

        _animationController.forward();
      } else if (response.statusCode == 404) {
        setState(() => _error = 'Consignment not found (ID: $id)');
      } else {
        setState(() =>
            _error = 'Failed to load consignment (${response.statusCode})');
      }
    } on SocketException catch (e) {
      if ((e.osError?.errorCode == 7 || e.osError?.errorCode == 11001) &&
          useDNS) {
        await _fetchConsignment(useDNS: false);
        return;
      }
      setState(() => _error = 'Network error. Please check your connection.');
    } catch (e) {
      debugPrint('Error: $e');
      setState(() => _error = 'Unexpected error occurred: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _clearAll() {
    setState(() {
      _consignment = null;
      _error = null;
      _idController.clear();
    });
    _animationController.reset();
    _idFocusNode.requestFocus();
  }

  // ─────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLargeScreen = MediaQuery.of(context).size.width > 768;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Consignment Lookup',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 3,
        actions: [
          if (_consignment != null)
            IconButton(
              tooltip: 'Clear',
              icon: const Icon(Icons.refresh),
              onPressed: _clearAll,
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isLargeScreen ? 800 : double.infinity,
            ),
            child: Column(
              children: [
                _buildSearchSection(),
                Expanded(child: _buildContent()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // SEARCH SECTION
  // ─────────────────────────────────────────────────────────────
  Widget _buildSearchSection() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.qr_code_scanner,
                    color: Colors.teal, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Track Consignment',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Enter the consignment ID to view full details',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _idController,
                  focusNode: _idFocusNode,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _fetchConsignment(),
                  decoration: InputDecoration(
                    hintText: 'e.g. 12345',
                    prefixIcon: const Icon(Icons.tag, color: Colors.teal),
                    filled: true,
                    fillColor: colorScheme.surface,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          BorderSide(color: colorScheme.outline.withOpacity(0.3)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          BorderSide(color: colorScheme.outline.withOpacity(0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Colors.teal, width: 2),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _fetchConsignment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 2,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Icon(Icons.search, size: 22),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // CONTENT
  // ─────────────────────────────────────────────────────────────
  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.teal),
            SizedBox(height: 16),
            Text('Fetching consignment...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return _buildErrorState();
    }

    if (_consignment == null) {
      return _buildEmptyState();
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: _buildConsignmentDetails(),
    );
  }

  Widget _buildErrorState() {
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
              child: Icon(Icons.error_outline,
                  size: 60, color: Colors.red.shade300),
            ),
            const SizedBox(height: 20),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _fetchConsignment,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.inventory_2_outlined,
                size: 80,
                color: Colors.teal.shade300,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Consignment Loaded',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.teal.shade700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Enter a Consignment ID above to view its full details, route, sender & receiver information.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // DETAILS VIEW
  // ─────────────────────────────────────────────────────────────
  Widget _buildConsignmentDetails() {
    final consignment = _consignment;
    final bool isParcel = consignment['is_parcel'] == true;
    final bool isPaid = consignment['payment_status'] == true;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderCard(consignment, isParcel, isPaid),
          const SizedBox(height: 16),
          _buildSection(
            title: 'Package Information',
            icon: Icons.inventory,
            children: [
              _buildRow('Package No', '${consignment['package_id'] ?? 'N/A'}'),
              _buildRow('Package Name', consignment['package_name']),
              _buildRow(
                'Package Value',
                'TZS ${NumberFormat('#,##0').format((consignment['package_value'] ?? 0).toInt())}',
              ),
              _buildRow(
                'Paid Amount',
                'TZS ${NumberFormat('#,##0').format((consignment['paid_amount'] ?? 0).toInt())}',
              ),
              _buildRow(
                'Payment Status',
                isPaid ? 'Paid' : 'Not Paid',
                valueColor: isPaid ? Colors.green : Colors.orange,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSection(
            title: 'Route Information',
            icon: Icons.route,
            children: [
              _buildRow('From', consignment['from']),
              _buildRow('To', consignment['to']),
            ],
          ),
          const SizedBox(height: 16),
          _buildSection(
            title: 'Sender Details',
            icon: Icons.person_outline,
            children: [
              _buildRow('Name', consignment['sender_name']),
              _buildRow(
                'Phone',
                consignment['sender_phone_number'],
                clickable: true,
                onTap: () =>
                    _launchPhoneCall(consignment['sender_phone_number']),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSection(
            title: 'Receiver Details',
            icon: Icons.person,
            children: [
              _buildRow('Name', consignment['receiver_name']),
              _buildRow(
                'Phone',
                consignment['receiver_phone_number'],
                clickable: true,
                onTap: () =>
                    _launchPhoneCall(consignment['receiver_phone_number']),
              ),
            ],
          ),
          if (consignment['consignment_items'] != null &&
              (consignment['consignment_items'] as List).isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildItemsSection(consignment['consignment_items']),
          ],
          const SizedBox(height: 16),
          _buildSection(
            title: 'Issued By',
            icon: Icons.assignment_ind,
            children: [
              _buildRow('Name', consignment['issued_by']),
              _buildRow(
                'Phone',
                consignment['issuer_phone_number'],
                clickable: true,
                onTap: () =>
                    _launchPhoneCall(consignment['issuer_phone_number']),
              ),
              if (consignment['createdAt'] != null)
                _buildRow(
                  'Date',
                  DateFormat('d MMM yyyy, HH:mm').format(
                    DateTime.parse(consignment['createdAt']),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(dynamic c, bool isParcel, bool isPaid) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal.shade600, Colors.teal.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isParcel ? Icons.inventory_2 : Icons.local_shipping,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isParcel ? 'PARCEL' : 'CONSIGNMENT',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 12,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      c['package_name'] ?? 'Unnamed Package',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.tag, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  'ID: ${c['package_id'] ?? _idController.text}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPaid
                        ? Colors.green.shade400
                        : Colors.orange.shade400,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPaid ? Icons.check_circle : Icons.pending,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isPaid ? 'PAID' : 'UNPAID',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: Colors.teal.shade700),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal.shade700,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(
    String label,
    String? value, {
    bool clickable = false,
    VoidCallback? onTap,
    Color? valueColor,
  }) {
    final displayValue = (value == null || value.isEmpty) ? 'N/A' : value;

    Widget valueWidget = Text(
      displayValue,
      style: TextStyle(
        fontWeight: FontWeight.w500,
        fontSize: 14,
        color: valueColor ?? (clickable ? Colors.blue : null),
        decoration: clickable ? TextDecoration.underline : TextDecoration.none,
      ),
    );

    if (clickable && onTap != null) {
      valueWidget = GestureDetector(onTap: onTap, child: valueWidget);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
          ),
          Expanded(child: valueWidget),
        ],
      ),
    );
  }

  Widget _buildItemsSection(List<dynamic> items) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.shopping_bag,
                      size: 18, color: Colors.teal),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Consignment Items',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${items.length}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.teal.shade900,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = items[index];
              final int value = (item['value'] ?? 0).toInt();
              final int qty = (item['quantity'] ?? 1).toInt();
              return Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.teal.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.teal,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['name'] ?? 'Unnamed Item',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Qty: $qty  •  Unit: TZS ${NumberFormat('#,##0').format(value)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'TZS ${NumberFormat('#,##0').format(value * qty)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.teal,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────
  Future<void> _launchPhoneCall(String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.isEmpty) return;
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch phone app')),
      );
    }
  }
}