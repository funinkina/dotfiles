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

    // Manual city preference; empty file/absent -> geo-IP autodetection
    readonly property string cityPref: cityFile.text().trim()

    FileView {
        id: cityFile
        path: "/home/funinkina/.config/openweather.city"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            root.lat = 0;
            root.lon = 0;
            root.refresh();
        }
    }

    function setCity(c) {
        // $0-argument trick: no shell quoting issues with city names
        Quickshell.execDetached(["sh", "-c",
            'printf %s "$0" > /home/funinkina/.config/openweather.city', c.trim()]);
        lat = 0;
        lon = 0;
    }

    function iconName(id, isNight) {
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
            return isNight ? "weather-clear-night-symbolic" : "weather-clear-symbolic";
        if (id <= 802)
            return isNight ? "weather-few-clouds-night-symbolic" : "weather-few-clouds-symbolic";
        return "weather-overcast-symbolic";
    }

    function iconFor() {
        return iconName(data?.weather?.[0]?.id ?? 800, night);
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
        if (lat !== 0 || lon !== 0) {
            fetchWeather();
            return;
        }
        if (cityPref !== "") {
            get("https://api.openweathermap.org/geo/1.0/direct"
                + `?q=${encodeURIComponent(cityPref)}&limit=1&appid=${apiKey}`, r => {
                if (!r || r.length === 0)
                    return;
                lat = r[0].lat;
                lon = r[0].lon;
                city = r[0].name;
                country = r[0].country;
                fetchWeather();
            });
        } else {
            get("http://ip-api.com/json", r => {
                if (r.status !== "success")
                    return;
                lat = r.lat;
                lon = r.lon;
                city = r.city;
                country = r.countryCode;
                fetchWeather();
            });
        }
    }

    // Daily forecast: [{ day, icon, min, max, pop }]
    property var forecast: []

    function fetchWeather() {
        get("https://api.openweathermap.org/data/2.5/weather"
            + `?lat=${lat}&lon=${lon}&units=metric&appid=${apiKey}`, r => {
            data = r;
            updatedAt = Date.now();
            if (r.name)
                city = r.name;
        });
        fetchForecast();
    }

    function fetchForecast() {
        get("https://api.openweathermap.org/data/2.5/forecast"
            + `?lat=${lat}&lon=${lon}&units=metric&appid=${apiKey}`, r => {
            const tz = r.city?.timezone ?? 0;
            const byDay = new Map();
            for (const it of r.list) {
                const local = new Date((it.dt + tz) * 1000);
                const key = local.toISOString().slice(0, 10);
                let d = byDay.get(key);
                if (!d) {
                    d = { temps: [], pops: [], mid: null, midDiff: 99,
                          dow: local.getUTCDay() };
                    byDay.set(key, d);
                }
                d.temps.push(it.main.temp_min, it.main.temp_max);
                d.pops.push(it.pop ?? 0);
                const diff = Math.abs(local.getUTCHours() - 13);
                if (diff < d.midDiff) {
                    d.midDiff = diff;
                    d.mid = it;
                }
            }
            const days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
            forecast = [...byDay.values()].slice(0, 5).map((d, i) => ({
                day: i === 0 ? "Today" : days[d.dow],
                min: Math.round(Math.min(...d.temps)),
                max: Math.round(Math.max(...d.temps)),
                pop: Math.round(Math.max(...d.pops) * 100),
                icon: iconName(d.mid.weather[0].id, false)
            }));
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
