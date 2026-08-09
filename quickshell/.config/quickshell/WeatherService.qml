pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Current weather from OpenWeatherMap. The API key lives OUTSIDE the
// dotfiles repo (~/.config/openweather.key) so it can't be committed.
// Location is auto-detected via geo-IP once per session.
Singleton {
    id: root

    readonly property string apiKey: keyFile.text().trim()
    property var data: null       // raw OWM response
    property string city: ""
    property string country: ""
    property real lat: 0
    property real lon: 0
    property double updatedAt: 0

    readonly property bool hasKey: apiKey !== ""
    readonly property real temp: data?.main?.temp ?? 0
    readonly property string desc: data?.weather?.[0]?.description ?? ""
    readonly property bool night:
        (data?.weather?.[0]?.icon ?? "").endsWith("n")

    FileView {
        id: keyFile
        path: "/home/funinkina/.config/openweather.key"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.refresh()
    }

    function iconFor() {
        const id = data?.weather?.[0]?.id ?? 800;
        if (id >= 200 && id < 300)
            return "weather-storm-symbolic";
        if (id >= 300 && id < 400)
            return "weather-showers-scattered-symbolic";
        if (id >= 500 && id < 600)
            return "weather-showers-symbolic";
        if (id >= 600 && id < 700)
            return "weather-snow-symbolic";
        if (id < 800)
            return "weather-fog-symbolic";
        if (id === 800)
            return night ? "weather-clear-night-symbolic" : "weather-clear-symbolic";
        if (id <= 802)
            return night ? "weather-few-clouds-night-symbolic" : "weather-few-clouds-symbolic";
        return "weather-overcast-symbolic";
    }

    function get(url, cb) {
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            if (xhr.status === 200) {
                try { cb(JSON.parse(xhr.responseText)); } catch (e) {}
            }
        };
        xhr.open("GET", url);
        xhr.send();
    }

    function refresh() {
        if (!hasKey)
            return;
        if (lat === 0 && lon === 0) {
            get("http://ip-api.com/json", r => {
                if (r.status !== "success")
                    return;
                lat = r.lat;
                lon = r.lon;
                city = r.city;
                country = r.countryCode;
                fetchWeather();
            });
        } else {
            fetchWeather();
        }
    }

    function fetchWeather() {
        get("https://api.openweathermap.org/data/2.5/weather"
            + `?lat=${lat}&lon=${lon}&units=metric&appid=${apiKey}`, r => {
            data = r;
            updatedAt = Date.now();
            if (r.name)
                city = r.name;
        });
    }

    Timer {
        interval: 900000   // 15 min
        running: root.hasKey
        repeat: true
        onTriggered: root.refresh()
    }

    // Retry sooner while we have a key but no data yet
    Timer {
        interval: 120000
        running: root.hasKey && root.data === null
        repeat: true
        onTriggered: root.refresh()
    }
}
