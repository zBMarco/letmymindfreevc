/// Native builds never call this: the iPhone app uses the native calendar sheet.
Future<bool> saveTextFile(String name, String mime, String text, {bool share = false}) async => false;

Future<String?> pickTextFile() async => null;
