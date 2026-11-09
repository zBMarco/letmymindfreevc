import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/reminders.dart';
import 'services/sound.dart';
import 'star/star_fx.dart';
import 'store.dart';
import 'ui/shell.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  if (kIsWeb && Uri.base.queryParameters['icon'] == '1') {
    // Browser-only helper used to render the app icon from the real shader.
    await StarFx.loadShader();
    StarFx.instance.sync(load: .45, nebula: false, seed: 0);
    runApp(const MaterialApp(debugShowCheckedModeBanner: false, home: ColoredBox(color: Color(0xFF04050D), child: StarView(detail: 1, zoom: 1.75))));
    return;
  }
  final store = AppStore();
  await Future.wait([
    store.init(),
    StarFx.loadShader(),
    Reminders.instance.init(),
  ]);
  SoundEngine.instance.enabled = store.sound;
  SoundEngine.instance.init(); // synthesizes sounds in the background
  runApp(MiEstrellaApp(store: store));
}

class MiEstrellaApp extends StatelessWidget {
  final AppStore store;
  const MiEstrellaApp({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final accent = Color(store.level.color);
        return MaterialApp(
          title: 'Mi Estrella',
          debugShowCheckedModeBanner: false,
          theme: buildTheme().copyWith(colorScheme: ColorScheme.dark(primary: accent, surface: C.bg)),
          home: Shell(store: store),
        );
      },
    );
  }
}
