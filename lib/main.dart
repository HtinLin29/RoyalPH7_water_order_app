import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dotenv/dotenv.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'providers/auth_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/connectivity_provider.dart';

Map<String, String> _parseEnvString(String contents) {
  final result = <String, String>{};
  for (final line in contents.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final eq = trimmed.indexOf('=');
    if (eq <= 0) continue;
    final key = trimmed.substring(0, eq).trim();
    var value = trimmed.substring(eq + 1).trim();
    if ((value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'"))) {
      value = value.substring(1, value.length - 1);
    }
    result[key] = value;
  }
  return result;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final env = DotEnv(includePlatformEnvironment: !kIsWeb);
  try {
    final envContents = await rootBundle.loadString('.env');
    env.addAll(_parseEnvString(envContents));
  } catch (_) {
    if (!kIsWeb) {
      env.load(['.env']);
    }
  }

  await Supabase.initialize(
    url: env['SUPABASE_URL'] ?? '',
    publishableKey: env['SUPABASE_ANON_KEY'] ?? '',
  );

  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
      ],
      child: const RoyalPh7App(),
    ),
  );
}
