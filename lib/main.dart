import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_masked_text/flutter_masked_text.dart';
import 'package:localstorage/localstorage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show TextInputFormatter, WhitelistingTextInputFormatter, rootBundle;
import 'package:encrypt/encrypt.dart';
import 'package:pointycastle/asymmetric/api.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:english_words/english_words.dart';
import 'package:flutter/src/foundation/key.dart' as classKey;

import './wolEntryClasses.dart';

void main() => runApp(MyApp());

final translator = {
    '#': new RegExp(r'[0-9a-fA-F]'),
};
String jsonFilename = "woldata";
RegExp ipAddrRegExp = new RegExp(r'^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$');
final LocalStorage woldata = new LocalStorage(jsonFilename);
final WOLEntryList wolEntryList = new WOLEntryList();

enum UsePortNo {
  seven,
  nine,
  custom
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wake On Lan Client',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(),
    );
  }
}

class AddWOLEntryPage extends StatefulWidget{
  final int wolIndex;

  AddWOLEntryPage(this.wolIndex, {classKey.Key key}): super(key: key);

  @override
  _AddWOLEntryPageState createState() =>_AddWOLEntryPageState(wolIndex);
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool initialized = false;

  Future<String> loadPubKey() async {
    return await rootBundle.loadString('assets/wol_rsa_pub.pem');
  }

  @override
  void dispose() {
    _saveToStorage();
    super.dispose();
  }

  _saveToStorage() {
    woldata.setItem(jsonFilename, wolEntryList.toJSONEncodable());
  }

  _displaySnackBar(BuildContext context, String outputStr) {
    final snackBar = SnackBar(content: Text(outputStr));
    _scaffoldKey.currentState.showSnackBar(snackBar);
  }

  sendJsonReq(String macAddr, String bcastAddr, String svrAddr, int portNo, BuildContext context) async {
    Map jsonData = new Map();
    Map jsonSend = new Map();
    var timeNow = new DateTime.now().toUtc();
    final pubKey = RSAKeyParser().parse(await loadPubKey()) as RSAPublicKey;
    final encrypter = Encrypter(RSA(publicKey: pubKey));

    jsonData['macAddr'] = macAddr.split(":").map((String k) {int.parse(k, radix: 16);}).toList();
    jsonData['repeatNum'] = 3;
    jsonData['salt'] = nouns[Random().nextInt(nouns.length)];
    jsonData['datetime'] = timeNow.toIso8601String();
    jsonData['portNo'] = portNo;
    jsonData['bcastAddr'] = bcastAddr;
    var jsonEncryptStr = encrypter.encrypt(jsonEncode(jsonData));
    jsonSend['data'] = jsonEncryptStr.base64;

    if(!(svrAddr.startsWith('http://')) || !(svrAddr.startsWith('https://')))
    {
      svrAddr = 'http://' + svrAddr;
    }

    
    try
    {
      HttpClientRequest request = await HttpClient().postUrl(Uri.parse(svrAddr))
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(jsonSend));
      HttpClientResponse response = await request.close();
      var respList = await utf8.decoder.bind(response).toList();
      var respString = respList.map((val) => '$val').join('');
    
      _displaySnackBar(context, 'Server: ' + respString);
    }
    on TimeoutException catch(e)
    {
      _displaySnackBar(context, 'Timeout: ' + e.toString());
    }
    on SocketException catch(e)
    {
      _displaySnackBar(context, 'Socket: ' + e.toString());
    }

  }

  Widget _buildwolEntryItem(BuildContext context, int index, VoidCallback onTapDelete) {
    return Slidable(
      actionPane: SlidableScrollActionPane(),
      actionExtentRatio: 0.2,
      child: ListTile(
        title: Text(wolEntryList.wolEntryList[index].svrAddr, style: TextStyle(color: Colors.deepPurple)),
        subtitle: Text(wolEntryList.wolEntryList[index].macAddr, style: TextStyle(color: Colors.deepPurple)),
        onTap: () => sendJsonReq(wolEntryList.wolEntryList[index].macAddr, wolEntryList.wolEntryList[index].bcastAddr, 
        wolEntryList.wolEntryList[index].svrAddr, wolEntryList.wolEntryList[index].portNo, context),
        onLongPress: (){
            Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddWOLEntryPage(index)),
          ).then((val) => (val != null || val)? setState(() {_displaySnackBar(context, 'WOL Entry modified!');}) : null);
        },
      ),
      secondaryActions: <Widget>[
        IconSlideAction(
          caption: 'Delete',
          color: Colors.red,
          icon: Icons.delete,
          onTap: onTapDelete,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text('WOL Client'),
      ),
      body: new Container(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        padding: new EdgeInsets.all(10.0),
        child: new FutureBuilder(
          future: woldata.ready,
          builder: (BuildContext context, AsyncSnapshot snapshot) {
              if (snapshot.data == null) {
                return Center(
                  child: CircularProgressIndicator(),
                );
              }

              if (!initialized) {
                var items = woldata.getItem(jsonFilename);

                if (items != null) {
                  wolEntryList.wolEntryList = List<WOLEntry>.from(
                    (items as List).map(
                      (item) => WOLEntry(
                        svrAddr: item['svrAddr'],
                        bcastAddr: item['bcastAddr'],
                        macAddr: item['macAddr'],
                        portNo: item['portNo']
                      ),
                    ),
                  );
                }
                initialized = true;
              }
            return ListView.separated(
              separatorBuilder: (context, index) => Divider(
                color: Colors.grey,
              ),
              itemBuilder: (BuildContext context, int index){
                return _buildwolEntryItem(context, index, (){
                  setState(() {
                    wolEntryList.wolEntryList.removeAt(index);
                    _saveToStorage();
                  });
                  _displaySnackBar(context, 'Deleted');
                });
              },
              itemCount: wolEntryList.wolEntryList.length,
            );
          }
        ),
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        onPressed: (){
            Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddWOLEntryPage(null)),
          ).then((val) => (val != null || val)? setState(() {_displaySnackBar(context, 'WOL Entry saved!');}) : null);
        }
      ),
    );
  }
}

class _AddWOLEntryPageState extends State<AddWOLEntryPage> {
  final _addrController = new TextEditingController();
  final _macController = new MaskedTextController(mask: '##:##:##:##:##:##', translator: translator);
  final _portController = new TextEditingController();
  final _bcastController = new TextEditingController();
  UsePortNo _radioValue = UsePortNo.seven;
  FocusNode myFocusNode;
  final _formKey = GlobalKey<FormState>();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool initialized = false;
  int wolIndex;

  _AddWOLEntryPageState(this.wolIndex);

  @override
  void initState() {
    super.initState();
    myFocusNode = FocusNode();

    if (wolIndex != null)
    {
      _addrController.text = wolEntryList.wolEntryList[wolIndex].svrAddr;
      _macController.text = wolEntryList.wolEntryList[wolIndex].macAddr;
      _bcastController.text = wolEntryList.wolEntryList[wolIndex].bcastAddr;

      setState(() {
        switch(wolEntryList.wolEntryList[wolIndex].portNo)
        {
          case 7:
            _radioValue = UsePortNo.seven;
            break;
          case 9:
            _radioValue = UsePortNo.nine;
            break;
          default:
            _radioValue = UsePortNo.custom;
            _portController.text = wolEntryList.wolEntryList[wolIndex].portNo.toString();
        }
      });
    }
  }

  @override
  void dispose() {
    _addrController.dispose();
    _macController.dispose();
    _portController.dispose();
    _bcastController.dispose();
    super.dispose();
  }

  _addwolEntry(String svrAddr, String bcastAddr, 
  String macAddr, int portNo) {
    setState(() {
      final wolentry = new WOLEntry(svrAddr: svrAddr, 
      bcastAddr: bcastAddr, macAddr: macAddr, portNo: portNo);
      wolEntryList.wolEntryList.add(wolentry);
      _saveToStorage();
    });
  }

  _saveToStorage() {
    woldata.setItem(jsonFilename, wolEntryList.toJSONEncodable());
  }

  _displaySnackBar(BuildContext context, String outputStr) {
    final snackBar = SnackBar(content: Text(outputStr));
    _scaffoldKey.currentState.showSnackBar(snackBar);
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text('Edit WOL Entry'),
      ),
      body: new Container(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        padding: new EdgeInsets.all(10.0),
        child: new FutureBuilder(
          future: woldata.ready,
          builder: (BuildContext context, AsyncSnapshot snapshot) {
            if (snapshot.data == null) {
              return Center(
                child: CircularProgressIndicator(),
              );
            }

            if (!initialized) {
              var items = woldata.getItem(jsonFilename);

              if (items != null) {
                wolEntryList.wolEntryList = List<WOLEntry>.from(
                  (items as List).map(
                    (item) => WOLEntry(
                      svrAddr: item['svrAddr'],
                      bcastAddr: item['bcastAddr'],
                      macAddr: item['macAddr'],
                      portNo: item['portNo']
                    ),
                  ),
                );
              }

              initialized = true;
            }

            return Form(
              key: _formKey,
              child: new Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  new Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.all(6),
                      child: TextFormField(
                        controller: _addrController,
                        maxLines: 1,
                        decoration: new InputDecoration(
                            hintText: "Enter Server Address",
                            labelText: "Server Address",
                        ),
                        validator: (value) {
                          if (value.isEmpty) {
                            return 'Please enter server address';
                          }

                          try
                          {
                            if(!(value.startsWith('http://')) || !(value.startsWith('https://')))
                            {
                              value = 'http://' + value;
                            }
                            Uri.parse(value);
                          } 
                          on FormatException {
                            return "Invalid server address format";
                          }

                          return null;
                        },
                      ),
                  ),
                  new Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.all(6),
                      child: TextFormField(
                        controller: _bcastController,
                        maxLines: 1,
                        decoration: new InputDecoration(
                            hintText: "Enter Broadcast IP",
                            labelText: "Broadcast IP",
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value.isEmpty) {
                            return 'Please enter broadcast IP';
                          }
                          else if (!ipAddrRegExp.hasMatch(value))
                          {
                            return 'Invalid broadcast IP';
                          }
                          return null;
                        },
                      ),
                  ),
                  new Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.all(6),
                      child: TextFormField(
                        controller: _macController,
                        maxLength: 17,
                        maxLines: 1,
                        decoration: new InputDecoration(
                            hintText: "Enter WOL MAC address",
                            labelText: "WOL MAC Address",
                            counterText: "",
                        ),
                        validator: (value) {
                          if (value.length < 17) {
                            return 'Please enter full MAC address';
                          }
                          return null;
                        },
                      ),
                  ), 
                  new Padding(padding: const EdgeInsets.all(6.0)),
                  new Text('Port Configuration',
                    textAlign: TextAlign.left,
                  ),
                  new Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(6),
                    child: Row(
                      children: <Widget>[
                        new Text(
                          '7',
                          style: new TextStyle(fontSize: 18.0),
                        ),
                        new Radio(
                          value: UsePortNo.seven,
                          groupValue: _radioValue,
                          onChanged: (UsePortNo value) {
                            setState(() { _radioValue = value; });
                            _portController.clear();
                            FocusScopeNode currentFocus = FocusScope.of(context);

                            if (!currentFocus.hasPrimaryFocus) {
                              currentFocus.unfocus();
                            }
                          },
                        ),
                        new Text(
                          '9',
                          style: new TextStyle(
                            fontSize: 18.0,
                          ),
                        ),
                        new Radio(
                          value: UsePortNo.nine,
                          groupValue: _radioValue,
                          onChanged: (UsePortNo value) {
                            setState(() { _radioValue = value; });
                            _portController.clear();
                            FocusScopeNode currentFocus = FocusScope.of(context);

                            if (!currentFocus.hasPrimaryFocus) {
                              currentFocus.unfocus();
                            }
                          },
                        ),
                        new Text(
                          'Custom',
                          style: new TextStyle(fontSize: 18.0),
                        ),
                        new Radio(
                          value: UsePortNo.custom,
                          groupValue: _radioValue,
                          onChanged: (UsePortNo value) {
                            setState(() { _radioValue = value; });
                            myFocusNode.requestFocus();
                          },
                        ),
                        Container(
                          alignment: Alignment.center,
                          height: 20,
                          width: 50,
                          child: new TextFormField(
                            maxLines: 1,
                            maxLength: 5,
                            focusNode: myFocusNode,
                            controller: _portController,
                            onTap: () => setState((){ _radioValue = UsePortNo.custom;}),
                            keyboardType: TextInputType.number,
                            inputFormatters: <TextInputFormatter>[
                                WhitelistingTextInputFormatter.digitsOnly
                            ],
                            decoration: new InputDecoration(
                                hintText: "Port",
                                counterText: "",
                                errorStyle: TextStyle(height: 0),
                            ),
                            validator: (value) {
                              if (value.isEmpty && _radioValue == UsePortNo.custom) {
                                return '';
                              }
                              else if (_radioValue == UsePortNo.custom)
                              {
                                try {
                                  var n = int.parse(value);
                                  if(n < 0 || n > 65536){
                                    return '';
                                  }
                                } on FormatException {
                                  return '';
                                }
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  new RaisedButton(onPressed: (){
                      //sendJsonReq();
                      if (_formKey.currentState.validate()) {
                        // If the form is valid, display a Snackbar.
                        FocusScopeNode currentFocus = FocusScope.of(context);
                        int portNo;

                        if (!currentFocus.hasPrimaryFocus) {
                          currentFocus.unfocus();
                        }

                        _displaySnackBar(context, 'Saving WOL Entry...');

                        switch(_radioValue) { 
                          case UsePortNo.seven: { 
                            portNo = 7;
                          } 
                          break; 
                          
                          case UsePortNo.nine: { 
                            portNo = 9;
                          } 
                          break; 

                          case UsePortNo.custom: { 
                            portNo = int.parse(_portController.text);
                          }
                          break;
                        }

                        if (wolIndex == null)
                        {
                          _addwolEntry(_addrController.text, _bcastController.text, _macController.text, portNo);
                        }
                        else
                        {
                          wolEntryList.wolEntryList[wolIndex].bcastAddr = _bcastController.text;
                          wolEntryList.wolEntryList[wolIndex].svrAddr = _addrController.text;
                          wolEntryList.wolEntryList[wolIndex].macAddr = _macController.text;
                          wolEntryList.wolEntryList[wolIndex].portNo = portNo;
                        }
                        Navigator.pop(context, true);
                      }
                    },
                    child: new Text('Add WOL Entry'),
                  ),
                ],
              ),
            );
          }
        ),
      ),
    );
  }
}
