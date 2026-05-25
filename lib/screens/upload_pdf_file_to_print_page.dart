import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:tiketi_mkononi/env.dart';

class UploadPDFFileToPrintPage extends StatefulWidget {
  final int userId;

  const UploadPDFFileToPrintPage({
    super.key,
    required this.userId,
  });

  @override
  State<UploadPDFFileToPrintPage> createState() =>
      _UploadPDFFileToPrintPageState();
}

class _UploadPDFFileToPrintPageState extends State<UploadPDFFileToPrintPage> {
  File? _pdfFile;
  String? _fileName;
  bool _isUploading = false;
  bool _isPrinting = false;

  Future<void> _pickPdfFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result == null || result.files.single.path == null) return;

      setState(() {
        _pdfFile = File(result.files.single.path!);
        _fileName = result.files.single.name;
      });

      _showSnackBar("PDF selected: $_fileName");
    } catch (e) {
      _showSnackBar("Error picking file: $e");
    }
  }

  Future<void> _printPdfFile() async {
    if (_pdfFile == null) {
      _showSnackBar("Please upload a PDF first");
      return;
    }

    setState(() => _isPrinting = true);

    try {
      final Uri uri = Uri.parse('${local_backend_url}api/print_pdf');

      var request = http.MultipartRequest('POST', uri);

      request.fields['userId'] = '${widget.userId}';

      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          _pdfFile!.path,
          contentType: MediaType('application', 'pdf'),
        ),
      );

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        _showSnackBar("✅ Print Success: $responseBody");
      } else {
        _showSnackBar("❌ Print Failed: $responseBody");
      }
    } catch (e) {
      _showSnackBar("Error printing file: $e");
    }

    setState(() => _isPrinting = false);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Upload PDF to Print",
          style: TextStyle(fontWeight: FontWeight.normal)
        ),
        backgroundColor: const Color.fromARGB(255, 240, 244, 247),
        centerTitle: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),

            // Upload Button
            ElevatedButton.icon(
              onPressed: _pickPdfFile,
              icon: const Icon(Icons.upload_file),
              label: const Text("Upload PDF File"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(14),
              ),
            ),

            const SizedBox(height: 20),

            // File Name Display
            if (_fileName != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.picture_as_pdf, color: Colors.red),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _fileName!,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 30),

            // Print Button
            ElevatedButton.icon(
              onPressed:
                  (_pdfFile == null || _isPrinting) ? null : _printPdfFile,
              icon: _isPrinting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.print),
              label: Text(_isPrinting ? "Printing..." : "Print PDF"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}