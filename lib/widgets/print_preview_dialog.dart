import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/sld_controller.dart';
import '../widgets/sld_view_widget.dart';

class PrintPreviewScreen extends StatefulWidget {
  final String substationName;
  final DateTime startDate;
  final DateTime endDate;
  final Function(double zoom, Offset position) onGeneratePdf;
  final SldController sldController;

  const PrintPreviewScreen({
    super.key,
    required this.substationName,
    required this.startDate,
    required this.endDate,
    required this.onGeneratePdf,
    required this.sldController,
  });

  @override
  State<PrintPreviewScreen> createState() => _PrintPreviewScreenState();
}

class _PrintPreviewScreenState extends State<PrintPreviewScreen> {
  double _zoomLevel = 1.0;
  Offset _sldPosition = Offset.zero;
  final TransformationController _previewController =
      TransformationController();
  bool _isGenerating = false;
  bool _showControls = true;

  // Paper dimensions (A4 in points: 595 x 842)
  static const double _paperWidth = 595.0;
  static const double _paperHeight = 842.0;
  static const double _headerHeight = 100.0;
  static const double _footerHeight = 50.0;
  static const double _printableWidth = _paperWidth - 40;
  static const double _printableHeight =
      _paperHeight - _headerHeight - _footerHeight - 40;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerSldInPrintArea();
    });
  }

  void _centerSldInPrintArea() {
    if (widget.sldController.bayRenderDataList.isEmpty) return;

    final bounds = _calculateSldBounds(widget.sldController);

    final scaleX = _printableWidth / bounds.width;
    final scaleY = _printableHeight / bounds.height;
    final optimalZoom =
        (scaleX < scaleY ? scaleX : scaleY) * 2.0; // INCREASED from 0.8 to 2.0

    setState(() {
      _zoomLevel = optimalZoom.clamp(
        0.5,
        10.0,
      ); // INCREASED min from 0.1 to 0.5, max from 3.0 to 10.0
      _sldPosition = Offset.zero; // Start at center
    });

    _updatePreviewTransformation();
  }

  void _updatePreviewTransformation() {
    final matrix = Matrix4.identity()
      ..translate(_sldPosition.dx, _sldPosition.dy)
      ..scale(_zoomLevel);
    _previewController.value = matrix;
  }

  Rect _calculateSldBounds(SldController sldController) {
    if (sldController.bayRenderDataList.isEmpty) {
      return const Rect.fromLTWH(0, 0, 400, 300);
    }

    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (final renderData in sldController.bayRenderDataList) {
      minX = minX < renderData.rect.left ? minX : renderData.rect.left;
      minY = minY < renderData.rect.top ? minY : renderData.rect.top;
      maxX = maxX > renderData.rect.right ? maxX : renderData.rect.right;
      maxY = maxY > renderData.rect.bottom ? maxY : renderData.rect.bottom;
    }

    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ChangeNotifierProvider<SldController>.value(
      value: widget.sldController,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: _buildAppBar(theme),
        body: SafeArea(
          child: Stack(
            children: [
              _buildPreviewArea(theme),
              // Floating toggle button
              Positioned(
                top: 16,
                right: 16,
                child: FloatingActionButton.small(
                  onPressed: _toggleControls,
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  child: Icon(
                    _showControls ? Icons.keyboard_arrow_down : Icons.tune,
                  ),
                ),
              ),
              // UPDATED: Use better positioned controls
              if (_showControls) _buildPositionedControls(theme),
            ],
          ),
        ),
      ),
    );
  }

  // UPDATED: Better positioned controls method
  Widget _buildPositionedControls(ThemeData theme) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.4, // Max 40% height
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            // Controls content with flexible sizing
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Layout Controls',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Zoom Control
                    _buildZoomControl(theme),
                    const SizedBox(height: 20),

                    // Position Controls
                    _buildPositionControls(theme),
                    const SizedBox(height: 20),

                    // Quick Actions
                    _buildQuickActions(theme),
                    SizedBox(
                      height: MediaQuery.of(context).padding.bottom + 16,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        onPressed: () => Navigator.of(context).pop(),
        icon: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.arrow_back_ios,
            color: theme.colorScheme.primary,
            size: 18,
          ),
        ),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.print_outlined,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Print Preview',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          Text(
            widget.substationName,
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16),
          child: ElevatedButton.icon(
            onPressed: _isGenerating ? null : _generatePdf,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            icon: _isGenerating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.picture_as_pdf, size: 18),
            label: Text(_isGenerating ? 'Generating...' : 'Generate PDF'),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewArea(ThemeData theme) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.description,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                const Text(
                  'A4 Paper Preview',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 12),
                Text(
                  '${(_zoomLevel * 100).toInt()}% zoom',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Center(
              child: Container(
                width:
                    _paperWidth * 0.7, // Increased size for better visibility
                height: _paperHeight * 0.7,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    children: [
                      // Header area
                      Container(
                        height: _headerHeight * 0.7,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          border: Border(
                            bottom: BorderSide(color: Colors.grey.shade200),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'Header Area',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ),
                      // SLD content area - IMPROVED
                      Positioned(
                        top: _headerHeight * 0.7,
                        left: 20 * 0.7,
                        right: 20 * 0.7,
                        bottom: _footerHeight * 0.7,
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.blue.withOpacity(0.2),
                              width: 1,
                            ),
                            color: Colors.white,
                          ),
                          child: _buildSldPreviewContent(),
                        ),
                      ),
                      // Footer area
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        height: _footerHeight * 0.7,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            border: Border(
                              top: BorderSide(color: Colors.grey.shade200),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'Footer Area',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade600,
                              ),
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
          // REDUCED: Bottom padding when controls are shown
          SizedBox(
            height: _showControls ? 0 : 16,
          ), // No extra padding needed with positioned controls
        ],
      ),
    );
  }

  // UPDATED: Better scaling for SLD preview content
  Widget _buildSldPreviewContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final availableHeight = constraints.maxHeight;

        return Container(
          width: availableWidth,
          height: availableHeight,
          child: Stack(
            children: [
              // White background
              Container(color: Colors.white),
              // SLD Content with MUCH BETTER scaling
              Center(
                child: Transform.scale(
                  scale: 0.8, // INCREASED from 0.6 to 0.8 for better visibility
                  child: Container(
                    width: availableWidth * 1.5, // REDUCED virtual canvas size
                    height: availableHeight * 1.5,
                    child: Center(
                      child: Transform(
                        transform: Matrix4.identity()
                          ..translate(
                            _sldPosition.dx * 0.1,
                            _sldPosition.dy * 0.1,
                          ) // REDUCED translation factor
                          ..scale(_zoomLevel), // REMOVED the 0.5 multiplier
                        child: SldViewWidget(
                          isEnergySld: true,
                          isCapturingPdf: true,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // UPDATED: Zoom control with extended range
  Widget _buildZoomControl(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Zoom Level',
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${(_zoomLevel * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                onPressed: () {
                  setState(() {
                    _zoomLevel = (_zoomLevel - 0.2).clamp(
                      0.5,
                      10.0,
                    ); // INCREASED step and range
                  });
                  _updatePreviewTransformation();
                },
                icon: Icon(Icons.zoom_out, color: theme.colorScheme.primary),
                iconSize: 20,
              ),
            ),
            Expanded(
              child: Slider(
                value: _zoomLevel,
                min: 0.5, // INCREASED minimum
                max: 10.0, // INCREASED maximum
                divisions: 95, // Updated divisions
                activeColor: theme.colorScheme.primary,
                onChanged: (value) {
                  setState(() {
                    _zoomLevel = value;
                  });
                  _updatePreviewTransformation();
                },
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                onPressed: () {
                  setState(() {
                    _zoomLevel = (_zoomLevel + 0.2).clamp(
                      0.5,
                      10.0,
                    ); // INCREASED step and range
                  });
                  _updatePreviewTransformation();
                },
                icon: Icon(Icons.zoom_in, color: theme.colorScheme.primary),
                iconSize: 20,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPositionControls(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Position',
          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildPositionButton(Icons.keyboard_arrow_up, () {
              setState(() {
                _sldPosition = Offset(_sldPosition.dx, _sldPosition.dy - 10);
              });
              _updatePreviewTransformation();
            }, theme),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildPositionButton(Icons.keyboard_arrow_left, () {
              setState(() {
                _sldPosition = Offset(_sldPosition.dx - 10, _sldPosition.dy);
              });
              _updatePreviewTransformation();
            }, theme),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.control_camera,
                color: theme.colorScheme.primary,
              ),
            ),
            _buildPositionButton(Icons.keyboard_arrow_right, () {
              setState(() {
                _sldPosition = Offset(_sldPosition.dx + 10, _sldPosition.dy);
              });
              _updatePreviewTransformation();
            }, theme),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildPositionButton(Icons.keyboard_arrow_down, () {
              setState(() {
                _sldPosition = Offset(_sldPosition.dx, _sldPosition.dy + 10);
              });
              _updatePreviewTransformation();
            }, theme),
          ],
        ),
      ],
    );
  }

  Widget _buildPositionButton(
    IconData icon,
    VoidCallback onPressed,
    ThemeData theme,
  ) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: theme.colorScheme.primary),
        iconSize: 20,
      ),
    );
  }

  Widget _buildQuickActions(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _centerSldInPrintArea,
                icon: const Icon(Icons.center_focus_strong, size: 16),
                label: const Text('Auto Fit'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: BorderSide(color: theme.colorScheme.primary),
                  foregroundColor: theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _zoomLevel = 1.0;
                    _sldPosition = Offset.zero;
                  });
                  _updatePreviewTransformation();
                },
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Reset'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: BorderSide(color: Colors.grey.shade400),
                  foregroundColor: Colors.grey.shade700,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // UPDATED: Better PDF generation with proper SnackBar handling
  Future<void> _generatePdf() async {
    // Hide controls first to ensure clean capture
    if (_showControls) {
      setState(() {
        _showControls = false;
      });
      // Wait for controls to hide
      await Future.delayed(const Duration(milliseconds: 300));
    }

    setState(() {
      _isGenerating = true;
    });

    try {
      // Show SnackBar with fixed behavior
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Generating PDF...'),
          behavior: SnackBarBehavior.fixed, // Use fixed behavior
          duration: Duration(seconds: 2),
        ),
      );

      await widget.onGeneratePdf(_zoomLevel, _sldPosition);

      if (mounted) {
        // Hide the generating SnackBar
        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF generated successfully!'),
            behavior: SnackBarBehavior.fixed,
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating PDF: $e'),
            behavior: SnackBarBehavior.fixed,
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _previewController.dispose();
    super.dispose();
  }
}
