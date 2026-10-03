import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/grid_erp_app.dart';
import 'core/cache/local_cache.dart';
import 'core/supabase/supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabasePublishableKey,
    authOptions: const FlutterAuthClientOptions(authFlowType: AuthFlowType.pkce),
  );
  final cache = await LocalCache.open();

  runApp(ProviderScope(
    overrides: [localCacheProvider.overrideWithValue(cache)],
    child: const GridErpApp(),
  ));
}
