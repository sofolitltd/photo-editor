// Show crop modal
// void _showCropModal(BuildContext context, ImageItem imageItem) {
//   CropController _cropController = CropController();
//   //
//   showModalBottomSheet(
//     context: context,
//     isScrollControlled: true, // Make modal height adjustable
//     builder: (context) {
//       return StatefulBuilder(
//         builder: (BuildContext context, StateSetter setState) {
//           return Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 // Modal Header (Cancel - Title - Done)
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     TextButton(
//                       onPressed: () {
//                         Navigator.pop(context); // Cancel the cropping
//                       },
//                       child: const Text('Cancel'),
//                     ),
//                     const Text(
//                       'Crop Image',
//                       style: TextStyle(fontWeight: FontWeight.bold),
//                     ),
//                     TextButton(
//                       onPressed: () {
//                         _cropController.crop(); // Trigger the cropping process
//                       },
//                       child: const Text('Done'),
//                     ),
//                   ],
//                 ),
//                 const SizedBox(height: 16),
//                 // Crop widget
//                 Expanded(
//                   child: Crop(
//                     image: imageItem.file.readAsBytesSync(),
//                     // Load image data
//                     controller: _cropController,
//                     // aspectRatio: 1.0,
//                     // You can set this to null for free cropping
//                     onCropped: (croppedData) async {
//                       // Save the cropped data as a new image file
//                       final tempDir = await getTemporaryDirectory();
//                       final newImagePath = '${tempDir.path}/cropped_image.png';
//                       final newFile = File(newImagePath);
//
//                       // Write the bytes to the new file
//                       await newFile.writeAsBytes(croppedData);
//
//                       setState(() {
//                         // Update the file in the imageItem after cropping
//                         imageItem.file = newFile;
//                       });
//
//                       // Close the modal after cropping is done
//                       Navigator.pop(context);
//                     },
//                   ),
//                 ),
//               ],
//             ),
//           );
//         },
//       );
//     },
//   );
// }

// Method to pick one image at a time
// Future<void> _pickImages() async {
//   final XFile? pickedFile =
//       await _picker.pickImage(source: ImageSource.gallery);
//   if (pickedFile != null) {
//     final imageFile = File(pickedFile.path);
//     final image = await decodeImageFromList(imageFile.readAsBytesSync());
//     final double aspectRatio = image.width / image.height;
//
//     setState(() {
//       _images.add(
//         ImageItem(
//           file: imageFile,
//           x: 0,
//           y: 0,
//           width: 300,
//           // Default width
//           height: 300 / aspectRatio,
//           // Maintain aspect ratio for height
//           aspectRatio: aspectRatio,
//           angle: 0.0,
//           // Default angle for rotation
//           oldAngle: 0.0, // Store the previous angle
//         ),
//       );
//     });
//   }
// }
