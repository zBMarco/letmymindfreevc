import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../services/sound.dart';
import '../store.dart';
import 'pages_tasks.dart';
import 'theme.dart';

Future<void> showTaskSheet(BuildContext context, AppStore store, {Task? edit}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x80020310),
    builder: (_) => _TaskSheet(store: store, edit: edit),
  );
}

class _TaskSheet extends StatefulWidget {
  final AppStore store;
  final Task? edit;
  const _TaskSheet({required this.store, this.edit});
  @override
  State<_TaskSheet> createState() => _TaskSheetState();
}

class _TaskSheetState extends State<_TaskSheet> {
  late final title = TextEditingController(text: widget.edit?.title ?? '');
  late final notes = TextEditingController(text: widget.edit?.notes ?? '');
  late String? catId = widget.edit?.catId ?? (widget.store.lastCat != null && widget.store.cats.containsKey(widget.store.lastCat) ? widget.store.lastCat : null);
  late int size = widget.edit?.size ?? 2;
  late bool hasDue = widget.edit?.due != null;
  late DateTime due = widget.edit?.due != null ? DateTime.fromMillisecondsSinceEpoch(widget.edit!.due!) : _defaultDue();
  late Repeat repeat = widget.edit?.repeat ?? Repeat.none;
  late bool remind = widget.edit?.remind ?? true;
  String? error;

  static DateTime _defaultDue() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day + 1, 10);
  }

  @override
  void dispose() {
    title.dispose();
    notes.dispose();
    super.dispose();
  }

  void _tap() {
    if (widget.store.haptics) HapticFeedback.selectionClick();
  }

  void _save() {
    final text = title.text.trim();
    if (text.isEmpty) {
      setState(() => error = 'Escribe qué tienes que hacer.');
      return;
    }
    final s = widget.store;
    if (widget.edit != null) {
      s.updateTask(widget.edit!.id, title: text, catId: catId, size: size, due: hasDue ? due.millisecondsSinceEpoch : null, repeat: repeat, notes: notes.text, remind: remind);
    } else {
      s.addTask(title: text, catId: catId, size: size, due: hasDue ? due.millisecondsSinceEpoch : null, repeat: repeat, notes: notes.text, remind: remind);
      SoundEngine.instance.play('add', volume: .8);
      if (s.haptics) HapticFeedback.lightImpact();
    }
    Navigator.of(context).pop();
  }

  Future<void> _pickDate() async {
    var picked = due;
    await showCupertinoModalPopup(
      context: context,
      builder: (ctx) => Container(
        height: 320,
        padding: const EdgeInsets.only(top: 8),
        decoration: const BoxDecoration(color: Color(0xFF14162E), borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: SafeArea(
          top: false,
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              CupertinoButton(child: Text('Listo', style: sora(16, w: FontWeight.w600, color: Theme.of(context).colorScheme.primary)), onPressed: () => Navigator.of(ctx).pop()),
            ]),
            Expanded(
              child: CupertinoTheme(
                data: const CupertinoThemeData(brightness: Brightness.dark),
                child: CupertinoDatePicker(
                  initialDateTime: due,
                  minimumDate: DateTime.now().subtract(const Duration(days: 1)),
                  use24hFormat: true,
                  onDateTimeChanged: (d) => picked = d,
                ),
              ),
            ),
          ]),
        ),
      ),
    );
    setState(() => due = picked);
  }

  @override
  Widget build(BuildContext context) {
    final cats = widget.store.sortedCats;
    final pct = widget.store.pctOf(size.toDouble());
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .9),
            decoration: const BoxDecoration(
              color: Color(0xC7141630),
              border: Border(top: BorderSide(color: C.line2)),
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(18, 10, 18, 22 + MediaQuery.of(context).padding.bottom),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: C.line2, borderRadius: BorderRadius.circular(99)))),
                const SizedBox(height: 12),
                Text(widget.edit != null ? 'Editar' : '¿Qué te pesa?', style: sora(24, w: FontWeight.w600)),
                const SizedBox(height: 14),
                GlassField(controller: title, hint: 'Ej. Pagar la tarjeta', onSubmit: (_) => _save()),
                if (error != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(error!, style: sora(13, color: C.hot))),
                const SizedBox(height: 18),
                Text('TIPO', style: label()),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  Chip2('Sin tipo', on: catId == null, onTap: () {
                    _tap();
                    setState(() => catId = null);
                  }),
                  for (final c in cats)
                    Chip2(c.name, on: catId == c.id, dot: Color(c.color), onTap: () {
                      _tap();
                      setState(() => catId = c.id);
                    }),
                ]),
                if (cats.isEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Crea tipos en la pestaña Tipos para agruparlas.', style: sora(13, color: C.faint))),
                const SizedBox(height: 18),
                Text('TAMAÑO · CUÁNTO TE ESTRESA', style: label()),
                const SizedBox(height: 8),
                Row(children: [
                  for (var w = 1; w <= 5; w++) ...[
                    if (w > 1) const SizedBox(width: 8),
                    Expanded(
                      child: _PickBox(
                        on: size == w,
                        top: '$w',
                        bottom: sizeNames[w],
                        onTap: () {
                          _tap();
                          setState(() => size = w);
                        },
                      ),
                    ),
                  ],
                ]),
                const SizedBox(height: 8),
                Text('${sizeHints[size]} · +$pct% de carga', style: sora(13, color: C.muted)),
                const SizedBox(height: 18),
                _Opt(children: [
                  Row(children: [
                    Expanded(child: Text('Fecha límite', style: sora(16, w: FontWeight.w500))),
                    Toggle(value: hasDue, onChanged: (v) {
                      _tap();
                      setState(() => hasDue = v);
                    }),
                  ]),
                  if (hasDue) ...[
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: _pickDate,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .06), borderRadius: BorderRadius.circular(16), border: Border.all(color: C.line)),
                        child: Row(children: [
                          const Icon(Icons.event_rounded, size: 18, color: C.muted),
                          const SizedBox(width: 10),
                          Text(fmtWhen(due.millisecondsSinceEpoch), style: mono(15)),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: Text('Recordarme', style: sora(15))),
                      Toggle(value: remind, onChanged: (v) {
                        _tap();
                        setState(() => remind = v);
                      }),
                    ]),
                    Text('Notificaciones 1 día, 3 h, 1 h y 30 min antes, y al vencer. Si se vence, pesa el doble.', style: sora(12.5, color: C.faint, height: 1.4)),
                  ],
                ]),
                const SizedBox(height: 12),
                _Opt(children: [
                  Text('Repetir', style: sora(16, w: FontWeight.w500)),
                  const SizedBox(height: 10),
                  Row(children: [
                    for (final r in Repeat.values) ...[
                      if (r != Repeat.none) const SizedBox(width: 8),
                      Expanded(
                        child: _PickBox(
                          on: repeat == r,
                          bottom: repeatNames[r]!,
                          onTap: () {
                            _tap();
                            setState(() => repeat = r);
                          },
                        ),
                      ),
                    ],
                  ]),
                ]),
                const SizedBox(height: 18),
                Text('NOTAS (OPCIONAL)', style: label()),
                const SizedBox(height: 8),
                GlassField(controller: notes, hint: 'Números, links, detalles', lines: 3),
                const SizedBox(height: 20),
                SizedBox(width: double.infinity, child: Center(child: Pill(widget.edit != null ? 'Guardar cambios' : 'Agregar', primary: true, onTap: _save))),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _Opt extends StatelessWidget {
  final List<Widget> children;
  const _Opt({required this.children});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 12),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .04), borderRadius: BorderRadius.circular(16), border: Border.all(color: C.line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );
}

class _PickBox extends StatelessWidget {
  final bool on;
  final String? top;
  final String bottom;
  final VoidCallback onTap;
  const _PickBox({required this.on, this.top, required this.bottom, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final star = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: on ? Colors.white.withValues(alpha: .92) : Colors.white.withValues(alpha: .05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: on ? Colors.transparent : C.line),
          boxShadow: on ? [BoxShadow(color: star.withValues(alpha: .35), blurRadius: 20)] : null,
        ),
        child: Column(children: [
          if (top != null) Text(top!, style: mono(15, w: FontWeight.w500, color: on ? C.ink : C.text)),
          if (top != null) const SizedBox(height: 3),
          FittedBox(child: Text(bottom, style: sora(10, w: FontWeight.w500, color: on ? C.ink : C.muted))),
        ]),
      ),
    );
  }
}
