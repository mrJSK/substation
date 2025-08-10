import 'dart:typed_data';
import 'dart:ui';

class CapturedSldData {
  CapturedSldData({
    required this.pngBytes,
    required this.baseLogicalWidth,
    required this.baseLogicalHeight,
    required this.pixelRatio,
    DateTime? captureTimestamp,
  }) : captureTimestamp = captureTimestamp ?? DateTime.now(),
       assert(pngBytes.length > 0, 'Image bytes cannot be empty'),
       assert(baseLogicalWidth > 0, 'Base width must be positive'),
       assert(baseLogicalHeight > 0, 'Base height must be positive'),
       assert(pixelRatio > 0, 'Pixel ratio must be positive');

  final Uint8List pngBytes;
  final double baseLogicalWidth;
  final double baseLogicalHeight;
  final double pixelRatio;
  final DateTime captureTimestamp;

  bool get isValid =>
      pngBytes.isNotEmpty && baseLogicalWidth > 0 && baseLogicalHeight > 0;
}

class PdfGeneratorData {
  const PdfGeneratorData({
    required this.pageWidth,
    required this.pageHeight,
    required this.marginLeft,
    required this.marginRight,
    required this.marginTop,
    required this.marginBottom,
    required this.headerHeight,
    required this.footerHeight,
    required this.sldImageBytes,
    required this.sldBaseLogicalWidth,
    required this.sldBaseLogicalHeight,
    required this.sldZoom,
    required this.sldOffset,
  }) : assert(
         pageWidth > 0 && pageHeight > 0,
         'Page dimensions must be positive',
       ),
       assert(sldZoom > 0, 'SLD zoom must be positive'),
       assert(
         sldBaseLogicalWidth > 0 && sldBaseLogicalHeight > 0,
         'SLD dimensions must be positive',
       );

  final double pageWidth;
  final double pageHeight;
  final double marginLeft;
  final double marginRight;
  final double marginTop;
  final double marginBottom;
  final double headerHeight;
  final double footerHeight;
  final Uint8List sldImageBytes;
  final double sldBaseLogicalWidth;
  final double sldBaseLogicalHeight;
  final double sldZoom;
  final Offset sldOffset;

  // Computed properties
  double get printableWidth => pageWidth - marginLeft - marginRight;
  double get printableHeight =>
      pageHeight - marginTop - marginBottom - headerHeight - footerHeight;

  // Utility methods
  PdfGeneratorData copyWith({double? sldZoom, Offset? sldOffset}) {
    return PdfGeneratorData(
      pageWidth: pageWidth,
      pageHeight: pageHeight,
      marginLeft: marginLeft,
      marginRight: marginRight,
      marginTop: marginTop,
      marginBottom: marginBottom,
      headerHeight: headerHeight,
      footerHeight: footerHeight,
      sldImageBytes: sldImageBytes,
      sldBaseLogicalWidth: sldBaseLogicalWidth,
      sldBaseLogicalHeight: sldBaseLogicalHeight,
      sldZoom: sldZoom ?? this.sldZoom,
      sldOffset: sldOffset ?? this.sldOffset,
    );
  }
}
