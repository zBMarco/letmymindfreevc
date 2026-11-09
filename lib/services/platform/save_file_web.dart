import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Hands a text file to the browser. On iPhone, Safari opens an .ics file
/// straight into "Add to Calendar".
Future<bool> saveTextFile(String name, String mime, String text, {bool share = false}) async {
  try {
    final bytes = utf8.encode(text);
    final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mime));
    final file = web.File([blob].toJS, name, web.FilePropertyBag(type: mime));
    final nav = web.window.navigator;
    // Share sheet lets a backup go to Files/iCloud from the home-screen app.
    final data = web.ShareData(files: [file].toJS);
    if (share && nav.canShare(data)) {
      await nav.share(data).toDart;
      return true;
    }
    final url = web.URL.createObjectURL(blob);
    final a = web.HTMLAnchorElement()
      ..href = url
      ..download = name;
    web.document.body!.append(a);
    a.click();
    a.remove();
    Future.delayed(const Duration(seconds: 30), () => web.URL.revokeObjectURL(url));
    return true;
  } catch (_) {
    return false;
  }
}

/// Lets the person choose a file (e.g. a backup from Files/iCloud) and returns its text.
Future<String?> pickTextFile() {
  final done = Completer<String?>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = '.json,application/json,text/plain';
  input.onchange = ((web.Event _) {
    final f = input.files?.item(0);
    if (f == null) {
      done.complete(null);
      return;
    }
    f.text().toDart.then((t) => done.complete(t.toDart), onError: (_) => done.complete(null));
  }).toJS;
  input.click();
  return done.future;
}
