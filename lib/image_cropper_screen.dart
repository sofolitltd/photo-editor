import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

class ImageCropperPage extends StatefulWidget {
  final File image;

  ImageCropperPage({required this.image});

  @override
  _ImageCropperPageState createState() => _ImageCropperPageState();
}

class _ImageCropperPageState extends State<ImageCropperPage> {
  List<Offset> points = [];
  int? selectedPointIndex;
  double imageWidth = 0;
  double imageHeight = 0;

  @override
  void initState() {
    super.initState();
    _initializeImage();
  }

  Future<void> _initializeImage() async {
    // Load the image and get its dimensions
    final imageBytes = await widget.image.readAsBytes();
    final ui.Image image = await decodeImageFromList(imageBytes);

    setState(() {
      imageWidth = image.width.toDouble();
      imageHeight = image.height.toDouble();

      // Set points to cover the entire image area
      points = [
        const Offset(0, 0), // Top-left
        Offset(imageWidth, 0), // Top-right
        Offset(0, imageHeight), // Bottom-left
        Offset(imageWidth, imageHeight), // Bottom-right

        // Midpoints
        Offset(imageWidth * 0.5, 0), // Top-midpoint
        Offset(0, imageHeight * 0.5), // Left-midpoint
        Offset(imageWidth, imageHeight * 0.5), // Right-midpoint
        Offset(imageWidth * 0.5, imageHeight), // Bottom-midpoint
      ];
    });
  }

  Future<void> _processImage() async {
    final imageBytes = await widget.image.readAsBytes();
    img.Image? originalImage = img.decodeImage(imageBytes);

    if (originalImage != null) {
      img.Image croppedImage = _cropImage(originalImage, points);

      final croppedImageFile = File('${widget.image.path}_cropped.jpg')
        ..writeAsBytesSync(img.encodeJpg(croppedImage));

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProcessedImagePage(image: croppedImageFile),
        ),
      );
    }
  }

  img.Image _cropImage(img.Image image, List<Offset> points) {
    int left = points
        .sublist(0, 4)
        .map((e) => e.dx.toInt())
        .reduce((a, b) => a < b ? a : b);
    int top = points
        .sublist(0, 4)
        .map((e) => e.dy.toInt())
        .reduce((a, b) => a < b ? a : b);
    int right = points
        .sublist(0, 4)
        .map((e) => e.dx.toInt())
        .reduce((a, b) => a > b ? a : b);
    int bottom = points
        .sublist(0, 4)
        .map((e) => e.dy.toInt())
        .reduce((a, b) => a > b ? a : b);

    double scaleX = image.width / imageWidth;
    double scaleY = image.height / imageHeight;

    int x = (left * scaleX).toInt();
    int y = (top * scaleY).toInt();
    int width = ((right - left) * scaleX).toInt();
    int height = ((bottom - top) * scaleY).toInt();

    return img.copyCrop(image, x: x, y: y, width: width, height: height);
  }

  void _onPanStart(DragStartDetails details) {
    for (int i = 0; i < points.length; i++) {
      if ((points[i] - details.localPosition).distance < 20) {
        selectedPointIndex = i;
        break;
      }
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (selectedPointIndex != null) {
      setState(() {
        Offset newPoint = details.localPosition;
        if (selectedPointIndex! < 4) {
          points[selectedPointIndex!] = _keepPointInBounds(newPoint);
        } else {
          if (selectedPointIndex == 4) {
            // Top Midpoint
            points[0] = Offset(
                points[0].dx, points[0].dy + (newPoint.dy - points[4].dy));
            points[1] = Offset(
                points[1].dx, points[1].dy + (newPoint.dy - points[4].dy));
          } else if (selectedPointIndex == 5) {
            // Left Midpoint
            points[0] = Offset(
                points[0].dx + (newPoint.dx - points[5].dx), points[0].dy);
            points[2] = Offset(
                points[2].dx + (newPoint.dx - points[5].dx), points[2].dy);
          } else if (selectedPointIndex == 6) {
            // Right Midpoint
            points[1] = Offset(
                points[1].dx + (newPoint.dx - points[6].dx), points[1].dy);
            points[3] = Offset(
                points[3].dx + (newPoint.dx - points[6].dx), points[3].dy);
          } else if (selectedPointIndex == 7) {
            // Bottom Midpoint
            points[2] = Offset(
                points[2].dx, points[2].dy + (newPoint.dy - points[7].dy));
            points[3] = Offset(
                points[3].dx, points[3].dy + (newPoint.dy - points[7].dy));
          }
        }

        _updateMidpoints();
      });
    }
  }

  void _onPanEnd(DragEndDetails details) {
    selectedPointIndex = null;
  }

  Offset _keepPointInBounds(Offset point) {
    return Offset(
      point.dx.clamp(0, imageWidth),
      point.dy.clamp(0, imageHeight),
    );
  }

  void _updateMidpoints() {
    points[4] = _getMidpoint(points[0], points[1]); // Top-midpoint
    points[5] = _getMidpoint(points[0], points[2]); // Left-midpoint
    points[6] = _getMidpoint(points[1], points[3]); // Right-midpoint
    points[7] = _getMidpoint(points[2], points[3]); // Bottom-midpoint
  }

  Offset _getMidpoint(Offset p1, Offset p2) {
    return Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crop Image'),
      ),
      body: imageWidth == 0 || imageHeight == 0
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                Container(
                  color: Colors.red,
                  child: Positioned.fill(
                    child: Image.file(
                      widget.image,
                    ),
                  ),
                ),
                GestureDetector(
                  onPanStart: _onPanStart,
                  onPanUpdate: _onPanUpdate,
                  onPanEnd: _onPanEnd,
                  child: CustomPaint(
                    painter: CropPainter(points),
                    child: Container(),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          onPressed: _processImage,
          child: const Text('Done'),
        ),
      ),
    );
  }
}

class CropPainter extends CustomPainter {
  final List<Offset> points;

  CropPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    Paint pointPaint = Paint()
      ..color = Colors.red
      ..strokeWidth = 5.0
      ..style = PaintingStyle.fill;

    Paint linePaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2.0;

    for (var i = 0; i < 4; i++) {
      canvas.drawCircle(points[i], 8.0, pointPaint);
    }

    canvas.drawLine(points[0], points[1], linePaint); // Top
    canvas.drawLine(points[1], points[3], linePaint); // Right
    canvas.drawLine(points[3], points[2], linePaint); // Bottom
    canvas.drawLine(points[2], points[0], linePaint); // Left

    for (int i = 4; i < points.length; i++) {
      canvas.drawCircle(points[i], 5.0, pointPaint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}

class ProcessedImagePage extends StatelessWidget {
  final File image;

  ProcessedImagePage({required this.image});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Processed Image'),
      ),
      body: Center(
        child: Image.file(image),
      ),
    );
  }
}
