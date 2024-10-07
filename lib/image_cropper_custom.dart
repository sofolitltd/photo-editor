import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

final _repaintBoundaryKey = GlobalKey();
final _movingRectKey = GlobalKey();

class ImageCropperCustom extends StatelessWidget {
  const ImageCropperCustom({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: Container(
        height: 56,
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(8),
        ),
        margin: const EdgeInsets.all(16),
        child: Column(
          children: [
            IconButton(
              onPressed: () {
                const double pixelRatio = 3.0;
                final RenderRepaintBoundary boundary =
                    _repaintBoundaryKey.currentContext!.findRenderObject()
                        as RenderRepaintBoundary;
                final Size widgetSize = boundary.size;
                final ui.Image image =
                    boundary.toImageSync(pixelRatio: pixelRatio);
                final MovingRectWrapperState state =
                    _movingRectKey.currentState as MovingRectWrapperState;

                // Retrieve the corner points from the current state
                final Offset topLeft = state._topLeft;
                final Offset topRight = state._topRight;
                final Offset bottomRight = state._bottomRight;
                final Offset bottomLeft = state._bottomLeft;

                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => CroppedImageScreen(
                      image: image,
                      topLeft: topLeft,
                      topRight: topRight,
                      bottomRight: bottomRight,
                      bottomLeft: bottomLeft,
                      widgetSize: widgetSize,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.save),
            ),
          ],
        ),
      ),
      body: Center(
        child: MovingRectWrapper(
          key: _movingRectKey,
          child: RepaintBoundary(
            key: _repaintBoundaryKey,
            child: Image.network(
              // 'https://picsum.photos/id/418/400/700',
              'https://www.printonweb.in/images/paper/paper1.webp',
            ),
          ),
        ),
      ),
    );
  }
}

//
class MovingRectWrapper extends StatefulWidget {
  const MovingRectWrapper({super.key, required this.child});
  final Widget child;

  @override
  State<MovingRectWrapper> createState() => MovingRectWrapperState();
}

class MovingRectWrapperState extends State<MovingRectWrapper> {
  late Offset _topLeft;
  late Offset _topRight;
  late Offset _bottomRight;
  late Offset _bottomLeft;

  @override
  void initState() {
    super.initState();
    _topLeft = const Offset(100, 100);
    _topRight = const Offset(200, 100);
    _bottomRight = const Offset(200, 200);
    _bottomLeft = const Offset(100, 200);
  }

  // Calculate the center point of the cropping area based on corners
  Offset get center {
    return Offset(
      (_topLeft.dx + _bottomRight.dx) / 2,
      (_topLeft.dy + _bottomRight.dy) / 2,
    );
  }

  // Calculate the size of the cropping area based on corners
  Size get size {
    return Size(
      _topRight.dx - _topLeft.dx,
      _bottomLeft.dy - _topLeft.dy,
    );
  }

  void _onDragCorner(DragUpdateDetails details, int corner) {
    setState(() {
      switch (corner) {
        case 0:
          _topLeft += details.delta;
          break;
        case 1:
          _topRight += details.delta;
          break;
        case 2:
          _bottomRight += details.delta;
          break;
        case 3:
          _bottomLeft += details.delta;
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTap: () {
        setState(() {
          // Reset to default positions
          _topLeft = const Offset(100, 100);
          _topRight = const Offset(200, 100);
          _bottomRight = const Offset(200, 200);
          _bottomLeft = const Offset(100, 200);
        });
      },
      child: Stack(
        children: [
          widget.child, // The image behind the cropping rectangle
          CustomPaint(
            painter: CropperPainter(
              topLeft: _topLeft,
              topRight: _topRight,
              bottomRight: _bottomRight,
              bottomLeft: _bottomLeft,
            ),
          ),
          // Corner draggable handles
          Positioned(
            top: _topLeft.dy - 10,
            left: _topLeft.dx - 10,
            child: _buildHandle(0),
          ),
          Positioned(
            top: _topRight.dy - 10,
            left: _topRight.dx - 10,
            child: _buildHandle(1),
          ),
          Positioned(
            top: _bottomRight.dy - 10,
            left: _bottomRight.dx - 10,
            child: _buildHandle(2),
          ),
          Positioned(
            top: _bottomLeft.dy - 10,
            left: _bottomLeft.dx - 10,
            child: _buildHandle(3),
          ),
        ],
      ),
    );
  }

  // Builds the draggable handle widget for each corner
  Widget _buildHandle(int corner) {
    return GestureDetector(
      onPanUpdate: (details) => _onDragCorner(details, corner),
      child: Container(
        width: 20,
        height: 20,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.blue,
        ),
      ),
    );
  }
}

class CropperPainter extends CustomPainter {
  const CropperPainter({
    required this.topLeft,
    required this.topRight,
    required this.bottomRight,
    required this.bottomLeft,
  });

  final Offset topLeft;
  final Offset topRight;
  final Offset bottomRight;
  final Offset bottomLeft;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Draw the cropping rectangle by connecting corners
    final path = Path()
      ..moveTo(topLeft.dx, topLeft.dy)
      ..lineTo(topRight.dx, topRight.dy)
      ..lineTo(bottomRight.dx, bottomRight.dy)
      ..lineTo(bottomLeft.dx, bottomLeft.dy)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CropperPainter oldDelegate) {
    return topLeft != oldDelegate.topLeft ||
        topRight != oldDelegate.topRight ||
        bottomRight != oldDelegate.bottomRight ||
        bottomLeft != oldDelegate.bottomLeft;
  }
}

class CroppedImageScreen extends StatelessWidget {
  const CroppedImageScreen({
    super.key,
    required this.image,
    required this.topLeft,
    required this.topRight,
    required this.bottomRight,
    required this.bottomLeft,
    required this.widgetSize,
  });

  final ui.Image image;
  final Offset topLeft;
  final Offset topRight;
  final Offset bottomRight;
  final Offset bottomLeft;
  final Size widgetSize;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cropped Image'),
      ),
      body: Center(
        child: CustomPaint(
          size: Size(
            bottomRight.dx - topLeft.dx, // Width of the cropping area
            bottomRight.dy - topLeft.dy, // Height of the cropping area
          ),
          painter: CroppedImagePainter(
            image: image,
            topLeft: topLeft,
            topRight: topRight,
            bottomRight: bottomRight,
            bottomLeft: bottomLeft,
            widgetSize: widgetSize,
          ),
        ),
      ),
    );
  }
}

class CroppedImagePainter extends CustomPainter {
  const CroppedImagePainter({
    required this.image,
    required this.topLeft,
    required this.topRight,
    required this.bottomRight,
    required this.bottomLeft,
    required this.widgetSize,
  });
  final ui.Image image;
  final Offset topLeft;
  final Offset topRight;
  final Offset bottomRight;
  final Offset bottomLeft;
  final Size widgetSize;

  @override
  void paint(Canvas canvas, Size size) {
    final pixelRatio = image.width / widgetSize.width;

    // Create the path for the cropped area
    final path = Path()
      ..moveTo(topLeft.dx, topLeft.dy)
      ..lineTo(topRight.dx, topRight.dy)
      ..lineTo(bottomRight.dx, bottomRight.dy)
      ..lineTo(bottomLeft.dx, bottomLeft.dy)
      ..close();

    // Clip the canvas to the free-form shape
    canvas.clipPath(path);

    // Calculate the source rectangle from the image
    final src = Rect.fromLTRB(
      topLeft.dx * pixelRatio,
      topLeft.dy * pixelRatio,
      bottomRight.dx * pixelRatio,
      bottomRight.dy * pixelRatio,
    );

    // Draw the image within the clipped area
    canvas.drawImageRect(
      image,
      src,
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint(),
    );
  }

  @override
  bool shouldRepaint(CroppedImagePainter oldDelegate) {
    return topLeft != oldDelegate.topLeft ||
        topRight != oldDelegate.topRight ||
        bottomRight != oldDelegate.bottomRight ||
        bottomLeft != oldDelegate.bottomLeft;
  }
}
