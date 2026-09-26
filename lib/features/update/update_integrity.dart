import 'dart:io';
import 'package:crypto/crypto.dart';

Future<String> sha256File(File file) => sha256Stream(file.openRead());
Future<String> sha256Stream(Stream<List<int>> stream) async =>
    (await sha256.bind(stream).first).toString();
