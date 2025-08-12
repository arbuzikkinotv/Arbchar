
// Arbchar — Flutter Bluetooth Chat (simplified)
// - Dark theme
// - Scan / Connect via flutter_bluetooth_serial
// - Chat screen with send/receive
// - Local history storage using sqflite
// - Basic AES encryption (key generated once and stored in SharedPreferences)
//
// NOTE: This code is a project skeleton. You must test on real Android devices.
//

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as encrypt_pkg;
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(ArbcharApp());
}

class ArbcharApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Arbchar',
      theme: ThemeData.dark().copyWith(
        colorScheme: ThemeData.dark().colorScheme.copyWith(
              primary: Colors.tealAccent,
              secondary: Colors.teal,
            ),
      ),
      home: HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// Simple message model for DB
class MessageModel {
  final int? id;
  final String peerAddress;
  final String text; // encrypted text stored
  final int isMe;
  final int timestamp;

  MessageModel({
    this.id,
    required this.peerAddress,
    required this.text,
    required this.isMe,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'peer': peerAddress,
      'text': text,
      'isMe': isMe,
      'ts': timestamp,
    };
  }

  static MessageModel fromMap(Map<String, dynamic> m) {
    return MessageModel(
      id: m['id'] as int?,
      peerAddress: m['peer'] as String,
      text: m['text'] as String,
      isMe: m['isMe'] as int,
      timestamp: m['ts'] as int,
    );
  }
}

class DBHelper {
  Database? _db;

  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'arbchar.db');
    _db = await openDatabase(path, version: 1, onCreate: (db, v) async {
      await db.execute('''
        CREATE TABLE messages (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          peer TEXT,
          text TEXT,
          isMe INTEGER,
          ts INTEGER
        )
      ''');
    });
  }

  Future<int> insertMessage(MessageModel m) async {
    return await _db!.insert('messages', m.toMap());
  }

  Future<List<MessageModel>> getMessagesForPeer(String peer) async {
    final res = await _db!.query('messages', where: 'peer = ?', whereArgs: [peer], orderBy: 'ts ASC');
    return res.map((e) => MessageModel.fromMap(e)).toList();
  }
}

class CryptoHelper {
  static const _keyPref = 'arbchar_aes_key';

  // Generate or load a 32-byte key stored in SharedPreferences (base64)
  static Future<encrypt_pkg.Key> loadOrCreateKey() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_keyPref);
    if (existing != null) {
      final bytes = base64Decode(existing);
      return encrypt_pkg.Key(Uint8List.fromList(bytes));
    } else {
      final key = List<int>.generate(32, (i) => DateTime.now().millisecondsSinceEpoch.remainder(256) ^ i);
      final b = Uint8List.fromList(key);
      prefs.setString(_keyPref, base64Encode(b));
      return encrypt_pkg.Key(b);
    }
  }

  static Future<String> encryptText(String plain, encrypt_pkg.Key key) async {
    final iv = encrypt_pkg.IV.fromLength(16);
    final encrypter = encrypt_pkg.Encrypter(encrypt_pkg.AES(key, mode: encrypt_pkg.AESMode.cbc));
    final encrypted = encrypter.encrypt(plain, iv: iv);
    return encrypted.base64;
  }

  static Future<String> decryptText(String cipherBase64, encrypt_pkg.Key key) async {
    final iv = encrypt_pkg.IV.fromLength(16);
    final encrypter = encrypt_pkg.Encrypter(encrypt_pkg.AES(key, mode: encrypt_pkg.AESMode.cbc));
    try {
      final decrypted = encrypter.decrypt64(cipherBase64, iv: iv);
      return decrypted;
    } catch (e) {
      return '[decrypt error]';
    }
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  BluetoothState _bluetoothState = BluetoothState.UNKNOWN;
  List<BluetoothDevice> _devices = [];
  bool _discovering = false;
  final DBHelper _db = DBHelper();
  encrypt_pkg.Key? _aesKey;

  @override
  void initState() {
    super.initState();
    _initAll();
  }

  Future<void> _initAll() async {
    await _db.init();
    final k = await CryptoHelper.loadOrCreateKey();
    setState(() => _aesKey = k);

    FlutterBluetoothSerial.instance.state.then((s) {
      setState(() => _bluetoothState = s);
    });
    FlutterBluetoothSerial.instance.onStateChanged().listen((s) {
      setState(() => _bluetoothState = s);
    });
    _loadBonded();
  }

  Future<void> _loadBonded() async {
    try {
      final bonded = await FlutterBluetoothSerial.instance.getBondedDevices();
      setState(() => _devices = bonded);
    } catch (e) {
      debugPrint('Error loading bonded: $e');
    }
  }

  Future<void> _startDiscovery() async {
    await _requestPermissions();
    setState(() {
      _discovering = true;
      _devices = [];
    });
    FlutterBluetoothSerial.instance.startDiscovery().listen((r) {
      final d = r.device;
      if (!_devices.any((x) => x.address == d.address)) {
        setState(() => _devices.add(d));
      }
    }).onDone(() {
      setState(() => _discovering = false);
    });
  }

  Future<void> _requestPermissions() async {
    // request location as a baseline (Android <12)
    if (!await Permission.location.isGranted) {
      await Permission.location.request();
    }
    // Note: For Android 12+ you may need to request specific BLUETOOTH_SCAN and BLUETOOTH_CONNECT using permission_handler 10+
  }

  Widget _deviceTile(BluetoothDevice d) {
    return ListTile(
      leading: Icon(Icons.devices),
      title: Text(d.name ?? 'Unknown'),
      subtitle: Text(d.address ?? ''),
      trailing: ElevatedButton(
        child: Text('Connect'),
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => ChatPage(device: d, db: _db, aesKey: _aesKey)));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Arbchar — Devices')),
      body: Column(
        children: [
          ListTile(
            title: Text('Bluetooth: $_bluetoothState'),
            trailing: IconButton(icon: Icon(Icons.refresh), onPressed: _loadBonded),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                ElevatedButton(
                  onPressed: _discovering ? null : _startDiscovery,
                  child: Text(_discovering ? 'Scanning...' : 'Scan'),
                ),
                SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () async {
                    final enabled = await FlutterBluetoothSerial.instance.isEnabled ?? false;
                    if (!enabled) {
                      await FlutterBluetoothSerial.instance.requestEnable();
                    } else {
                      await FlutterBluetoothSerial.instance.requestDisable();
                    }
                    _loadBonded();
                  },
                  child: Text('Toggle BT'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _devices.length,
              itemBuilder: (c, i) => _deviceTile(_devices[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class ChatPage extends StatefulWidget {
  final BluetoothDevice device;
  final DBHelper db;
  final encrypt_pkg.Key? aesKey;

  ChatPage({required this.device, required this.db, required this.aesKey});

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  BluetoothConnection? _connection;
  bool _connecting = true;
  bool get isConnected => _connection != null && _connection!.isConnected;
  List<_Message> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _initConnection();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final msgs = await widget.db.getMessagesForPeer(widget.device.address!);
    final key = widget.aesKey;
    if (key != null) {
      final list = <_Message>[];
      for (var m in msgs) {
        final decrypted = await CryptoHelper.decryptText(m.text, key);
        list.add(_Message(text: decrypted, isMe: m.isMe == 1));
      }
      setState(() => _messages = list);
      _scrollToBottom();
    }
  }

  Future<void> _initConnection() async {
    try {
      _connection = await BluetoothConnection.toAddress(widget.device.address);
      setState(() => _connecting = false);
      _connection!.input!.listen(_onDataReceived).onDone(() {
        debugPrint('Disconnected');
        if (mounted) setState(() {});
      });
    } catch (e) {
      debugPrint('Connect error: $e');
      if (mounted) setState(() => _connecting = false);
    }
  }

  void _onDataReceived(Uint8List data) async {
    final raw = utf8.decode(data);
    final key = widget.aesKey;
    String text = raw;
    if (key != null) {
      text = await CryptoHelper.decryptText(raw, key);
    }
    setState(() => _messages.add(_Message(text: text, isMe: false)));
    await widget.db.insertMessage(MessageModel(peerAddress: widget.device.address!, text: raw, isMe: 0, timestamp: DateTime.now().millisecondsSinceEpoch));
    _scrollToBottom();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final key = widget.aesKey;
    String toSend = text;
    if (key != null) {
      toSend = await CryptoHelper.encryptText(text, key);
    }
    try {
      _connection?.output.add(Uint8List.fromList(utf8.encode(toSend)));
      await _connection?.output.allSent;
      setState(() {
        _messages.add(_Message(text: text, isMe: true));
      });
      await widget.db.insertMessage(MessageModel(peerAddress: widget.device.address!, text: toSend, isMe: 1, timestamp: DateTime.now().millisecondsSinceEpoch));
      _controller.clear();
      _scrollToBottom();
    } catch (e) {
      debugPrint('Send error: $e');
    }
  }

  void _scrollToBottom() {
    Future.delayed(Duration(milliseconds: 100), () {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent, duration: Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  @override
  void dispose() {
    _connection?.dispose();
    super.dispose();
  }

  Widget _buildMessage(_Message m) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      alignment: m.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: m.isMe ? Colors.tealAccent.withOpacity(0.12) : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(m.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Chat — ${widget.device.name ?? widget.device.address}')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              itemCount: _messages.length,
              itemBuilder: (c, i) => _buildMessage(_messages[i]),
            ),
          ),
          Divider(height: 1),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration.collapsed(hintText: _connecting ? 'Connecting...' : 'Type a message...'),
                    enabled: !_connecting && isConnected,
                    onSubmitted: (_) => _send(),
                  ),
                ),
                IconButton(icon: Icon(Icons.send), onPressed: _connecting || !isConnected ? null : _send),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Message {
  final String text;
  final bool isMe;
  _Message({required this.text, required this.isMe});
}
