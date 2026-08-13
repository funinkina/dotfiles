pragma Singleton
import Quickshell
import Quickshell.Services.Pam
import QtQuick

Singleton {
    id: root

    property bool locked: false
    property bool awake: false
    property string status: ""
    property bool authenticating: false
    property string pendingPw: ""

    property bool fpBroken: false
    property int fpFastFails: 0
    property double fpStartedAt: 0
    property double lockedAt: 0

    readonly property int idleTimeout: 60000
    readonly property string fpBrokenMsg: "Fingerprint unavailable. Use password"

    signal inputCleared()
    function lock() {
        if (locked)
            return;
        status = "";
        fpBroken = false;
        awake = false;
        idleTimer.stop();
        fpRestart.stop();
        lockedAt = Date.now();
        locked = true;
    }

    function unlock() {
        locked = false;
        awake = false;
        status = "";
        authenticating = false;
        pendingPw = "";
        idleTimer.stop();
        fpRestart.stop();
        if (pwPam.active)
            pwPam.abort();
        if (fpPam.active)
            fpPam.abort();
    }


    function wake() {
        if (!locked)
            return;

        if (Date.now() - lockedAt < 500)
            return;
        idleTimer.restart();
        if (awake)
            return;
        awake = true;
        fpFastFails = 0;
        armFp();
    }

    function sleep() {
        if (!awake)
            return;
        awake = false;
        fpRestart.stop();
        if (fpPam.active)
            fpPam.abort();
        status = fpBroken ? fpBrokenMsg : "";
        inputCleared();
    }

    function armFp() {
        if (fpBroken || !awake)
            return;
        if (fpPam.active) {
            fpRestart.restart();
            return;
        }
        fpStartedAt = Date.now();
        if (!fpPam.start())
            breakFp();
    }

    function breakFp() {
        fpBroken = true;
        fpRestart.stop();
        status = fpBrokenMsg;
    }

    function submitPassword(pw) {
        if (authenticating)
            return;
        wake();
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

    PamContext {
        id: fpPam
        config: "qs-fprintd"
        onCompleted: result => {
            if (!root.locked || !root.awake)
                return;
            if (result === PamResult.Success) {
                root.unlock();
                return;
            }
            if (Date.now() - root.fpStartedAt < 2000) {
                if (++root.fpFastFails >= 3) {
                    root.breakFp();
                    return;
                }
            } else {
                root.fpFastFails = 0;
            }
            fpRestart.restart();
        }
    }

    Timer {
        id: fpRestart
        interval: 600
        onTriggered: root.armFp()
    }

    Timer {
        id: idleTimer
        interval: root.idleTimeout
        onTriggered: root.authenticating ? restart() : root.sleep()
    }
}
