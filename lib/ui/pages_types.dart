import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../services/platform/save_file.dart';
import '../services/reminders.dart';
import '../services/sound.dart';
import '../store.dart';
import 'pages_tasks.dart';
import 'theme.dart';

class TypesPage extends StatefulWidget {
  final AppStore store;
  const TypesPage({super.key, required this.store});
  @override
  State<TypesPage> createState() => _TypesPageState();
}

class _TypesPageState extends State<TypesPage> {
  final name = TextEditingController();
  int color = catPalette[0];
  String? msg;
  AppStore get store => widget.store;

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  void _add(String n, int c) {
    if (n.trim().isEmpty) {
      setState(() => msg = 'Escribe un nombre para el tipo.');
      return;
    }
    final ok = store.addCat(n.trim(), c);
    if (!ok) {
      setState(() => msg = 'Ese tipo ya existe.');
      return;
    }
    if (store.haptics) HapticFeedback.lightImpact();
    SoundEngine.instance.play('tick', volume: .7);
    final used = store.cats.values.map((x) => x.color).toSet();
    setState(() {
      msg = null;
      name.clear();
      color = catPalette.firstWhere((p) => !used.contains(p), orElse: () => catPalette[0]);
    });
  }

  Future<void> _confirmDelete(TaskType c) async {
    final count = store.tasks.values.where((t) => t.catId == c.id).length;
    final yes = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoTheme(
        data: const CupertinoThemeData(brightness: Brightness.dark),
        child: CupertinoAlertDialog(
          title: Text('¿Borrar “${c.name}”?'),
          content: Text('Sus $count tareas quedan como “Sin tipo”.'),
          actions: [
            CupertinoDialogAction(child: const Text('Cancelar'), onPressed: () => Navigator.pop(ctx, false)),
            CupertinoDialogAction(isDestructiveAction: true, child: const Text('Borrar'), onPressed: () => Navigator.pop(ctx, true)),
          ],
        ),
      ),
    );
    if (yes == true) store.deleteCat(c.id);
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(context).padding.bottom + 90),
      backgroundColor: const Color(0xE6181A38),
      content: Text(msg, style: sora(14)),
    ));
  }

  Future<void> _restore() async {
    final text = await pickTextFile();
    if (text == null || !mounted) return;
    final yes = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoTheme(
        data: const CupertinoThemeData(brightness: Brightness.dark),
        child: CupertinoAlertDialog(
          title: const Text('¿Restaurar este respaldo?'),
          content: const Text('Reemplaza todas tus tareas, tipos y tu estrella actuales.'),
          actions: [
            CupertinoDialogAction(child: const Text('Cancelar'), onPressed: () => Navigator.pop(ctx, false)),
            CupertinoDialogAction(isDestructiveAction: true, child: const Text('Restaurar'), onPressed: () => Navigator.pop(ctx, true)),
          ],
        ),
      ),
    );
    if (yes != true || !mounted) return;
    _toast(store.importBackup(text) ? 'Listo, respaldo restaurado.' : 'Ese archivo no es un respaldo de Mi Estrella.');
  }

  @override
  Widget build(BuildContext context) {
    final cats = store.sortedCats;
    final names = cats.map((c) => c.name.toLowerCase()).toSet();
    final sugg = catSuggestions.where((s) => !names.contains(s.$1.toLowerCase())).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 170),
      children: [
        Text('Tipos de tareas', style: sora(28, w: FontWeight.w600, ls: -.5)),
        const SizedBox(height: 14),
        Glass(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('NUEVO TIPO', style: label()),
            const SizedBox(height: 8),
            GlassField(controller: name, hint: 'Ej. Universidad', onSubmit: (v) => _add(v, color)),
            if (msg != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(msg!, style: sora(13, color: C.hot))),
            const SizedBox(height: 14),
            Wrap(spacing: 14, runSpacing: 12, children: [
              for (final p in catPalette)
                GestureDetector(
                  onTap: () => setState(() => color = p),
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color == p ? Colors.white : Colors.transparent, width: 2)),
                    child: Orb(color: Color(p), size: 34),
                  ),
                ),
            ]),
            const SizedBox(height: 16),
            Pill('Crear tipo', primary: true, onTap: () => _add(name.text, color)),
            if (sugg.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('IDEAS RÁPIDAS', style: label()),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [for (final s in sugg) Chip2(s.$1, dot: Color(s.$2), onTap: () => _add(s.$1, s.$2))]),
            ],
          ]),
        ),
        const SizedBox(height: 14),
        if (cats.isEmpty)
          Glass(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Aún no tienes tipos.', style: sora(19, w: FontWeight.w600)),
              const SizedBox(height: 8),
              Text('Cada tipo es un planeta que gira alrededor de tu estrella. Así ves qué área de tu vida te está cargando más.', style: sora(14, color: C.muted, height: 1.45)),
            ]),
          )
        else
          for (final c in cats)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Glass(
                padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
                child: Row(children: [
                  Orb(color: Color(c.color), size: 30),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(c.name, style: sora(17, w: FontWeight.w500)),
                      Text(
                        '${store.tasks.values.where((t) => t.catId == c.id && t.isVisible).length} pendientes · ${store.tasks.values.where((t) => t.catId == c.id && t.completedAt != null).length} hechas',
                        style: mono(12, color: C.muted),
                      ),
                    ]),
                  ),
                  IconButton(onPressed: () => _confirmDelete(c), icon: const Icon(Icons.close_rounded, color: C.faint), tooltip: 'Borrar tipo'),
                ]),
              ),
            ),
        const SizedBox(height: 14),
        Text('Ajustes', style: sora(28, w: FontWeight.w600, ls: -.5)),
        const SizedBox(height: 14),
        Glass(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('AGUANTE DE TU ESTRELLA', style: label()),
            const SizedBox(height: 10),
            Row(children: [
              for (final (v, n) in const [(15, 'Chica'), (20, 'Normal'), (30, 'Grande')]) ...[
                if (v != 15) const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () => store.setCap(v),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: store.star.cap == v ? Colors.white.withValues(alpha: .92) : Colors.white.withValues(alpha: .05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: store.star.cap == v ? Colors.transparent : C.line),
                      ),
                      child: Column(children: [
                        Text(n, style: sora(15, w: FontWeight.w600, color: store.star.cap == v ? C.ink : C.text)),
                        Text('$v de carga', style: sora(11, color: store.star.cap == v ? C.ink : C.muted)),
                      ]),
                    ),
                  ),
                ),
              ],
            ]),
            const SizedBox(height: 8),
            Text('Cuánta carga aguanta antes de explotar. Una tarea Grande pesa 3, una Monstruo pesa 5.', style: sora(13, color: C.faint, height: 1.4)),
            const SizedBox(height: 14),
            Row(children: [Expanded(child: Text('Sonido', style: sora(16))), Toggle(value: store.sound, onChanged: store.setSound)]),
            if (!kIsWeb) ...[
              Row(children: [Expanded(child: Text('Vibración', style: sora(16))), Toggle(value: store.haptics, onChanged: store.setHaptics)]),
              const SizedBox(height: 8),
              Pill('Permitir notificaciones', small: true, color: C.sky, icon: Icons.notifications_active_outlined, onTap: () async {
                final ok = await Reminders.instance.requestPermission();
                if (!context.mounted) return;
                _toast(ok ? 'Listo. Te avisaré antes de cada fecha límite.' : 'Actívalas en Ajustes del iPhone › Mi Estrella › Notificaciones.');
              }),
            ],
          ]),
        ),
        if (kIsWeb) ...[
          const SizedBox(height: 12),
          Glass(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('RESPALDO', style: label()),
              const SizedBox(height: 8),
              Text('Tus datos viven en este iPhone. Guarda un respaldo de vez en cuando en Archivos o iCloud; si borras la app del inicio, se borran.', style: sora(13, color: C.faint, height: 1.4)),
              const SizedBox(height: 12),
              Wrap(spacing: 10, runSpacing: 10, children: [
                Pill('Guardar respaldo', small: true, color: C.sky, icon: Icons.ios_share_rounded, onTap: () async {
                  final d = DateTime.now();
                  final name = 'mi-estrella-${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}.json';
                  final ok = await saveTextFile(name, 'application/json', store.exportBackup(), share: true);
                  if (!ok && context.mounted) _toast('No se pudo guardar el respaldo.');
                }),
                Pill('Restaurar', small: true, icon: Icons.restore_rounded, onTap: _restore),
              ]),
            ]),
          ),
        ],
      ],
    );
  }
}
