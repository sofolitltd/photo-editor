import 'dart:io';

import 'package:flutter/material.dart';

class ProcessedImagePage extends StatelessWidget {
  final File image;

  ProcessedImagePage({super.key, required this.image});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Processed Image'),
      ),
      body: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, // Adjust the number of columns
        ),
        itemCount: 1, // We are showing 1 image for now
        itemBuilder: (context, index) {
          return Image.file(image); // Display the image
        },
      ),
    );
  }
}
