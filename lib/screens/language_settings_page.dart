import 'package:flutter/material.dart';

class LanguageSettingsPage extends StatefulWidget {
  const LanguageSettingsPage({super.key});

  @override
  State<LanguageSettingsPage> createState() => _LanguageSettingsPageState();
}

class _LanguageSettingsPageState extends State<LanguageSettingsPage> {
  String _selectedLanguage = 'English';

  final List<Map<String, String>> _languages = [
    {'name': 'English', 'code': 'en'},
    {'name': 'Kiswahili', 'code': 'sw'},
  ];

  // Helper method to determine screen size
  bool _isLargeScreen(BuildContext context) {
    return MediaQuery.of(context).size.width > 600;
  }

  @override
  Widget build(BuildContext context) {
    final bool isLargeScreen = _isLargeScreen(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Language Settings'),
        backgroundColor: const Color.fromARGB(255, 240, 244, 247),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isLargeScreen ? 600 : double.infinity,
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isLargeScreen ? 32 : 16,
              vertical: isLargeScreen ? 24 : 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isLargeScreen) ...[
                  const Text(
                    'Select Your Preferred Language',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Choose the language you want to use in the app.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                Card(
                  elevation: isLargeScreen ? 4 : 0,
                  shape: isLargeScreen
                      ? RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        )
                      : null,
                  child: Column(
                    children: [
                      for (final language in _languages)
                        _buildLanguageTile(
                          context: context,
                          language: language,
                          isLargeScreen: isLargeScreen,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                _buildLanguageInfoSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageTile({
    required BuildContext context,
    required Map<String, String> language,
    required bool isLargeScreen,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(
        horizontal: isLargeScreen ? 24 : 16,
        vertical: isLargeScreen ? 16 : 12,
      ),
      title: Text(
        language['name']!,
        style: TextStyle(
          fontSize: isLargeScreen ? 18 : 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      leading: Radio<String>(
        value: language['name']!,
        groupValue: _selectedLanguage,
        onChanged: (value) {
          setState(() {
            _selectedLanguage = value.toString();
          });
          _handleLanguageChange(context, language);
        },
        activeColor: Colors.orange[800],
      ),
      trailing: isLargeScreen
          ? Text(
              language['code']!.toUpperCase(),
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
            )
          : null,
      shape: RoundedRectangleBorder(
        borderRadius: isLargeScreen
            ? BorderRadius.circular(8)
            : BorderRadius.zero,
      ),
      tileColor: isLargeScreen ? Colors.grey[50] : null,
    );
  }

  void _handleLanguageChange(BuildContext context, Map<String, String> language) {
    if (language['name'] == "Kiswahili") {
      setState(() {
        _selectedLanguage = 'English';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '😳 Kwa sasa programu hii inapatikana kwa Kingereza, Hivi karibuni itapatikana kwa ${language['name']} 🇹🇿 pia❗👍🏾',
            style: const TextStyle(fontSize: 14),
          ),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.symmetric(
            horizontal: _isLargeScreen(context) ? 32 : 16,
            vertical: 16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Language changed to ${language['name']}',
            style: const TextStyle(fontSize: 14),
          ),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.symmetric(
            horizontal: _isLargeScreen(context) ? 32 : 16,
            vertical: 16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }

  Widget _buildLanguageInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'About Languages',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        _buildInfoItem(
          icon: Icons.language,
          title: 'English',
          subtitle: 'Default language with full support',
        ),
        const SizedBox(height: 12),
        _buildInfoItem(
          icon: Icons.language,
          title: 'Kiswahili',
          subtitle: 'Coming soon with full localization',
        ),
      ],
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: Colors.orange[800],
          size: 24,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}