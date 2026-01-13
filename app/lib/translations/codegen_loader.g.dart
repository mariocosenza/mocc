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
  "login": "Login with Microsoft",
  "login_title": "Login with a Social",
  "fridge": "Fridge",
  "shopping": "Shopping",
  "step1_title": "Plan meals with what you already have",
  "step1_description": "MOCC turns your inventory into optimized meal options—less waste, better balance, smarter choices.",
  "step2_title": "Import groceries from receipts",
  "step2_description": "Snap a receipt photo: MOCC extracts items and updates your inventory automatically.",
  "step3_title": "Climb the leaderboard",
  "step3_description": "Earn points from your activity in MOCC, compare with other users, and aim for the top of the leaderboard.",
  "items_count": {
    "zero": "No items",
    "one": "1 item",
    "other": "{} items"
  }
};
static const Map<String,dynamic> _it = {
  "hello": "Ciao!",
  "login": "Accedi con Microsoft",
  "welcome": "Benvenuto nella nostra app, {name}!",
  "login_title": "Accedi con un social",
  "fridge": "Frigo",
  "shopping": "Carrello",
  "step1_title": "Pianifica i pasti con ciò che hai",
  "step1_description": "MOCC trasforma il tuo inventario in proposte ottimizzate: meno sprechi, più equilibrio e scelte guidate.",
  "step2_title": "Importa la spesa dallo scontrino",
  "step2_description": "Scatta una foto allo scontrino: MOCC riconosce i prodotti e aggiorna automaticamente l’inventario.",
  "step3_title": "Raggiungi i tuoi obiettivi",
  "step3_description": "Guadagna punti con le tue attività su MOCC, confrontati con gli altri utenti e punta al top della leaderboard.",
  "items_count": {
    "zero": "0 elementi",
    "one": "1 elemento",
    "other": "{} elementi"
  }
};
static const Map<String, Map<String,dynamic>> mapLocales = {"en": _en, "it": _it};
}
