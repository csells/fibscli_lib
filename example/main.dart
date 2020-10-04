import 'dart:convert';
import 'dart:io';
import 'package:fibscli_lib/fibscli_lib.dart';
// import 'package:logging/logging.dart';

void main() {
  // Logger.root.level = Level.ALL; // defaults to Level.INFO
  // Logger.root.onRecord.listen((record) {
  //   print('${record.level.name}: ${record.time}: ${record.message}');
  // });

  final proxy = 'localhost';
  final port = 8080;
  final user = 'chris';
  final pass = 'chris1';

  final conn = FibsConnection(proxy, port);
  // conn.stream.listen((cm) => print(cm));
  conn.login(user, pass);

  stdin.transform(utf8.decoder).transform(LineSplitter()).listen((cmd) {
    print('connected: ${conn.connected}');
    if (conn.connected) {
      conn.send(cmd);
    } else {
      exit(0);
    }
  });
}
