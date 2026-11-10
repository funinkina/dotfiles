var IDS = ["ble_channel_cache_data_V4","ble_business_data","BEACON_DATA",
           "ble_channel_cache_data_V2","thing_cdm_ble_"];
Java.perform(function () {
  var MMKV = Java.use("com.thingclips.smart.mmkv.MMKV");
  IDS.forEach(function (id) {
    var inst = MMKV.mmkvWithID(id);
    if (inst === null) return;
    var ck = null; try { ck = inst.cryptKey(); } catch (e) {}
    var ts = null; try { ts = inst.totalSize(); } catch (e) {}
    send({tag:"meta", id:id, cryptKey: ck===null?null:(""+ck), totalSize: ts});
    var keys = inst.allKeys();
    if (keys === null) return;
    for (var i = 0; i < keys.length; i++) {
      var k = "" + keys[i], o = {tag:"kv", id:id, key:k};
      try { var s = inst.decodeString(k); if (s!==null) o.str = ""+s; } catch (e) {}
      try { var b = inst.decodeBytes(k); if (b!==null) {
        var u=new Uint8Array(b),h=""; for (var j=0;j<u.length;j++) h+=("0"+u[j].toString(16)).slice(-2);
        o.bytes=h; o.blen=u.length; } } catch (e) {}
      try { var iv = inst.decodeInt(k); o.int = iv; } catch (e) {}
      send(o);
    }
  });
  send({tag:"done"});
});
