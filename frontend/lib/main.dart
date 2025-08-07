import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:file_picker/file_picker.dart';

void main() {
  runApp(DIURoutineScraperApp());
}

class DIURoutineScraperApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'DIU Routine Scraper',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: RoutineHomePage(),
    );
  }
}

class RoutineHomePage extends StatefulWidget {
  @override
  _RoutineHomePageState createState() => _RoutineHomePageState();
}

class _RoutineHomePageState extends State<RoutineHomePage> {
  final TextEditingController _controller = TextEditingController();
  List<dynamic> routine = [];
  bool isLoading = false;

  Future<void> fetchRoutine(String batchCode) async {
    setState(() {
      isLoading = true;
      routine = [];
    });
    final response = await http.get(Uri.parse('http://localhost:5000/routine/$batchCode'));
    if (response.statusCode == 200) {
      setState(() {
        routine = json.decode(response.body);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No routine found for batch $batchCode')),
      );
    }
    setState(() {
      isLoading = false;
    });
  }

  Future<void> uploadRoutineFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['xlsx', 'csv']);
    if (result != null && result.files.single.path != null) {
      var request = http.MultipartRequest('POST', Uri.parse('http://localhost:5000/upload'));
      request.files.add(await http.MultipartFile.fromPath('file', result.files.single.path!));
      var response = await request.send();
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Routine uploaded successfully.')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed.')));
      }
    }
  }

  void downloadPDF() async {
    final pdf = pw.Document();
    pdf.addPage(pw.Page(build: (pw.Context context) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('DIU Routine', style: pw.TextStyle(fontSize: 24)),
          pw.SizedBox(height: 16),
          pw.Table.fromTextArray(
            headers: ['Day', 'Time', 'Course', 'Room', 'Teacher'],
            data: routine.map((item) => [
              item['day'], item['time'], item['course'], item['room'], item['teacher']
            ]).toList(),
          ),
        ],
      );
    }));
    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('DIU Routine Scraper'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(children: [
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              labelText: 'Enter Batch Code (e.g., 67_C)',
              border: OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(Icons.search),
                onPressed: () => fetchRoutine(_controller.text.trim()),
              ),
            ),
            onSubmitted: (value) => fetchRoutine(value.trim()),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              ElevatedButton.icon(
                icon: Icon(Icons.upload_file),
                label: Text('Upload Routine PDF/Excel'),
                onPressed: uploadRoutineFile,
              ),
              const SizedBox(width: 10),
              if (routine.isNotEmpty)
                ElevatedButton.icon(
                  icon: Icon(Icons.picture_as_pdf),
                  label: Text('Download PDF'),
                  onPressed: downloadPDF,
                ),
            ],
          ),
          const SizedBox(height: 20),
          isLoading
              ? CircularProgressIndicator()
              : Expanded(
                  child: routine.isEmpty
                      ? Center(child: Text('No routine loaded.'))
                      : ListView.builder(
                          itemCount: routine.length,
                          itemBuilder: (context, index) {
                            final entry = routine[index];
                            return Card(
                              elevation: 2,
                              child: ListTile(
                                title: Text('${entry['course']} (${entry['section']})'),
                                subtitle: Text('${entry['day']} | ${entry['time']}\\nRoom: ${entry['room']} | Teacher: ${entry['teacher']}'),
                                isThreeLine: true,
                              ),
                            );
                          },
                        ),
                ),
        ]),
      ),
    );
  }
}
