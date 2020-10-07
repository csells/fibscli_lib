import 'dart:async';
import 'package:fibscli_lib/src/cookie_monster.dart';
import 'package:socket_io_client/socket_io_client.dart' as ws;

enum _LoginState {
  prelogin,
  sentcred,
  postlogin,
}

class FibsConnection {
  static final _fibsVersion = '1008';
  final String proxy;
  final int port;
  final _streamController = StreamController<CookieMessage>();
  ws.Socket _socket;
  final _monster = CookieMonster();
  Completer<FibsCookie> _loginCompleter;
  _LoginState _loginState;

  FibsConnection(this.proxy, this.port);

  bool get connected => _socket != null;
  Stream<CookieMessage> get stream => _streamController.stream;

  Future<FibsCookie> login(String user, String pass) {
    assert(!connected);

    _socket = ws.io('ws://$proxy:$port', <String, dynamic>{
      'transports': ['websocket'],
      'forceNew': true,
    });

    _socket.on('connect', (data) {
      _receive('connect', data);
      _socket.emit('stream', '\n');
    });

    _socket.on('stream', (bytes) async {
      final s = String.fromCharCodes(bytes);
      final cms = _receive('stream', s).toList();

      switch (_loginState) {
        case _LoginState.prelogin:
          // wait for login prompt
          final expecting = [FibsCookie.FIBS_LoginPrompt];
          final found = cms.map((cm) => cm.cookie).where((c) => expecting.contains(c)).toList();
          if (found.isEmpty) return; // wait for next batch

          // send credentials
          send('login flutter-fibs $_fibsVersion $user $pass');
          _loginState = _LoginState.sentcred;
          break;

        case _LoginState.sentcred:
          // wait for login prompt
          final expecting = [FibsCookie.CLIP_WELCOME, FibsCookie.FIBS_FailedLogin, FibsCookie.FIBS_LoginPrompt];
          final found = cms.map((cm) => cm.cookie).where((c) => expecting.contains(c)).toList();
          if (found.isEmpty) return; // wait for next batch

          // complete the login
          final cookie = found.single;
          _loginCompleter.complete(cookie);
          _loginCompleter = null;
          _loginState = _LoginState.postlogin;
          break;

        case _LoginState.postlogin:
          break;
      }
    });

    _socket.on('status', (status) {
      _receive('status', status);
      if (status == 'Telnet disconnected.\n') close();
    });

    _loginState = _LoginState.prelogin;
    _loginCompleter = Completer<FibsCookie>();
    return _loginCompleter.future;
  }

  void send(String s) {
    assert(connected);
    assert(!s.endsWith('\n'));
    print('SEND: $s');
    _socket.emit('stream', '$s\n');
  }

  Iterable<CookieMessage> _receive(String event, String message) sync* {
    assert(event == 'stream');
    print('RECEIVE: $message');

    final lines = message.split('\n');
    for (final line in lines) {
      final cm = _monster.eatCookie(line.replaceAll('\r', ''));
      assert(cm != null);
      _streamController.add(cm);
      yield cm;
    }
  }

  void close() {
    if (_socket != null) {
      _socket.close();
      _socket = null;
      _streamController.done;
    }
  }
}
