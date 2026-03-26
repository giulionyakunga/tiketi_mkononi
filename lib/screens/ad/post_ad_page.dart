// screens/post_ad_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:intl/intl.dart';
import 'package:tiketi_mkononi/models/ad_model.dart';
import './ad_service.dart';
import './color_picker_dialog.dart';
import './image_picker_dialog.dart';

class PostAdPage extends StatefulWidget {
  final AdModel? adToEdit;
  
  const PostAdPage({Key? key, this.adToEdit}) : super(key: key);

  @override
  State<PostAdPage> createState() => _PostAdPageState();
}

class _PostAdPageState extends State<PostAdPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _buttonTextController = TextEditingController();
  final _linkUrlController = TextEditingController();
  final _priorityController = TextEditingController();
  
  String? _imageUrl;
  File? _selectedImage;
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
    _priorityController.text = ad.priority.toString();
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

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _buttonTextController.dispose();
    _linkUrlController.dispose();
    _priorityController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
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
                    
                    // Target Users
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
                    
                    // Target Roles
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
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      String finalImageUrl = _imageUrl ?? '';
      
      // Upload image if selected from gallery/camera
      if (_selectedImage != null) {
        finalImageUrl = await _adService.uploadImage(_selectedImage!);
        if (finalImageUrl.isEmpty) {
          throw Exception('Failed to upload image');
        }
      }
      
      final ad = AdModel(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        imageUrl: finalImageUrl,
        buttonText: _buttonTextController.text.trim(),
        linkUrl: _linkUrlController.text.trim().isEmpty 
            ? null 
            : _linkUrlController.text.trim(),
        backgroundColor: _backgroundColor,
        accentColor: _accentColor,
        priority: int.parse(_priorityController.text.trim()),
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
      if (widget.adToEdit != null) {
        success = await _adService.updateAd(widget.adToEdit!.id!, ad);
      } else {
        success = await _adService.createAd(ad);
      }
      
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.adToEdit != null 
                    ? 'Ad updated successfully!' 
                    : 'Ad created successfully!',
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        throw Exception('Failed to save ad');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.adToEdit != null ? 'Edit Ad' : 'Create New Ad',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Theme.of(context).primaryColor,
      ),
      body: Stack(
        children: [
          Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image Section
                  _buildImageSection(),
                  const SizedBox(height: 24),
                  
                  // Title
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
                  const SizedBox(height: 16),
                  
                  // Description
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
                  const SizedBox(height: 16),
                  
                  // Button Text & Link URL
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
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
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTextField(
                          controller: _linkUrlController,
                          label: 'Link URL (Optional)',
                          hint: 'https://...',
                          icon: Icons.link,
                          keyboardType: TextInputType.url,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Priority
                  _buildTextField(
                    controller: _priorityController,
                    label: 'Priority (0-100)',
                    hint: 'Higher priority shows first',
                    icon: Icons.star,
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter priority';
                      }
                      final priority = int.tryParse(value);
                      if (priority == null || priority < 0 || priority > 100) {
                        return 'Priority must be between 0 and 100';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Colors
                  _buildColorSection(),
                  const SizedBox(height: 16),
                  
                  // Schedule
                  _buildScheduleSection(),
                  const SizedBox(height: 16),
                  
                  // Target Audience
                  _buildTargetAudienceSection(),
                  const SizedBox(height: 16),
                  
                  // Status
                  _buildStatusSection(),
                  const SizedBox(height: 24),
                  
                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitAd,
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              widget.adToEdit != null 
                                  ? 'Update Ad' 
                                  : 'Create Ad',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImageSection() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.image, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Ad Image',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.upload),
                  label: const Text('Select Image'),
                ),
              ],
            ),
          ),
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
              color: Colors.grey[100],
            ),
            child: _selectedImage != null
                ? Image.file(
                    _selectedImage!,
                    fit: BoxFit.cover,
                  )
                : _imageUrl != null
                    ? Image.network(
                        _imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.broken_image,
                                  size: 50,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Failed to load image',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          );
                        },
                      )
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate,
                              size: 50,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No image selected',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tap "Select Image" to add',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
          ),
        ],
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
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      validator: validator,
    );
  }

  Widget _buildColorSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Colors',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildColorPicker(
                  label: 'Background',
                  color: _backgroundColor,
                  onTap: () => _pickColor(true),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildColorPicker(
                  label: 'Text Color',
                  color: _accentColor,
                  onTap: () => _pickColor(false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Color(int.parse(_backgroundColor.replaceFirst('#', '0xff'))),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Preview: ${_buttonTextController.text.isEmpty ? 'Button Text' : _buttonTextController.text}',
              style: TextStyle(
                color: Color(int.parse(_accentColor.replaceFirst('#', '0xff'))),
                fontWeight: FontWeight.bold,
              ),
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
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Color(int.parse(color.replaceFirst('#', '0xff'))),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey),
              ),
            ),
            const SizedBox(height: 4),
            Text(color, style: const TextStyle(fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Schedule (Optional)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.calendar_today),
            title: const Text('Start Date'),
            subtitle: Text(
              _startDate != null
                  ? DateFormat('MMM dd, yyyy').format(_startDate!)
                  : 'Not set',
            ),
            trailing: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _selectDate(true),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.calendar_today),
            title: const Text('End Date'),
            subtitle: Text(
              _endDate != null
                  ? DateFormat('MMM dd, yyyy').format(_endDate!)
                  : 'Not set',
            ),
            trailing: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _selectDate(false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetAudienceSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Target Audience',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              TextButton(
                onPressed: _showTargetAudienceDialog,
                child: Text(_hasTargetAudience ? 'Edit' : 'Add'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_hasTargetAudience) ...[
            if (_targetUserIds.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Wrap(
                  spacing: 8,
                  children: _targetUserIds.map((userId) {
                    return Chip(
                      label: Text('User: $userId'),
                      backgroundColor: Colors.blue[100],
                    );
                  }).toList(),
                ),
              ),
            if (_targetRoles.isNotEmpty)
              Wrap(
                spacing: 8,
                children: _targetRoles.map((role) {
                  return Chip(
                    label: Text(role.toUpperCase()),
                    backgroundColor: Colors.green[100],
                  );
                }).toList(),
              ),
            if (_targetUserIds.isEmpty && _targetRoles.isEmpty)
              const Text(
                'No targeting set. Ad will be shown to all users.',
                style: TextStyle(color: Colors.grey),
              ),
          ] else
            const Text(
              'No targeting set. Ad will be shown to all users.',
              style: TextStyle(color: Colors.grey),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Active Status',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          Switch(
            value: _isActive,
            onChanged: (value) {
              setState(() {
                _isActive = value;
              });
            },
            activeColor: Colors.green,
          ),
        ],
      ),
    );
  }
}