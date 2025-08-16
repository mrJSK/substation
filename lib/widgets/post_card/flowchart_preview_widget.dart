import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:graphite/graphite.dart';

class FlowchartPreviewWidget extends StatelessWidget {
  final Map<String, dynamic>? flowchartData;
  final double height;
  final bool showTitle;
  final VoidCallback? onTap;

  const FlowchartPreviewWidget({
    Key? key,
    required this.flowchartData,
    this.height = 200,
    this.showTitle = true,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (flowchartData == null || flowchartData!['nodes'] == null) {
      return _buildEmptyState();
    }

    try {
      final nodesList = flowchartData!['nodes'] as String;
      final nodes = nodeInputFromJson(nodesList);

      if (nodes.isEmpty) {
        return _buildEmptyState();
      }

      return GestureDetector(
        onTap: onTap,
        child: Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 2.0,
            constrained: false,
            child: DirectGraph(
              list: nodes,
              defaultCellSize: const Size(100, 50),
              cellPadding: const EdgeInsets.all(16),
              orientation: MatrixOrientation.Vertical,
              centered: true,
              nodeBuilder: (context, node) => Container(
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  border: Border.all(color: Colors.blue!),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      node.id,
                      style: GoogleFonts.lora(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      return _buildErrorState();
    }
  }

  Widget _buildEmptyState() {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey!),
      ),
      child: Center(
        child: Text(
          'No flowchart data available',
          style: GoogleFonts.lora(fontSize: 14, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red!),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, color: Colors.red, size: 24),
            const SizedBox(height: 8),
            Text(
              'Error displaying flowchart',
              style: GoogleFonts.lora(fontSize: 14, color: Colors.red),
            ),
          ],
        ),
      ),
    );
  }
}
