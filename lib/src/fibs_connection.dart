import 'dart:async';
import 'package:fibscli_lib/src/cookie_monster.dart';
import 'package:socket_io_client/socket_io_client.dart' as ws;

class FibsConnection {
  static final _fibsVersion = '1008';
  final String proxy;
  final int port;
  final _controller = StreamController<CookieMessage>();
  ws.Socket _socket;
  final _monster = CookieMonster();
  FibsConnection(this.proxy, this.port);

  bool get connected => _socket != null;
  Stream<CookieMessage> get stream => _controller.stream;

  void login(String user, String pass) {
    assert(!connected);

    _socket = ws.io('ws://$proxy:$port', <String, dynamic>{
      'transports': ['websocket'],
      'forceNew': true,
    });

    _socket.on('connect', (data) {
      _receive('connect', data);
      _socket.emit('stream', '\n');
    });

    _socket.on('stream', (bytes) {
      final s = String.fromCharCodes(bytes);
      final cms = _receive('stream', s).toList();
      if (cms.any((cm) => cm.cookie == FibsCookie.FIBS_LoginPrompt)) {
        send('login flutter-fibs $_fibsVersion $user $pass');
      }
    });

    _socket.on('status', (status) {
      _receive('status', status);
      if (status == 'Telnet disconnected.\n') close();
    });
  }

  void send(String s) {
    assert(connected);
    assert(!s.endsWith('\n'));
    // Logger.root.log(Level.FINE, 'SEND: $s');
    print('SEND: $s');
    _socket.emit('stream', '$s\n');
  }

  Iterable<CookieMessage> _receive(String event, String message) sync* {
    if (event != 'stream') return;
    print('RECEIVE: $message');
    final lines = message.split('\n');
    for (final line in lines) {
      final cm = _monster.eatCookie(line.replaceAll('\r', ''));
      assert(cm != null);
      _controller.add(cm);
      yield cm;
    }
  }

  void close() {
    if (_socket != null) {
      _socket.close();
      _socket = null;
      _controller.done;
    }
  }
}
