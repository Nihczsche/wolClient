import 'package:localstorage/localstorage.dart';

import './wolentryclasses.dart';

enum UsePortNo {
  seven,
  nine,
  custom
}

String jsonFilename = "woldata";
RegExp ipAddrRegExp = new RegExp(r'^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$');
final LocalStorage woldata = new LocalStorage(jsonFilename);
final WOLEntryList wolEntryList = new WOLEntryList();