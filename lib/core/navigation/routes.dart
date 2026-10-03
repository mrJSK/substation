import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

abstract final class Routes {
  static const login = '/login';
  static const home = '/home';
  static const logsheet = '/logsheet';
  static const workOrders = '/work-orders';
  static const ptw = '/ptw';
  static const defects = '/defects';

  static String app(String code) => '$home/app/$code';
}

/// Micro-apps that have their own bottom-navigation tab.
const tabAppRoutes = <String, String>{
  'OP01': Routes.logsheet,
  'MT01': Routes.workOrders,
  'PT01': Routes.ptw,
  'MT02': Routes.defects,
};

/// Opens a micro-app by its T-code, like SAP's command field.
void openMicroApp(BuildContext context, String code) {
  final normalized = code.trim().toUpperCase();
  context.go(tabAppRoutes[normalized] ?? Routes.app(normalized));
}
