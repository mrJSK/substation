// // lib/widgets/energy_movement_controls_widget.dart

// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:collection/collection.dart';
// import '../controllers/sld_controller.dart';
// import '../enums/movement_mode.dart';
// import '../utils/snackbar_utils.dart';

// class EnergyMovementControlsWidget extends StatelessWidget {
//   final VoidCallback onSave;
//   final bool isViewingSavedSld;

//   const EnergyMovementControlsWidget({
//     super.key,
//     required this.onSave,
//     required this.isViewingSavedSld,
//   });

//   @override
//   Widget build(BuildContext context) {
//     if (isViewingSavedSld) return const SizedBox.shrink();

//     final sldController = Provider.of<SldController>(context);
//     final selectedBayId = sldController.selectedBayForMovementId;

//     if (selectedBayId == null) return const SizedBox.shrink();

//     final selectedBay = sldController.baysMap[selectedBayId];
//     if (selectedBay == null) return const SizedBox.shrink();

//     final selectedBayRenderData = sldController.bayRenderDataList
//         .firstWhereOrNull((data) => data.bay.id == selectedBayId);
//     if (selectedBayRenderData == null) return const SizedBox.shrink();

//     final theme = Theme.of(context);
//     final hasUnsavedChanges = sldController.hasUnsavedChanges();
//     final isDarkMode = theme.brightness == Brightness.dark;

//     return Container(
//       decoration: BoxDecoration(
//         gradient: LinearGradient(
//           colors: isDarkMode
//               ? [Colors.grey.shade900, Colors.blueGrey.shade800]
//               : [Colors.white, Colors.grey.shade50],
//           begin: Alignment.topCenter,
//           end: Alignment.bottomCenter,
//         ),
//         boxShadow: [
//           BoxShadow(
//             color: isDarkMode
//                 ? Colors.black.withOpacity(0.3)
//                 : Colors.black.withOpacity(0.1),
//             blurRadius: 12,
//             offset: const Offset(0, -4),
//           ),
//         ],
//         border: isDarkMode
//             ? null
//             : Border(top: BorderSide(color: Colors.grey.shade200)),
//       ),
//       child: SafeArea(
//         child: Padding(
//           padding: const EdgeInsets.all(20),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               _buildHeader(selectedBay, theme, hasUnsavedChanges, isDarkMode),
//               const SizedBox(height: 20),
//               _buildModeSelector(sldController, theme, isDarkMode),
//               const SizedBox(height: 20),
//               _buildMovementControls(sldController, theme, isDarkMode),

//               // Show only relevant controls based on movement mode
//               if (sldController.movementMode == MovementMode.energyText) ...[
//                 const SizedBox(height: 20),
//                 _buildEnergyTextControls(
//                   selectedBayRenderData,
//                   sldController,
//                   theme,
//                   isDarkMode,
//                 ),
//               ],
//               if (sldController.movementMode == MovementMode.bay &&
//                   selectedBay.bayType == 'Busbar') ...[
//                 const SizedBox(height: 20),
//                 _buildBusbarLengthControls(
//                   selectedBayRenderData,
//                   sldController,
//                   theme,
//                   isDarkMode,
//                 ),
//               ],

//               if (hasUnsavedChanges) ...[
//                 const SizedBox(height: 16),
//                 _buildUnsavedChangesIndicator(theme, isDarkMode),
//               ],
//               const SizedBox(height: 24),
//               _buildActionButtons(
//                 context,
//                 sldController,
//                 theme,
//                 hasUnsavedChanges,
//                 isDarkMode,
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildHeader(
//     dynamic selectedBay,
//     ThemeData theme,
//     bool hasUnsavedChanges,
//     bool isDarkMode,
//   ) {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: isDarkMode
//             ? Colors.white.withOpacity(0.15)
//             : Colors.grey.shade100,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(
//           color: isDarkMode
//               ? Colors.white.withOpacity(0.2)
//               : Colors.grey.shade300,
//         ),
//       ),
//       child: Row(
//         children: [
//           Container(
//             padding: const EdgeInsets.all(8),
//             decoration: BoxDecoration(
//               color: theme.colorScheme.primary,
//               borderRadius: BorderRadius.circular(8),
//             ),
//             child: const Icon(Icons.tune, color: Colors.white, size: 20),
//           ),
//           const SizedBox(width: 12),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   'Adjusting Position',
//                   style: TextStyle(
//                     color: isDarkMode ? Colors.white70 : Colors.grey.shade600,
//                     fontSize: 12,
//                     fontWeight: FontWeight.w500,
//                   ),
//                 ),
//                 Text(
//                   selectedBay.name,
//                   style: TextStyle(
//                     color: isDarkMode ? Colors.white : Colors.grey.shade800,
//                     fontSize: 16,
//                     fontWeight: FontWeight.w600,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           Container(
//             padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//             decoration: BoxDecoration(
//               color: hasUnsavedChanges
//                   ? Colors.orange.withOpacity(0.2)
//                   : Colors.green.withOpacity(0.2),
//               borderRadius: BorderRadius.circular(8),
//               border: Border.all(
//                 color: hasUnsavedChanges
//                     ? Colors.orange.withOpacity(0.3)
//                     : Colors.green.withOpacity(0.3),
//               ),
//             ),
//             child: Text(
//               hasUnsavedChanges ? 'MODIFIED' : 'LIVE',
//               style: TextStyle(
//                 color: hasUnsavedChanges ? Colors.orange : Colors.green,
//                 fontSize: 10,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildModeSelector(
//     SldController sldController,
//     ThemeData theme,
//     bool isDarkMode,
//   ) {
//     return Container(
//       padding: const EdgeInsets.all(4),
//       decoration: BoxDecoration(
//         color: isDarkMode
//             ? Colors.white.withOpacity(0.1)
//             : Colors.grey.shade200,
//         borderRadius: BorderRadius.circular(12),
//       ),
//       child: Row(
//         children: [
//           _buildModeButton(
//             context: sldController,
//             mode: MovementMode.bay,
//             icon: Icons.open_with,
//             label: 'Bay',
//             isSelected: sldController.movementMode == MovementMode.bay,
//             onTap: () => sldController.setMovementMode(MovementMode.bay),
//             theme: theme,
//             isDarkMode: isDarkMode,
//           ),
//           _buildModeButton(
//             context: sldController,
//             mode: MovementMode.text,
//             icon: Icons.text_fields,
//             label: 'Name',
//             isSelected: sldController.movementMode == MovementMode.text,
//             onTap: () => sldController.setMovementMode(MovementMode.text),
//             theme: theme,
//             isDarkMode: isDarkMode,
//           ),
//           _buildModeButton(
//             context: sldController,
//             mode: MovementMode.energyText,
//             icon: Icons.format_list_numbered,
//             label: 'Readings',
//             isSelected: sldController.movementMode == MovementMode.energyText,
//             onTap: () => sldController.setMovementMode(MovementMode.energyText),
//             theme: theme,
//             isDarkMode: isDarkMode,
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildModeButton({
//     required SldController context,
//     required MovementMode mode,
//     required IconData icon,
//     required String label,
//     required bool isSelected,
//     required VoidCallback onTap,
//     required ThemeData theme,
//     required bool isDarkMode,
//   }) {
//     return Expanded(
//       child: GestureDetector(
//         onTap: onTap,
//         child: AnimatedContainer(
//           duration: const Duration(milliseconds: 200),
//           padding: const EdgeInsets.symmetric(vertical: 12),
//           decoration: BoxDecoration(
//             color: isSelected
//                 ? (isDarkMode ? Colors.white : theme.colorScheme.primary)
//                 : Colors.transparent,
//             borderRadius: BorderRadius.circular(8),
//             boxShadow: isSelected
//                 ? [
//                     BoxShadow(
//                       color: Colors.black.withOpacity(isDarkMode ? 0.1 : 0.2),
//                       blurRadius: 4,
//                       offset: const Offset(0, 2),
//                     ),
//                   ]
//                 : null,
//           ),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Icon(
//                 icon,
//                 size: 20,
//                 color: isSelected
//                     ? (isDarkMode ? theme.colorScheme.primary : Colors.white)
//                     : (isDarkMode ? Colors.white70 : Colors.grey.shade600),
//               ),
//               const SizedBox(height: 4),
//               Text(
//                 label,
//                 style: TextStyle(
//                   fontSize: 12,
//                   fontWeight: FontWeight.w600,
//                   color: isSelected
//                       ? (isDarkMode ? theme.colorScheme.primary : Colors.white)
//                       : (isDarkMode ? Colors.white70 : Colors.grey.shade600),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildMovementControls(
//     SldController sldController,
//     ThemeData theme,
//     bool isDarkMode,
//   ) {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: isDarkMode
//             ? Colors.white.withOpacity(0.1)
//             : Colors.grey.shade100,
//         borderRadius: BorderRadius.circular(12),
//       ),
//       child: Column(
//         children: [
//           Text(
//             'Movement Controls',
//             style: TextStyle(
//               color: isDarkMode ? Colors.white : Colors.grey.shade800,
//               fontSize: 14,
//               fontWeight: FontWeight.w600,
//             ),
//           ),
//           const SizedBox(height: 16),
//           Row(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               _buildDirectionButton(
//                 Icons.arrow_back,
//                 () => sldController.moveSelectedItem(-5.0, 0),
//                 theme,
//                 isDarkMode,
//               ),
//               const SizedBox(width: 20),
//               Column(
//                 children: [
//                   _buildDirectionButton(
//                     Icons.arrow_upward,
//                     () => sldController.moveSelectedItem(0, -5.0),
//                     theme,
//                     isDarkMode,
//                   ),
//                   const SizedBox(height: 12),
//                   Container(
//                     padding: const EdgeInsets.all(8),
//                     decoration: BoxDecoration(
//                       color: isDarkMode
//                           ? Colors.white.withOpacity(0.2)
//                           : Colors.grey.shade300,
//                       borderRadius: BorderRadius.circular(6),
//                     ),
//                     child: Icon(
//                       Icons.control_camera,
//                       color: isDarkMode ? Colors.white70 : Colors.grey.shade600,
//                       size: 16,
//                     ),
//                   ),
//                   const SizedBox(height: 12),
//                   _buildDirectionButton(
//                     Icons.arrow_downward,
//                     () => sldController.moveSelectedItem(0, 5.0),
//                     theme,
//                     isDarkMode,
//                   ),
//                 ],
//               ),
//               const SizedBox(width: 20),
//               _buildDirectionButton(
//                 Icons.arrow_forward,
//                 () => sldController.moveSelectedItem(5.0, 0),
//                 theme,
//                 isDarkMode,
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildDirectionButton(
//     IconData icon,
//     VoidCallback onPressed,
//     ThemeData theme,
//     bool isDarkMode,
//   ) {
//     return Container(
//       decoration: BoxDecoration(
//         gradient: LinearGradient(
//           colors: [
//             theme.colorScheme.primary,
//             theme.colorScheme.primary.withOpacity(0.8),
//           ],
//           begin: Alignment.topLeft,
//           end: Alignment.bottomRight,
//         ),
//         borderRadius: BorderRadius.circular(8),
//         boxShadow: [
//           BoxShadow(
//             color: theme.colorScheme.primary.withOpacity(0.3),
//             blurRadius: 4,
//             offset: const Offset(0, 2),
//           ),
//         ],
//       ),
//       child: Material(
//         color: Colors.transparent,
//         child: InkWell(
//           onTap: onPressed,
//           borderRadius: BorderRadius.circular(8),
//           child: Container(
//             width: 44,
//             height: 44,
//             alignment: Alignment.center,
//             child: Icon(icon, color: Colors.white, size: 20),
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildEnergyTextControls(
//     dynamic selectedBayRenderData,
//     SldController sldController,
//     ThemeData theme,
//     bool isDarkMode,
//   ) {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: isDarkMode
//             ? Colors.white.withOpacity(0.1)
//             : Colors.grey.shade100,
//         borderRadius: BorderRadius.circular(12),
//       ),
//       child: Column(
//         children: [
//           Row(
//             children: [
//               Icon(
//                 Icons.format_size,
//                 color: isDarkMode ? Colors.white70 : Colors.grey.shade600,
//                 size: 20,
//               ),
//               const SizedBox(width: 8),
//               Text(
//                 'Energy Reading Style',
//                 style: TextStyle(
//                   color: isDarkMode ? Colors.white : Colors.grey.shade800,
//                   fontSize: 14,
//                   fontWeight: FontWeight.w600,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 16),
//           Row(
//             children: [
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       'Font Size',
//                       style: TextStyle(
//                         color: isDarkMode
//                             ? Colors.white70
//                             : Colors.grey.shade600,
//                         fontSize: 12,
//                       ),
//                     ),
//                     const SizedBox(height: 8),
//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         _buildControlButton(
//                           Icons.remove,
//                           () => sldController.adjustEnergyReadingFontSize(-0.5),
//                           theme,
//                           isDarkMode,
//                         ),
//                         Container(
//                           margin: const EdgeInsets.symmetric(horizontal: 12),
//                           padding: const EdgeInsets.symmetric(
//                             horizontal: 12,
//                             vertical: 6,
//                           ),
//                           decoration: BoxDecoration(
//                             color: isDarkMode
//                                 ? Colors.white.withOpacity(0.2)
//                                 : Colors.grey.shade200,
//                             borderRadius: BorderRadius.circular(6),
//                           ),
//                           child: Text(
//                             selectedBayRenderData.energyReadingFontSize
//                                 .toStringAsFixed(1),
//                             style: TextStyle(
//                               color: isDarkMode
//                                   ? Colors.white
//                                   : Colors.grey.shade800,
//                               fontSize: 14,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                         ),
//                         _buildControlButton(
//                           Icons.add,
//                           () => sldController.adjustEnergyReadingFontSize(0.5),
//                           theme,
//                           isDarkMode,
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
//               const SizedBox(width: 16),
//               Column(
//                 children: [
//                   Text(
//                     'Bold Text',
//                     style: TextStyle(
//                       color: isDarkMode ? Colors.white70 : Colors.grey.shade600,
//                       fontSize: 12,
//                     ),
//                   ),
//                   const SizedBox(height: 8),
//                   Switch(
//                     value: selectedBayRenderData.energyReadingIsBold,
//                     onChanged: (value) =>
//                         sldController.toggleEnergyReadingBold(),
//                     activeColor: theme.colorScheme.primary,
//                     activeTrackColor: theme.colorScheme.primary.withOpacity(
//                       0.3,
//                     ),
//                     inactiveThumbColor: isDarkMode
//                         ? Colors.white70
//                         : Colors.grey.shade400,
//                     inactiveTrackColor: isDarkMode
//                         ? Colors.white.withOpacity(0.2)
//                         : Colors.grey.shade300,
//                   ),
//                 ],
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildBusbarLengthControls(
//     dynamic selectedBayRenderData,
//     SldController sldController,
//     ThemeData theme,
//     bool isDarkMode,
//   ) {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: isDarkMode
//             ? Colors.white.withOpacity(0.1)
//             : Colors.grey.shade100,
//         borderRadius: BorderRadius.circular(12),
//       ),
//       child: Column(
//         children: [
//           Row(
//             children: [
//               Icon(
//                 Icons.straighten,
//                 color: isDarkMode ? Colors.white70 : Colors.grey.shade600,
//                 size: 20,
//               ),
//               const SizedBox(width: 8),
//               Text(
//                 'Busbar Length Control',
//                 style: TextStyle(
//                   color: isDarkMode ? Colors.white : Colors.grey.shade800,
//                   fontSize: 14,
//                   fontWeight: FontWeight.w600,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 16),
//           Row(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               _buildControlButton(
//                 Icons.remove,
//                 () => sldController.adjustBusbarLength(-10.0),
//                 theme,
//                 isDarkMode,
//               ),
//               Container(
//                 margin: const EdgeInsets.symmetric(horizontal: 16),
//                 padding: const EdgeInsets.symmetric(
//                   horizontal: 16,
//                   vertical: 8,
//                 ),
//                 decoration: BoxDecoration(
//                   color: isDarkMode
//                       ? Colors.white.withOpacity(0.2)
//                       : Colors.grey.shade200,
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 child: Column(
//                   children: [
//                     Text(
//                       selectedBayRenderData.busbarLength.toStringAsFixed(0),
//                       style: TextStyle(
//                         color: isDarkMode ? Colors.white : Colors.grey.shade800,
//                         fontSize: 16,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                     Text(
//                       'px',
//                       style: TextStyle(
//                         color: isDarkMode
//                             ? Colors.white70
//                             : Colors.grey.shade600,
//                         fontSize: 10,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//               _buildControlButton(
//                 Icons.add,
//                 () => sldController.adjustBusbarLength(10.0),
//                 theme,
//                 isDarkMode,
//               ),
//             ],
//           ),
//           const SizedBox(height: 8),
//           Text(
//             'Tap - or + to adjust busbar length',
//             style: TextStyle(
//               color: isDarkMode ? Colors.white60 : Colors.grey.shade500,
//               fontSize: 11,
//               fontStyle: FontStyle.italic,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildUnsavedChangesIndicator(ThemeData theme, bool isDarkMode) {
//     return Container(
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: Colors.orange.withOpacity(0.1),
//         borderRadius: BorderRadius.circular(8),
//         border: Border.all(color: Colors.orange.withOpacity(0.3)),
//       ),
//       child: Row(
//         children: [
//           Icon(
//             Icons.warning_amber_rounded,
//             color: Colors.orange.shade600,
//             size: 16,
//           ),
//           const SizedBox(width: 8),
//           Expanded(
//             child: Text(
//               'You have unsaved changes. Use back button to save all changes at once.',
//               style: TextStyle(
//                 color: Colors.orange.shade700,
//                 fontSize: 12,
//                 fontWeight: FontWeight.w500,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildControlButton(
//     IconData icon,
//     VoidCallback onPressed,
//     ThemeData theme,
//     bool isDarkMode,
//   ) {
//     return Container(
//       decoration: BoxDecoration(
//         color: isDarkMode
//             ? Colors.white.withOpacity(0.2)
//             : Colors.grey.shade300,
//         borderRadius: BorderRadius.circular(6),
//         border: Border.all(
//           color: isDarkMode
//               ? Colors.white.withOpacity(0.3)
//               : Colors.grey.shade400,
//         ),
//       ),
//       child: Material(
//         color: Colors.transparent,
//         child: InkWell(
//           onTap: onPressed,
//           borderRadius: BorderRadius.circular(6),
//           child: Container(
//             width: 36,
//             height: 36,
//             alignment: Alignment.center,
//             child: Icon(
//               icon,
//               color: isDarkMode ? Colors.white : Colors.grey.shade700,
//               size: 18,
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildActionButtons(
//     BuildContext context,
//     SldController sldController,
//     ThemeData theme,
//     bool hasUnsavedChanges,
//     bool isDarkMode,
//   ) {
//     return Row(
//       children: [
//         Expanded(
//           child: Container(
//             height: 48,
//             decoration: BoxDecoration(
//               gradient: LinearGradient(
//                 colors: [Colors.blue.shade600, Colors.blue.shade500],
//                 begin: Alignment.topLeft,
//                 end: Alignment.bottomRight,
//               ),
//               borderRadius: BorderRadius.circular(12),
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.blue.withOpacity(0.3),
//                   blurRadius: 4,
//                   offset: const Offset(0, 2),
//                 ),
//               ],
//             ),
//             child: Material(
//               color: Colors.transparent,
//               child: InkWell(
//                 onTap: () async {
//                   final success = await sldController
//                       .saveSelectedBayLayoutChanges();
//                   if (context.mounted) {
//                     if (success) {
//                       SnackBarUtils.showSnackBar(
//                         context,
//                         'Layout changes saved for this bay!',
//                       );
//                     } else {
//                       SnackBarUtils.showSnackBar(
//                         context,
//                         'Failed to save layout changes.',
//                         isError: true,
//                       );
//                     }
//                   }
//                 },
//                 borderRadius: BorderRadius.circular(12),
//                 child: const Row(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     Icon(Icons.save_outlined, color: Colors.white, size: 20),
//                     SizedBox(width: 8),
//                     Text(
//                       'Save This Bay',
//                       style: TextStyle(
//                         color: Colors.white,
//                         fontSize: 14,
//                         fontWeight: FontWeight.w600,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//         ),
//         const SizedBox(width: 12),
//         Expanded(
//           child: Container(
//             height: 48,
//             decoration: BoxDecoration(
//               gradient: LinearGradient(
//                 colors: [Colors.grey.shade600, Colors.grey.shade500],
//                 begin: Alignment.topLeft,
//                 end: Alignment.bottomRight,
//               ),
//               borderRadius: BorderRadius.circular(12),
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.grey.withOpacity(0.3),
//                   blurRadius: 4,
//                   offset: const Offset(0, 2),
//                 ),
//               ],
//             ),
//             child: Material(
//               color: Colors.transparent,
//               child: InkWell(
//                 onTap: () {
//                   sldController.setSelectedBayForMovement(null);
//                   SnackBarUtils.showSnackBar(
//                     context,
//                     hasUnsavedChanges
//                         ? 'Selection cleared. Changes preserved.'
//                         : 'Selection cleared.',
//                   );
//                 },
//                 borderRadius: BorderRadius.circular(12),
//                 child: const Row(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     Icon(Icons.clear, color: Colors.white, size: 20),
//                     SizedBox(width: 8),
//                     Text(
//                       'Clear Selection',
//                       style: TextStyle(
//                         color: Colors.white,
//                         fontSize: 14,
//                         fontWeight: FontWeight.w600,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//         ),
//       ],
//     );
//   }
// }
// lib/widgets/energy_movement_controls_widget.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import '../controllers/sld_controller.dart';
import '../enums/movement_mode.dart';
import '../utils/snackbar_utils.dart';

class EnergyMovementControlsWidget extends StatelessWidget {
  final VoidCallback onSave;
  final bool isViewingSavedSld;

  const EnergyMovementControlsWidget({
    super.key,
    required this.onSave,
    required this.isViewingSavedSld,
  });

  @override
  Widget build(BuildContext context) {
    if (isViewingSavedSld) return const SizedBox.shrink();

    final sldController = Provider.of<SldController>(context);
    final selectedBayId = sldController.selectedBayForMovementId;

    if (selectedBayId == null) return const SizedBox.shrink();

    final selectedBay = sldController.baysMap[selectedBayId];
    if (selectedBay == null) return const SizedBox.shrink();

    final selectedBayRenderData = sldController.bayRenderDataList
        .firstWhereOrNull((data) => data.bay.id == selectedBayId);
    if (selectedBayRenderData == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final hasUnsavedChanges = sldController.hasUnsavedChanges();
    final isDarkMode = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDarkMode
              ? [Colors.grey.shade900, Colors.blueGrey.shade800]
              : [Colors.white, Colors.grey.shade50],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
        border: isDarkMode
            ? null
            : Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Compact header with bay info and mode selector
              Row(
                children: [
                  // Bay info
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? Colors.white.withOpacity(0.1)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.tune,
                          color: theme.colorScheme.primary,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          selectedBay.name,
                          style: TextStyle(
                            color: isDarkMode
                                ? Colors.white
                                : Colors.grey.shade800,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (hasUnsavedChanges) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Compact mode selector
                  Expanded(
                    child: _buildCompactModeSelector(
                      sldController,
                      theme,
                      isDarkMode,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Movement controls and specific controls in one row
              Row(
                children: [
                  // Movement controls
                  _buildCompactMovementControls(
                    sldController,
                    theme,
                    isDarkMode,
                  ),
                  const SizedBox(width: 16),

                  // Mode-specific controls
                  Expanded(
                    child: _buildCompactModeSpecificControls(
                      selectedBay,
                      selectedBayRenderData,
                      sldController,
                      theme,
                      isDarkMode,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Compact action buttons
              _buildCompactActionButtons(
                context,
                sldController,
                theme,
                isDarkMode,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactModeSelector(
    SldController sldController,
    ThemeData theme,
    bool isDarkMode,
  ) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withOpacity(0.1)
            : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          _buildCompactModeButton(
            icon: Icons.open_with,
            label: 'Bay',
            isSelected: sldController.movementMode == MovementMode.bay,
            onTap: () => sldController.setMovementMode(MovementMode.bay),
            theme: theme,
            isDarkMode: isDarkMode,
          ),
          _buildCompactModeButton(
            icon: Icons.text_fields,
            label: 'Text',
            isSelected: sldController.movementMode == MovementMode.text,
            onTap: () => sldController.setMovementMode(MovementMode.text),
            theme: theme,
            isDarkMode: isDarkMode,
          ),
          _buildCompactModeButton(
            icon: Icons.format_list_numbered,
            label: 'Reading',
            isSelected: sldController.movementMode == MovementMode.energyText,
            onTap: () => sldController.setMovementMode(MovementMode.energyText),
            theme: theme,
            isDarkMode: isDarkMode,
          ),
        ],
      ),
    );
  }

  Widget _buildCompactModeButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required ThemeData theme,
    required bool isDarkMode,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDarkMode ? Colors.white : theme.colorScheme.primary)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? (isDarkMode ? theme.colorScheme.primary : Colors.white)
                    : (isDarkMode ? Colors.white70 : Colors.grey.shade600),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: isSelected
                      ? (isDarkMode ? theme.colorScheme.primary : Colors.white)
                      : (isDarkMode ? Colors.white70 : Colors.grey.shade600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactMovementControls(
    SldController sldController,
    ThemeData theme,
    bool isDarkMode,
  ) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withOpacity(0.1)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildCompactDirectionButton(
            Icons.keyboard_arrow_up,
            () => sldController.moveSelectedItem(0, -5.0),
            theme,
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildCompactDirectionButton(
                Icons.keyboard_arrow_left,
                () => sldController.moveSelectedItem(-5.0, 0),
                theme,
              ),
              const SizedBox(width: 4),
              _buildCompactDirectionButton(
                Icons.keyboard_arrow_right,
                () => sldController.moveSelectedItem(5.0, 0),
                theme,
              ),
            ],
          ),
          _buildCompactDirectionButton(
            Icons.keyboard_arrow_down,
            () => sldController.moveSelectedItem(0, 5.0),
            theme,
          ),
        ],
      ),
    );
  }

  Widget _buildCompactDirectionButton(
    IconData icon,
    VoidCallback onPressed,
    ThemeData theme,
  ) {
    return Container(
      width: 32,
      height: 32,
      margin: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.3),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(4),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
      ),
    );
  }

  Widget _buildCompactModeSpecificControls(
    dynamic selectedBay,
    dynamic selectedBayRenderData,
    SldController sldController,
    ThemeData theme,
    bool isDarkMode,
  ) {
    if (sldController.movementMode == MovementMode.energyText) {
      return _buildCompactEnergyControls(
        selectedBayRenderData,
        sldController,
        theme,
        isDarkMode,
      );
    } else if (sldController.movementMode == MovementMode.bay &&
        selectedBay.bayType == 'Busbar') {
      return _buildCompactBusbarControls(
        selectedBayRenderData,
        sldController,
        theme,
        isDarkMode,
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildCompactEnergyControls(
    dynamic selectedBayRenderData,
    SldController sldController,
    ThemeData theme,
    bool isDarkMode,
  ) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withOpacity(0.1)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // Font size controls
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTinyButton(
                  Icons.remove,
                  () => sldController.adjustEnergyReadingFontSize(-0.5),
                  theme,
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.2)
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    selectedBayRenderData.energyReadingFontSize.toStringAsFixed(
                      1,
                    ),
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.grey.shade800,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildTinyButton(
                  Icons.add,
                  () => sldController.adjustEnergyReadingFontSize(0.5),
                  theme,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Bold toggle
          GestureDetector(
            onTap: () => sldController.toggleEnergyReadingBold(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: selectedBayRenderData.energyReadingIsBold
                    ? theme.colorScheme.primary.withOpacity(0.2)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: selectedBayRenderData.energyReadingIsBold
                      ? theme.colorScheme.primary
                      : (isDarkMode ? Colors.white38 : Colors.grey.shade400),
                ),
              ),
              child: Text(
                'B',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: selectedBayRenderData.energyReadingIsBold
                      ? theme.colorScheme.primary
                      : (isDarkMode ? Colors.white70 : Colors.grey.shade600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactBusbarControls(
    dynamic selectedBayRenderData,
    SldController sldController,
    ThemeData theme,
    bool isDarkMode,
  ) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withOpacity(0.1)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildTinyButton(
            Icons.remove,
            () => sldController.adjustBusbarLength(-10.0),
            theme,
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.white.withOpacity(0.2)
                  : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${selectedBayRenderData.busbarLength.toStringAsFixed(0)}px',
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.grey.shade800,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _buildTinyButton(
            Icons.add,
            () => sldController.adjustBusbarLength(10.0),
            theme,
          ),
        ],
      ),
    );
  }

  Widget _buildTinyButton(
    IconData icon,
    VoidCallback onPressed,
    ThemeData theme,
  ) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(4),
          child: Icon(icon, color: theme.colorScheme.primary, size: 14),
        ),
      ),
    );
  }

  Widget _buildCompactActionButtons(
    BuildContext context,
    SldController sldController,
    ThemeData theme,
    bool isDarkMode,
  ) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade600, Colors.blue.shade500],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () async {
                  final success = await sldController
                      .saveSelectedBayLayoutChanges();
                  if (context.mounted) {
                    SnackBarUtils.showSnackBar(
                      context,
                      success ? 'Saved!' : 'Save failed',
                      isError: !success,
                    );
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.save_outlined, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'Save Bay',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.grey.shade600, Colors.grey.shade500],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  sldController.setSelectedBayForMovement(null);
                  SnackBarUtils.showSnackBar(context, 'Selection cleared');
                },
                borderRadius: BorderRadius.circular(8),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.clear, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'Clear',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
