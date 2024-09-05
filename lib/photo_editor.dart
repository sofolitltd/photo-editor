import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:iconsax/iconsax.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class PhotoEditor extends StatefulWidget {
  const PhotoEditor({super.key});

  @override
  State<PhotoEditor> createState() => _PhotoEditorState();
}

class _PhotoEditorState extends State<PhotoEditor> {
  final GlobalKey _repaintKey = GlobalKey(); // Key for RepaintBoundary
  File? _image;
  bool _isLoading = false;
  bool _isImageSelected = false;

  // Controller for handling transformations
  final TransformationController _transformationController =
      TransformationController();

  //
  double _canvasHeight = 400;
  double _canvasWidth = 400;
  Color _selectedColor = Colors.white; // Default background color

  //
  double _removedImageSize = 250;
  Offset _imageOffset = const Offset(16, 56); // Starting position
  double _rotationAngle = 0.0; // Initial rotation angle

  double? _aspectRatio;

  //
  Future getImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);

    setState(() {
      if (pickedFile != null) {
        _image = File(pickedFile.path);
        _isImageSelected = true; // Image is selected

        //
        _calculateAspectRatio();
      } else {
        print('No image selected.');
      }
    });
  }

  //
  Future<void> _cropImage() async {
    if (_image != null) {
      CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: _image!.path,
        compressFormat: ImageCompressFormat.png,
        compressQuality: 100,
        uiSettings: [
          AndroidUiSettings(
            hideBottomControls: false,
            toolbarTitle: 'Image Editor',
            toolbarColor: Colors.white,
            toolbarWidgetColor: Colors.black,
            backgroundColor: Colors.white,
            cropFrameColor: Colors.deepPurple,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
            aspectRatioPresets: [
              CropAspectRatioPreset.original,
              CropAspectRatioPreset.square,
              CropAspectRatioPreset.ratio4x3,
              CropAspectRatioPreset.ratio5x3,
              CropAspectRatioPreset.ratio16x9,
            ],
          ),
          WebUiSettings(
            context: context,
            presentStyle: WebPresentStyle.dialog,
            size: const CropperSize(
              width: 520,
              height: 520,
            ),
          ),
        ],
      );
      if (croppedFile != null) {
        setState(() {
          _image = File(croppedFile.path);
          _calculateAspectRatio();
        });
      }
    }
  }

  //
  void _calculateAspectRatio() async {
    final ui.Image image =
        await decodeImageFromList(await _image!.readAsBytes());
    setState(() {
      _aspectRatio = image.width / image.height;
    });
  }

  //
  Future<File?> removeBackground(File imageFile) async {
    const String apiKey = "PpcjHuziUePQPRppJSyP8SRU";
    final Uri url = Uri.parse('https://api.remove.bg/v1.0/removebg');

    try {
      final request = http.MultipartRequest('POST', url)
        ..fields['size'] = 'auto'
        ..headers['X-Api-Key'] = apiKey
        ..files.add(
            await http.MultipartFile.fromPath('image_file', imageFile.path));

      final http.StreamedResponse response = await request.send();

      if (response.statusCode == 200) {
        final List<int> bytes = await response.stream.toBytes();
        final File outputFile = File('${imageFile.path}_no_bg.png');
        await outputFile.writeAsBytes(bytes);
        print('Removed Image Path: ${outputFile.path}');
        return outputFile;
      } else {
        print('Error removing background: ${response.reasonPhrase}');
        return null;
      }
    } catch (e) {
      print('Error removing background: $e');
      return null;
    }
  }

  //
  void _onRemoveBackground() async {
    if (_image == null) return;

    setState(() {
      _isLoading = true;
    });

    final File? result = await removeBackground(_image!);

    setState(() {
      _isLoading = false;
      if (result != null) {
        _image = result; // Update the image if successful
      }
    });
  }

  //
  Future<void> _captureAndSave() async {
    //
    try {
      RenderRepaintBoundary boundary = _repaintKey.currentContext
          ?.findRenderObject() as RenderRepaintBoundary;

      // Capture the boundary as an image
      ui.Image image = await boundary.toImage();
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

      //
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

  //
  void _showCustomSizeModal(BuildContext context) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      // Change result type
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return CustomSizeModal(
          initialWidth: _canvasWidth.toInt(),
          initialHeight: _canvasHeight.toInt(),
          initialColor: _selectedColor, // Pass the current color
        );
      },
    );

    if (result != null) {
      final parts = result['size']?.split(' x '); // Get size from result map
      if (parts?.length == 2) {
        setState(() {
          _canvasWidth = double.tryParse(parts[0]) ?? _canvasWidth;
          _canvasHeight = double.tryParse(parts[1]) ?? _canvasHeight;
          _selectedColor = result['color'] ?? _selectedColor; // Update color
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (_image != null) {
          setState(() {
            _isImageSelected = false; // Image is deselected
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: const Text('Image Editor'),
          // actions: [
          //   IconButton(
          //       onPressed: () {
          //         Navigator.push(
          //           context,
          //           MaterialPageRoute(
          //             builder: (context) => const BackgroundRemoval(),
          //           ),
          //         );
          //       },
          //       icon: const Icon(Icons.gamepad_outlined)),
          // ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              //
              if (_image != null)
                Expanded(
                  child: Center(
                    child: RepaintBoundary(
                      key: _repaintKey,
                      child: Stack(
                        children: [
                          Container(
                            width: _canvasWidth,
                            height: _canvasHeight,
                            decoration: BoxDecoration(
                              color: _selectedColor,
                            ),
                            child: Center(
                              child: Stack(
                                children: [
                                  Positioned(
                                    left: _imageOffset.dx,
                                    top: _imageOffset.dy,
                                    child: GestureDetector(
                                      onPanUpdate: _isImageSelected
                                          ? (details) {
                                              setState(() {
                                                _imageOffset += details.delta;
                                              });
                                            }
                                          : null,
                                      onTap: () {
                                        setState(() {
                                          _isImageSelected =
                                              true; // Select the image
                                        });
                                      },
                                      child: Transform(
                                        alignment: Alignment.center,
                                        transform: Matrix4.identity()
                                          ..rotateZ(_rotationAngle),

                                        //
                                        child: Container(
                                          width: _aspectRatio != null
                                              ? _removedImageSize *
                                                  _aspectRatio!
                                              : _removedImageSize,
                                          // Use aspect ratio for width
                                          height: _removedImageSize,
                                          decoration: BoxDecoration(
                                            border: _isImageSelected
                                                ? Border.all(
                                                    color:
                                                        Colors.deepPurpleAccent,
                                                    width: 2.5,
                                                  )
                                                : null,
                                          ),
                                          child: _isLoading
                                              ? Positioned.fill(
                                                  child: Container(
                                                    color: Colors.black12,
                                                    child: const Center(
                                                      child:
                                                          CircularProgressIndicator(
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                                )
                                              : Stack(
                                                  clipBehavior: Clip.none,
                                                  children: [
                                                    InteractiveViewer(
                                                      transformationController:
                                                          _transformationController,
                                                      panEnabled: true,
                                                      scaleEnabled: true,
                                                      child: Image.file(
                                                        _image!,
                                                        fit: BoxFit.cover,
                                                      ),
                                                    ),

                                                    /// ----- rotation handler ---- ///
                                                    if (_isImageSelected &&
                                                        _aspectRatio != null)
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(8.0),
                                                        child: GestureDetector(
                                                          onPanUpdate:
                                                              (details) {
                                                            setState(() {
                                                              _rotationAngle +=
                                                                  details.delta
                                                                          .dx *
                                                                      0.01;
                                                              print(
                                                                  'Rotation angle: $_rotationAngle');
                                                            });
                                                          },
                                                          child: Container(
                                                            decoration:
                                                                BoxDecoration(
                                                              border: Border.all(
                                                                  color: Colors
                                                                      .black12),
                                                              color:
                                                                  Colors.white,
                                                              shape: BoxShape
                                                                  .circle,
                                                              boxShadow: const [
                                                                BoxShadow(
                                                                  color: Colors
                                                                      .black12,
                                                                  blurRadius: 4,
                                                                  spreadRadius:
                                                                      3,
                                                                ),
                                                              ],
                                                            ),
                                                            padding:
                                                                const EdgeInsets
                                                                    .all(4),
                                                            child: const Icon(
                                                              Icons
                                                                  .rotate_right,
                                                              color:
                                                                  Colors.black,
                                                              size: 24,
                                                            ),
                                                          ),
                                                        ),
                                                      ),

                                                    // ------- Scale handles ------- ///
                                                    if (_isImageSelected) ...[
                                                      //top left
                                                      Positioned(
                                                        top: -12,
                                                        left: -12,
                                                        child: GestureDetector(
                                                          onPanUpdate:
                                                              (details) {
                                                            setState(() {
                                                              _removedImageSize -=
                                                                  details
                                                                      .delta.dx;
                                                              _imageOffset +=
                                                                  details.delta;
                                                            });
                                                          },
                                                          child:
                                                              _buildScaleHandle(),
                                                        ),
                                                      ),

                                                      //top right
                                                      Positioned(
                                                        top: -12,
                                                        right: -12,
                                                        child: GestureDetector(
                                                          onPanUpdate:
                                                              (details) {
                                                            setState(() {
                                                              _removedImageSize +=
                                                                  details
                                                                      .delta.dx;
                                                              _imageOffset =
                                                                  Offset(
                                                                _imageOffset.dx,
                                                                _imageOffset
                                                                        .dy +
                                                                    details
                                                                        .delta
                                                                        .dy,
                                                              );
                                                            });
                                                          },
                                                          child:
                                                              _buildScaleHandle(),
                                                        ),
                                                      ),

                                                      // bottom right
                                                      Positioned(
                                                        bottom: -12,
                                                        right: -12,
                                                        child: GestureDetector(
                                                          onPanUpdate:
                                                              (details) {
                                                            setState(() {
                                                              _removedImageSize +=
                                                                  details
                                                                      .delta.dx;
                                                            });
                                                          },
                                                          child:
                                                              _buildScaleHandle(),
                                                        ),
                                                      ),

                                                      // bottom left
                                                      Positioned(
                                                        bottom: -12,
                                                        left: -12,
                                                        child: GestureDetector(
                                                          onPanUpdate:
                                                              (details) {
                                                            setState(() {
                                                              _removedImageSize -=
                                                                  details
                                                                      .delta.dx;
                                                              _imageOffset =
                                                                  Offset(
                                                                _imageOffset
                                                                        .dx +
                                                                    details
                                                                        .delta
                                                                        .dx,
                                                                _imageOffset.dy,
                                                              );
                                                            });
                                                          },
                                                          child:
                                                              _buildScaleHandle(),
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // edit btn
              if (_image != null) ...[
                const SizedBox(height: 16),

                //
                Container(
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
                      // remove bg
                      IconButton(
                        onPressed: _onRemoveBackground,
                        icon: const Icon(Iconsax.image),
                      ),

                      //
                      IconButton(
                        onPressed: _cropImage,
                        icon: const Icon(Iconsax.crop),
                      ),

                      //
                      IconButton(
                        onPressed: () {
                          _showCustomSizeModal(context);
                        },
                        icon: const Icon(Iconsax.size),
                      ),

                      //
                      IconButton(
                        onPressed: getImage,
                        icon: const Icon(Iconsax.add_square),
                      ),

                      //
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _isImageSelected =
                                false; // Hide handlers and rotate button
                          });
                          Future.delayed(const Duration(milliseconds: 500))
                              .then((val) {
                            _captureAndSave();
                          });
                        },
                        icon: const Icon(Iconsax.direct_inbox),
                      ),
                    ],
                  ),
                ),
              ],

              // upload btn
              if (_image == null) ...[
                const SizedBox(height: 16),

                //
                ElevatedButton(
                  onPressed: getImage,
                  child: const Text(
                    'Upload Image',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}

// scale handler ui
Widget _buildScaleHandle() {
  return Container(
    height: 20,
    width: 20,
    margin: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      border: Border.all(color: Colors.black26),
      color: Colors.white,
      shape: BoxShape.circle,
      boxShadow: const [
        BoxShadow(
          color: Colors.black12,
          blurRadius: 2,
          spreadRadius: 2,
        ),
      ],
    ),
    padding: const EdgeInsets.all(4),
  );
}

// crop handler ui
Widget _buildCropHandle({double? height, double? width}) {
  return Container(
    height: height ?? 16,
    width: width ?? 40,
    margin: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      border: Border.all(color: Colors.black26),
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      boxShadow: const [
        BoxShadow(
          color: Colors.black12,
          blurRadius: 2,
          spreadRadius: 2,
        ),
      ],
    ),
    padding: const EdgeInsets.all(4),
  );
}

// Stateful Widget for the bottom modal content
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
      // Return a map with size and color
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

            //
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
                  _buildSizeChip('1024 x 1024'),
                  _buildSizeChip('512 x 512'),
                  _buildSizeChip('400 x 400'),
                  _buildSizeChip('300 x 200'),
                ],
              ),
            ),
            const SizedBox(height: 16.0),

            //

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
                const Expanded(child: SizedBox()),
              ],
            ),

            const SizedBox(height: 16.0),

            const Divider(),

            const SizedBox(height: 16.0),

            //
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
                  _buildColorCircle(Colors.yellow),
                  // Add more colors as needed
                ],
              ),
            ),

            //
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _handleSaveBackground,
              child: const Text('Save Background'),
            ),
          ],
        ),
      ),
    );
  }

  //
  Widget _buildSizeChip(String size) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: ActionChip(
        label: Text(
          size,
          style: TextStyle(
            color: _selectedSize == size ? Colors.white : Colors.black,
          ),
        ),
        onPressed: () => _handleSizeSelection(size),
        backgroundColor: _selectedSize == size ? Colors.blueAccent : null,
      ),
    );
  }

  //
  Widget _buildColorCircle(Color color) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedColor = color;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(
            color: color == _selectedColor ? Colors.black : Colors.black12,
            width: 2,
          ),
        ),
      ),
    );
  }
}
