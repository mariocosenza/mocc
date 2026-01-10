// DO NOT EDIT. This is code generated via package:easy_localization/generate.dart

// ignore_for_file: prefer_single_quotes, avoid_renaming_method_parameters, constant_identifier_names

import 'dart:ui';

import 'package:easy_localization/easy_localization.dart' show AssetLoader;

class CodegenLoader extends AssetLoader{
  const CodegenLoader();

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) {
    return Future.value(mapLocales[locale.toString()]);
  }

  static const Map<String,dynamic> _en = {
  "hello": "Hello!",
  "welcome": "Welcome to our app, {name}!",
  "items_count": {
    "zero": "No items",
    "one": "1 item",
    "other": "{} items"
  }
};
static const Map<String,dynamic> _it = {
  "hello": "Ciao!",
  "welcome": "Benvenuto nella nostra app, {name}!",
  "items_count": {
    "zero": "0 elementi",
    "one": "1 elemento",
    "other": "{} elementi"
  }
};
static const Map<String, Map<String,dynamic>> mapLocales = {"en": _en, "it": _it};
}
