import 'dart:io';
import 'package:flutter/services.dart';

Future<ByteData> _font(String weight) async {
  final bytes = await File(
    'test/fixtures/fonts/Roboto-$weight.ttf',
  ).readAsBytes();
  return ByteData.sublistView(bytes);
}

Future<void> loadAppFonts() async {
  final roboto = FontLoader('Roboto')
    ..addFont(_font('Regular'))
    ..addFont(_font('Medium'))
    ..addFont(_font('Bold'));
  final icons = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await Future.wait([roboto.load(), icons.load()]);
}
