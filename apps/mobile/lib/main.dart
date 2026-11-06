import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'locale_controller.dart';
import 'main_app.dart';
import 'online/online_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(ShaxmatApp(localeController: LocaleController(prefs), onlineClient: OnlineClient(prefs: prefs)));
}
