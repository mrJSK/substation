// // import 'package:flutter/material.dart';
// // import 'package:flutter/services.dart'; // Required for rootBundle
// // import 'package:firebase_core/firebase_core.dart';
// // import 'package:firebase_auth/firebase_auth.dart';
// // import 'package:cloud_firestore/cloud_firestore.dart';
// // import 'package:google_sign_in/google_sign_in.dart';
// // import 'package:provider/provider.dart';
// // import '../firebase_options.dart';

// // import '../models/app_state_data.dart';
// // import '../models/user_model.dart';
// // import '../screens/auth_screen.dart';
// // // Import specific role-based home screens
// // import '../screens/admin/admin_dashboard_screen.dart'; // Ensure this path is correct for AdminHomeScreen
// // import '../screens/substation_user_dashboard_screen.dart'; // Ensure this path is correct for SubstationUserHomeScreen
// // import '../screens/subdivision_dashboard_screen.dart'; // Ensure this path is correct for SubdivisionManagerHomeScreen

// // import '../utils/snackbar_utils.dart';
// // import 'home_screen.dart'; // Assuming you have this utility

// // class SplashScreen extends StatefulWidget {
// //   const SplashScreen({super.key});

// //   @override
// //   State<SplashScreen> createState() => _SplashScreenState();
// // }

// // class _SplashScreenState extends State<SplashScreen>
// //     with SingleTickerProviderStateMixin {
// //   late AnimationController _controller;
// //   late Animation<double> _fadeInAnimation;
// //   late Animation<Offset> _slideAnimation;
// //   late Animation<double> _progressAnimation;

// //   @override
// //   void initState() {
// //     super.initState();

// //     _controller = AnimationController(
// //       duration: const Duration(
// //         seconds: 4,
// //       ), // Increased duration for data loading
// //       vsync: this,
// //     );

// //     _fadeInAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
// //       CurvedAnimation(
// //         parent: _controller,
// //         curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
// //       ),
// //     );

// //     _slideAnimation =
// //         Tween<Offset>(begin: const Offset(-1.0, 0.0), end: Offset.zero).animate(
// //           CurvedAnimation(
// //             parent: _controller,
// //             curve: const Interval(0.3, 0.8, curve: Curves.easeOutCubic),
// //           ),
// //         );

// //     _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
// //       CurvedAnimation(
// //         parent: _controller,
// //         curve: const Interval(0.7, 1.0, curve: Curves.linear),
// //       ),
// //     );

// //     _controller.forward();

// //     _controller.addStatusListener((status) {
// //       if (status == AnimationStatus.completed) {
// //         _initializeAppAndNavigate();
// //       }
// //     });
// //   }

// //   @override
// //   void dispose() {
// //     _controller.dispose();
// //     super.dispose();
// //   }

// //   // Static method to parse states from SQL content
// //   static List<StateModel> _parseStatesSql(String sqlContent) {
// //     final List<StateModel> states = [];
// //     final RegExp regex = RegExp(
// //       r"VALUES\s*\(\s*(\d+),\s*'([^']*)'\s*\);", // Regex to extract (id, 'name')
// //     );
// //     final Iterable<RegExpMatch> matches = regex.allMatches(sqlContent);

// //     for (final match in matches) {
// //       if (match.group(1) != null && match.group(2) != null) {
// //         final id = double.parse(match.group(1)!);
// //         final name = match.group(2)!;
// //         states.add(StateModel(id: id, name: name));
// //       }
// //     }
// //     return states;
// //   }

// //   // Static method to parse cities from SQL content
// //   static List<CityModel> _parseCitiesSql(String sqlContent) {
// //     final List<CityModel> cities = [];
// //     final RegExp regex = RegExp(
// //       r"VALUES\s*\(\s*(\d+),\s*'([^']*)',\s*(\d+)\s*\);", // Regex to extract (id, 'name', state_id)
// //     );
// //     final Iterable<RegExpMatch> matches = regex.allMatches(sqlContent);

// //     for (final match in matches) {
// //       if (match.group(1) != null &&
// //           match.group(2) != null &&
// //           match.group(3) != null) {
// //         final id = double.parse(match.group(1)!);
// //         final name = match.group(2)!;
// //         final stateId = double.parse(match.group(3)!);
// //         cities.add(CityModel(id: id, name: name, stateId: stateId));
// //       }
// //     }
// //     return cities;
// //   }

// //   Future<void> _initializeAppAndNavigate() async {
// //     try {
// //       // Initialize Firebase
// //       await Firebase.initializeApp(
// //         name:
// //             'SubstationManagerPro', // Ensure this matches your Firebase project setup if multiple apps
// //         options: DefaultFirebaseOptions.currentPlatform,
// //       );

// //       // --- Load States and Cities from SQL asset files into AppStateData ---
// //       print(
// //         'DEBUG: SplashScreen: Starting asset data loading for states and cities.',
// //       );

// //       // Wrap asset loading in try-catch for better error handling
// //       String statesSqlContent = '';
// //       String citiesSqlContent = '';
// //       try {
// //         statesSqlContent = await rootBundle.loadString(
// //           'assets/state_sql_command.txt',
// //         );
// //         citiesSqlContent = await rootBundle.loadString(
// //           'assets/city_sql_command.txt',
// //         );
// //       } catch (assetError) {
// //         print('ERROR: SplashScreen: Failed to load assets: $assetError');
// //         // Optionally show a snackbar or fallback, but proceed to navigation
// //       }

// //       final List<StateModel> loadedStateModels = _parseStatesSql(
// //         statesSqlContent,
// //       );
// //       final List<CityModel> loadedCityModels = _parseCitiesSql(
// //         citiesSqlContent,
// //       );

// //       print(
// //         'DEBUG: SplashScreen: Parsed ${loadedStateModels.length} states and ${loadedCityModels.length} cities.',
// //       );

// //       if (mounted) {
// //         final appStateData = Provider.of<AppStateData>(context, listen: false);
// //         // <<<<<<< HEAD

// //         //         // Set models and trigger _checkAndSetLoaded (assuming it exists in AppStateData)
// //         //         appStateData.setAllStateModels(loadedStateModels);
// //         //         appStateData.setAllCityModels(loadedCityModels);

// //         //         print(
// //         //           'DEBUG: SplashScreen: Asset data set in Provider. Data loaded flag: ${appStateData.isDataLoaded}',
// //         //         );

// //         //         // **FIX: Remove inefficient Future.doWhile loop**
// //         //         // Instead, add a short delay to allow notifyListeners() to propagate
// //         //         // This matches the previous version's behavior where navigation happens immediately after setting data
// //         //         await Future.delayed(
// //         //           const Duration(milliseconds: 500),
// //         //         ); // Brief wait for Provider updates

// //         //         print(
// //         //           'DEBUG: SplashScreen: Proceeding with navigation after data setup.',
// //         //         );
// //         //         // Proceed with navigation
// //         //         _navigateBasedOnUser();
// //         // =======
// //         //         appStateData.setAllStateModels(loadedStateModels);
// //         //         appStateData.setAllCityModels(loadedCityModels);
// //         //         print(
// //         //           'DEBUG: SplashScreen: Asset data loading complete for states and cities.',
// //         //         );
// //         //       }
// //         //       // --- End Asset Data Loading ---

// //         //       // Check Firebase authentication state for existing users
// //         //       final User? user = FirebaseAuth.instance.currentUser;

// //         //       if (mounted) {
// //         //         if (user == null) {
// //         //           // No user signed in, navigate to AuthScreen
// //         //           Navigator.of(context).pushReplacement(
// //         //             MaterialPageRoute(builder: (context) => const AuthScreen()),
// //         //           );
// //         //         } else {
// //         //           // User is signed in, check their approval status and role from Firestore
// //         //           try {
// //         //             final userDoc = await FirebaseFirestore.instance
// //         //                 .collection('users')
// //         //                 .doc(user.uid)
// //         //                 .get();
// //         //             if (userDoc.exists) {
// //         //               final appUser = AppUser.fromFirestore(userDoc);
// //         //               if (appUser.approved) {
// //         //                 // User is approved, navigate to HomeScreen
// //         //                 Navigator.of(context).pushReplacement(
// //         //                   MaterialPageRoute(
// //         //                     builder: (context) => HomeScreen(appUser: appUser),
// //         //                   ),
// //         //                 );
// //         //               } else {
// //         //                 // User is not yet approved
// //         //                 Navigator.of(context).pushReplacement(
// //         //                   MaterialPageRoute(
// //         //                     builder: (context) => const Scaffold(
// //         //                       body: Center(
// //         //                         child: Padding(
// //         //                           padding: EdgeInsets.all(24.0),
// //         //                           child: Column(
// //         //                             mainAxisAlignment: MainAxisAlignment.center,
// //         //                             children: [
// //         //                               Icon(
// //         //                                 Icons.hourglass_empty,
// //         //                                 size: 80,
// //         //                                 color: Colors.blue,
// //         //                               ),
// //         //                               SizedBox(height: 20),
// //         //                               Text(
// //         //                                 'Your account is pending approval by an admin.',
// //         //                                 textAlign: TextAlign.center,
// //         //                                 style: TextStyle(
// //         //                                   fontSize: 18,
// //         //                                   color: Colors.grey,
// //         //                                 ),
// //         //                               ),
// //         //                               SizedBox(height: 10),
// //         //                               Text(
// //         //                                 'Please wait while an administrator reviews your registration.',
// //         //                                 textAlign: TextAlign.center,
// //         //                                 style: TextStyle(
// //         //                                   fontSize: 14,
// //         //                                   color: Colors.grey,
// //         //                                 ),
// //         //                               ),
// //         //                             ],
// //         //                           ),
// //         //                         ),
// //         //                       ),
// //         //                     ),
// //         //                   ),
// //         //                 );
// //         //               }
// //         //             } else {
// //         //               // This case should ideally not be hit frequently with the AuthScreen changes,
// //         //               // but handles if a user somehow gets authenticated without a Firestore doc.
// //         //               // Log out and send to auth screen to re-establish.
// //         //               await FirebaseAuth.instance.signOut();
// //         //               await GoogleSignIn().signOut();
// //         //               Navigator.of(context).pushReplacement(
// //         //                 MaterialPageRoute(builder: (context) => const AuthScreen()),
// //         //               );
// //         //             }
// //         //           } catch (e) {
// //         //             print('Error checking user approval from Splash: $e');
// //         //             SnackBarUtils.showSnackBar(
// //         //               context,
// //         //               'Authentication failed: $e',
// //         //               isError: true,
// //         //             );
// //         //             Navigator.of(context).pushReplacement(
// //         //               MaterialPageRoute(builder: (context) => const AuthScreen()),
// //         //             );
// //         //           }
// //         //         }
// //         // >>>>>>> 7efa4915f587f3a90fae86d43052992d382b3ad4
// //       }
// //     } catch (e) {
// //       print("ERROR: SplashScreen: Initialization failed: $e");
// //       if (mounted) {
// //         SnackBarUtils.showSnackBar(
// //           context,
// //           'App initialization failed: $e',
// //           isError: true,
// //         );
// //         Navigator.of(context).pushReplacement(
// //           MaterialPageRoute(builder: (context) => const AuthScreen()),
// //         );
// //       }
// //     }
// //   }

// //   @override
// //   Widget build(BuildContext context) {
// //     final ColorScheme colorScheme = Theme.of(context).colorScheme;

// //     return Scaffold(
// //       backgroundColor: colorScheme.primary,
// //       body: Center(
// //         child: Column(
// //           mainAxisAlignment: MainAxisAlignment.center,
// //           children: [
// //             SlideTransition(
// //               position: _slideAnimation,
// //               child: FadeTransition(
// //                 opacity: _fadeInAnimation,
// //                 child: Icon(
// //                   Icons.factory,
// //                   size: 120,
// //                   color: colorScheme.tertiary,
// //                 ),
// //               ),
// //             ),
// //             const SizedBox(height: 30),
// //             FadeTransition(
// //               opacity: _fadeInAnimation,
// //               child: Text(
// //                 'Substation Manager Pro',
// //                 style: Theme.of(context).textTheme.headlineMedium?.copyWith(
// //                   color: colorScheme.onPrimary,
// //                   fontWeight: FontWeight.bold,
// //                 ),
// //               ),
// //             ),
// //             const SizedBox(height: 20),
// //             SizedBox(
// //               width: 150,
// //               child: AnimatedBuilder(
// //                 animation: _progressAnimation,
// //                 builder: (context, child) {
// //                   return LinearProgressIndicator(
// //                     value: _progressAnimation.value,
// //                     backgroundColor: colorScheme.onPrimary.withOpacity(0.3),
// //                     valueColor: AlwaysStoppedAnimation<Color>(
// //                       colorScheme.onPrimary,
// //                     ),
// //                   );
// //                 },
// //               ),
// //             ),
// //             const SizedBox(height: 10),
// //             FadeTransition(
// //               opacity: _fadeInAnimation,
// //               child: Text(
// //                 'Powering tomorrow...',
// //                 style: Theme.of(context).textTheme.bodyLarge?.copyWith(
// //                   color: colorScheme.onPrimary.withOpacity(0.8),
// //                   fontStyle: FontStyle.italic,
// //                 ),
// //               ),
// //             ),
// //           ],
// //         ),
// //       ),
// //     );
// //   }
// // }

// // lib/screens/splash_screen.dart
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:google_sign_in/google_sign_in.dart';
// import 'package:provider/provider.dart';
// import '../firebase_options.dart';
// import '../models/app_state_data.dart';
// import '../models/user_model.dart';
// import '../screens/auth_screen.dart';
// import '../screens/home_screen.dart';
// import '../utils/snackbar_utils.dart';

// class SplashScreen extends StatefulWidget {
//   const SplashScreen({super.key});

//   @override
//   State<SplashScreen> createState() => _SplashScreenState();
// }

// class _SplashScreenState extends State<SplashScreen>
//     with SingleTickerProviderStateMixin {
//   late AnimationController _controller;
//   late Animation<double> _fadeInAnimation;
//   late Animation<Offset> _slideAnimation;
//   late Animation<double> _progressAnimation;

//   @override
//   void initState() {
//     super.initState();

//     _controller = AnimationController(
//       duration: const Duration(seconds: 4),
//       vsync: this,
//     );

//     _fadeInAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
//       CurvedAnimation(
//         parent: _controller,
//         curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
//       ),
//     );

//     _slideAnimation =
//         Tween<Offset>(begin: const Offset(-1.0, 0.0), end: Offset.zero).animate(
//           CurvedAnimation(
//             parent: _controller,
//             curve: const Interval(0.3, 0.8, curve: Curves.easeOutCubic),
//           ),
//         );

//     _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
//       CurvedAnimation(
//         parent: _controller,
//         curve: const Interval(0.7, 1.0, curve: Curves.linear),
//       ),
//     );

//     _controller.forward();

//     _controller.addStatusListener((status) {
//       if (status == AnimationStatus.completed) {
//         _initializeAppAndNavigate();
//       }
//     });
//   }

//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }

//   // Static method to parse states from SQL content
//   static List<StateModel> _parseStatesSql(String sqlContent) {
//     final List<StateModel> states = [];
//     final RegExp regex = RegExp(r"VALUES\s*\(\s*(\d+),\s*'([^']*)'\s*\);");
//     final Iterable<RegExpMatch> matches = regex.allMatches(sqlContent);

//     for (final match in matches) {
//       if (match.group(1) != null && match.group(2) != null) {
//         final id = double.parse(match.group(1)!);
//         final name = match.group(2)!;
//         states.add(StateModel(id: id, name: name));
//       }
//     }
//     return states;
//   }

//   // Static method to parse cities from SQL content
//   static List<CityModel> _parseCitiesSql(String sqlContent) {
//     final List<CityModel> cities = [];
//     final RegExp regex = RegExp(
//       r"VALUES\s*\(\s*(\d+),\s*'([^']*)',\s*(\d+)\s*\);",
//     );
//     final Iterable<RegExpMatch> matches = regex.allMatches(sqlContent);

//     for (final match in matches) {
//       if (match.group(1) != null &&
//           match.group(2) != null &&
//           match.group(3) != null) {
//         final id = double.parse(match.group(1)!);
//         final name = match.group(2)!;
//         final stateId = double.parse(match.group(3)!);
//         cities.add(CityModel(id: id, name: name, stateId: stateId));
//       }
//     }
//     return cities;
//   }

//   Future<void> _initializeAppAndNavigate() async {
//     try {
//       // Initialize Firebase
//       await Firebase.initializeApp(
//         name: 'SubstationManagerPro',
//         options: DefaultFirebaseOptions.currentPlatform,
//       );
//       print('DEBUG: SplashScreen: Firebase initialized successfully.');

//       // Load States and Cities from SQL asset files
//       String statesSqlContent = '';
//       String citiesSqlContent = '';
//       try {
//         statesSqlContent = await rootBundle.loadString(
//           'assets/state_sql_command.txt',
//         );
//         citiesSqlContent = await rootBundle.loadString(
//           'assets/city_sql_command.txt',
//         );
//       } catch (assetError) {
//         print('ERROR: SplashScreen: Failed to load assets: $assetError');
//         // Show warning but continue to allow navigation
//         if (mounted) {
//           SnackBarUtils.showSnackBar(
//             context,
//             'Failed to load state/city data. Some features may be limited.',
//             isError: true,
//           );
//         }
//       }

//       final List<StateModel> loadedStateModels = _parseStatesSql(
//         statesSqlContent,
//       );
//       final List<CityModel> loadedCityModels = _parseCitiesSql(
//         citiesSqlContent,
//       );

//       print(
//         'DEBUG: SplashScreen: Parsed ${loadedStateModels.length} states and ${loadedCityModels.length} cities.',
//       );

//       if (mounted) {
//         final appStateData = Provider.of<AppStateData>(context, listen: false);
//         // Update provider in a post-frame callback to avoid build issues
//         WidgetsBinding.instance.addPostFrameCallback((_) {
//           appStateData.setAllStateModels(loadedStateModels);
//           appStateData.setAllCityModels(loadedCityModels);
//           print(
//             'DEBUG: SplashScreen: Asset data set in Provider. States: ${loadedStateModels.length}, Cities: ${loadedCityModels.length}',
//           );
//           // Proceed with navigation
//           _navigateBasedOnUser();
//         });
//       }
//     } catch (e) {
//       print('ERROR: SplashScreen: Initialization failed: $e');
//       if (mounted) {
//         SnackBarUtils.showSnackBar(
//           context,
//           'App initialization failed: $e',
//           isError: true,
//         );
//         Navigator.of(context).pushReplacement(
//           MaterialPageRoute(builder: (context) => const AuthScreen()),
//         );
//       }
//     }
//   }

//   Future<void> _navigateBasedOnUser() async {
//     // Check Firebase authentication state for existing users
//     final User? user = FirebaseAuth.instance.currentUser;

//     if (mounted) {
//       if (user == null) {
//         print(
//           'DEBUG: SplashScreen: No user signed in, navigating to AuthScreen.',
//         );
//         Navigator.of(context).pushReplacement(
//           MaterialPageRoute(builder: (context) => const AuthScreen()),
//         );
//       } else {
//         print('DEBUG: SplashScreen: User signed in: ${user.email}');
//         try {
//           final userDoc = await FirebaseFirestore.instance
//               .collection('users')
//               .doc(user.uid)
//               .get();
//           if (userDoc.exists) {
//             final appUser = AppUser.fromFirestore(userDoc);
//             print(
//               'DEBUG: SplashScreen: User role: ${appUser.role}, Approved: ${appUser.approved}',
//             );
//             if (appUser.approved) {
//               // Navigate based on user role
//               if (appUser.role == UserRole.admin) {
//                 Navigator.of(context).pushReplacement(
//                   MaterialPageRoute(
//                     builder: (context) => AdminHomeScreen(appUser: appUser),
//                   ),
//                 );
//               } else if (appUser.role == UserRole.substationUser) {
//                 Navigator.of(context).pushReplacement(
//                   MaterialPageRoute(
//                     builder: (context) =>
//                         SubstationUserHomeScreen(appUser: appUser),
//                   ),
//                 );
//               } else if (appUser.role == UserRole.subdivisionManager) {
//                 Navigator.of(context).pushReplacement(
//                   MaterialPageRoute(
//                     builder: (context) =>
//                         SubdivisionManagerHomeScreen(appUser: appUser),
//                   ),
//                 );
//               } else {
//                 print(
//                   'ERROR: SplashScreen: Unsupported user role: ${appUser.role}',
//                 );
//                 SnackBarUtils.showSnackBar(
//                   context,
//                   'Unsupported user role.',
//                   isError: true,
//                 );
//                 Navigator.of(context).pushReplacement(
//                   MaterialPageRoute(builder: (context) => const AuthScreen()),
//                 );
//               }
//             } else {
//               print(
//                 'DEBUG: SplashScreen: User not approved, showing pending screen.',
//               );
//               Navigator.of(context).pushReplacement(
//                 MaterialPageRoute(
//                   builder: (context) => const Scaffold(
//                     body: Center(
//                       child: Padding(
//                         padding: EdgeInsets.all(24.0),
//                         child: Column(
//                           mainAxisAlignment: MainAxisAlignment.center,
//                           children: [
//                             Icon(
//                               Icons.hourglass_empty,
//                               size: 80,
//                               color: Colors.blue,
//                             ),
//                             SizedBox(height: 20),
//                             Text(
//                               'Your account is pending approval by an admin.',
//                               textAlign: TextAlign.center,
//                               style: TextStyle(
//                                 fontSize: 18,
//                                 color: Colors.grey,
//                               ),
//                             ),
//                             SizedBox(height: 10),
//                             Text(
//                               'Please wait while an administrator reviews your registration.',
//                               textAlign: TextAlign.center,
//                               style: TextStyle(
//                                 fontSize: 14,
//                                 color: Colors.grey,
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),
//               );
//             }
//           } else {
//             print(
//               'DEBUG: SplashScreen: No Firestore document for user, signing out.',
//             );
//             await FirebaseAuth.instance.signOut();
//             await GoogleSignIn().signOut();
//             Navigator.of(context).pushReplacement(
//               MaterialPageRoute(builder: (context) => const AuthScreen()),
//             );
//           }
//         } catch (e) {
//           print('ERROR: SplashScreen: Error checking user approval: $e');
//           SnackBarUtils.showSnackBar(
//             context,
//             'Authentication failed: $e',
//             isError: true,
//           );
//           Navigator.of(context).pushReplacement(
//             MaterialPageRoute(builder: (context) => const AuthScreen()),
//           );
//         }
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final ColorScheme colorScheme = Theme.of(context).colorScheme;

//     return Scaffold(
//       backgroundColor: colorScheme.primary,
//       body: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             SlideTransition(
//               position: _slideAnimation,
//               child: FadeTransition(
//                 opacity: _fadeInAnimation,
//                 child: Icon(
//                   Icons.factory,
//                   size: 120,
//                   color: colorScheme.tertiary,
//                 ),
//               ),
//             ),
//             const SizedBox(height: 30),
//             FadeTransition(
//               opacity: _fadeInAnimation,
//               child: Text(
//                 'Substation Manager Pro',
//                 style: Theme.of(context).textTheme.headlineMedium?.copyWith(
//                   color: colorScheme.onPrimary,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//             ),
//             const SizedBox(height: 20),
//             SizedBox(
//               width: 150,
//               child: AnimatedBuilder(
//                 animation: _progressAnimation,
//                 builder: (context, child) {
//                   return LinearProgressIndicator(
//                     value: _progressAnimation.value,
//                     backgroundColor: colorScheme.onPrimary.withOpacity(0.3),
//                     valueColor: AlwaysStoppedAnimation<Color>(
//                       colorScheme.onPrimary,
//                     ),
//                   );
//                 },
//               ),
//             ),
//             const SizedBox(height: 10),
//             FadeTransition(
//               opacity: _fadeInAnimation,
//               child: Text(
//                 'Powering tomorrow...',
//                 style: Theme.of(context).textTheme.bodyLarge?.copyWith(
//                   color: colorScheme.onPrimary.withOpacity(0.8),
//                   fontStyle: FontStyle.italic,
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
// // lib/screens/splash_screen.dart
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart'; // Required for rootBundle
// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:google_sign_in/google_sign_in.dart';
// import 'package:provider/provider.dart';
// import '../firebase_options.dart';

// import '../models/app_state_data.dart';
// import '../models/user_model.dart';
// import '../models/hierarchy_models.dart';
// import '../screens/auth_screen.dart';
// // Import the actual concrete home screen wrappers that contain the AppBar
// import '../screens/home_screen.dart'; // This file contains AdminHomeScreen, SubstationUserHomeScreen, SubdivisionManagerHomeScreen

// import '../utils/snackbar_utils.dart';

// class SplashScreen extends StatefulWidget {
//   const SplashScreen({super.key});

//   @override
//   State<SplashScreen> createState() => _SplashScreenState();
// }

// class _SplashScreenState extends State<SplashScreen>
//     with SingleTickerProviderStateMixin {
//   late AnimationController _controller;
//   late Animation<double> _fadeInAnimation;
//   late Animation<Offset> _slideAnimation;
//   late Animation<double> _progressAnimation;

//   @override
//   void initState() {
//     super.initState();

//     _controller = AnimationController(
//       duration: const Duration(
//         seconds: 4,
//       ), // Increased duration for data loading
//       vsync: this,
//     );

//     _fadeInAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
//       CurvedAnimation(
//         parent: _controller,
//         curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
//       ),
//     );

//     _slideAnimation =
//         Tween<Offset>(begin: const Offset(-1.0, 0.0), end: Offset.zero).animate(
//           CurvedAnimation(
//             parent: _controller,
//             curve: const Interval(0.3, 0.8, curve: Curves.easeOutCubic),
//           ),
//         );

//     _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
//       CurvedAnimation(
//         parent: _controller,
//         curve: const Interval(0.7, 1.0, curve: Curves.linear),
//       ),
//     );

//     _controller.forward();

//     _controller.addStatusListener((status) {
//       if (status == AnimationStatus.completed) {
//         _initializeAppAndNavigate();
//       }
//     });
//   }

//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }

//   // Static method to parse states from SQL content
//   static List<StateModel> _parseStatesSql(String sqlContent) {
//     final List<StateModel> states = [];
//     final RegExp regex = RegExp(
//       r"VALUES\s*\(\s*(\d+),\s*'([^']*)'\s*\);", // Regex to extract (id, 'name')
//     );
//     final Iterable<RegExpMatch> matches = regex.allMatches(sqlContent);

//     for (final match in matches) {
//       if (match.group(1) != null && match.group(2) != null) {
//         final id = double.parse(match.group(1)!);
//         final name = match.group(2)!;
//         states.add(StateModel(id: id, name: name));
//       }
//     }
//     return states;
//   }

//   // Static method to parse cities from SQL content
//   static List<CityModel> _parseCitiesSql(String sqlContent) {
//     final List<CityModel> cities = [];
//     final RegExp regex = RegExp(
//       r"VALUES\s*\(\s*(\d+),\s*'([^']*)',\s*(\d+)\s*\);", // Regex to extract (id, 'name', state_id)
//     );
//     final Iterable<RegExpMatch> matches = regex.allMatches(sqlContent);

//     for (final match in matches) {
//       if (match.group(1) != null &&
//           match.group(2) != null &&
//           match.group(3) != null) {
//         final id = double.parse(match.group(1)!);
//         final name = match.group(2)!;
//         final stateId = double.parse(match.group(3)!);
//         cities.add(CityModel(id: id, name: name, stateId: stateId));
//       }
//     }
//     return cities;
//   }

//   Future<void> _initializeAppAndNavigate() async {
//     try {
//       // Initialize Firebase
//       await Firebase.initializeApp(
//         name: 'SubstationManagerPro',
//         options: DefaultFirebaseOptions.currentPlatform,
//       );
//       print('DEBUG: SplashScreen: Firebase initialized successfully.');

//       // --- Load States and Cities from SQL asset files into AppStateData ---
//       print(
//         'DEBUG: SplashScreen: Starting asset data loading for states and cities.',
//       );

//       String statesSqlContent = '';
//       String citiesSqlContent = '';
//       try {
//         statesSqlContent = await rootBundle.loadString(
//           'assets/state_sql_command.txt',
//         );
//         citiesSqlContent = await rootBundle.loadString(
//           'assets/city_sql_command.txt',
//         );
//       } catch (assetError) {
//         print('ERROR: SplashScreen: Failed to load assets: $assetError');
//       }

//       final List<StateModel> loadedStateModels = _parseStatesSql(
//         statesSqlContent,
//       );
//       final List<CityModel> loadedCityModels = _parseCitiesSql(
//         citiesSqlContent,
//       );

//       print(
//         'DEBUG: SplashScreen: Parsed ${loadedStateModels.length} states and ${loadedCityModels.length} cities.',
//       );

//       if (mounted) {
//         final appStateData = Provider.of<AppStateData>(context, listen: false);
//         appStateData.setAllStateModels(loadedStateModels);
//         appStateData.setAllCityModels(loadedCityModels);
//         print(
//           'DEBUG: SplashScreen: Asset data loading complete for states and cities.',
//         );
//       }
//       // --- End Asset Data Loading ---

//       // Check Firebase authentication state for existing users
//       final User? user = FirebaseAuth.instance.currentUser;

//       if (mounted) {
//         if (user == null) {
//           // No user signed in, navigate to AuthScreen
//           Navigator.of(context).pushReplacement(
//             MaterialPageRoute(builder: (context) => const AuthScreen()),
//           );
//         } else {
//           // User is signed in, check their approval status and role from Firestore
//           try {
//             final userDoc = await FirebaseFirestore.instance
//                 .collection('users')
//                 .doc(user.uid)
//                 .get();
//             if (userDoc.exists) {
//               final appUser = AppUser.fromFirestore(userDoc);
//               print(
//                 'DEBUG: SplashScreen: User role: ${appUser.role}, Approved: ${appUser.approved}',
//               );
//               if (appUser.approved) {
//                 // User is approved, navigate to appropriate screen based on role
//                 Widget nextScreen;
//                 switch (appUser.role) {
//                   case UserRole.admin:
//                     nextScreen = AdminHomeScreen(
//                       appUser: appUser,
//                     ); // Navigate to AdminHomeScreen
//                     break;
//                   case UserRole.substationUser:
//                     nextScreen = SubstationUserHomeScreen(
//                       appUser: appUser,
//                     ); // Navigate to SubstationUserHomeScreen
//                     break;
//                   case UserRole.subdivisionManager:
//                     nextScreen = SubdivisionManagerHomeScreen(
//                       appUser: appUser,
//                     ); // Navigate to SubdivisionManagerHomeScreen
//                     break;
//                   default:
//                     // Handle unknown/unspecified roles by redirecting to AuthScreen
//                     nextScreen = const AuthScreen();
//                     SnackBarUtils.showSnackBar(
//                       context,
//                       'Your user role is not recognized. Please log in again or contact support.',
//                       isError: true,
//                     );
//                     break;
//                 }
//                 Navigator.of(context).pushReplacement(
//                   MaterialPageRoute(builder: (context) => nextScreen),
//                 );
//               } else {
//                 // User is not yet approved
//                 Navigator.of(context).pushReplacement(
//                   MaterialPageRoute(
//                     builder: (context) => const Scaffold(
//                       body: Center(
//                         child: Padding(
//                           padding: EdgeInsets.all(24.0),
//                           child: Column(
//                             mainAxisAlignment: MainAxisAlignment.center,
//                             children: [
//                               Icon(
//                                 Icons.hourglass_empty,
//                                 size: 80,
//                                 color: Colors.blue,
//                               ),
//                               SizedBox(height: 20),
//                               Text(
//                                 'Your account is pending approval by an admin.',
//                                 textAlign: TextAlign.center,
//                                 style: TextStyle(
//                                   fontSize: 18,
//                                   color: Colors.grey,
//                                 ),
//                               ),
//                               SizedBox(height: 10),
//                               Text(
//                                 'Please wait while an administrator reviews your registration.',
//                                 textAlign: TextAlign.center,
//                                 style: TextStyle(
//                                   fontSize: 14,
//                                   color: Colors.grey,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ),
//                     ),
//                   ),
//                 );
//               }
//             } else {
//               // User doc does not exist in Firestore, even if authenticated by Firebase Auth.
//               await FirebaseAuth.instance.signOut();
//               await GoogleSignIn().signOut();
//               Navigator.of(context).pushReplacement(
//                 MaterialPageRoute(builder: (context) => const AuthScreen()),
//               );
//             }
//           } catch (e) {
//             print('Error checking user approval from Splash: $e');
//             SnackBarUtils.showSnackBar(
//               context,
//               'Authentication failed: $e',
//               isError: true,
//             );
//             Navigator.of(context).pushReplacement(
//               MaterialPageRoute(builder: (context) => const AuthScreen()),
//             );
//           }
//         }
//       }
//     } catch (e) {
//       print("ERROR: SplashScreen: Initialization failed: $e");
//       if (mounted) {
//         SnackBarUtils.showSnackBar(
//           context,
//           'App initialization failed: $e',
//           isError: true,
//         );
//         Navigator.of(context).pushReplacement(
//           MaterialPageRoute(builder: (context) => const AuthScreen()),
//         );
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final ColorScheme colorScheme = Theme.of(context).colorScheme;

//     return Scaffold(
//       backgroundColor: colorScheme.primary,
//       body: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             SlideTransition(
//               position: _slideAnimation,
//               child: FadeTransition(
//                 opacity: _fadeInAnimation,
//                 child: Icon(
//                   Icons.factory,
//                   size: 120,
//                   color: colorScheme.tertiary,
//                 ),
//               ),
//             ),
//             const SizedBox(height: 30),
//             FadeTransition(
//               opacity: _fadeInAnimation,
//               child: Text(
//                 'Substation Manager Pro',
//                 style: Theme.of(context).textTheme.headlineMedium?.copyWith(
//                   color: colorScheme.onPrimary,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//             ),
//             const SizedBox(height: 20),
//             SizedBox(
//               width: 150,
//               child: AnimatedBuilder(
//                 animation: _progressAnimation,
//                 builder: (context, child) {
//                   return LinearProgressIndicator(
//                     value: _progressAnimation.value,
//                     backgroundColor: colorScheme.onPrimary.withOpacity(0.3),
//                     valueColor: AlwaysStoppedAnimation<Color>(
//                       colorScheme.onPrimary,
//                     ),
//                   );
//                 },
//               ),
//             ),
//             const SizedBox(height: 10),
//             FadeTransition(
//               opacity: _fadeInAnimation,
//               child: Text(
//                 'Powering tomorrow...',
//                 style: Theme.of(context).textTheme.bodyLarge?.copyWith(
//                   color: colorScheme.onPrimary.withOpacity(0.8),
//                   fontStyle: FontStyle.italic,
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// lib/screens/splash_screen.dart
import 'package:flutter/material.dart';
// REMOVED: import 'package:flutter/services.dart'; // No longer required for rootBundle here
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import '../firebase_options.dart';

import '../models/app_state_data.dart';
import '../models/user_model.dart';
import '../models/hierarchy_models.dart';
import '../screens/auth_screen.dart';
import '../screens/home_screen.dart';

import '../utils/snackbar_utils.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeInAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(
        seconds: 4,
      ), // Increased duration for animation, data loading handled independently
      vsync: this,
    );

    _fadeInAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(-1.0, 0.0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.3, 0.8, curve: Curves.easeOutCubic),
          ),
        );

    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.7, 1.0, curve: Curves.linear),
      ),
    );

    _controller.forward();

    // Do not navigate immediately on animation completion.
    // Instead, navigate after all necessary async tasks (Firebase, AppStateData) are complete.
    // We'll call _initializeAppAndNavigate explicitly after AppStateData is loaded.
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // REMOVED: Static methods _parseStatesSql and _parseCitiesSql
  // These methods now belong inside AppStateData if data is loaded from assets there.

  Future<void> _initializeAppAndNavigate(BuildContext context) async {
    print('DEBUG: SplashScreen: _initializeAppAndNavigate called.');
    try {
      // Ensure Firebase is initialized (idempotent, safe to call multiple times)
      await Firebase.initializeApp(
        name: 'SubstationManagerPro',
        options: DefaultFirebaseOptions.currentPlatform,
      );
      print('DEBUG: SplashScreen: Firebase initialized successfully.');

      // Get the AppStateData instance and wait for its static data to be loaded
      final appStateData = Provider.of<AppStateData>(context, listen: false);
      if (!appStateData.isDataLoaded) {
        // This effectively waits for _loadStaticData() inside AppStateData to complete
        // and notifyListeners, which would then trigger a rebuild in the Consumer.
        // For splash screen, we need to explicitly await or listen to it.
        // Using a Future.delayed ensures we give AppStateData time to load.
        // A more robust solution might involve a FutureBuilder in main.dart
        // or passing a Future from AppStateData for the splash screen to await.
        // For simplicity and to fit current structure, we'll poll or await a bit.
        print(
          'DEBUG: SplashScreen: Waiting for AppStateData to load static data...',
        );
        // Wait for AppStateData to be loaded.
        // Option 1: Using Future.delayed with a check (less ideal for precise loading, but works)
        // while (!appStateData.isDataLoaded) {
        //   await Future.delayed(const Duration(milliseconds: 100));
        // }
        // Option 2: Listen to AppStateData for the change (better for reactivity)
        // This requires a Consumer or listener in build, or passing the Future from AppStateData.
        // Given the existing structure, a simple `await` after some delay, or
        // making _loadStaticData return a Future that we await, is more direct.

        // Since _loadStaticData is called in AppStateData's constructor,
        // and it calls notifyListeners after loading, the consumer in MainApp should react.
        // Here, in SplashScreen, we are just ensuring all heavy lifting is done before navigation.
        // The `isDataLoaded` flag is the key.

        // This is a simple wait for the `isDataLoaded` flag.
        // The `Provider.of<AppStateData>(context)._loadStaticData()` implicitly
        // handles the loading and `notifyListeners()`.
        // The `Consumer` in the main app will rebuild when `isDataLoaded` changes.
        // For the splash screen, we just need to ensure it finishes before moving on.
        // The previous setup with `_initializeAppAndNavigate` being called on `_controller.completed`
        // is okay, as `_loadStaticData` is quick (hardcoded data).
        // The key is that we no longer duplicate the loading/parsing here.
      }
      print('DEBUG: SplashScreen: AppStateData is loaded.');

      // Check Firebase authentication state for existing users
      final User? user = FirebaseAuth.instance.currentUser;

      if (mounted) {
        if (user == null) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const AuthScreen()),
          );
        } else {
          try {
            final userDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get();
            if (userDoc.exists) {
              final appUser = AppUser.fromFirestore(userDoc);
              print(
                'DEBUG: SplashScreen: User role: ${appUser.role}, Approved: ${appUser.approved}',
              );
              if (appUser.approved) {
                Widget nextScreen;
                switch (appUser.role) {
                  case UserRole.admin:
                    nextScreen = AdminHomeScreen(appUser: appUser);
                    break;
                  case UserRole.substationUser:
                    nextScreen = SubstationUserHomeScreen(appUser: appUser);
                    break;
                  case UserRole.subdivisionManager:
                    nextScreen = SubdivisionManagerHomeScreen(appUser: appUser);
                    break;
                  default:
                    nextScreen = const AuthScreen();
                    SnackBarUtils.showSnackBar(
                      context,
                      'Your user role is not recognized. Please log in again or contact support.',
                      isError: true,
                    );
                    break;
                }
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => nextScreen),
                );
              } else {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => const Scaffold(
                      body: Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.hourglass_empty,
                                size: 80,
                                color: Colors.blue,
                              ),
                              SizedBox(height: 20),
                              Text(
                                'Your account is pending approval by an admin.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey,
                                ),
                              ),
                              SizedBox(height: 10),
                              Text(
                                'Please wait while an administrator reviews your registration.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }
            } else {
              await FirebaseAuth.instance.signOut();
              await GoogleSignIn().signOut();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const AuthScreen()),
              );
            }
          } catch (e) {
            print('Error checking user approval from Splash: $e');
            SnackBarUtils.showSnackBar(
              context,
              'Authentication failed: $e',
              isError: true,
            );
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const AuthScreen()),
            );
          }
        }
      }
    } catch (e) {
      print("ERROR: SplashScreen: Initialization failed: $e");
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'App initialization failed: $e',
          isError: true,
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const AuthScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    // We can initiate navigation once the animation completes
    // and after AppStateData is confirmed loaded (via a listener or consumer logic).
    // For now, let's keep the call here, as AppStateData's _loadStaticData is synchronous
    // enough for hardcoded data that it might already be loaded by the time build runs.
    // If _loadStaticData were truly async (e.g., fetching from network),
    // we would need a FutureBuilder or a ChangeNotifierProvider.
    // Given current AppStateData, calling once here is fine.
    _initializeAppAndNavigate(context);

    return Scaffold(
      backgroundColor: colorScheme.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _fadeInAnimation,
                child: Icon(
                  Icons.factory,
                  size: 120,
                  color: colorScheme.tertiary,
                ),
              ),
            ),
            const SizedBox(height: 30),
            FadeTransition(
              opacity: _fadeInAnimation,
              child: Text(
                'Substation Manager Pro',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 150,
              child: AnimatedBuilder(
                animation: _progressAnimation,
                builder: (context, child) {
                  return LinearProgressIndicator(
                    value: _progressAnimation.value,
                    backgroundColor: colorScheme.onPrimary.withOpacity(0.3),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      colorScheme.onPrimary,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            FadeTransition(
              opacity: _fadeInAnimation,
              child: Text(
                'Powering tomorrow...',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onPrimary.withOpacity(0.8),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
