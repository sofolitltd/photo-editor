import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

const double ballRadius = 7.5;

class ImageManager extends StatefulWidget {
  const ImageManager({super.key});

  @override
  State<ImageManager> createState() => _ImageManagerState();
}

class _ImageManagerState extends State<ImageManager> {
  final GlobalKey _repaintKey = GlobalKey(); // Key for RepaintBoundary

  // canvas
  var _canvasWidth = 512.0;
  var _canvasHeight = 512.0;
  Color _selectedColor = Colors.white; // Default color

  final ImagePicker _picker = ImagePicker();
  final CropController _cropController = CropController();
  bool _isCropping = false;
  Uint8List? croppedData;

  final List<ImageItem> _images = [];
  ImageItem? _selectedImage;

  Future<void> _pickImages() async {
    // Pick multiple images
    final List<XFile> pickedFiles = await _picker.pickMultiImage();

    if (pickedFiles.isNotEmpty) {
      for (var pickedFile in pickedFiles) {
        final imageFile = File(pickedFile.path);
        final image = await decodeImageFromList(imageFile.readAsBytesSync());
        final double aspectRatio = image.width / image.height;
        final int imageWidth = image.width;
        final int imageHeight = image.height;

        setState(() {
          _images.add(
            ImageItem(
              file: imageFile,
              x: 0,
              y: 0,
              width: 300,
              // Default width
              height: 300 / aspectRatio,
              // Maintain aspect ratio for height
              aspectRatio: aspectRatio,
              angle: 0.0,
              // Default angle for rotation
              oldAngle: 0.0, // Store the previous angle
            ),
          );
        });
      }
    }
  }

  void _deselectImage() {
    setState(() {
      _isCropping = false;
      _selectedImage = null;
    });
  }

  //
  Future<void> _captureAndSave() async {
    try {
      RenderRepaintBoundary boundary = _repaintKey.currentContext
          ?.findRenderObject() as RenderRepaintBoundary;

      // Capture the size of the canvas
      final ui.Image image = await boundary.toImage(
        pixelRatio: _canvasWidth / boundary.size.width,
      ); // You can adjust this for quality
      ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List imageData = byteData!.buffer.asUint8List();

      // Get the external storage directory
      Directory? externalDirectory = await getExternalStorageDirectory();
      if (externalDirectory == null) {
        print('External storage directory not found!');
        return; // Handle the case where the directory is not found
      }

      // Construct the Downloads directory path
      String downloadsPath =
          '/storage/emulated/0/Download'; // Note the capitalization of "Download"

      Directory downloadsDirectory = Directory(downloadsPath);
      if (!await downloadsDirectory.exists()) {
        await downloadsDirectory
            .create(); // Create the Downloads directory if it doesn't exist
      }

      final filePath =
          '$downloadsPath/${DateTime.now().microsecondsSinceEpoch}.png';
      final file = File(filePath);

      // Write the image data to file
      await file.writeAsBytes(imageData);

      Fluttertoast.showToast(msg: 'Image Saved to Downloads!');

      print('Image saved to $filePath');
    } catch (e) {
      print('Error capturing and saving image: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final scaleFactor = screenSize.width / _canvasWidth;
    final scaledCanvasHeight = _canvasHeight * scaleFactor;

    //
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text("Image Editor"),
      ),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.black12.withOpacity(.2),
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            //
            if (_selectedImage != null)
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  _showImageReorderModal();
                },
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.all(8.0),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        Iconsax.layer,
                        size: 30,
                      ),
                      SizedBox(height: 4),
                      Text('Layers'),
                    ],
                  ),
                ),
              ),

            // const Spacer(),

            // bg
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                _showCustomSizeModal(context);
              },
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(8.0),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      Iconsax.category_2,
                      size: 30,
                    ),
                    SizedBox(height: 4),
                    Text('Canvas'),
                  ],
                ),
              ),
            ),

            // gallery
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                _pickImages();
              },
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(8.0),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      Iconsax.gallery,
                      size: 30,
                    ),
                    SizedBox(height: 4),
                    Text('Gallery'),
                  ],
                ),
              ),
            ),

            // save
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                if (_images.isNotEmpty) {
                  _deselectImage();
                  Future.delayed(const Duration(seconds: 1)).then((_) {
                    _captureAndSave();
                  });
                } else {
                  Fluttertoast.showToast(msg: "No image found");
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(8.0),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      Iconsax.direct_inbox,
                      size: 30,
                    ),
                    SizedBox(height: 4),
                    Text('Save'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      body: GestureDetector(
        onTap: _deselectImage,
        child: Center(
          child: RepaintBoundary(
            key: _repaintKey,
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                //
                CustomPaint(
                  size: Size(screenSize.width, scaledCanvasHeight),
                  painter: CanvasPainter(
                    color: _selectedColor,
                    canvasWidth: _canvasWidth,
                    canvasHeight: _canvasHeight,
                    scaleFactor: scaleFactor,
                  ),
                ),

                //
                ..._images.asMap().entries.map(
                      (entry) => _buildImageWidget(
                        entry.key,
                        entry.value,
                      ),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Build each image widget with corner points for resizing, moving, and rotation
  Widget _buildImageWidget(int index, ImageItem imageItem) {
    return Positioned(
      top: imageItem.y,
      left: imageItem.x,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedImage = imageItem;
          });
        },
        onPanUpdate: (DragUpdateDetails details) {
          if (_selectedImage == imageItem) {
            setState(() {
              imageItem.x += details.delta.dx;
              imageItem.y += details.delta.dy;
            });
          }
        },
        child: Transform.rotate(
          angle: imageItem.angle,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: Container(
                  decoration: BoxDecoration(
                    border: _selectedImage == imageItem
                        ? Border.all(color: Colors.blue, width: 2)
                        : null,
                  ),
                  child: (_selectedImage == imageItem && _isCropping)
                      ? _buildCropWidget(imageItem) // Show crop widget
                      : Image.file(
                          imageItem.file,
                          height: imageItem.height,
                          width: imageItem.width,
                          fit: BoxFit.cover,
                        ),
                ),
              ),

              // Resizing handles
              if (_selectedImage == imageItem && !_isCropping)
                ..._buildResizingHandles(imageItem),

              // delete, duplicate, more
              if (_selectedImage == imageItem && !_isCropping)
                _buildActionButtons(imageItem, index),

              // rotate
              if (_selectedImage == imageItem && !_isCropping)
                _buildRotationHandle(imageItem), // Rotation handle
            ],
          ),
        ),
      ),
    );
  }

  // Build action buttons for delete, duplicate, etc.
  Widget _buildActionButtons(ImageItem imageItem, int index) {
    return Positioned(
      top: 8,
      right: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              spreadRadius: 3,
              blurRadius: 3,
            ),
          ],
        ),
        child: Row(
          children: [
            // crop button
            Padding(
              padding: const EdgeInsets.all(4),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _isCropping = true; // Enable crop mode
                  });
                },
                child: const Icon(
                  Icons.crop,
                  size: 20,
                ),
              ),
            ),

            // duplicate
            Padding(
              padding: const EdgeInsets.all(4),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    // Duplicate the selected image
                    _images.add(ImageItem(
                      file: imageItem.file,
                      x: imageItem.x + 10,
                      // Offset position slightly
                      y: imageItem.y + 10,
                      // Offset position slightly
                      width: imageItem.width,
                      height: imageItem.height,
                      aspectRatio: imageItem.aspectRatio,
                      angle: imageItem.angle,
                      oldAngle: imageItem.oldAngle,
                    ));
                  });
                },
                child: const Icon(
                  Icons.copy,
                  size: 20,
                ),
              ),
            ),

            // delete
            Padding(
              padding: const EdgeInsets.all(4),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _images.removeAt(index);
                  });
                },
                child: const Icon(
                  Icons.delete,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

// In your Widget class

// Crop widget builder function
  Widget _buildCropWidget(ImageItem imageItem) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(
          width: imageItem.width,
          height: imageItem.height,
          child: Crop(
            image: imageItem.file.readAsBytesSync(),
            controller: _cropController,
            onCropped: (croppedData) async {
              // Save the cropped data as a new image file
              final tempDir = await getTemporaryDirectory();
              String fileName =
                  DateTime.now().microsecondsSinceEpoch.toString();
              final newImagePath = '${tempDir.path}/$fileName.png';
              final newFile = File(newImagePath);

              // Write the bytes to the new file
              await newFile.writeAsBytes(croppedData);

              // Update the image item with the new file and dimensions
              final image = await decodeImageFromList(croppedData);
              if (image != null) {
                setState(() {
                  imageItem.file = newFile;
                  imageItem.width = image.width.toDouble();
                  imageItem.height = image.height.toDouble();
                  imageItem.aspectRatio =
                      image.width / image.height; // Update aspect ratio
                  _isCropping = false; // Disable cropping mode after crop
                });
              }
            },
            initialRectBuilder: (rect, rec) => Rect.fromLTRB(rect.left + 24,
                rect.top + 24, rect.right - 24, rect.bottom - 24),
            // progressIndicator: const CircularProgressIndicator(),
            cornerDotBuilder: (size, edgeAlignment) =>
                const DotControl(color: Colors.blue),
            // clipBehavior: Clip.none,
            interactive: false,
          ),
        ),
        Positioned(
          right: 5,
          bottom: 0,
          child: ElevatedButton(
            onPressed: () {
              _cropController.crop(); // Trigger the cropping
            },
            child: const Text('Crop'), // Button to execute crop
          ),
        ),
        Positioned(
          right: 85,
          bottom: 0,
          child: IconButton.filledTonal(
            onPressed: () {
              setState(() {
                _isCropping = false; // Exit cropping mode
              });
            },
            icon: const Icon(Icons.close),
          ),
        ),
      ],
    );
  }

// Build corner drag points for resizing
  List<Widget> _buildResizingHandles(ImageItem imageItem) {
    return [
      // Top Left
      Positioned(
        top: -ballRadius,
        left: -ballRadius,
        child: Ball(
          onDrag: (double dx, double dy) {
            // Adjusting dimensions based on cropping
            final newWidth = (imageItem.width - dx).clamp(0.0, double.infinity);
            final newHeight = newWidth / imageItem.aspectRatio;

            setState(() {
              imageItem.x += dx; // Adjust the position based on the drag
              imageItem.width = newWidth; // Update width
              imageItem.height = newHeight; // Update height
            });
          },
        ),
      ),
      // Top Right
      Positioned(
        top: -ballRadius,
        left: imageItem.width - ballRadius,
        child: Ball(
          onDrag: (double dx, double dy) {
            final newWidth = (imageItem.width + dx).clamp(0.0, double.infinity);
            final newHeight = newWidth / imageItem.aspectRatio;

            setState(() {
              imageItem.width = newWidth; // Update width
              imageItem.height = newHeight; // Update height
            });
          },
        ),
      ),
      // Bottom Left
      Positioned(
        top: imageItem.height - ballRadius,
        left: -ballRadius,
        child: Ball(
          onDrag: (double dx, double dy) {
            final newHeight =
                (imageItem.height + dy).clamp(0.0, double.infinity);
            final newWidth = newHeight * imageItem.aspectRatio;

            setState(() {
              imageItem.x += (imageItem.width - newWidth); // Adjust position
              imageItem.width = newWidth; // Update width
              imageItem.height = newHeight; // Update height
            });
          },
        ),
      ),
      // Bottom Right
      Positioned(
        top: imageItem.height - ballRadius,
        left: imageItem.width - ballRadius,
        child: Ball(
          onDrag: (double dx, double dy) {
            final newWidth = (imageItem.width + dx).clamp(0.0, double.infinity);
            final newHeight = newWidth / imageItem.aspectRatio;

            setState(() {
              imageItem.width = newWidth; // Update width
              imageItem.height = newHeight; // Update height
            });
          },
        ),
      ),
    ];
  }

  // Build rotation handle
  Widget _buildRotationHandle(ImageItem imageItem) {
    return Positioned(
      top: imageItem.height - 10,
      left: imageItem.width / 2 - 10,
      child: GestureDetector(
        onPanStart: (details) {
          setState(() {
            imageItem.angleDelta = imageItem.oldAngle -
                (details.localPosition.direction); // Track initial direction
          });
        },
        onPanUpdate: (details) {
          setState(() {
            final touchPositionFromCenter = details.localPosition;
            imageItem.angle = touchPositionFromCenter.direction +
                imageItem.angleDelta; // Update rotation angle
          });
        },
        onPanEnd: (details) {
          setState(() {
            imageItem.oldAngle =
                imageItem.angle; // Store old angle for next rotation
          });
        },
        child: Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            child: const Icon(Icons.refresh_rounded)),
      ),
    );
  }

  // Delete image from the list
  void _deleteImage(int index) {
    setState(() {
      _images.removeAt(index); // Remove the image from the main list

      // Close modal if no more images
      if (_images.isEmpty) {
        _deselectImage();
        Navigator.pop(context); // Close modal when no images are left
      }
    });
  }

  // Show image reorder modal
  void _showImageReorderModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Ensures the modal adjusts to content size
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter modalSetState) {
            return Container(
              padding: const EdgeInsets.all(16),
              height: MediaQuery.of(context).size.height * 0.6,
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Iconsax.layer),
                    title: const Text(
                      'Layers',
                      style: TextStyle(
                        // fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    ),
                    trailing: IconButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.close),
                    ),
                  ),
                  const Divider(),
                  Expanded(
                    child: _images.isNotEmpty
                        ? ReorderableListView.builder(
                            itemCount: _images.length,
                            reverse: true,
                            itemBuilder: (context, index) {
                              return Container(
                                key: ValueKey(_images[index]),
                                margin: const EdgeInsets.only(top: 8),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.black12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: ListTile(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  title: Image.file(
                                    _images[index].file,
                                    height: 50,
                                    fit: BoxFit.contain,
                                  ),
                                  leading: const Icon(Icons.drag_handle),
                                  trailing: Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: GestureDetector(
                                      onTap: () {
                                        modalSetState(() {
                                          _deleteImage(index);
                                        });
                                      },
                                      child: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                            onReorder: (int oldIndex, int newIndex) {
                              if (newIndex > oldIndex) newIndex -= 1;
                              final ImageItem movedImage =
                                  _images.removeAt(oldIndex);
                              setState(() {
                                _images.insert(newIndex, movedImage);
                              });
                            },
                          )
                        : const Center(
                            child: Text("No images left"),
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // canvas
  void _showCustomSizeModal(BuildContext context) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return CustomSizeModal(
          initialWidth: _canvasWidth.toInt(),
          initialHeight: _canvasHeight.toInt(),
          initialColor: _selectedColor,
        );
      },
    );

    if (result != null) {
      final parts = result['size']?.split(' x ');
      if (parts?.length == 2) {
        setState(() {
          _canvasWidth = double.tryParse(parts[0]) ?? _canvasWidth;
          _canvasHeight = double.tryParse(parts[1]) ?? _canvasHeight;
          _selectedColor = result['color'] ?? _selectedColor;
        });
      }
    }
  }
}

//
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

// Class to manage each image's position, size, aspect ratio, and rotation
class ImageItem {
  File file;
  double x;
  double y;
  double width;
  double height;
  double aspectRatio;
  double angle;
  double oldAngle;
  double angleDelta;

  ImageItem({
    required this.file,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.aspectRatio,
    required this.angle,
    required this.oldAngle,
    this.angleDelta = 0.0,
  });
}

class Ball extends StatelessWidget {
  final Function onDrag;

  const Ball({
    super.key,
    required this.onDrag,
  });

  void _onDragUpdate(DragUpdateDetails details) {
    onDrag(details.delta.dx, details.delta.dy);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: _onDragUpdate,
      child: Container(
        height: 2 * ballRadius,
        width: 2 * ballRadius,
        decoration: BoxDecoration(
          color: Colors.blue,
          borderRadius: BorderRadius.circular(ballRadius),
          border: Border.all(
            width: 3,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class ImageReorderModal extends StatefulWidget {
  final List<ImageItem> images;
  final Function(int) onDeleteImage; // Callback for deleting an image

  const ImageReorderModal({
    super.key,
    required this.images,
    required this.onDeleteImage, // Accept the callback in constructor
  });

  @override
  State<ImageReorderModal> createState() => _ImageReorderModalState();
}

class _ImageReorderModalState extends State<ImageReorderModal> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Layers'.toUpperCase(),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
            trailing: IconButton(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: const Icon(Icons.close),
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              itemCount: widget.images.length,
              reverse: true,
              itemBuilder: (context, index) {
                return Container(
                  key: ValueKey(widget.images[index]),
                  margin: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    title: Image.file(
                      widget.images[index].file,
                      height: 50,
                      fit: BoxFit.cover,
                    ),
                    leading: const Icon(Icons.drag_handle),
                    trailing: Padding(
                      padding: const EdgeInsets.all(4),
                      child: GestureDetector(
                        onTap: () {
                          widget.onDeleteImage(index); // Call delete callback
                        },
                        child: const Icon(
                          Icons.delete,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ),
                );
              },
              onReorder: (int oldIndex, int newIndex) {
                if (newIndex > oldIndex) newIndex -= 1;
                final ImageItem movedImage = widget.images.removeAt(oldIndex);
                widget.images.insert(newIndex, movedImage);
              },
            ),
          ),
        ],
      ),
    );
  }
}

//
class CustomSizeModal extends StatefulWidget {
  const CustomSizeModal({
    super.key,
    required this.initialWidth,
    required this.initialHeight,
    required this.initialColor,
  });

  final int initialWidth;
  final int initialHeight;
  final Color initialColor;

  @override
  State<CustomSizeModal> createState() => _CustomSizeModalState();
}

class _CustomSizeModalState extends State<CustomSizeModal> {
  late TextEditingController _widthController;
  late TextEditingController _heightController;
  String? _selectedSize;
  Color? _selectedColor;

  @override
  void initState() {
    super.initState();
    _widthController =
        TextEditingController(text: widget.initialWidth.toString());
    _heightController =
        TextEditingController(text: widget.initialHeight.toString());
    _selectedColor = widget.initialColor;
    _selectedSize =
        '${widget.initialWidth} x ${widget.initialHeight}'; // Ensure the size is selected based on initial values
  }

  @override
  void dispose() {
    _widthController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  void _handleSizeSelection(String size) {
    setState(() {
      _selectedSize = size;
      final parts = size.split(' x ');
      if (parts.length == 2) {
        _widthController.text = parts[0];
        _heightController.text = parts[1];
      }
    });
  }

  void _handleSaveBackground() {
    int width = int.tryParse(_widthController.text) ?? 0;
    int height = int.tryParse(_heightController.text) ?? 0;
    Navigator.pop(context, {
      'size': '$width x $height',
      'color': _selectedColor,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Customize Background',
              style: TextStyle(
                fontSize: 18.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16.0),
            const Text(
              'Resize',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildSizeChip('1920 x 1080'),
                  _buildSizeChip('1024 x 1024'),
                  _buildSizeChip('512 x 512'),
                  _buildSizeChip('400 x 400'),
                  _buildSizeChip('300 x 200'),
                ],
              ),
            ),
            const SizedBox(height: 16.0),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _widthController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Width',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _heightController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Height',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 10),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16.0),
            const Divider(),
            const SizedBox(height: 16.0),
            const Text(
              'Color',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildColorCircle(Colors.transparent),
                  _buildColorCircle(Colors.white),
                  _buildColorCircle(Colors.black),
                  _buildColorCircle(Colors.red),
                  _buildColorCircle(Colors.green),
                  _buildColorCircle(Colors.blue),
                ],
              ),
            ),
            const SizedBox(height: 16.0),
            ElevatedButton(
              onPressed: _handleSaveBackground,
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSizeChip(String size) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(size),
        selected: _selectedSize == size,
        onSelected: (_) {
          _handleSizeSelection(size);
        },
      ),
    );
  }

  Widget _buildColorCircle(Color color) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedColor = color;
        });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: _selectedColor == color ? Colors.black : Colors.transparent,
            width: 2,
          ),
        ),
        width: 36,
        height: 36,
      ),
    );
  }
}
