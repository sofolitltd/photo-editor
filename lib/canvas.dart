import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';

class _ImageData {
  Image image;
  File file;
  Offset position;
  double scale;
  double rotation;
  bool selected;
  Size size;
  GlobalKey key = GlobalKey(); // Global key to get rendered size

  _ImageData({
    required this.image,
    required this.file,
    required this.position,
    this.scale = 1.0,
    this.rotation = 0.0,
    this.selected = false,
    this.size = const Size(100, 100), // Default size
  });
}

class CanvasWidget extends StatefulWidget {
  const CanvasWidget({super.key});

  @override
  State<CanvasWidget> createState() => _CanvasWidgetState();
}

class _CanvasWidgetState extends State<CanvasWidget> {
// Controller for cropping
  var _canvasWidth = 512.0;
  var _canvasHeight = 512.0;
  Color _selectedColor = Colors.white; // Default color

  final List<_ImageData> _images = []; // Store images and their data
  bool _isImageSelected = false; // Track if any image is selected
  Uint8List? _imageBytes; // Store the image data for cropping
  int? _selectedImageIndex; // Track the selected image index

  Future<void> _addImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final file = File(pickedFile.path);
      final image = await _loadImage(file);

      setState(() {
        _images.add(_ImageData(
          image: image,
          file: file,
          position: const Offset(100, 100),
          // Default position
          size: const Size(150, 150),
          // Default size
          selected: true,
        ));
        _isImageSelected = true;
        _selectedImageIndex =
            _images.length - 1; // Select the newly added image
      });
    }
  }

  Future<Image> _loadImage(File file) async {
    return Image.file(file);
  }

  void _selectImage(_ImageData imageData, int index) {
    setState(() {
      for (var image in _images) {
        image.selected = false;
      }
      imageData.selected = true;
      _isImageSelected = true;
      _selectedImageIndex = index;
    });
  }

  void _updateImagePosition(_ImageData imageData, Offset newPosition) {
    setState(() {
      imageData.position = newPosition;
    });
  }

  void _deselectAllImages() {
    setState(() {
      for (var image in _images) {
        image.selected = false;
      }
      _isImageSelected = false;
      _selectedImageIndex = null;
    });
  }

  // Method to rotate image
  void _rotateImage(_ImageData imageData, double rotationDelta) {
    setState(() {
      imageData.rotation += rotationDelta;
      // Normalize rotation to keep it within 0 to 2π (0 to 360 degrees)
      imageData.rotation %= 2 * 3.141592653589793; // 2π
    });
  }

  // Function to build corner points for scaling
  Widget _buildCornerPoint(
      _ImageData imageData, int index, Alignment alignment) {
    return Align(
      alignment: alignment,
      child: GestureDetector(
        onPanUpdate: (details) {
          // Determine which corner is being dragged
          if (alignment == Alignment.topLeft) {
            // Dragging top-left corner, keep bottom-right corner fixed
            _resizeImageFromCorner(
              imageData,
              details.delta,
              Alignment.topLeft,
            );
          } else if (alignment == Alignment.topRight) {
            // Dragging top-right corner, keep bottom-left corner fixed
            _resizeImageFromCorner(
              imageData,
              details.delta,
              Alignment.topRight,
            );
          } else if (alignment == Alignment.bottomLeft) {
            // Dragging bottom-left corner, keep top-right corner fixed
            _resizeImageFromCorner(
              imageData,
              details.delta,
              Alignment.bottomLeft,
            );
          } else if (alignment == Alignment.bottomRight) {
            // Dragging bottom-right corner, keep top-left corner fixed
            _resizeImageFromCorner(
              imageData,
              details.delta,
              Alignment.bottomRight,
            );
          }

          setState(() {}); // Update the UI after resizing
        },
        child: Container(
          width: 18,
          height: 16,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                spreadRadius: 3,
                blurRadius: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }

// Helper function to resize image from a specific corner
  void _resizeImageFromCorner(
      _ImageData imageData, Offset delta, Alignment alignment) {
    final newWidth = imageData.size.width +
        delta.dx *
            (alignment == Alignment.topLeft || alignment == Alignment.bottomLeft
                ? -1
                : 1);
    final newHeight = imageData.size.height +
        delta.dy *
            (alignment == Alignment.topLeft || alignment == Alignment.topRight
                ? -1
                : 1);

    // Ensure new width and height maintain the original aspect ratio
    final aspectRatio = imageData.size.width / imageData.size.height;
    final newHeightMaintainingRatio = newWidth / aspectRatio;

    // Limit the size to a minimum to avoid negative or too small dimensions
    if (newWidth > 50 && newHeightMaintainingRatio > 50) {
      imageData.size = Size(newWidth, newHeightMaintainingRatio);

      // Update the position based on which corner is being dragged
      if (alignment == Alignment.topLeft) {
        imageData.position += delta; // Move the image along with the drag
      } else if (alignment == Alignment.topRight) {
        imageData.position += Offset(0, delta.dy); // Adjust the y-position only
      } else if (alignment == Alignment.bottomLeft) {
        imageData.position += Offset(delta.dx, 0); // Adjust the x-position only
      }
      // Bottom-right corner doesn't change position; only the size is updated
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final scaleFactor = screenSize.width / _canvasWidth;
    final scaledCanvasHeight = _canvasHeight * scaleFactor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Canvas Design Page'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: GestureDetector(
                onTap: _deselectAllImages, // Deselect all images on canvas tap
                child: Center(
                  child: ClipRect(
                    child: Stack(
                      children: [
                        CustomPaint(
                          size: Size(screenSize.width, scaledCanvasHeight),
                          painter: CanvasPainter(
                            color: _selectedColor,
                            canvasWidth: _canvasWidth,
                            canvasHeight: _canvasHeight,
                            scaleFactor: scaleFactor,
                          ),
                        ),

                        // Display the images
                        for (int i = 0; i < _images.length; i++)
                          Positioned(
                            left: _images[i].position.dx,
                            top: _images[i].position.dy,
                            child: GestureDetector(
                              onTap: () => _selectImage(_images[i], i),
                              onPanUpdate: (details) {
                                if (_images[i].selected) {
                                  _updateImagePosition(
                                    _images[i],
                                    _images[i].position + details.delta,
                                  );
                                }
                              },
                              child: Transform.rotate(
                                angle: _images[i].rotation,
                                // Apply rotation to the entire widget
                                child: Stack(
                                  children: [
                                    // Image with scaling and rotation
                                    SizedBox(
                                      width: _images[i].size.width,
                                      height: _images[i].size.height,
                                      child: _images[i].image,
                                    ),

                                    // If selected, display the outline and corner points
                                    if (_images[i].selected)
                                      Positioned.fill(
                                        child: Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            // Purple outline around the image
                                            Container(
                                              width: _images[i].size.width,
                                              height: _images[i].size.height,
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                  color: Colors.purple,
                                                  width: 2,
                                                ),
                                              ),
                                            ),

                                            // Corner points for scaling
                                            _buildCornerPoint(_images[i], i,
                                                Alignment.topLeft),
                                            _buildCornerPoint(_images[i], i,
                                                Alignment.topRight),
                                            _buildCornerPoint(_images[i], i,
                                                Alignment.bottomLeft),
                                            _buildCornerPoint(_images[i], i,
                                                Alignment.bottomRight),

                                            //
                                            _buildCornerPoint(_images[i], i,
                                                Alignment.centerRight),
                                            _buildCornerPoint(_images[i], i,
                                                Alignment.centerLeft),
                                            _buildCornerPoint(_images[i], i,
                                                Alignment.topCenter),
                                            _buildCornerPoint(_images[i], i,
                                                Alignment.bottomCenter),

                                            // Rotation icon on bottom right
                                            Positioned(
                                              right: 4,
                                              top: 10,
                                              child: GestureDetector(
                                                onPanUpdate: (details) {
                                                  _rotateImage(
                                                      _images[i],
                                                      details.delta.dx *
                                                          0.01); // Rotating image
                                                },
                                                child: Container(
                                                  decoration:
                                                      const BoxDecoration(
                                                    color: Colors.white,
                                                    shape: BoxShape.circle,
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.black12,
                                                        spreadRadius: 2,
                                                        blurRadius: 3,
                                                      ),
                                                    ],
                                                  ),
                                                  padding:
                                                      const EdgeInsets.all(6),
                                                  child: const Icon(
                                                    Icons.rotate_right,
                                                    size: 20,
                                                    color: Colors.purple,
                                                  ),
                                                ),
                                              ),
                                            ),

                                            // delete image
                                            Positioned(
                                              right: 45,
                                              top: 10,
                                              child: GestureDetector(
                                                onTap: () {
                                                  // delete selected image
                                                  setState(() {
                                                    _images.removeAt(i);
                                                    _selectedImageIndex =
                                                        null; // Reset selection
                                                    _isImageSelected =
                                                        false; // Deselect after deleting
                                                  });
                                                },
                                                child: Container(
                                                  decoration:
                                                      const BoxDecoration(
                                                    color: Colors.white,
                                                    shape: BoxShape.circle,
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.black12,
                                                        spreadRadius: 2,
                                                        blurRadius: 3,
                                                      ),
                                                    ],
                                                  ),
                                                  padding:
                                                      const EdgeInsets.all(6),
                                                  child: const Icon(
                                                    Icons.delete,
                                                    size: 20,
                                                    color: Colors.purple,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Button container below the canvas
          Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.black12),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12.withOpacity(.05),
                  blurRadius: 4,
                  spreadRadius: 2,
                  offset: const Offset(2, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Remove background button
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Iconsax.image),
                ),
                // Canvas size and color
                IconButton(
                  onPressed: () {
                    // _showCustomSizeModal(context);
                  },
                  icon: const Icon(Iconsax.category_2),
                ),

                // Add image button
                IconButton(
                  onPressed: () {
                    _addImage();
                  },
                  icon: const Icon(Iconsax.add_square),
                ),
                // Save button
                IconButton(
                  onPressed: () {
                    // Implement save functionality here
                  },
                  icon: const Icon(Iconsax.direct_inbox),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Custom painter to paint the canvas
class CanvasPainter extends CustomPainter {
  final Color color;
  final double canvasWidth;
  final double canvasHeight;
  final double scaleFactor;

  CanvasPainter({
    required this.color,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.scaleFactor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;

    // Draw the main canvas background
    canvas.drawRect(
      Rect.fromLTWH(
          0, 0, canvasWidth * scaleFactor, canvasHeight * scaleFactor),
      paint,
    );
  }

  @override
  bool shouldRepaint(CanvasPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.canvasWidth != canvasWidth ||
        oldDelegate.canvasHeight != canvasHeight;
  }
}

//
// void _showCustomSizeModal(BuildContext context) async {
//   final result = await showModalBottomSheet<Map<String, dynamic>>(
//     context: context,
//     isScrollControlled: true,
//     builder: (BuildContext context) {
//       return CustomSizeModal(
//         initialWidth: _canvasWidth.toInt(),
//         initialHeight: _canvasHeight.toInt(),
//         initialColor: _selectedColor,
//       );
//     },
//   );
//
//   if (result != null) {
//     final parts = result['size']?.split(' x ');
//     if (parts?.length == 2) {
//       setState(() {
//         _canvasWidth = double.tryParse(parts[0]) ?? _canvasWidth;
//         _canvasHeight = double.tryParse(parts[1]) ?? _canvasHeight;
//         _selectedColor = result['color'] ?? _selectedColor;
//       });
//     }
//   }
// }

// //
// class CustomSizeModal extends StatefulWidget {
//   const CustomSizeModal({
//     super.key,
//     required this.initialWidth,
//     required this.initialHeight,
//     required this.initialColor,
//   });
//
//   final int initialWidth;
//   final int initialHeight;
//   final Color initialColor;
//
//   @override
//   State<CustomSizeModal> createState() => _CustomSizeModalState();
// }
//
// class _CustomSizeModalState extends State<CustomSizeModal> {
//   late TextEditingController _widthController;
//   late TextEditingController _heightController;
//   String? _selectedSize;
//   Color? _selectedColor;
//
//   @override
//   void initState() {
//     super.initState();
//     _widthController =
//         TextEditingController(text: widget.initialWidth.toString());
//     _heightController =
//         TextEditingController(text: widget.initialHeight.toString());
//     _selectedColor = widget.initialColor;
//     _selectedSize =
//         '${widget.initialWidth} x ${widget.initialHeight}'; // Ensure the size is selected based on initial values
//   }
//
//   @override
//   void dispose() {
//     _widthController.dispose();
//     _heightController.dispose();
//     super.dispose();
//   }
//
//   void _handleSizeSelection(String size) {
//     setState(() {
//       _selectedSize = size;
//       final parts = size.split(' x ');
//       if (parts.length == 2) {
//         _widthController.text = parts[0];
//         _heightController.text = parts[1];
//       }
//     });
//   }
//
//   void _handleSaveBackground() {
//     int width = int.tryParse(_widthController.text) ?? 0;
//     int height = int.tryParse(_heightController.text) ?? 0;
//     Navigator.pop(context, {
//       'size': '$width x $height',
//       'color': _selectedColor,
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: EdgeInsets.only(
//         bottom: MediaQuery.of(context).viewInsets.bottom,
//       ),
//       child: Container(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           crossAxisAlignment: CrossAxisAlignment.stretch,
//           children: [
//             const Text(
//               'Customize Background',
//               style: TextStyle(
//                 fontSize: 18.0,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//             const SizedBox(height: 16.0),
//             const Text(
//               'Resize',
//               style: TextStyle(
//                 fontSize: 16,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//             const SizedBox(height: 8),
//             SingleChildScrollView(
//               scrollDirection: Axis.horizontal,
//               child: Row(
//                 children: [
//                   _buildSizeChip('1920 x 1080'),
//                   _buildSizeChip('1024 x 1024'),
//                   _buildSizeChip('512 x 512'),
//                   _buildSizeChip('400 x 400'),
//                   _buildSizeChip('300 x 200'),
//                 ],
//               ),
//             ),
//             const SizedBox(height: 16.0),
//             Row(
//               children: [
//                 Expanded(
//                   child: TextField(
//                     controller: _widthController,
//                     keyboardType: TextInputType.number,
//                     decoration: InputDecoration(
//                       labelText: 'Width',
//                       border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(8),
//                       ),
//                       contentPadding:
//                           const EdgeInsets.symmetric(horizontal: 10),
//                     ),
//                   ),
//                 ),
//                 const SizedBox(width: 16),
//                 Expanded(
//                   child: TextField(
//                     controller: _heightController,
//                     keyboardType: TextInputType.number,
//                     decoration: InputDecoration(
//                       labelText: 'Height',
//                       border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(8),
//                       ),
//                       contentPadding:
//                           const EdgeInsets.symmetric(horizontal: 10),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 16.0),
//             const Divider(),
//             const SizedBox(height: 16.0),
//             const Text(
//               'Color',
//               style: TextStyle(
//                 fontSize: 16,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//             const SizedBox(height: 8),
//             SingleChildScrollView(
//               scrollDirection: Axis.horizontal,
//               child: Row(
//                 children: [
//                   _buildColorCircle(Colors.transparent),
//                   _buildColorCircle(Colors.white),
//                   _buildColorCircle(Colors.black),
//                   _buildColorCircle(Colors.red),
//                   _buildColorCircle(Colors.green),
//                   _buildColorCircle(Colors.blue),
//                 ],
//               ),
//             ),
//             const SizedBox(height: 16.0),
//             ElevatedButton(
//               onPressed: _handleSaveBackground,
//               child: const Text('Save'),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildSizeChip(String size) {
//     return Padding(
//       padding: const EdgeInsets.only(right: 8.0),
//       child: ChoiceChip(
//         label: Text(size),
//         selected: _selectedSize == size,
//         onSelected: (_) {
//           _handleSizeSelection(size);
//         },
//       ),
//     );
//   }
//
//   Widget _buildColorCircle(Color color) {
//     return GestureDetector(
//       onTap: () {
//         setState(() {
//           _selectedColor = color;
//         });
//       },
//       child: Container(
//         margin: const EdgeInsets.symmetric(horizontal: 4),
//         decoration: BoxDecoration(
//           color: color,
//           shape: BoxShape.circle,
//           border: Border.all(
//             color: _selectedColor == color ? Colors.black : Colors.transparent,
//             width: 2,
//           ),
//         ),
//         width: 36,
//         height: 36,
//       ),
//     );
//   }
// }
