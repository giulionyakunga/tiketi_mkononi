// widgets/image_picker_dialog.dart
import 'package:flutter/material.dart';

class ImagePickerDialog extends StatelessWidget {
  final VoidCallback onCameraTap;
  final VoidCallback onGalleryTap;
  final VoidCallback onUrlTap;

  const ImagePickerDialog({
    Key? key,
    required this.onCameraTap,
    required this.onGalleryTap,
    required this.onUrlTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Select Image Source',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildOption(
                icon: Icons.camera_alt,
                label: 'Camera',
                onTap: onCameraTap,
              ),
              _buildOption(
                icon: Icons.photo_library,
                label: 'Gallery',
                onTap: onGalleryTap,
              ),
              _buildOption(
                icon: Icons.link,
                label: 'URL',
                onTap: onUrlTap,
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 30, color: Colors.grey[700]),
          ),
          const SizedBox(height: 8),
          Text(label),
        ],
      ),
    );
  }
}