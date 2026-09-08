// screens/post_ad_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:intl/intl.dart';
import 'package:tiketi_mkononi/env.dart';
import 'package:tiketi_mkononi/l10n/app_localizations.dart';
import 'package:tiketi_mkononi/models/ad_model.dart';
import './ad_service.dart';
import './color_picker_dialog.dart';
import './image_picker_dialog.dart';

class PostAdPage extends StatefulWidget {
  final int userId;
  final AdModel? adToEdit;
  
  const PostAdPage({Key? key, this.adToEdit, required this.userId}) : super(key: key);

  @override
  State<PostAdPage> createState() => _PostAdPageState();
}

class _PostAdPageState extends State<PostAdPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController(); 
  final _buttonTextController = TextEditingController();
  final _linkUrlController = TextEditingController();
  String _selectedPriority = 'Medium';
  
  String? _imageUrl;
  File? _selectedImage;
  String fileType = '';
  String _backgroundColor = '#FF6B6B';
  String _accentColor = '#FFFFFF';
  bool _isActive = true;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _hasTargetAudience = false;
  List<int> _targetUserIds = [];
  List<String> _targetRoles = [];
  bool _isLoading = false;
  
  final ImagePicker _imagePicker = ImagePicker();
  final AdService _adService = AdService();

  String selectedPaymentMethod = 'MIXX BY YAS';
  final List<String> paymentMethods = ['MIXX BY YAS', 'M-PESA', 'AIRTEL MONEY', 'HALOPESA', 'AZAMPESA'];

  List<dynamic> receiptPackages = [];

  // Responsive helpers
  late double screenWidth;
  late double screenHeight;
  late bool isTablet;
  late bool isSmallScreen;
  late double paddingSize;
  late double fontSizeScale;

  @override
  void initState() {
    super.initState();
    if (widget.adToEdit != null) {
      _loadAdData();
    }
  }

  void _loadAdData() {
    final ad = widget.adToEdit!;
    _titleController.text = ad.title;
    _descriptionController.text = ad.description;
    _buttonTextController.text = ad.buttonText;
    _linkUrlController.text = ad.linkUrl ?? '';
    _selectedPriority = _getPriorityLabel(ad.priority);
    _imageUrl = ad.imageUrl;
    _backgroundColor = ad.backgroundColor;
    _accentColor = ad.accentColor;
    _isActive = ad.isActive;
    _startDate = ad.startDate;
    _endDate = ad.endDate;
    if (ad.targetAudience != null) {
      _hasTargetAudience = true;
      _targetUserIds = List<int>.from(ad.targetAudience?['user_ids'] ?? []);
      _targetRoles = List<String>.from(ad.targetAudience?['roles'] ?? []);
    }
  }

  String _getPriorityLabel(int priority) {
    if (priority >= 70) return 'High';
    if (priority >= 40) return 'Medium';
    return 'Low';
  }

  int _getPriorityValue(String label) {
    switch (label) {
      case 'High':
        return 80;
      case 'Medium':
        return 50;
      case 'Low':
        return 20;
      default:
        return 50;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _buttonTextController.dispose();
    _linkUrlController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => ImagePickerDialog(
        onCameraTap: () async {
          Navigator.pop(context);
          final pickedFile = await _imagePicker.pickImage(
            source: ImageSource.camera,
            maxWidth: 1920,
            maxHeight: 1080,
            imageQuality: 85,
          );
          if (pickedFile != null) {
            setState(() {
              _selectedImage = File(pickedFile.path);
              fileType = pickedFile.path.split('.').last.toLowerCase();
              _imageUrl = null;
            });
          }
        },
        onGalleryTap: () async {
          Navigator.pop(context);
          final pickedFile = await _imagePicker.pickImage(
            source: ImageSource.gallery,
            maxWidth: 1920,
            maxHeight: 1080,
            imageQuality: 85,
          );
          if (pickedFile != null) {
            setState(() {
              _selectedImage = File(pickedFile.path);
              fileType = pickedFile.path.split('.').last.toLowerCase();
              _imageUrl = null;
            });
          }
        },
        onUrlTap: () {
          Navigator.pop(context);
          _showUrlInputDialog();
        },
      ),
    );
  }

  void _showUrlInputDialog() {
    final urlController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Image URL'),
        content: TextField(
          controller: urlController,
          decoration: const InputDecoration(
            hintText: 'https://example.com/image.jpg',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (urlController.text.isNotEmpty) {
                setState(() {
                  _imageUrl = urlController.text;
                  _selectedImage = null;
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _pickColor(bool isBackground) {
    showDialog(
      context: context,
      builder: (context) => ColorPickerDialog(
        initialColor: isBackground ? _backgroundColor : _accentColor,
        title: isBackground ? 'Select Background Color' : 'Select Text Color',
        onColorSelected: (color) {
          setState(() {
            if (isBackground) {
              _backgroundColor = color;
            } else {
              _accentColor = color;
            }
          });
        },
      ),
    );
  }

  Future<void> _selectDate(bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate 
          ? (_startDate ?? DateTime.now())
          : (_endDate ?? DateTime.now()),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  void _showTargetAudienceDialog() {
    final tempUserIds = List<int>.from(_targetUserIds);
    final tempRoles = List<String>.from(_targetRoles);
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Target Audience'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Target specific users or roles (optional)',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    
                    ListTile(
                      title: const Text('Specific Users'),
                      subtitle: Text(
                        tempUserIds.isEmpty 
                            ? 'No users selected' 
                            : '${tempUserIds.length} user(s) selected',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.person_add),
                        onPressed: () => _addUserId(tempUserIds, setStateDialog),
                      ),
                    ),
                    if (tempUserIds.isNotEmpty)
                      Container(
                        height: 100,
                        margin: const EdgeInsets.only(top: 8),
                        child: ListView.builder(
                          itemCount: tempUserIds.length,
                          itemBuilder: (context, index) {
                            return ListTile(
                              dense: true,
                              title: Text('User ID: ${tempUserIds[index]}'),
                              trailing: IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () {
                                  setStateDialog(() {
                                    tempUserIds.removeAt(index);
                                  });
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    
                    const Divider(height: 32),
                    
                    ListTile(
                      title: const Text('User Roles'),
                      subtitle: Text(
                        tempRoles.isEmpty 
                            ? 'No roles selected' 
                            : tempRoles.join(', '),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () => _addRole(tempRoles, setStateDialog),
                      ),
                    ),
                    if (tempRoles.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: tempRoles.map((role) {
                          return Chip(
                            label: Text(role),
                            onDeleted: () {
                              setStateDialog(() {
                                tempRoles.remove(role);
                              });
                            },
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _targetUserIds = tempUserIds;
                    _targetRoles = tempRoles;
                    _hasTargetAudience = _targetUserIds.isNotEmpty || 
                                         _targetRoles.isNotEmpty;
                  });
                  Navigator.pop(context);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _addUserId(List<int> userIds, StateSetter setStateDialog) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add User ID'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: 'Enter user ID',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final userId = int.tryParse(controller.text);
              if (userId != null && !userIds.contains(userId)) {
                setStateDialog(() {
                  userIds.add(userId);
                });
              }
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _addRole(List<String> roles, StateSetter setStateDialog) {
    final controller = TextEditingController();
    final availableRoles = ['admin', 'user', 'premium', 'vip'];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Role'),
        content: DropdownButtonFormField<String>(
          value: null,
          items: availableRoles.map((role) {
            return DropdownMenuItem(
              value: role,
              child: Text(role.toUpperCase()),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null && !roles.contains(value)) {
              setStateDialog(() {
                roles.add(value);
              });
              Navigator.pop(context);
            }
          },
          decoration: const InputDecoration(
            hintText: 'Choose a role',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitAd() async {
    FocusScope.of(context).unfocus();
    await Future.delayed(const Duration(milliseconds: 100));

    if (_formKey.currentState == null) {
      debugPrint("Form key is null!");
      _showSnackBar('Form is not properly initialized', isError: true);
      return;
    }

    bool isValid = true;
    String errorMessage = '';

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      errorMessage = 'Please enter ad title';
      isValid = false;
    } else if (title.length < 3) {
      errorMessage = 'Title must be at least 3 characters';
      isValid = false;
    }

    final description = _descriptionController.text.trim();
    if (isValid && description.isEmpty) {
      errorMessage = 'Please enter description';
      isValid = false;
    } else if (isValid && description.length < 10) {
      errorMessage = 'Description must be at least 10 characters';
      isValid = false;
    }

    final buttonText = _buttonTextController.text.trim();
    if (isValid && buttonText.isEmpty) {
      errorMessage = 'Please enter button text';
      isValid = false;
    }

    final linkUrl = _linkUrlController.text.trim(); 
    if (isValid && linkUrl.isNotEmpty) {
      final urlPattern = RegExp(
        r'^(https?:\/\/)?'
        r'((([a-zA-Z0-9\-]+\.)+[a-zA-Z]{2,})|'
        r'localhost|'
        r'(\d{1,3}\.){3}\d{1,3})'
        r'(:\d+)?'
        r'(\/.*)?$',
        caseSensitive: false,
      );
      
      if (!urlPattern.hasMatch(linkUrl)) {
        errorMessage = 'Please enter a valid URL (e.g., https://example.com)';
        isValid = false;
      }
    } else if (linkUrl.isEmpty) {
      errorMessage = 'Please enter a valid Ad URL';
      isValid = false;
    }

    if (isValid && _selectedPriority.isEmpty) {
      errorMessage = 'Please select priority';
      isValid = false;
    }

    final priority = _getPriorityValue(_selectedPriority);

    if (!isValid) {
      debugPrint("Validation failed: $errorMessage");
      _showSnackBar(errorMessage, isError: true);
      return;
    }

    if (_selectedImage == null && (_imageUrl == null || _imageUrl!.isEmpty)) {
      _showSnackBar('Please select an image or provide an image URL', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      String finalImageUrl = _imageUrl ?? '';
      String imageBase64 = '';

      if (_selectedImage != null) {
        try {
          if (!await _selectedImage!.exists()) {
            throw Exception('Image file does not exist');
          }
          
          final bytes = await _selectedImage!.readAsBytes();
          imageBase64 = base64Encode(bytes);
          fileType = _selectedImage!.path.split('.').last.toLowerCase();
          debugPrint("Image loaded successfully, size: ${bytes.length} bytes");
        } catch (e) {
          debugPrint("Error reading image: $e");
          throw Exception('Failed to read image file: $e');
        }
      }

      final ad = AdModel(
        userId: widget.userId,
        id: widget.adToEdit?.id ?? 0,
        title: title,
        description: description,
        imageUrl: finalImageUrl,
        buttonText: buttonText,
        linkUrl: _linkUrlController.text.trim().isEmpty
            ? null
            : _linkUrlController.text.trim(),
        backgroundColor: _backgroundColor,
        accentColor: _accentColor,
        priority: priority,
        isActive: _isActive,
        startDate: _startDate,
        endDate: _endDate,
        targetAudience: _hasTargetAudience
            ? {
                'user_ids': _targetUserIds,
                'roles': _targetRoles,
              }
            : null,
      );

      bool success;
      String message = '';

      if (widget.adToEdit != null) {
        success = await _adService.updateAd(
          widget.adToEdit!.id,
          ad,
        );
      } else {
        Map<String, dynamic> resp = await _adService.createAd(
          ad,
          _selectedImage != null ? fileType : '',
          _selectedImage != null ? imageBase64 : '',
        );
        success = resp['status'] == true;
        message = resp['body'];
      }

      if (message.trim() == "Kifurushi chako kimeisha!") {
        await getReceiptPackages();
        _payDialog();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message.trim())),
        );
      }

      if (!success) {
        throw Exception('Failed to save ad');
      }

      if (!mounted) return;

      _showSnackBar(
        widget.adToEdit != null
            ? 'Ad updated successfully!'
            : 'Ad created successfully!',
        isError: false,
      );

      Navigator.pop(context, true);
    } catch (e, stackTrace) {
      debugPrint('CREATE AD ERROR: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;
      _showSnackBar('Error: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _submitAdWithSafeValidation() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _submitAd();
    });
  }

  Future<void> getReceiptPackages({bool useDNS = true}) async {
    final Uri uri = useDNS ? Uri.parse('${backend_url}api/receipt_packages_new/ads') 
    : Uri.parse('${backend_url_with_fallback_ip}receipt_packages_new/ads');

    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        debugPrint("response.body : ${response.body}");
        final responseData = jsonDecode(response.body);
        if(responseData.length > 0) {
          setState(() {
            receiptPackages = responseData;
          });
        } 
      }
    } on SocketException catch (e) {
      debugPrint('Network error occurred:');
      debugPrint('- Exception type: ${e.runtimeType}');
      debugPrint('- Message: ${e.message}');
      
      if (e.osError != null) {
        debugPrint('  - Error number (errno): ${e.osError!.errorCode}');
        debugPrint('  - OS message: ${e.osError!.message}');
        debugPrint('  - errorCode: ${e.osError!.errorCode}');
        debugPrint('  - useDNS: ${useDNS}');

        if ((e.osError!.errorCode == 11001 || e.osError!.errorCode == 7) && useDNS) {
          debugPrint('DNS failed! Retrying with IP: ${backend_url_with_fallback_ip}...');
          await getReceiptPackages(useDNS: false);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('use_dns', false);
          return;
        }
      }
      _handleSocketException(e);
    } catch (e) {
      debugPrint('Error getting offices: $e');
    } finally {
      debugPrint('Process finished');
    }
  }

  Future<void> _payDialog() async {
    int? selectedReceiptPackages = receiptPackages.isNotEmpty ? receiptPackages[0]["number_of_receipts"] as int : null;
    int? selectedAmount = receiptPackages.isNotEmpty ? receiptPackages[0]["price"] as int : null;

    final TextEditingController phoneController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              title: const Text(
                "Chagua siku",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Divider(height: 4),
                    
                    ...receiptPackages
                    .map((pkg) {
                      return RadioListTile(
                        dense: true,
                        visualDensity: const VisualDensity(vertical: -4),
                        title: Text(
                          "Siku ${pkg["number_of_receipts"]} - TSH ${NumberFormat('#,##0').format(pkg["price"])}",
                          style: const TextStyle(fontSize: 12),
                        ),
                        value: pkg["number_of_receipts"],
                        groupValue: selectedReceiptPackages,
                        onChanged: (value) {
                          setState(() {
                            selectedReceiptPackages = value;
                            selectedAmount = pkg["price"] as int;
                          });
                        },
                      );
                    }),

                    const SizedBox(height: 6),

                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Njia ya Malipo",
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),

                    const Divider(height: 10),

                    Column(
                      children: paymentMethods.map((method) {
                        return RadioListTile(
                          dense: true,
                          visualDensity: const VisualDensity(vertical: -4),
                          title: Text(method, style: const TextStyle(fontSize: 12)),
                          value: method,
                          groupValue: selectedPaymentMethod,
                          onChanged: (value) {
                            debugPrint('Selected payment method: $value');
                            debugPrint('Selected payment method: $selectedPaymentMethod');
                            setState(() {
                              selectedPaymentMethod = value.toString();
                            });
                          },
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 6),

                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        isDense: true,
                        labelText: "Namba ya simu ya malipo",
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 10),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : () async {
                          if(selectedReceiptPackages != null && selectedReceiptPackages! > 0) {
                            setState(() => _isLoading = true);
                            await _sendPaymentRequest(
                              phoneController.text.trim(),
                              selectedReceiptPackages,
                              selectedAmount,
                            );
                          } else {
                            _showSnackBar("Tafadhali chagua siku", isError: true);
                          }
                        },
                        child: _isLoading ? const CircularProgressIndicator() : const Text("Lipa"),
                      ),
                    ) 
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
  
  Future<void> _sendPaymentRequest(
    String phone,
    int? days,
    int? amount,
    {bool useDNS = true}
  ) async {

    if (phone.isEmpty) {
      _showSnackBar('Phone number cannot be empty', isError: true);
      return;
    }
 
    final Uri uri = useDNS ? Uri.parse('${backend_url}api/pay_ads_package/${widget.userId}')
    : Uri.parse('${backend_url_with_fallback_ip}pay_ads_package/${widget.userId}');

    debugPrint('Selected payment method: $selectedPaymentMethod');

    String selectedPaymentMethod2 = '';
    if(selectedPaymentMethod == 'M-PESA') {
      selectedPaymentMethod2 = 'Mpesa';
    }else if(selectedPaymentMethod == 'MIXX BY YAS') {
      selectedPaymentMethod2 = 'Tigo';
    }else if(selectedPaymentMethod == 'AIRTEL MONEY') {
      selectedPaymentMethod2 = 'Airtel';
    }else if(selectedPaymentMethod == 'HALOPESA') {
      selectedPaymentMethod2 = 'Halopesa';
    }else if(selectedPaymentMethod == 'AZAMPESA') {
      selectedPaymentMethod2 = 'Azampesa';
    }

    try {
      setState(() => _isLoading = true);

      final response = await http.post(
        uri,
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "phone_number": phone,
          "days": days,
          "amount": amount,
          'selected_payment_method': selectedPaymentMethod2,
        }),
      );

      debugPrint('phone_number: $phone');
      debugPrint('days: $days');
      debugPrint('amount: $amount');

      if (response.statusCode == 200) {
        if (response.body == "Processing payment!") { 
          _showSnackBar("Ombi la malipo limetumwa", isError: false);
        } else {
          _showSnackBar(response.body, isError: true);
        }
        Navigator.pop(context);
      } else {
        _showSnackBar("Malipo yameshindwa", isError: true);
      }
    }  on SocketException catch (e) {
      debugPrint('Network error occurred:');
      debugPrint('- Exception type: ${e.runtimeType}');
      debugPrint('- Message: ${e.message}');
      
      if (e.osError != null) {
        debugPrint('  - Error number (errno): ${e.osError!.errorCode}');
        debugPrint('  - OS message: ${e.osError!.message}');
        debugPrint('  - errorCode: ${e.osError!.errorCode}');
        debugPrint('  - useDNS: ${useDNS}');

        if ((e.osError!.errorCode == 11001 || e.osError!.errorCode == 7) && useDNS) {
          debugPrint('DNS failed! Retrying with IP: ${backend_url_with_fallback_ip}...');
          await _sendPaymentRequest(phone, days, amount, useDNS: false);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('use_dns', false);
          return;
        }
      }
      _handleSocketException(e);
    } catch (e) {
      print("Payment error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _handleSocketException(SocketException e) {
    if (e.osError?.errorCode == 7 || e.osError?.errorCode == 101 || e.osError?.errorCode == 111) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Connection Error'),
          content: const Text('Could not connect to the server. Please check your internet connection.'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
    } else {
      _showSnackBar('Connection Error: ${e.message}', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: EdgeInsets.all(16),
      ),
    );
  }

  PopupMenuItem<String> _buildMenuItem({
    required IconData icon,
    required String text,
    required String value,
  }) {
    return PopupMenuItem<String>(
      value: value,
      height: 44,
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: Colors.grey.shade800,
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Responsive layout methods
  void _updateResponsiveValues(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    screenWidth = mediaQuery.size.width;
    screenHeight = mediaQuery.size.height;
    isTablet = screenWidth >= 600;
    isSmallScreen = screenWidth < 400;
    paddingSize = isTablet ? 24.0 : (isSmallScreen ? 12.0 : 16.0);
    fontSizeScale = isTablet ? 1.2 : (isSmallScreen ? 0.9 : 1.0);
  }

  double _responsiveFontSize(double baseSize) {
    return baseSize * fontSizeScale;
  }

  double _responsivePadding(double basePadding) {
    return basePadding * (isTablet ? 1.5 : (isSmallScreen ? 0.75 : 1.0));
  }

  @override
  Widget build(BuildContext context) {
    _updateResponsiveValues(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: EdgeInsets.all(paddingSize),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: IntrinsicHeight(
                    child: Form(
                      key: _formKey,
                      child: isTablet
                          ? _buildTabletLayout()
                          : _buildMobileLayout(),
                    ),
                  ),
                ),
              );
            },
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: Container(
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).primaryColor,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Saving Ad...',
                        style: TextStyle(
                          fontSize: _responsiveFontSize(16),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(
        widget.adToEdit != null ? 'Edit Ad' : 'Create New Ad',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: _responsiveFontSize(20),
        ),
      ),
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: Theme.of(context).primaryColor,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        PopupMenuButton<String>(
          padding: EdgeInsets.zero,
          tooltip: 'More Options',
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          icon: Icon(
            Icons.more_vert,
            color: Theme.of(context).primaryColor,
            size: 22,
          ),
          onSelected: (value) async {
            if (value == 'pay_ads') {
              await getReceiptPackages();
              _payDialog();
            } else if (value == 'exit') {
              Navigator.pop(context);
            }
          },
          itemBuilder: (context) => [   
            _buildMenuItem(
              icon: Icons.add_card,
              text: AppLocalizations.of(context)!.payAds,
              value: 'pay_ads',
            ),
            const PopupMenuDivider(),
            _buildMenuItem(
              icon: Icons.exit_to_app,
              text: AppLocalizations.of(context)!.exit,
              value: 'exit',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildImageSection(),
        SizedBox(height: _responsivePadding(24)),
        _buildTextField(
          controller: _titleController,
          label: 'Ad Title',
          hint: 'Enter catchy title',
          icon: Icons.title,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter ad title';
            }
            if (value.length < 3) {
              return 'Title must be at least 3 characters';
            }
            return null;
          },
        ),
        SizedBox(height: _responsivePadding(16)),
        _buildTextField(
          controller: _descriptionController,
          label: 'Description',
          hint: 'Enter ad description',
          icon: Icons.description,
          maxLines: 3,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter description';
            }
            if (value.length < 10) {
              return 'Description must be at least 10 characters';
            }
            return null;
          },
        ),
        SizedBox(height: _responsivePadding(16)),
        Column(
          children: [
            _buildTextField(
              controller: _buttonTextController,
              label: 'Button Text',
              hint: 'e.g., Learn More',
              icon: Icons.smart_button,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Required';
                }
                return null;
              },
            ),
            SizedBox(height: _responsivePadding(12)),
            _buildTextField(
              controller: _linkUrlController,
              label: 'Link URL (Required)',
              hint: 'https://...',
              icon: Icons.link,
              keyboardType: TextInputType.url,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'URL is required';
                }
                return null;
              },
            ),
          ],
        ),
        SizedBox(height: _responsivePadding(16)),
        _buildPriorityDropdown(),
        SizedBox(height: _responsivePadding(16)),
        _buildColorSection(),
        SizedBox(height: _responsivePadding(16)),
        _buildScheduleSection(),
        SizedBox(height: _responsivePadding(16)),
        _buildTargetAudienceSection(),
        SizedBox(height: _responsivePadding(16)),
        _buildStatusSection(),
        SizedBox(height: _responsivePadding(24)),
        _buildSubmitButton(),
        SizedBox(height: _responsivePadding(32)),
      ],
    );
  }

  Widget _buildTabletLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildImageSection(),
        SizedBox(height: _responsivePadding(24)),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  _buildTextField(
                    controller: _titleController,
                    label: 'Ad Title',
                    hint: 'Enter catchy title',
                    icon: Icons.title,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter ad title';
                      }
                      if (value.length < 3) {
                        return 'Title must be at least 3 characters';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: _responsivePadding(16)),
                  _buildTextField(
                    controller: _descriptionController,
                    label: 'Description',
                    hint: 'Enter ad description',
                    icon: Icons.description,
                    maxLines: 3,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter description';
                      }
                      if (value.length < 10) {
                        return 'Description must be at least 10 characters';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            SizedBox(width: _responsivePadding(16)),
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  _buildTextField(
                    controller: _buttonTextController,
                    label: 'Button Text',
                    hint: 'e.g., Learn More',
                    icon: Icons.smart_button,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: _responsivePadding(16)),
                  _buildTextField(
                    controller: _linkUrlController,
                    label: 'Link URL (Required)',
                    hint: 'https://...',
                    icon: Icons.link,
                    keyboardType: TextInputType.url,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'URL is required';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: _responsivePadding(16)),
        Row(
          children: [
            Expanded(
              child: _buildPriorityDropdown(),
            ),
            SizedBox(width: _responsivePadding(16)),
            Expanded(
              child: _buildStatusSection(),
            ),
          ],
        ),
        SizedBox(height: _responsivePadding(16)),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildColorSection(),
            ),
            SizedBox(width: _responsivePadding(16)),
            Expanded(
              child: Column(
                children: [
                  _buildScheduleSection(),
                  SizedBox(height: _responsivePadding(16)),
                  _buildTargetAudienceSection(),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: _responsivePadding(24)),
        _buildSubmitButton(),
        SizedBox(height: _responsivePadding(32)),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: isTablet ? 60 : 50,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitAdWithSafeValidation,
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
          backgroundColor: Theme.of(context).primaryColor,
        ),
        child: _isLoading
            ? SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Colors.white,
                ),
              )
            : Text(
                widget.adToEdit != null 
                    ? 'Update Ad' 
                    : 'Create Ad',
                style: TextStyle(
                  fontSize: _responsiveFontSize(16),
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  Widget _buildImageSection() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(_responsivePadding(16)),
            child: Row(
              children: [
                Icon(Icons.image, size: isTablet ? 24 : 20, color: Theme.of(context).primaryColor),
                SizedBox(width: 8),
                Text(
                  'Ad Image',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: _responsiveFontSize(16),
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _pickImage,
                  icon: Icon(Icons.upload, size: isTablet ? 20 : 16),
                  label: Text(
                    'Select Image',
                    style: TextStyle(fontSize: _responsiveFontSize(14)),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: isTablet ? 300 : (isSmallScreen ? 150 : 200),
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              color: Colors.grey[100],
            ),
            child: _selectedImage != null
                ? ClipRRect(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    child: Image.file(
                      _selectedImage!,
                      fit: BoxFit.cover,
                    ),
                  )
                : _imageUrl != null
                    ? ClipRRect(
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                        ),
                        child: Image.network(
                          _imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildEmptyImageState();
                          },
                        ),
                      )
                    : _buildEmptyImageState(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyImageState() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        color: Colors.grey[100],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_photo_alternate,
              size: isTablet ? 80 : 50,
              color: Colors.grey[400],
            ),
            SizedBox(height: 8),
            Text(
              'No image selected',
              style: TextStyle(
                fontSize: _responsiveFontSize(16),
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Tap "Select Image" to add',
              style: TextStyle(
                fontSize: _responsiveFontSize(12),
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: TextStyle(fontSize: _responsiveFontSize(14)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: _responsiveFontSize(14)),
        hintText: hint,
        hintStyle: TextStyle(fontSize: _responsiveFontSize(14)),
        prefixIcon: Icon(icon, size: isTablet ? 24 : 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(
          horizontal: _responsivePadding(16),
          vertical: _responsivePadding(14),
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildPriorityDropdown() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: DropdownButtonFormField<String>(
        value: _selectedPriority,
        decoration: InputDecoration(
          labelText: 'Priority',
          labelStyle: TextStyle(fontSize: _responsiveFontSize(14)),
          prefixIcon: Icon(Icons.star, size: isTablet ? 24 : 20),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: _responsivePadding(12),
            vertical: _responsivePadding(8),
          ),
        ),
        items: const [
          DropdownMenuItem(
            value: 'High',
            child: Row(
              children: [
                Icon(Icons.priority_high, color: Colors.red, size: 20),
                SizedBox(width: 8),
                Text('High', style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
          DropdownMenuItem(
            value: 'Medium',
            child: Row(
              children: [
                Icon(Icons.priority_high, color: Colors.orange, size: 20),
                SizedBox(width: 8),
                Text('Medium', style: TextStyle(color: Colors.orange)),
              ],
            ),
          ),
          DropdownMenuItem(
            value: 'Low',
            child: Row(
              children: [
                Icon(Icons.low_priority_rounded, color: Colors.green, size: 20),
                SizedBox(width: 8),
                Text('Low', style: TextStyle(color: Colors.green)),
              ],
            ),
          ),
        ],
        onChanged: (value) {
          setState(() {
            _selectedPriority = value!;
          });
        },
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please select priority';
          }
          return null;
        },
        style: TextStyle(
          fontSize: _responsiveFontSize(14),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildColorSection() {
    return Container(
      padding: EdgeInsets.all(_responsivePadding(16)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.palette, size: isTablet ? 24 : 20, color: Theme.of(context).primaryColor),
              SizedBox(width: 8),
              Text(
                'Colors',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: _responsiveFontSize(16),
                ),
              ),
            ],
          ),
          SizedBox(height: _responsivePadding(12)),
          Row(
            children: [
              Expanded(
                child: _buildColorPicker(
                  label: 'Background',
                  color: _backgroundColor,
                  onTap: () => _pickColor(true),
                ),
              ),
              SizedBox(width: _responsivePadding(16)),
              Expanded(
                child: _buildColorPicker(
                  label: 'Text Color',
                  color: _accentColor,
                  onTap: () => _pickColor(false),
                ),
              ),
            ],
          ),
          SizedBox(height: _responsivePadding(12)),
          Container(
            padding: EdgeInsets.all(_responsivePadding(12)),
            decoration: BoxDecoration(
              color: Color(int.parse(_backgroundColor.replaceFirst('#', '0xff'))),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Preview: ${_buttonTextController.text.isEmpty ? 'Button Text' : _buttonTextController.text}',
              style: TextStyle(
                color: Color(int.parse(_accentColor.replaceFirst('#', '0xff'))),
                fontWeight: FontWeight.bold,
                fontSize: _responsiveFontSize(14),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorPicker({
    required String label,
    required String color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(_responsivePadding(12)),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
          color: Colors.grey[50],
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: _responsiveFontSize(12),
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: _responsivePadding(8)),
            Container(
              width: isTablet ? 50 : 40,
              height: isTablet ? 50 : 40,
              decoration: BoxDecoration(
                color: Color(int.parse(color.replaceFirst('#', '0xff'))),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[400]!, width: 2),
              ),
            ),
            SizedBox(height: _responsivePadding(4)),
            Text(
              color,
              style: TextStyle(
                fontSize: _responsiveFontSize(10),
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleSection() {
    return Container(
      padding: EdgeInsets.all(_responsivePadding(16)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today, size: isTablet ? 24 : 20, color: Theme.of(context).primaryColor),
              SizedBox(width: 8),
              Text(
                'Schedule (Optional)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: _responsiveFontSize(16),
                ),
              ),
            ],
          ),
          SizedBox(height: _responsivePadding(12)),
          _buildDateTile(
            icon: Icons.calendar_today,
            title: 'Start Date',
            date: _startDate,
            onTap: () => _selectDate(true),
          ),
          _buildDateTile(
            icon: Icons.calendar_today,
            title: 'End Date',
            date: _endDate,
            onTap: () => _selectDate(false),
          ),
        ],
      ),
    );
  }

  Widget _buildDateTile({
    required IconData icon,
    required String title,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).primaryColor, size: 20),
      title: Text(
        title,
        style: TextStyle(
          fontSize: _responsiveFontSize(14),
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        date != null
            ? DateFormat('MMM dd, yyyy').format(date!)
            : 'Not set',
        style: TextStyle(
          fontSize: _responsiveFontSize(13),
          color: date != null ? Colors.black87 : Colors.grey[500],
        ),
      ),
      trailing: IconButton(
        icon: Icon(Icons.edit, size: isTablet ? 22 : 20),
        onPressed: onTap,
        color: Theme.of(context).primaryColor,
      ),
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }

  Widget _buildTargetAudienceSection() {
    return Container(
      padding: EdgeInsets.all(_responsivePadding(16)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.people, size: isTablet ? 24 : 20, color: Theme.of(context).primaryColor),
                  SizedBox(width: 8),
                  Text(
                    'Target Audience',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: _responsiveFontSize(16),
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: _showTargetAudienceDialog,
                style: TextButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  _hasTargetAudience ? 'Edit' : 'Add',
                  style: TextStyle(
                    fontSize: _responsiveFontSize(14),
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: _responsivePadding(8)),
          if (_hasTargetAudience) ...[
            if (_targetUserIds.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _targetUserIds.map((userId) {
                    return Chip(
                      label: Text(
                        'User: $userId',
                        style: TextStyle(fontSize: _responsiveFontSize(12)),
                      ),
                      backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                      labelStyle: TextStyle(color: Theme.of(context).primaryColor),
                    );
                  }).toList(),
                ),
              ),
            if (_targetRoles.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _targetRoles.map((role) {
                  return Chip(
                    label: Text(
                      role.toUpperCase(),
                      style: TextStyle(fontSize: _responsiveFontSize(12)),
                    ),
                    backgroundColor: Colors.green.withOpacity(0.1),
                    labelStyle: const TextStyle(color: Colors.green),
                  );
                }).toList(),
              ),
            if (_targetUserIds.isEmpty && _targetRoles.isEmpty)
              Text(
                'No targeting set. Ad will be shown to all users.',
                style: TextStyle(
                  fontSize: _responsiveFontSize(13),
                  color: Colors.grey[600],
                ),
              ),
          ] else
            Text(
              'No targeting set. Ad will be shown to all users.',
              style: TextStyle(
                fontSize: _responsiveFontSize(13),
                color: Colors.grey[600],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusSection() {
    return Container(
      padding: EdgeInsets.all(_responsivePadding(16)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                _isActive ? Icons.check_circle : Icons.cancel,
                color: _isActive ? Colors.green : Colors.red,
                size: isTablet ? 24 : 20,
              ),
              SizedBox(width: 8),
              Text(
                'Active Status',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: _responsiveFontSize(16),
                ),
              ),
            ],
          ),
          Switch(
            value: _isActive,
            onChanged: (value) {
              setState(() {
                _isActive = value;
              });
            },
            activeColor: Colors.green,
            inactiveThumbColor: Colors.red,
            activeTrackColor: Colors.green.withOpacity(0.5),
            inactiveTrackColor: Colors.red.withOpacity(0.3),
          ),
        ],
      ),
    );
  }
}