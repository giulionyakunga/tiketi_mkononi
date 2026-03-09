import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiketi_mkononi/env.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:tiketi_mkononi/services/SimpleCodec.dart';


class ConsignmentsPage extends StatefulWidget {
  final int userId;
  final int officeId;
  final String officeName;
  final String companyName;
  final int companyId;
  final String role;

  const ConsignmentsPage({super.key, required this.userId, required this.officeId, required this.officeName, required this.companyId, required this.companyName, required this.role});

  @override
  State<ConsignmentsPage> createState() => _ConsignmentsPageState();
}

class _ConsignmentsPageState extends State<ConsignmentsPage> {
  bool _isLoading = true;
  String? _error;
  List<dynamic> _consignments = [];
  double totalCollection = 0;
  dynamic _selectedConsignment;
  bool _showDetails = false;
  DateTime _selectedDate = DateTime.now();
  BluetoothDevice? selectedPrinter;
  String _typeFilter = 'all'; // all | parcel | consignment
  
  final BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;
  BluetoothDevice? selectedDevice;

  @override
  void initState() {
    super.initState();
    String dateStr = DateFormat('d-M-yyyy').format(DateTime.now());
    _selectedDate = DateFormat('d-M-yyyy').parse(dateStr);

    requestPermissions();    
    _fetchConsignments();
  }

  Future<void> requestPermissions() async {
    await [
      Permission.bluetooth,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.location,
    ].request();
  }

  Future<void> _fetchConsignments({bool useDNS = true}) async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
        _showDetails = false;
        _selectedConsignment = null;
      });

      final uri = useDNS ? Uri.parse('$backend_url/api/consignments/${widget.userId}/${widget.role}/${widget.officeId}/${widget.companyId}/${DateFormat('d-M-yyyy').format(_selectedDate)}')
      : Uri.parse('${backend_url_with_fallback_ip}consignments/${widget.userId}/${widget.role}/${widget.officeId}/${widget.companyId}/${DateFormat('d-M-yyyy').format(_selectedDate)}');

      final response = await http.get(uri);

      debugPrint('Fetching consignments from: $uri');

      if (response.statusCode == 200) {
        final dynamic responseData = jsonDecode(response.body);
        
        // Handle different response structures
        List<dynamic> consignmentsList = [];
        if (responseData is List) {
          consignmentsList = responseData;
        } else if (responseData is Map && responseData.containsKey('data')) {
          consignmentsList = responseData['data'] as List;
        }

        double totalPaid = 0;

        for (var consignment in consignmentsList) {
          if (consignment['payment_status'] == true) {
            totalPaid += (consignment['paid_amount'] ?? 0).toDouble();
          }
        }

        setState(() {
          totalCollection = totalPaid;
          _consignments = consignmentsList;
        });
        
        debugPrint('Loaded ${consignmentsList.length} consignments');
      } else {
        _error = 'Failed to load consignments (${response.statusCode})';
        debugPrint(_error);
      }
    } on SocketException catch (e) {
      if ((e.osError?.errorCode == 7 || e.osError?.errorCode == 11001) && useDNS) {
        await _fetchConsignments(useDNS: false);
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

  String _getPaymentStatusText(bool? status) {
    if (status == null) return 'Unknown';
    return status ? 'Paid' : 'Not Paid';
  }

  Color _getPaymentStatusColor(bool? status) {
    if (status == null) return Colors.grey;
    return status ? Colors.green : Colors.teal;
  }

  IconData _getPackageTypeIcon(bool? type) {
    if (type!)
      return Icons.inventory_2;   // package/box icon
    else
      return Icons.local_shipping; // shipment icon
  }

  Widget _buildDatePicker() {
    return TextButton.icon(
      onPressed: () => _selectDate(context),
      icon: const Icon(Icons.calendar_today, size: 18), // Optional: Adjust icon size
      label: Text(
        '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
        style: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w500,
          fontSize: 14, // Smaller font size for compactness
        ),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0), // Near-zero vertical padding
        minimumSize: const Size(0, 30), // Set a small fixed height (e.g., 30 logical pixels)
        tapTargetSize: MaterialTapTargetSize.shrinkWrap, // Reduces touch target to content size
        visualDensity: VisualDensity.compact, // Squeezes elements closer
        backgroundColor: Colors.grey[200],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Colors.teal[800]!, width: 1.5),
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2025),    // Allow dates as early as year 2000
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      if((picked != _selectedDate)) {
        setState(() {
          _selectedDate = picked;
        });
        _fetchConsignments();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          (widget.officeId > 0) ? '${widget.officeName} Consignments' : 'All Consignments',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600
          ),
        ),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 3,
        actions: [
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: _buildDatePicker(),
          ),
          if (_selectedConsignment != null)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _showDetails = false;
                  _selectedConsignment = null;
                });
              },
            ),
        ],
      ),
      // body: RefreshIndicator(
      //   onRefresh: _fetchConsignments,
      //   color: Colors.teal,
      //   child: Column(
      //     children: [
      //       Expanded(
      //         child: _buildBody(),
      //       ),
      //       if (_showDetails && _selectedConsignment != null)
      //         _buildDetailsPanel(),
      //     ],
      //   ),
      // ),

      body: Stack(
        children: [

          RefreshIndicator(
            onRefresh: _fetchConsignments,
            color: Colors.teal,
            child: _buildBody(),
          ),

          if (_showDetails && _selectedConsignment != null) ...[
            
            /// This disables background clicks
            ModalBarrier(
              dismissible: true,
              onDismiss: () {
                setState(() {
                  _showDetails = false;
                  _selectedConsignment = null;
                });
              },
              color: Colors.black.withOpacity(0.2),
            ),

            /// Details panel
            Align(
              alignment: Alignment.bottomCenter,
              child: _buildDetailsPanel(),
            ),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.teal,
        onPressed: () {
          // Navigate to add consignment page
          // Navigator.push(
          //   context,
          //   MaterialPageRoute(
          //     builder: (context) => AddConsignmentPage(
          //       userId: widget.userId,
          //       companyId: widget.companyId,
          //     ),
          //   ),
          // );
        },
        icon: const Icon(Icons.money, color: Colors.white),
        label: Text(
          'TSH${NumberFormat('#,##0').format(totalCollection.toInt())}',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  Widget _buildTypeFilter() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Row(
        children: [
          _buildFilterChip(
            label: "All",
            icon: Icons.list,
            value: "all",
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: "Parcel",
            icon: Icons.inventory_2,
            value: "parcel",
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: "Consignment",
            icon: Icons.local_shipping,
            value: "consignment",
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
  required String label,
  required IconData icon,
  required String value,
}) {
  final bool isActive = _typeFilter == value;

  return GestureDetector(
    onTap: () {
      setState(() {
        _typeFilter = value;
      });
    },
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isActive ? Colors.teal : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive ? Colors.teal : Colors.grey.shade300,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: isActive ? Colors.white : Colors.grey.shade700,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isActive ? Colors.white : Colors.grey.shade800,
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildBody() {
    if (_isLoading) {
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
                onPressed: _fetchConsignments,
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

    if (_consignments.isEmpty) {
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
                Icons.inbox,
                size: 80,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Consignments Yet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Consignments you create will appear here',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    final filteredConsignments = _consignments.where((c) {
      if (_typeFilter == 'all') return true;
      return _typeFilter == 'parcel'
          ? c['is_parcel'] == true
          : c['is_parcel'] == false;
    }).toList();
        
    return Column(
      children: [
        // FILTER BUTTONS
        _buildTypeFilter(),

        Expanded(
          child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filteredConsignments.length,
              itemBuilder: (context, index) {
                final consignment = filteredConsignments[index];
                final isSelected = _selectedConsignment == consignment;
          

              return Card(
                elevation: isSelected ? 8 : 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: isSelected
                      ? BorderSide(color: Colors.teal.shade300, width: 2)
                      : BorderSide.none,
                ),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      if (_selectedConsignment == consignment) {
                        _showDetails = !_showDetails;
                      } else {
                        _selectedConsignment = consignment;
                        _showDetails = true;
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
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
                                _getPackageTypeIcon(consignment['is_parcel']),
                                color: Colors.teal,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    consignment['package_name'] ?? 'Unnamed Package',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _getPaymentStatusColor(
                                                  consignment['payment_status'])
                                              .withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              consignment['payment_status'] == true
                                                  ? Icons.check_circle
                                                  : Icons.pending,
                                              size: 14,
                                              color: _getPaymentStatusColor(
                                                  consignment['payment_status']),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              _getPaymentStatusText(
                                                  consignment['payment_status']),
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color: _getPaymentStatusColor(
                                                    consignment['payment_status']),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              isSelected && _showDetails
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                              color: Colors.grey.shade400,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Route information
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Icon(Icons.location_on,
                                        size: 16, color: Colors.grey.shade600),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        consignment['from'] ?? 'Unknown',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w500),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Icon(Icons.arrow_forward,
                                    size: 16, color: Colors.grey.shade400),
                              ),
                              Expanded(
                                child: Row(
                                  children: [
                                    Icon(Icons.location_on,
                                        size: 16, color: Colors.grey.shade600),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        consignment['to'] ?? 'Unknown',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w500),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(),
                        // Sender & Receiver info
                        Row(
                          children: [
                            Expanded(
                              child: _buildPersonInfo(
                                icon: Icons.person_outline,
                                label: 'Sender',
                                name: consignment['sender_name'],
                                phone: consignment['sender_phone_number'],
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 30,
                              color: Colors.grey.shade300,
                              margin: const EdgeInsets.symmetric(horizontal: 12),
                            ),
                            Expanded(
                              child: _buildPersonInfo(
                                icon: Icons.person,
                                label: 'Receiver',
                                name: consignment['receiver_name'],
                                phone: consignment['receiver_phone_number'],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          )
        )
      ]
    );
  }

  Widget _buildPersonInfo({
    required IconData icon,
    required String label,
    required String? name,
    required String? phone,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.grey.shade600),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          name ?? 'N/A',
          style: const TextStyle(fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          phone ?? 'N/A',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Future<void> _printBluetoothReceipt(dynamic consignment) async {

    bool? isConnected = await bluetooth.isConnected;

    if (!(isConnected ?? false)) {
      debugPrint(' Not Connected to bluetooth device, connecting...');
      List<BluetoothDevice> devices = await bluetooth.getBondedDevices();

      if (devices.isNotEmpty) {
        await _selectPrinterDialog(devices);

        if (selectedPrinter == null) {
          print("No printer found");
          return;
        }

        try {
          await bluetooth.connect(selectedPrinter!);
          isConnected = true;
        } catch (e) {
          isConnected = false;
          debugPrint('Failed to connect to printer: $e');

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to connect to printer'),
              backgroundColor: Colors.red,
            ),
          );
          return; // stop printing
        }
      } else {
        // No paired printer found
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No paired Bluetooth printer found.'),
            backgroundColor: Colors.red,
          ),
        );
        return; // stop printing
      }
    }

    if (!(isConnected ?? false)) {
      // Printer still not connected
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Printer is not connected.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final items = consignment['consignment_items'] ?? [];

    bluetooth.printNewLine();
    bluetooth.printCustom(widget.companyName, 2, 1);
    bluetooth.printNewLine();
    bluetooth.printCustom(consignment['is_parcel'] ? "PARCEL RECEIPT" : "CONSIGNMENT RECEIPT", 1, 1);
    bluetooth.printNewLine();

    bluetooth.printCustom("Package No: ${consignment['id']}", 1, 1);

    bluetooth.printLeftRight("Package Name", consignment['package_name'] ?? '', 0);

    bluetooth.printLeftRight(
      "Package Value",
      "TZS ${NumberFormat('#,##0').format((consignment['package_value'] ?? 0).toInt())}",
      0,
    );

    bluetooth.printLeftRight("Payment Status", consignment['payment_status'] ? 'Paid' : 'Not Paid', 0);

    if(consignment['payment_status']) {
      bluetooth.printLeftRight(
        "Paid Amount",
        "TZS ${NumberFormat('#,##0').format((consignment['paid_amount'] ?? 0).toInt())}",
        0,
      );
    }

    bluetooth.printNewLine();
    bluetooth.printCustom("Route", 1, 0);

    bluetooth.printLeftRight("From", consignment['from'] ?? '', 0);
    bluetooth.printLeftRight("To", consignment['to'] ?? '', 0);

    bluetooth.printNewLine();
    bluetooth.printCustom("Sender", 1, 0);

    bluetooth.printLeftRight("Name", consignment['sender_name'] ?? '', 0);
    bluetooth.printLeftRight("Phone", consignment['sender_phone_number'] ?? '', 0);

    bluetooth.printNewLine();
    bluetooth.printCustom("Receiver", 1, 0); 

    bluetooth.printLeftRight("Name", consignment['receiver_name'] ?? '', 0);
    bluetooth.printLeftRight("Phone", consignment['receiver_phone_number'] ?? '', 0);

    if (items.length > 1) {
      bluetooth.printNewLine();
      bluetooth.printCustom("Items", 1, 0);

      int index = 1;
      for (var item in items) {
        bluetooth.printLeftRight(
          "$index. ${item['name']} (x${item['quantity']})",
          "TZS ${NumberFormat('#,##0').format(((item['value'] ?? 0) * item['quantity']).toInt())}",
          1,
        );

        index++;
      }
    }

    bluetooth.printNewLine();
    bluetooth.printCustom("Issued By", 1, 0);

    bluetooth.printLeftRight("Name", consignment['issued_by'] ?? '', 0);
    bluetooth.printLeftRight("Phone", consignment['issuer_phone_number'] ?? '', 0);

    String data = SimpleCodec.encode(jsonEncode({
      "cid": consignment['id'],
      "oid": consignment['office_id'],
    }));

    // QR CODE
    bluetooth.printQRcode(
      data,
      200,
      200,
      1,
    );

    bluetooth.printCustom("Thank you", 1, 1);
    bluetooth.printNewLine();
    bluetooth.printCustom("Powered by Tiketi Mkononi", 1, 1);
    bluetooth.printCustom("https://tiketimkononi.telabs.co.tz", 1, 1);
    bluetooth.printNewLine();
    bluetooth.printNewLine();
    bluetooth.paperCut();
  }

  Future<void> _selectPrinterDialog(List<BluetoothDevice> devices) async {
    if (devices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No printers found.')),
      );
      return;
    }

    await showDialog(
      context: context,
      builder: (context) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final isSmallScreen = constraints.maxWidth < 400;
            final dialogWidth = isSmallScreen ? constraints.maxWidth * 0.9 : 400.0;

            return AlertDialog(
              contentPadding: EdgeInsets.all(20),
              title: Text("Select a printer"),
              content: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: dialogWidth),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: devices
                        .map(
                          (device) => ListTile(
                            title: Text(device.name!),
                            subtitle: Text(device.address!),
                            onTap: () async {
                              _saveSelectedPrinter(device.name!);
                              selectedPrinter = device;
                              Navigator.of(context).pop();
                            },
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _saveSelectedPrinter(String printerName) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_printer_name', printerName);
  }

  Future<void> _shareConsignment(dynamic consignment) async {
    final pdf = pw.Document();
    final items = consignment['consignment_items'] ?? [];

    String data = SimpleCodec.encode(jsonEncode({
      "cid": consignment['id'],
      "oid": consignment['office_id'],
    }));

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(58 * PdfPageFormat.mm, double.infinity),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [

              pw.SizedBox(height: 8),

              pw.Center(
                child: pw.Text(
                  widget.companyName,
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),

              pw.SizedBox(height: 8),

              pw.Center(
                child: pw.Text(
                  consignment['is_parcel'] ? 'PARCEL RECEIPT' : 'CONSIGNMENT RECEIPT',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),

              pw.SizedBox(height: 5),

              pw.Center(
                child: pw.Text(
                  "  Package No: ${consignment['id']}",
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),

              pw.SizedBox(height: 3),


              _pdfRow('  Package Name', consignment['package_name']),

              _pdfRow(
                '  Package Value',
                'TZS ${NumberFormat('#,##0').format((consignment['package_value'] ?? 0).toInt())}',
              ),

              _pdfRow(
                '  Paid Amount',
                'TZS ${NumberFormat('#,##0').format((consignment['paid_amount'] ?? 0).toInt())}',
              ),

              pw.Divider(),

              pw.Text('  Route', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),

              _pdfRow('  From', consignment['from']),
              _pdfRow('  To', consignment['to']),

              pw.Divider(),

              pw.Text('  Sender', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),

              _pdfRow('  Name', consignment['sender_name']),
              _pdfRow('  Phone', consignment['sender_phone_number']),

              pw.Divider(),

              pw.Text('  Receiver', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),

              _pdfRow('  Name', consignment['receiver_name']),
              _pdfRow('  Phone', consignment['receiver_phone_number']),

              if (items.length > 1) ...[
                pw.Divider(),
                pw.Text('  Items', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),


                ...items.asMap().entries.map<pw.Widget>((entry) {
                  int index = entry.key;
                  var item = entry.value;

                  return pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        '  ${index + 1}. ${item['name']}',
                        style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
                      ),
                      _pdfRow('    Quantity', '${item['quantity'] ?? 1}'),
                      _pdfRow(
                        '    Total Value',
                        'TZS ${NumberFormat('#,##0').format(((item['value'] ?? 0) * item['quantity']).toInt())}',
                      ),
                      pw.SizedBox(height: 4),
                    ],
                  );
                }).toList(),
              ],

              pw.Divider(),

              pw.Text('  Issued By', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),

              _pdfRow('  Name', consignment['issued_by']),
              _pdfRow('  Phone', consignment['issuer_phone_number']),

              pw.SizedBox(height: 6),

              pw.Center( child: pw.BarcodeWidget( barcode: pw.Barcode.qrCode(), data: data, width: 60, height: 60, ),),

              pw.SizedBox(height: 8),

              pw.Center(
                child: pw.Text(
                  'Thank you',
                  style: pw.TextStyle(fontSize: 10),
                ),
              ),

              pw.SizedBox(height: 6),

              pw.Center(
                child: pw.Text(
                  'Powered by Tiketi Mkononi',
                  style: pw.TextStyle(fontSize: 8),
                ),
              ),
                            
              pw.SizedBox(height: 2),

              pw.Center(
                child: pw.Text(
                  'https://tiketimkononi.telabs.co.tz',
                  style: pw.TextStyle(fontSize: 8),
                ),
              ),

              pw.SizedBox(height: 10),

            ],
          );
        },
      ),
    );

    // Save PDF
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/receipt.pdf',
    );

    await file.writeAsBytes(await pdf.save());

    // Share PDF
    await Share.shareXFiles(
      [XFile(file.path)],
      text: consignment['is_parcel'] ? 'Parcel Receipt' : 'Consignment Receipt',
    );
  }
  
  pw.Widget _pdfRow(String label, String? value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        children: [
          pw.Expanded(
            flex: 2,
            child: pw.Text(
              label,
              style: pw.TextStyle(fontSize: 7),
            ),
          ),
          pw.Expanded(
            flex: 3,
            child: pw.Text(
              value ?? '',
              style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsPanel() {
    final consignment = _selectedConsignment;
    if (consignment == null) return const SizedBox();

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
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

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.teal.shade700),
                const SizedBox(width: 8),

                Expanded(
                  child: Text(
                    consignment['is_parcel'] ? 'Parcel Details' : 'Consignment Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal.shade700,
                    ),
                  ),
                ),

                IconButton(
                  icon: const Icon(Icons.share),
                  color: Colors.blue,
                  onPressed: () => _shareConsignment(consignment),
                ),

                IconButton(
                  icon: const Icon(Icons.print),
                  color: Colors.teal,
                  onPressed: () => _printBluetoothReceipt(consignment),
                ),
              ],
            )
          ),

          const Divider(),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailSection(
                    title: 'Package Information',
                    icon: Icons.inventory,
                    children: [
                      _buildDetailRow('Package Name', consignment['package_name']),
                      _buildDetailRow('Package Value', 'TZS${NumberFormat('#,##0').format(  (consignment['package_value'] ?? 0).toInt())}'),
                      _buildDetailRow('Paid Amount', 'TZS${NumberFormat('#,##0').format(  (consignment['paid_amount'] ?? 0).toInt())}'),
                      
                    ],
                  ),

                  const SizedBox(height: 16),

                  _buildDetailSection(
                    title: 'Route Information',
                    icon: Icons.route,
                    children: [
                      _buildDetailRow('From', consignment['from']),
                      _buildDetailRow('To', consignment['to']),
                    ],
                  ),

                  const SizedBox(height: 16),

                  _buildDetailSection(
                    title: 'Sender Details',
                    icon: Icons.person_outline,
                    children: [
                      _buildDetailRow('Name', consignment['sender_name']),
                      _buildDetailRow('Phone', consignment['sender_phone_number']),
                    ],
                  ),

                  const SizedBox(height: 16),

                  _buildDetailSection(
                    title: 'Receiver Details',
                    icon: Icons.person,
                    children: [
                      _buildDetailRow('Name', consignment['receiver_name']),
                      _buildDetailRow('Phone', consignment['receiver_phone_number']),
                    ],
                  ),

                  const SizedBox(height: 16),

                  if (consignment['consignment_items'] != null && (consignment['consignment_items'] as List).length > 1)
                  _buildItemsSection(consignment['consignment_items']),

                  const SizedBox(height: 16),

                  _buildDetailSection(
                    title: 'Issued By',
                    icon: Icons.assignment_ind,
                    children: [
                      _buildDetailRow('Name', consignment['issued_by']),
                      _buildDetailRow('Phone', consignment['issuer_phone_number']),
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

  Widget _buildDetailRow(String label, String? value) {
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
              value ?? 'N/A',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsSection(List<dynamic> items) {
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
                Icon(Icons.shopping_bag, size: 18, color: Colors.teal.shade700),
                const SizedBox(width: 8),
                Text(
                  'Consignment Items',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal.shade700,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${items.length} items',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.teal.shade900,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 0),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 0),
            itemBuilder: (context, index) {
              final item = items[index];
              return Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['name'] ?? 'Unnamed Item',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildItemInfo(
                            label: 'Value',
                            value: 'TZS ${NumberFormat('#,##0').format((item['value'] ?? 0).toInt())}',
                          ),
                        ),
                        Expanded(
                          child: _buildItemInfo(
                            label: 'Quantity',
                            value: '${item['quantity'] ?? '1'}',
                          ),
                        ),
                      ],
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

  Widget _buildItemInfo({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

}