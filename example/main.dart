// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'package:fibscli_lib/fibscli_lib.dart';

void main() async {
  const proxy = '127.0.0.1';
  const port = 8080;
  const user = 'chris';
  const pass = 'chris1';

  final conn = FibsConnection(proxy, port);
  conn.stream.listen(print, onDone: () => exit(0));
  final cookie = await conn.login(user, pass);
  if (cookie != FibsCookie.CLIP_WELCOME) {
    print('error: login failed: $cookie');
    exit(-1);
  }

  stdin.transform(utf8.decoder).transform(const LineSplitter()).listen((cmd) {
    print('connected: ${conn.connected}');
    assert(conn.connected);
    conn.send(cmd);
  });
}
