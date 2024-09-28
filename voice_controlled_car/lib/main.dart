import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'dart:convert';
import 'dart:async';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Voice Controlled Car',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      debugShowCheckedModeBanner: false,
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _command = 'Komut bekleniyor...';
  BluetoothConnection? connection;
  bool _isConnected = false;
  String _connectionStatus = 'Bağlı değil';
  Timer? _commandTimer;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    FlutterBluetoothSerial.instance.state.then((state) {
      if (state == BluetoothState.STATE_OFF) {
        FlutterBluetoothSerial.instance.requestEnable();
      }
    });
  }

  Future<void> initBluetooth(String address) async {
    try {
      connection = await BluetoothConnection.toAddress(address);
      setState(() {
        _isConnected = true;
        _connectionStatus = 'Bağlandı';
      });
      print('Connected to the device');
    } catch (e) {
      setState(() {
        _isConnected = false;
        _connectionStatus = 'Bağlantı hatası';
      });
      print('Cannot connect, exception occurred: $e');
    }
  }

  void _startListening() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) => print('onStatus: $val'),
        onError: (val) => print('onError: $val'),
      );
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) {
            setState(() {
              _command = val.recognizedWords;
            });
            _sendCommand(_command);
          },
        );
      } else {
        setState(() => _command = 'Ses tanıma cihazda mevcut değil.');
      }
    }
  }

  void _stopListening() {
    setState(() {
      _isListening = false;
      _command = 'Komut bekleniyor...';
    });
    _speech.stop();
  }

  void _sendCommand(String command) {
    if (connection != null && connection!.isConnected) {
      String sendCommand = '';
      if (command.toLowerCase().contains('sağa dön')) {
        sendCommand = 'RIGHT';
      } else if (command.toLowerCase().contains('sola dön')) {
        sendCommand = 'LEFT';
      } else if (command.toLowerCase().contains('ileri git')) {
        sendCommand = 'FORWARD';
      } else if (command.toLowerCase().contains('geri git')) {
        sendCommand = 'BACKWARD';
      }

      if (sendCommand.isNotEmpty) {
        connection!.output.add(utf8.encode('$sendCommand\n'));

        // Komutu belirli bir süre için uygula (örneğin 5 saniye)
        _commandTimer?.cancel();
        _commandTimer = Timer(Duration(seconds: 5), () {
          connection!.output.add(utf8.encode('STOP\n'));
          setState(() {
            _command = 'Komut tamamlandı';
          });
        });
      }
    }
  }

  void _selectDevice() async {
    BluetoothDevice? selectedDevice = await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => SelectBondedDevicePage(checkAvailability: false)),
    );

    if (selectedDevice != null) {
      setState(() {
        _connectionStatus = 'Bağlanıyor...';
      });
      initBluetooth(selectedDevice.address);
    }
  }

  void _stopCommand() {
    if (connection != null && connection!.isConnected) {
      connection!.output.add(utf8.encode('STOP\n'));
      _commandTimer?.cancel();
      setState(() {
        _command = 'Komut durduruldu';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Voice Controlled Car'),
        backgroundColor: Colors.indigo,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade300, Colors.blue.shade900],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Card(
                  elevation: 4.0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Komut: $_command',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isListening ? _stopListening : _startListening,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isListening ? Colors.red : Colors.green,
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    textStyle: TextStyle(fontSize: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(_isListening ? 'Mikrofonu Kapat' : 'Mikrofonu Aç'),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _selectDevice,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    textStyle: TextStyle(fontSize: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text('Bluetooth Cihazı Seç'),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _stopCommand,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    textStyle: TextStyle(fontSize: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text('Komutu Durdur'),
                ),
                SizedBox(height: 20),
                Text(
                  _connectionStatus,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _isConnected ? Colors.green : Colors.red,
                  ),
                ),
                SizedBox(height: 20),
                _buildStatusIndicator(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator() {
    if (_isListening) {
      return Column(
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 10),
          Text(
            'Dinleniyor...',
            style: TextStyle(fontSize: 18, color: Colors.white),
          ),
        ],
      );
    } else {
      return Container();
    }
  }
}

class SelectBondedDevicePage extends StatefulWidget {
  final bool checkAvailability;

  SelectBondedDevicePage({required this.checkAvailability});

  @override
  _SelectBondedDevicePageState createState() => _SelectBondedDevicePageState();
}

class _SelectBondedDevicePageState extends State<SelectBondedDevicePage> {
  List<BluetoothDevice> devices = [];

  @override
  void initState() {
    super.initState();
    _getBondedDevices();
  }

  void _getBondedDevices() async {
    List<BluetoothDevice> bondedDevices = [];
    try {
      bondedDevices = await FlutterBluetoothSerial.instance.getBondedDevices();
    } catch (e) {
      print('Error getting bonded devices: $e');
    }

    setState(() {
      devices = bondedDevices;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Select Bonded Device'),
      ),
      body: devices.isEmpty
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: devices.length,
              itemBuilder: (context, index) {
                BluetoothDevice device = devices[index];
                return ListTile(
                  title: Text(device.name ?? 'Unknown device'),
                  subtitle: Text(device.address),
                  onTap: () {
                    Navigator.of(context).pop(device);
                  },
                );
              },
            ),
    );
  }
}
