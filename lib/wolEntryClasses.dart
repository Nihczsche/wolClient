class WOLEntry {
  String macAddr;
  String bcastAddr;
  String svrAddr;
  int portNo;

  WOLEntry({this.svrAddr, this.bcastAddr, 
  this.macAddr, this.portNo});

  toJSONEncodable() {
    Map<String, dynamic> m = new Map();

    m['svrAddr'] = svrAddr;
    m['bcastAddr'] = bcastAddr;
    m['macAddr'] = macAddr;
    m['portNo'] = portNo;

    return m;
  }
}

class WOLEntryList {
  List<WOLEntry> wolEntryList;

  WOLEntryList() {
    wolEntryList = new List();
  }

  toJSONEncodable() {
    return wolEntryList.map((item) {
      return item.toJSONEncodable();
    }).toList();
  }
}