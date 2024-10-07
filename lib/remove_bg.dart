import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class RemoveBG {
  File? _image;
  String? _resultImagePath;

  Future<void> _removeBackground(File image) async {
    try {
      final apiKey = await getAvailableApiKey();
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.remove.bg/v1.0/removebg'),
      )
        ..headers.addAll({'Authorization': 'Bearer $apiKey'})
        ..files
            .add(await http.MultipartFile.fromPath('image_file', image.path));

      final response = await request.send();
      final responseBytes =
          await http.Response.fromStream(response).then((res) => res.bodyBytes);
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/removed_bg.png';
      final file = File(filePath);
      await file.writeAsBytes(responseBytes);

      _resultImagePath = filePath;
    } catch (e) {
      print('Error: $e');
      // Handle error (e.g., show a message to the user or retry)
    }
  }

  Future<String> getAvailableApiKey() async {
    final apiKeysRef = FirebaseFirestore.instance.collection('apiKeys');
    final now = DateTime.now();

    // Reset usage counts if it's a new month
    final apiKeyDocs = await apiKeysRef.get();
    for (var doc in apiKeyDocs.docs) {
      final data = doc.data();
      final resetDate = (data['resetDate'] as Timestamp).toDate();

      if (now.isAfter(resetDate)) {
        await apiKeysRef.doc(doc.id).update({
          'usage': 0,
          'resetDate': getNextMonthStartDate(),
        });
      }
    }

    // Get the next available key
    final querySnapshot = await apiKeysRef
        .where('usage', isLessThan: 50)
        .orderBy('usage')
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) {
      throw Exception('No available API keys.');
    }

    final apiKeyDoc = querySnapshot.docs.first;
    final apiKey = apiKeyDoc['key'];

    // Increment the usage count
    await apiKeysRef.doc(apiKeyDoc.id).update({
      'usage': FieldValue.increment(1),
    });

    return apiKey;
  }

  DateTime getNextMonthStartDate() {
    final now = DateTime.now();
    final firstDayOfNextMonth = DateTime(now.year, now.month + 1, 1);
    return firstDayOfNextMonth;
  }
}
