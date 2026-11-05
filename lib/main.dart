import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app/app.dart';
import 'app/nav.dart';
import 'data/store.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = AppStore();
  await Future.wait([store.hydrate(), NotificationService.instance.init()]);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: store),
        ChangeNotifierProvider(create: (_) => TabNav()),
      ],
      child: const MoneyEntriApp(),
    ),
  );
}
