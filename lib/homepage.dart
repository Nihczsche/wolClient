import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:encrypt/encrypt.dart';
import 'package:pointycastle/asymmetric/api.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:english_words/english_words.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import './wolentryclasses.dart';
import './globals.dart';
import './addwolentrypage.dart';

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
    _scaffoldKey.currentState.removeCurrentSnackBar();
    final snackBar = SnackBar(content: Text(outputStr), duration: Duration(seconds: 3),);
    _scaffoldKey.currentState.showSnackBar(snackBar);
  }

  sendJsonReq(String macAddr, String bcastAddr, String svrAddr, int portNo, BuildContext context) async {
    Map jsonData = new Map();
    Map jsonSend = new Map();
    var timeNow = new DateTime.now().toUtc();
    final pubKey = RSAKeyParser().parse(await loadPubKey()) as RSAPublicKey;
    final encrypter = Encrypter(RSA(publicKey: pubKey));

    _displaySnackBar(context, 'Sending WOL request...');

    jsonData['macAddr'] = macAddr.split(":").map((String k) {return int.parse(k, radix: 16);}).toList();
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
    catch(e)
    {
      _displaySnackBar(context, 'Error: ' + e.toString());
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
          ).then((val) => (val)? setState(() {_displaySnackBar(context, 'WOL Entry modified!');}) : null);
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