import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'image_cropper_screen.dart';

class ImagePickerPage extends StatefulWidget {
  @override
  _ImagePickerPageState createState() => _ImagePickerPageState();
}

class _ImagePickerPageState extends State<ImagePickerPage> {
  File? _image;

  Future<void> _pickImage() async {
    final imagePicker = ImagePicker();

    // Await the result of picking the image
    final pickedFile = await imagePicker.pickImage(source: ImageSource.gallery);

    // Check if a file is selected
    if (pickedFile != null) {
      setState(() {
        // Convert XFile to File
        _image = File(pickedFile.path);
      });

      // Navigate to the second page with the selected image
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ImageCropperPage(image: _image!),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Select Image'),
      ),
      body: Center(
        child: Text('Pick an image from the gallery'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _pickImage,
        child: Icon(Icons.add_a_photo),
      ),
    );
  }
}
