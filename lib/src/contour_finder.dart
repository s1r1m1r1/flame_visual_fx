import 'dart:math';
import 'dart:ui';
import 'package:flame/components.dart';
import 'package:meta/meta.dart';

/// A utility class to find the contour (outline) of an image based on its
/// alpha channel.
@experimental
class ContourFinder {
  /// Scans the provided [image] and returns a list of vertices representing
  /// its outer boundary.
  ///
  /// [alphaThreshold] defines the minimum alpha value (0-255) to consider a
  /// pixel as "solid".
  /// [source] allows scanning only a specific portion of the image (e.g. a
  /// specific frame in a sprite sheet).
  static Future<List<Vector2>> findContour(
    Image image, {
    int alphaThreshold = 10,
    int detail = 4,
    Rect? source,
  }) async {
    final byteData = await image.toByteData(format: ImageByteFormat.rawRgba);
    if (byteData == null) return [];

    final width = image.width;
    final height = image.height;
    final src =
        source ?? Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());

    final startX = src.left.toInt().clamp(0, width - 1);
    final endX = src.right.toInt().clamp(0, width);
    final startY = src.top.toInt().clamp(0, height - 1);
    final endY = src.bottom.toInt().clamp(0, height);

    final List<Point<int>> boundaryPoints = [];
    Point<int>? start;

    // 1. Find the first solid pixel (starting from top-left)
    outer:
    for (int y = startY; y < endY; y++) {
      for (int x = startX; x < endX; x++) {
        if (_getAlpha(byteData, x, y, width) > alphaThreshold) {
          start = Point(x, y);
          break outer;
        }
      }
    }

    if (start == null) return [];

    // 2. Moore-Neighbor Tracing
    Point<int> current = start;
    // We start searching from the neighbor above the start pixel
    Point<int> back = Point(start.x, start.y - 1);

    const List<Point<int>> neighbors = [
      Point(-1, -1),
      Point(0, -1),
      Point(1, -1),
      Point(1, 0),
      Point(1, 1),
      Point(0, 1),
      Point(-1, 1),
      Point(-1, 0),
    ];

    do {
      boundaryPoints.add(current);

      // Find the direction from current to back
      final diff = Point(back.x - current.x, back.y - current.y);
      int startIdx = 0;
      for (int i = 0; i < 8; i++) {
        if (neighbors[i].x == diff.x && neighbors[i].y == diff.y) {
          startIdx = i;
          break;
        }
      }

      // Search clockwise
      bool found = false;
      for (int i = 1; i <= 8; i++) {
        final idx = (startIdx + i) % 8;
        final nextX = current.x + neighbors[idx].x;
        final nextY = current.y + neighbors[idx].y;

        // Check bounds and alpha
        if (nextX >= startX &&
            nextX < endX &&
            nextY >= startY &&
            nextY < endY) {
          if (_getAlpha(byteData, nextX, nextY, width) > alphaThreshold) {
            back = Point(
              current.x + neighbors[(idx + 7) % 8].x,
              current.y + neighbors[(idx + 7) % 8].y,
            );
            current = Point(nextX, nextY);
            found = true;
            break;
          }
        }
      }

      if (!found) break; // Isolated pixel
      if (boundaryPoints.length > 5000) break; // Safety break
    } while (current != start);

    // 3. Simplify and return
    final List<Vector2> finalPoints = [];
    for (int i = 0; i < boundaryPoints.length; i += detail) {
      final p = boundaryPoints[i];
      finalPoints.add(Vector2(p.x - src.left, p.y - src.top));
    }

    return finalPoints;
  }

  static int _getAlpha(dynamic byteData, int x, int y, int width) {
    // RGBA format: 4 bytes per pixel, alpha is the 4th byte
    final offset = (y * width + x) * 4 + 3;
    if (offset >= byteData.lengthInBytes) return 0;
    return byteData.getUint8(offset);
  }
}
