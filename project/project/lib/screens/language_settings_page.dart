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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Language'),
        backgroundColor: const Color.fromARGB(255, 240, 244, 247),
      ),
      body: ListView.builder(
        itemCount: _languages.length,
        itemBuilder: (context, index) {
          final language = _languages[index];
          return RadioListTile(
            title: Text(language['name']!),
            value: language['name']!,
            groupValue: _selectedLanguage,
            onChanged: (value) {
              setState(() {
                _selectedLanguage = value.toString();
              });
              // TODO: Implement language change logic
              if(language['name'] == "Kiswahili") {
                setState(() {
                  _selectedLanguage = 'English';
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    // content: Text('Language changed to ${language['name']}'),
                    content: Text('😳 Kwa sasa programu hii inapatikana kwa Kingereza, Hivi karibuni itapatikana kwa ${language['name']} 🇹🇿 pia❗👍🏾'),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Language changed to ${language['name']}'),
                  ),
                );
              }
            },
          );
        },
      ),
    );
  }
}