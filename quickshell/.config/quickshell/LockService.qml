pragma Singleton
import Quickshell
import Quickshell.Services.Pam
import QtQuick

// Session lock state + authentication. Password and fingerprint PAM
// contexts run independently; either unlocks.
Singleton {
    id: root

    property bool locked: false
    property string status: ""
    property bool authenticating: false
    property int fpRetries: 0
    property string pendingPw: ""

    signal inputCleared()

    function lock() {
        if (locked)
            return;
        status = "";
        fpRetries = 0;
        locked = true;
        fpPam.start();
    }

    function unlock() {
        locked = false;
        status = "";
        authenticating = false;
        pendingPw = "";
        if (pwPam.active)
            pwPam.abort();
        if (fpPam.active)
            fpPam.abort();
    }

    function submitPassword(pw) {
        if (authenticating)
            return;
        pendingPw = pw;
        authenticating = true;
        status = "Authenticating…";
        pwPam.start();
    }

    PamContext {
        id: pwPam
        config: "login"
        onPamMessage: {
            if (responseRequired)
                respond(root.pendingPw);
        }
        onCompleted: result => {
            root.authenticating = false;
            root.pendingPw = "";
            if (result === PamResult.Success) {
                root.unlock();
            } else {
                root.status = "Incorrect password";
                root.inputCleared();
            }
        }
    }

    // Requires /etc/pam.d/qs-fprintd:  auth required pam_fprintd.so
    // (fprintd's own prompt messages are ignored — the surface has a static hint)
    PamContext {
        id: fpPam
        config: "qs-fprintd"
        onCompleted: result => {
            if (!root.locked)
                return;
            if (result === PamResult.Success) {
                root.unlock();
            } else if (root.fpRetries < 5) {
                root.fpRetries++;
                fpRestart.restart();
            } else {
                root.status = "Fingerprint unavailable — use password";
            }
        }
    }

    Timer {
        id: fpRestart
        interval: 600
        onTriggered: if (root.locked) fpPam.start()
    }
}
