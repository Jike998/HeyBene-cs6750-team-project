import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/fusion_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const FusionApp());
}
