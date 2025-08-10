// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../controllers/sld_controller.dart';
// import '../widgets/sld_view_widget.dart';

// class PrintPreviewScreen extends StatefulWidget {
//   final String substationName;
//   final DateTime startDate;
//   final DateTime endDate;
//   final Function(double zoom, Offset position) onGeneratePdf;
//   final SldController sldController;

//   const PrintPreviewScreen({
//     super.key,
//     required this.substationName,
//     required this.startDate,
//     required this.endDate,
//     required this.onGeneratePdf,
//     required this.sldController,
//   });

//   @override
//   State<PrintPreviewScreen> createState() => _PrintPreviewScreenState();
// }

// class _PrintPreviewScreenState extends State<PrintPreviewScreen>
//     with TickerProviderStateMixin {
//   double _zoomLevel = 1.0;
//   Offset _sldPosition = Offset.zero;
//   bool _isGenerating = false;

//   // Animation controllers for smooth interactions
//   late AnimationController _scaleAnimationController;
//   late AnimationController _panAnimationController;
//   late Animation<double> _scaleAnimation;
//   late Animation<Offset> _panAnimation;

//   // Paper dimensions (A4 in points: 595 x 842)
//   static const double _paperWidth = 595.0;
//   static const double _paperHeight = 842.0;
//   static const double _headerHeight = 100.0;
//   static const double _footerHeight = 50.0;
//   static const double _printableWidth = _paperWidth - 40;
//   static const double _printableHeight =
//       _paperHeight - _headerHeight - _footerHeight - 40;

//   // Gesture tracking variables
//   double _baseScaleFactor = 1.0;
//   Offset _basePanOffset = Offset.zero;

//   @override
//   void initState() {
//     super.initState();

//     // Initialize animation controllers
//     _scaleAnimationController = AnimationController(
//       duration: const Duration(milliseconds: 200),
//       vsync: this,
//     );
//     _panAnimationController = AnimationController(
//       duration: const Duration(milliseconds: 200),
//       vsync: this,
//     );

//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _centerSldInPrintArea();
//     });
//   }

//   @override
//   void dispose() {
//     _scaleAnimationController.dispose();
//     _panAnimationController.dispose();
//     super.dispose();
//   }

//   void _centerSldInPrintArea() {
//     if (widget.sldController.bayRenderDataList.isEmpty) return;

//     final bounds = _calculateSldBounds(widget.sldController);
//     final scaleX = _printableWidth / bounds.width;
//     final scaleY = _printableHeight / bounds.height;
//     final optimalZoom = (scaleX < scaleY ? scaleX : scaleY) * 0.8;

//     setState(() {
//       _zoomLevel = optimalZoom.clamp(0.1, 5.0);
//       _sldPosition = Offset.zero;
//     });
//   }

//   Rect _calculateSldBounds(SldController sldController) {
//     if (sldController.bayRenderDataList.isEmpty) {
//       return const Rect.fromLTWH(0, 0, 400, 300);
//     }

//     double minX = double.infinity;
//     double minY = double.infinity;
//     double maxX = double.negativeInfinity;
//     double maxY = double.negativeInfinity;

//     for (final renderData in sldController.bayRenderDataList) {
//       minX = minX < renderData.rect.left ? minX : renderData.rect.left;
//       minY = minY < renderData.rect.top ? minY : renderData.rect.top;
//       maxX = maxX > renderData.rect.right ? maxX : renderData.rect.right;
//       maxY = maxY > renderData.rect.bottom ? maxY : renderData.rect.bottom;
//     }

//     return Rect.fromLTRB(minX, minY, maxX, maxY);
//   }

//   void _handleScaleStart(ScaleStartDetails details) {
//     _baseScaleFactor = _zoomLevel;
//     _basePanOffset = _sldPosition;
//   }

//   void _handleScaleUpdate(ScaleUpdateDetails details) {
//     setState(() {
//       // Handle zoom with constraints
//       final newScale = _baseScaleFactor * details.scale;
//       _zoomLevel = newScale.clamp(0.1, 5.0);

//       // Handle pan with smooth movement
//       final delta = details.focalPointDelta;
//       _sldPosition = Offset(
//         (_basePanOffset.dx + delta.dx).clamp(-500.0, 500.0),
//         (_basePanOffset.dy + delta.dy).clamp(-500.0, 500.0),
//       );
//     });
//   }

//   void _handleScaleEnd(ScaleEndDetails details) {
//     // Store the final position as the new base
//     _basePanOffset = _sldPosition;
//     _baseScaleFactor = _zoomLevel;
//   }

//   void _resetView() {
//     // Animate back to center and default zoom
//     _scaleAnimation = Tween<double>(begin: _zoomLevel, end: 1.0).animate(
//       CurvedAnimation(
//         parent: _scaleAnimationController,
//         curve: Curves.easeOutCubic,
//       ),
//     );

//     _panAnimation = Tween<Offset>(begin: _sldPosition, end: Offset.zero)
//         .animate(
//           CurvedAnimation(
//             parent: _panAnimationController,
//             curve: Curves.easeOutCubic,
//           ),
//         );

//     _scaleAnimationController.addListener(() {
//       setState(() {
//         _zoomLevel = _scaleAnimation.value;
//       });
//     });

//     _panAnimationController.addListener(() {
//       setState(() {
//         _sldPosition = _panAnimation.value;
//       });
//     });

//     _scaleAnimationController.forward().then((_) {
//       _scaleAnimationController.reset();
//     });
//     _panAnimationController.forward().then((_) {
//       _panAnimationController.reset();
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);

//     return ChangeNotifierProvider<SldController>.value(
//       value: widget.sldController,
//       child: Scaffold(
//         backgroundColor: const Color(0xFFF5F5F5),
//         appBar: _buildAppBar(theme),
//         body: SafeArea(
//           child: Stack(
//             children: [
//               _buildPreviewArea(theme),
//               // Floating reset and auto-fit buttons
//               Positioned(
//                 top: 16,
//                 right: 16,
//                 child: Column(
//                   children: [
//                     FloatingActionButton.small(
//                       onPressed: _centerSldInPrintArea,
//                       backgroundColor: theme.colorScheme.primary,
//                       foregroundColor: Colors.white,
//                       heroTag: "autofit",
//                       child: const Icon(Icons.center_focus_strong),
//                     ),
//                     const SizedBox(height: 8),
//                     FloatingActionButton.small(
//                       onPressed: _resetView,
//                       backgroundColor: Colors.grey.shade600,
//                       foregroundColor: Colors.white,
//                       heroTag: "reset",
//                       child: const Icon(Icons.refresh),
//                     ),
//                   ],
//                 ),
//               ),
//               // Zoom level indicator
//               Positioned(
//                 top: 16,
//                 left: 16,
//                 child: Container(
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 12,
//                     vertical: 8,
//                   ),
//                   decoration: BoxDecoration(
//                     color: Colors.black.withOpacity(0.7),
//                     borderRadius: BorderRadius.circular(20),
//                   ),
//                   child: Text(
//                     '${(_zoomLevel * 100).toInt()}%',
//                     style: const TextStyle(
//                       color: Colors.white,
//                       fontSize: 14,
//                       fontWeight: FontWeight.w600,
//                     ),
//                   ),
//                 ),
//               ),
//               // Instructions overlay
//               Positioned(
//                 bottom: 20,
//                 left: 20,
//                 right: 20,
//                 child: Container(
//                   padding: const EdgeInsets.all(12),
//                   decoration: BoxDecoration(
//                     color: Colors.black.withOpacity(0.8),
//                     borderRadius: BorderRadius.circular(12),
//                   ),
//                   child: Row(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       Icon(Icons.touch_app, color: Colors.white, size: 16),
//                       const SizedBox(width: 8),
//                       const Text(
//                         'Pinch to zoom • Drag to move • Double tap to reset',
//                         style: TextStyle(color: Colors.white, fontSize: 12),
//                         textAlign: TextAlign.center,
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   PreferredSizeWidget _buildAppBar(ThemeData theme) {
//     return AppBar(
//       backgroundColor: Colors.white,
//       elevation: 0,
//       leading: IconButton(
//         onPressed: () => Navigator.of(context).pop(),
//         icon: Container(
//           padding: const EdgeInsets.all(6),
//           decoration: BoxDecoration(
//             color: theme.colorScheme.primary.withOpacity(0.1),
//             borderRadius: BorderRadius.circular(8),
//           ),
//           child: Icon(
//             Icons.arrow_back_ios,
//             color: theme.colorScheme.primary,
//             size: 18,
//           ),
//         ),
//       ),
//       title: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Icon(
//                 Icons.print_outlined,
//                 color: theme.colorScheme.primary,
//                 size: 20,
//               ),
//               const SizedBox(width: 8),
//               const Text(
//                 'Print Preview',
//                 style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
//               ),
//             ],
//           ),
//           Text(
//             widget.substationName,
//             style: TextStyle(
//               fontSize: 12,
//               color: theme.colorScheme.onSurface.withOpacity(0.6),
//             ),
//           ),
//         ],
//       ),
//       actions: [
//         Container(
//           margin: const EdgeInsets.only(right: 16),
//           child: ElevatedButton.icon(
//             onPressed: _isGenerating ? null : _generatePdf,
//             style: ElevatedButton.styleFrom(
//               backgroundColor: theme.colorScheme.primary,
//               foregroundColor: Colors.white,
//               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//             ),
//             icon: _isGenerating
//                 ? const SizedBox(
//                     width: 16,
//                     height: 16,
//                     child: CircularProgressIndicator(
//                       strokeWidth: 2,
//                       color: Colors.white,
//                     ),
//                   )
//                 : const Icon(Icons.picture_as_pdf, size: 18),
//             label: Text(_isGenerating ? 'Generating...' : 'Generate PDF'),
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildPreviewArea(ThemeData theme) {
//     return Container(
//       width: double.infinity,
//       height: double.infinity,
//       padding: const EdgeInsets.all(16),
//       child: Column(
//         children: [
//           Container(
//             padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(6),
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.black.withOpacity(0.05),
//                   blurRadius: 4,
//                   offset: const Offset(0, 2),
//                 ),
//               ],
//             ),
//             child: Row(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Icon(
//                   Icons.description,
//                   size: 16,
//                   color: theme.colorScheme.primary,
//                 ),
//                 const SizedBox(width: 6),
//                 const Text(
//                   'A4 Paper Preview',
//                   style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
//                 ),
//                 const SizedBox(width: 12),
//                 Text(
//                   'Position: (${_sldPosition.dx.toInt()}, ${_sldPosition.dy.toInt()})',
//                   style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
//                 ),
//               ],
//             ),
//           ),
//           const SizedBox(height: 16),
//           Expanded(
//             child: Center(
//               child: Container(
//                 width: _paperWidth * 0.7,
//                 height: _paperHeight * 0.7,
//                 decoration: BoxDecoration(
//                   color: Colors.white,
//                   borderRadius: BorderRadius.circular(8),
//                   border: Border.all(color: Colors.grey.shade300),
//                   boxShadow: [
//                     BoxShadow(
//                       color: Colors.black.withOpacity(0.15),
//                       blurRadius: 20,
//                       offset: const Offset(0, 8),
//                     ),
//                   ],
//                 ),
//                 child: ClipRRect(
//                   borderRadius: BorderRadius.circular(8),
//                   child: Stack(
//                     children: [
//                       // Header area
//                       Container(
//                         height: _headerHeight * 0.7,
//                         decoration: BoxDecoration(
//                           color: Colors.grey.shade50,
//                           border: Border(
//                             bottom: BorderSide(color: Colors.grey.shade200),
//                           ),
//                         ),
//                         child: Center(
//                           child: Text(
//                             'Header Area',
//                             style: TextStyle(
//                               fontSize: 10,
//                               color: Colors.grey.shade600,
//                             ),
//                           ),
//                         ),
//                       ),
//                       // Interactive SLD content area
//                       Positioned(
//                         top: _headerHeight * 0.7,
//                         left: 20 * 0.7,
//                         right: 20 * 0.7,
//                         bottom: _footerHeight * 0.7,
//                         child: Container(
//                           decoration: BoxDecoration(
//                             border: Border.all(
//                               color: Colors.blue.withOpacity(0.2),
//                               width: 1,
//                             ),
//                             color: Colors.white,
//                           ),
//                           child: _buildInteractiveSldContent(),
//                         ),
//                       ),
//                       // Footer area
//                       Positioned(
//                         bottom: 0,
//                         left: 0,
//                         right: 0,
//                         height: _footerHeight * 0.7,
//                         child: Container(
//                           decoration: BoxDecoration(
//                             color: Colors.grey.shade50,
//                             border: Border(
//                               top: BorderSide(color: Colors.grey.shade200),
//                             ),
//                           ),
//                           child: Center(
//                             child: Text(
//                               'Footer Area',
//                               style: TextStyle(
//                                 fontSize: 10,
//                                 color: Colors.grey.shade600,
//                               ),
//                             ),
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//           ),
//           const SizedBox(height: 16),
//         ],
//       ),
//     );
//   }

//   Widget _buildInteractiveSldContent() {
//     return LayoutBuilder(
//       builder: (context, constraints) {
//         final availableWidth = constraints.maxWidth;
//         final availableHeight = constraints.maxHeight;

//         return Container(
//           width: availableWidth,
//           height: availableHeight,
//           child: GestureDetector(
//             onScaleStart: _handleScaleStart,
//             onScaleUpdate: _handleScaleUpdate,
//             onScaleEnd: _handleScaleEnd,
//             onDoubleTap: _resetView, // Double tap to reset
//             child: Stack(
//               children: [
//                 Container(color: Colors.white),
//                 // SLD content with smooth transforms
//                 Center(
//                   child: Transform(
//                     transform: Matrix4.identity()
//                       ..translate(_sldPosition.dx, _sldPosition.dy)
//                       ..scale(_zoomLevel),
//                     child: const SldViewWidget(
//                       isEnergySld: true,
//                       isCapturingPdf: true,
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }

//   Future<void> _generatePdf() async {
//     setState(() {
//       _isGenerating = true;
//     });

//     // Enhanced debug logging
//     print('DEBUG: === PDF Generation Started ===');
//     print('DEBUG: Preview zoom: $_zoomLevel (${(_zoomLevel * 100).toInt()}%)');
//     print('DEBUG: Preview position: $_sldPosition');
//     print(
//       'DEBUG: Transformation matrix: ${Matrix4.identity()
//         ..translate(_sldPosition.dx, _sldPosition.dy)
//         ..scale(_zoomLevel)}',
//     );

//     try {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Generating PDF...'),
//           behavior: SnackBarBehavior.fixed,
//           duration: Duration(seconds: 2),
//         ),
//       );

//       await widget.onGeneratePdf(_zoomLevel, _sldPosition);

//       if (mounted) {
//         ScaffoldMessenger.of(context).hideCurrentSnackBar();
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text('PDF generated successfully!'),
//             behavior: SnackBarBehavior.fixed,
//             backgroundColor: Colors.green,
//             duration: Duration(seconds: 2),
//           ),
//         );
//         Navigator.of(context).pop();
//       }

//       print('DEBUG: === PDF Generation Completed Successfully ===');
//     } catch (e) {
//       print(
//         'DEBUG ERROR: PDF generation failed with zoom: $_zoomLevel, position: $_sldPosition',
//       );
//       print('DEBUG ERROR: Exception details: $e');

//       if (mounted) {
//         ScaffoldMessenger.of(context).hideCurrentSnackBar();
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Error generating PDF: $e'),
//             behavior: SnackBarBehavior.fixed,
//             backgroundColor: Colors.red,
//             duration: const Duration(seconds: 3),
//           ),
//         );
//       }
//     } finally {
//       if (mounted) {
//         setState(() {
//           _isGenerating = false;
//         });
//       }
//     }
//   }
// }
