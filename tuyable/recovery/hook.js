// Catch Tuya device secrets as the app reads them from encrypted MMKV (decrypted in-library).
function hexAscii(s) {
  // return {hex, printable} for a java String or byte[]
  return s;
}
Java.perform(function () {
  function tap(clsName) {
    var C;
    try { C = Java.use(clsName); } catch (e) { return false; }
    ["decodeString", "getString"].forEach(function (m) {
      if (!C[m]) return;
      C[m].overloads.forEach(function (ov) {
        ov.implementation = function () {
          var r = ov.apply(this, arguments);
          try {
            var k = arguments.length ? ("" + arguments[0]) : "?";
            if (r !== null) {
              var v = "" + r;
              if (v.length >= 8 && v.length <= 2048)
                send({ tag: "mmkv.str", cls: clsName.split(".").pop(), key: k, val: v });
            }
          } catch (e) {}
          return r;
        };
      });
    });
    ["decodeBytes", "getBytes"].forEach(function (m) {
      if (!C[m]) return;
      C[m].overloads.forEach(function (ov) {
        ov.implementation = function () {
          var r = ov.apply(this, arguments);
          try {
            var k = arguments.length ? ("" + arguments[0]) : "?";
            if (r !== null && r.length >= 8 && r.length <= 2048) {
              var b = new Uint8Array(r), hex = "";
              for (var i = 0; i < b.length; i++) hex += ("0" + b[i].toString(16)).slice(-2);
              send({ tag: "mmkv.bytes", cls: clsName.split(".").pop(), key: k, len: b.length, hex: hex });
            }
          } catch (e) {}
          return r;
        };
      });
    });
    return true;
  }
  var hit = [];
  ["com.thingclips.smart.mmkv.MMKV"].forEach(function (c) {
    if (tap(c)) hit.push(c);
  });
  send({ tag: "ready", hooked: hit });
});
