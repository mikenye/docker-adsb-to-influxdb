# mikenye/adsb-to-influxdb

Pull ADS-B data from `dump1090`, `readsb` or another host that provides ADS-B data, and send to InfluxDB.

Supported input formats:

* Beast/BeastReduce (preferred)
* Basestation/SBS
* Raw
* JSON (from `readsb`)

This image is the spiritual successor to [`mikenye/piaware-to-influx`](https://hub.docker.com/repository/docker/mikenye/piaware-to-influx), with the differences being:

`mikenye/piaware-to-influx` converts every single received ADS-B message to InfluxDB line protocol (and thus uses a fair amount of CPU resources).

Instead, this image (for each tracked aircraft) sends a digest of the latest received information at a predefined interval.

For this reason, this image uses significantly less system resources than `mikenye/piaware-to-influx`.

Furthermore, this image provides many additional tags/fields - see the InfluxDB Schema below.

This image works well with:

* [mikenye/readsb](https://hub.docker.com/r/mikenye/readsb)
* [mikenye/piaware](https://hub.docker.com/r/mikenye/piaware)

## Multi Architecture Support

Currently, this image should pull and run on the following architectures:

* `amd64`: Linux x86-64
* `arm32v7`, `armv7l`: ARMv7 32-bit (Odroid HC1/HC2/XU4, RPi 2/3/4)
* `aarch64`, `arm64v8`: ARMv8 64-bit (RPi 4)

## Supported tags and respective Dockerfiles

* `latest` should always contain the latest released versions of `telegraf` and `readsb`. This image is built nightly from the [`master` branch](https://github.com/mikenye/docker-adsb-to-influxdb/tree/master) [`Dockerfile`](https://github.com/mikenye/docker-adsb-to-influxdb/blob/master/Dockerfile) for all supported architectures.
* `development` ([`dev` branch](https://github.com/mikenye/docker-adsb-to-influxdb/tree/dev), [`Dockerfile`](https://github.com/mikenye/docker-adsb-to-influxdb/blob/dev/Dockerfile), `amd64` architecture only, built on commit, not recommended for production)
* Specific version and architecture tags are available if required, however these are not regularly updated. It is generally recommended to run `latest`.

## Up-and-Running with `docker run`

Firstly, make sure all your hosts (`influxdb`, `piaware`/`dump1090`/`readsb` and the docker host that will run this container) have their clocks set correctly and are synchronised with NTP.

Next, you can start the container:

```shell
docker run \
 -d \
 --name adsb2influxdb \
 --restart=always \
 -e INFLUXDBURL="http://<influxdb_host>:<influxdb_port>" \
 -e ADSBHOST="<readsb_host>" \
 -e TZ="<your_timezone>" \
 mikenye/adsb-to-influxdb
```

For example:

```shell
docker run \
  -d \
  --name=adsb2influxdb \
  --restart=always \
  -e INFLUXDB_URL="http://192.168.3.84:8086" \
  -e ADSBHOST="192.168.3.85" \
  -e TZ="Australia/Perth" \
  mikenye/adsb-to-influxdb
```

The container will attempt to connect to the `readsb` instance at `192.168.3.85` to receive ADS-B data via Beast protocol.

It will then convert the data to line protocol, and send to InfluxDB, using database `adsb` (which will be created if it doesn't exist).

## Up-and-Running with Docker Compose

An example `docker-compose.xml` file is below:

```shell
version: '2.0'

services:
  adsb2influxdb:
    image: mikenye/adsb-to-influxdb:latest
    tty: true
    container_name: adsb2influxdb
    restart: always
    environment:
      - TZ="Australia/Perth"
      - INFLUXDBURL=http://192.168.3.84:8086
      - ADSBHOST=192.168.3.85
```

The container will attempt to connect to the `readsb` instance at `192.168.3.85` to receive ADS-B data via Beast protocol.

It will then convert the data to line protocol, and send to InfluxDB, using database `adsb` (which will be created if it doesn't exist).

## Runtime Configuration Options

There are a series of available variables you are required to set:

| Environment Variable | Default Value | Description |
|-|-|-|
| `ADSBHOST` | | Required. IP/hostname of an ADS-B data source. |
| `ADSBPORT` | `30005` | Optional. The TCP port to connect to on the ADS-B data source for ADS-B data. |
| `ADSBTYPE` | `beast_in` | Optional. Can be set to:<br>`beast_in`, `raw_in` or `sbs_in`. |
| `MLATHOST` | | Optional. IP/hostname of an MLAT data source (Beast format). |
| `MLATPORT` | `30105` | Optional. The TCP port to connect to on the MLAT data source for MLAT data. |
| `INFLUXDBURL` | | Required. The URL of your InfluxDB instance, eg: `http://192.168.1.10:8086`. |
| `INTERVAL` | `5` | Optional. The number of seconds between data being sent to InfluxDB for each tracked aircraft. Lowing this means more data being sent to InfluxDB and more system resources being used. |
| `JSONPORT` | `30012` | Optional. The TCP port that `readsb` will listen to for incoming JSON connections. |
| `TZ` | `UTC` | Optional.Your local timezone, eg `Australia/Perth`. |


## Ports

No ports need to be mapped into this container. If you want to see the raw JSON data being sent to InfluxDB, you can map `JSONPORT` to the container, and connect using `telnet` or `nc`.

The container will need to be able to access:

* The source of ADS-B data on port `30005` by default, or any other port you specify with the `ADSBPORT` variable.
* If `MLATHOST` is set, the source of MLAT data on port `30105` by default, or any other port you specify with the `MLATPORT` variable.
* The InfluxDB server (however you specify in the `INFLUXDBURL` environment variable)

## Telegraf

Telegraf (https://www.influxdata.com/time-series-platform/telegraf/) runs in this container as well. It handles taking the data generated by `readsb` and writing it to InfluxDB. Telegraf is used because the clever folks at InfluxData are better at writing software that talks to InfluxDB than I am. It handles buffering, it handles InfluxDB temporarily being unavailable, and lots of other nifty features.

It also makes it very easy to port this to any other backend that `telegraf` can output to - just fork the container and modify the `telegraf` output script (which is generated via `etc/cont-init.d/02-telegraf` on container start).

## InfluxDB retention policies

By default, when Telegraf creates a database, it uses the default retention policy. At the time of writing, with InfluxDB version 1.7, this means the data is kept for *7 days* (168 hours).

```
InfluxDB shell version: 1.8.0
> use adsb
Using database adsb
> show retention policies
name    duration shardGroupDuration replicaN default
----    -------- ------------------ -------- -------
autogen 0s       168h0m0s           1        true
```

If you need a longer retention than this, you will need to modify the retention policy yourself. For example, if you wanted to keep the last 30 days of data:

```
InfluxDB shell version: 1.8.0
> CREATE RETENTION POLICY "30_days" ON "adsb" DURATION 30d REPLICATION 1 DEFAULT
> use adsb
Using database adsb
> show retention policies
name    duration shardGroupDuration replicaN default
----    -------- ------------------ -------- -------
autogen 0s       168h0m0s           1        false
30_days 720h0m0s 24h0m0s            1        true
```

## InfluxDB Measurement Schema

The following outlines the data schema, which should closely resemble the schema of `dump1090`/`readsb`'s `aircraft.json` file.

See <https://github.com/wiedehopf/readsb/blob/master/README-json.md#aircraftjson> for further information.

### `adsb_icao` & `mlat` measurements

Messages from a Mode S or ADS-B transponder, using a 24-bit ICAO address.

#### Tags

| Tag Name    | Example   | Detail |
|-------------|-----------|--------|
| `category`  | `A1`      | Emitter category to identify particular aircraft or vehicle classes. A0-D7 (or 00 if unset) |
| `emergency` | `none`    | ADS-B emergency/priority status, a superset of the 7x00 squawks. |
| `flight`    | `FD601`   | ICAO Aircraft Registration (callsign) as 8 characters. |
| `ground`    | `false`   | `true` if the aircraft is on the ground, `false` if it is in the air. |
| `hex`       | `7c49f8`  | Aircraft Mode S hexadecimal code. |
| `host`      | `a2i`     | Hostname of container (can specify with `--hostname`). |
| `sil_type`  | `perhour` | Frequency which SIL (Source Integrity Level) value is updated. |
| `squawk`    | `4023`    | A 4-digit octal code assigned to the aircraft by air traffic control. |

#### Fields

| Field Name    | Example       | Units  | Detail |
|---------------|---------------|--------|--------|
| `alert`       | `0`           |        | FS Flight status alert bit. |
| `alt_baro`    | `27000`       | `ft`   | Barometric Altitude. The uncorrected, pressure-derived height of the aircraft above mean sea level (based on barometric pressure). |
| `alt_geom`    | `27725`       | `ft`   | Geometric Altitude referenced to the WGS84 ellipsoid. Geometric altitude measurement is typically performed using GPS. |
| `baro_rate`   | `-64`         | `fpm`  | Rate of change of barometric altitude, in feet per minute. |
| `calc_track`  | ?
| `geom_rate`   | `-65`         | `fpm`  | Rate of change of geometric (GNSS / INS) altitude, in feet per minute. |
| `gs`          | `250.0`       | `kn`   | Ground Speed. The horizontal speed of an aircraft relative to the ground. |
| `gva`         | `2`           |        | Geometric Vertical Accuracy.<br> `0`: unknown or > 150 meters<br>`1`: < 150 meters<br>`2`: < 45 meters<br>`3`: reserved. |
| `ias`         | `171`         | `kn`   | Indicated Airspeed. The speed shown on the airspeed indicator in the aircraft. |
| `lat`         | `-30.294986`  | `°`    | Last reported latitude of the aircraft.
| `lon`         | `116.807794`  | `°`    | Last reported longitude of the aircraft.
| `mach`        | `0.436`       |        | Mach number. Aircraft speed divided by speed of sound. Mach 1 is the speed of sound. |
| `mag_heading` | `14.24`       | `°`    | The aircraft heading in degrees clockwise from magnetic north. |
| `messages`    | `15676`       |        | The number of messages received from the aircraft. |
| `nac_p`       | `9`           |        | Navigation Accuracy Category - Position. See [here](https://mode-s.org/decode/adsb/uncertainty.html#nacp).
| `nac_v`       | `2`           |        | Navigation Accuracy Category - Velocity. See [here](https://mode-s.org/decode/adsb/uncertainty.html#nacv).
| `nav_altitude_fms` | `27008`  | `ft`   | Selected Altitude - the flight level which is manually entered in the FMS (Flight Management System) by the pilot. |
| `nav_altitude_mcp` | `27008`  | `ft`   | Selected Altitude - the flight level which is manually entered in the MCP/FCU (Mode Control Panel / Flight Control Unit) or equivalent equipment by the pilot. |
| `nav_heading`      | `12.66`  | `°`    | Selected Heading - the flight heading which is manually entered in the FMS by the pilot. |
| `nav_qnh`          | `1013.6` | `hPa` | QNH is an aeronautical code Q code, indicating the atmospheric pressure adjusted to mean sea level. Used by the aircraft navigation systems. |
| `nic`              | `8`      |        | Navigation Integrity Check. See [here](https://mode-s.org/decode/adsb/uncertainty.html#nic). |
| `nic_baro`         | `1`      |        | Barometric Altitude Integrity Code.<br>`0`: For aircraft with a Gillham altitude source without an automatic cross-check.<br>`1`: For aircraft with an approved, non-Gillham altitude source.<br>For aircraft which dynamically cross-check a Gillham altitude source with a second altitude source the value is set based on the result of this cross-check.|
| `oat`              | `-35.2`  | `°C`   | Outside Air Temperature. The ambient temperature measured outside an aircraft is known as the Outside Air Temperature (OAT) or Static Air Temperature (SAT). |
| `rc`               | `186`    | `m`    | Radius of containment. The radius that there is a 95% probability the aircraft is within that radius of its stated position, both horizontally and vertically. |
| `roll`             | `0.00`   | `°`    | Roll angle. Negative is left roll. The roll angle is also known as bank angle on a fixed-wing aircraft, which usually "banks" to change the horizontal direction of flight. |
| `rssi`             | `-25.4`  | `dBFS` | Received Signal Strength Indicator. Signal strength from this aircraft to the receiver. |
| `sda`              | `2`      |        | System Design Assurance. Probability of failure causing transmission of false or misleading information.<br>`0`: Unknown / No safety effect (&gt;1x10<sup>-3</sup> per hour or unknown)<br>`1`: Minor (&le;1x10<sup>-3</sup> per hour)<br>`2`: Major (&le;1x10<sup>-5</sup> per hour)<br>`3`: Hazardous (&le;1x10<sup>-7</sup> per hour) |
| `seen`             | `0.0`    | `s`    | Time in seconds since a message was received from this aircraft. |
| `seen_pos`         | `0.0`    | `s`    | Time in seconds since a position was received from this aircraft. |
| `sil`              | `3`      |        | Source Integrity Level. Probability of exceeding the NIC containment radius.<br>`0`: &gt;1x10<sup>-3</sup> per hour or sample unknown<br>`1`: &le;1x10<sup>-3</sup> per hours or sample<br>`2`: &le;1x10<sup>-5</sup> per hour or sample<br>`3`: &le;1x10<sup>-7</sup> per hour or sample |
| `spi`              | `0`      |        | FS Flight status SPI (Special Position Identification) |
| `tas`              | `250.0`  | `kn`   | True airspeed is the airspeed of an aircraft relative to undisturbed air. |
| `tat`              | `-26.2`  |        | Total Air Temperature. If temperature is measured by means of a sensor positioned in the airflow, kinetic heating will result, raising the temperature measured above the OAT. The temperature measured in this way is known as the Total Air Temperature (TAT) and is used in ADCs to calculate True Airspeed (TAS). |
| `track`            | `22.78`  | `°`    | Track. The projection on the earth’s surface of the path of an aircraft. |
| `track_rate`       | `0.03`   | `°/s`  | Track Angle Rate (called also Rate of Turn) gives the turning speed of the aircraft. |
| `true_heading`     | `13.49`  | `°`    | The direction the aircraft is pointing, clockwise from true north. |
| `version`          | `2`      |        | ADS-B version (0, 1, 2). |
| `wd`               | `62.19`  | `°`    | Wind is blowing (out of) this direction. |
| `ws`               | `4.12`   | `kn`   | Wind speed. |

### `adsb_icao_nt` measurement

Messages from an ADS-B equipped "non-transponder" emitter e.g. a ground vehicle, using a 24-bit ICAO address.

#### Tags

| Tag Name    | Example   | Detail |
|-------------|-----------|--------|
| `ground`    | `true`   | `true` if the vehicle is on the ground, `false` if it is in the air. |
| `hex`       | `7cf62e`  | Aircraft Mode S hexadecimal code. |
| `host`      | `a2i`     | Hostname of container (can specify with `--hostname`). |
| `sil_type`  | `unknown` | Frequency which SIL (Source Integrity Level) value is updated. |

#### Fields

| Field Name    | Example       | Units  | Detail |
|---------------|---------------|--------|--------|
| `gs`          | `9.2`       | `kn`   | Ground Speed. The horizontal speed of the vehicle on the ground. |
| `lat`         | `-31.934986`  | `°`    | Last reported latitude of the vehicle.
| `lon`         | `116.807794`  | `°`    | Last reported longitude of the vehicle.
| `messages`    | `15676`       |        | The number of messages received from the vehicle. |
| `nac_p`       | `10`           |        | Navigation Accuracy Category - Position. See [here](https://mode-s.org/decode/adsb/uncertainty.html#nacp).
| `nic`              | `10`      |        | Navigation Integrity Check. See [here](https://mode-s.org/decode/adsb/uncertainty.html#nic). |
| `rc`               | `25`    | `m`    | Radius of containment. The radius that there is a 95% probability the vehicle is within that radius of its stated position, both horizontally and vertically. |
| `rssi`             | `-25.4`  | `dBFS` | Received Signal Strength Indicator. Signal strength from this aircraft to the receiver. |
| `seen`             | `0.0`    | `s`    | Time in seconds since a message was received from this aircraft. |
| `seen_pos`         | `0.0`    | `s`    | Time in seconds since a position was received from this aircraft. |
| `sil`              | `2`      |        | Source Integrity Level. Probability of exceeding the NIC containment radius.<br>`0`: &gt;1x10<sup>-3</sup> per hour or sample unknown<br>`1`: &le;1x10<sup>-3</sup> per hours or sample<br>`2`: &le;1x10<sup>-5</sup> per hour or sample<br>`3`: &le;1x10<sup>-7</sup> per hour or sample |
| `track`            | `239`  | `°`    | Track. The projection on the earth’s surface of the path of an aircraft. |
| `version`          | `0`      |        | ADS-B version (0, 1, 2). |

## Visualising the data

A very simple visualisation would be to create a table showing recent squawks:

![Example Grafana Visualisation of ADS-B Data](https://github.com/mikenye/docker-adsb-to-influxdb/raw/master/example_vis_grafana_table.png "Example Grafana Visualisation of ADS-B Data")

The JSON for this panel is as follows:

```json
{
  "datasource": "adsb",
  "fieldConfig": {
    "defaults": {
      "custom": {
        "align": null
      },
      "thresholds": {
        "mode": "absolute",
        "steps": [
          {
            "color": "green",
            "value": null
          },
          {
            "color": "red",
            "value": 80
          }
        ]
      },
      "mappings": []
    },
    "overrides": [
      {
        "matcher": {
          "id": "byName",
          "options": "flight"
        },
        "properties": [
          {
            "id": "custom.width",
            "value": 82
          },
          {
            "id": "displayName",
            "value": "Ident"
          }
        ]
      },
      {
        "matcher": {
          "id": "byName",
          "options": "Time"
        },
        "properties": [
          {
            "id": "custom.width",
            "value": 162
          },
          {
            "id": "displayName",
            "value": "Last Seen"
          }
        ]
      },
      {
        "matcher": {
          "id": "byName",
          "options": "hex"
        },
        "properties": [
          {
            "id": "custom.width",
            "value": 73
          },
          {
            "id": "displayName",
            "value": "ICAO"
          }
        ]
      },
      {
        "matcher": {
          "id": "byName",
          "options": "last"
        },
        "properties": [
          {
            "id": "custom.width",
            "value": 84
          },
          {
            "id": "displayName",
            "value": "Lat"
          },
          {
            "id": "unit",
            "value": "degree"
          },
          {
            "id": "decimals",
            "value": 6
          }
        ]
      },
      {
        "matcher": {
          "id": "byName",
          "options": "lon"
        },
        "properties": [
          {
            "id": "custom.width",
            "value": 73
          },
          {
            "id": "displayName",
            "value": "Lon"
          },
          {
            "id": "unit",
            "value": "degree"
          },
          {
            "id": "decimals",
            "value": 6
          }
        ]
      },
      {
        "matcher": {
          "id": "byName",
          "options": "squawk"
        },
        "properties": [
          {
            "id": "custom.width",
            "value": 65
          },
          {
            "id": "displayName",
            "value": "Squawk"
          }
        ]
      },
      {
        "matcher": {
          "id": "byName",
          "options": "alt_baro"
        },
        "properties": [
          {
            "id": "custom.width",
            "value": 104
          },
          {
            "id": "displayName",
            "value": "Alt"
          },
          {
            "id": "unit",
            "value": "lengthft"
          }
        ]
      },
      {
        "matcher": {
          "id": "byName",
          "options": "geom_rate"
        },
        "properties": [
          {
            "id": "custom.width",
            "value": 86
          },
          {
            "id": "displayName",
            "value": "Alt Rate"
          },
          {
            "id": "unit",
            "value": "fpm"
          }
        ]
      },
      {
        "matcher": {
          "id": "byName",
          "options": "track"
        },
        "properties": [
          {
            "id": "custom.width",
            "value": 100
          },
          {
            "id": "displayName",
            "value": "Track"
          },
          {
            "id": "unit",
            "value": "degree"
          }
        ]
      },
      {
        "matcher": {
          "id": "byName",
          "options": "messages"
        },
        "properties": [
          {
            "id": "custom.width",
            "value": 98
          },
          {
            "id": "displayName",
            "value": "Msgs"
          }
        ]
      },
      {
        "matcher": {
          "id": "byName",
          "options": "rssi"
        },
        "properties": [
          {
            "id": "custom.width",
            "value": 91
          },
          {
            "id": "unit",
            "value": "dB"
          },
          {
            "id": "decimals",
            "value": 1
          },
          {
            "id": "displayName",
            "value": "RSSI"
          }
        ]
      },
      {
        "matcher": {
          "id": "byName",
          "options": "gs"
        },
        "properties": [
          {
            "id": "custom.width",
            "value": 71
          },
          {
            "id": "unit",
            "value": "velocityknot"
          },
          {
            "id": "displayName",
            "value": "Gnd Speed"
          }
        ]
      },
      {
        "matcher": {
          "id": "byName",
          "options": "ground"
        },
        "properties": [
          {
            "id": "custom.width",
            "value": 81
          },
          {
            "id": "displayName",
            "value": "On Ground"
          }
        ]
      }
    ]
  },
  "gridPos": {
    "h": 7,
    "w": 24,
    "x": 0,
    "y": 0
  },
  "hideTimeOverride": false,
  "id": 2,
  "options": {
    "showHeader": true,
    "sortBy": [
      {
        "desc": false,
        "displayName": "ICAO"
      }
    ]
  },
  "pluginVersion": "7.0.3",
  "targets": [
    {
      "groupBy": [
        {
          "params": [
            "hex"
          ],
          "type": "tag"
        },
        {
          "params": [
            "flight"
          ],
          "type": "tag"
        },
        {
          "params": [
            "squawk"
          ],
          "type": "tag"
        },
        {
          "params": [
            "ground"
          ],
          "type": "tag"
        }
      ],
      "measurement": "adsb_icao",
      "orderByTime": "ASC",
      "policy": "default",
      "refId": "A",
      "resultFormat": "table",
      "select": [
        [
          {
            "params": [
              "lat"
            ],
            "type": "field"
          },
          {
            "params": [],
            "type": "last"
          }
        ],
        [
          {
            "params": [
              "lon"
            ],
            "type": "field"
          }
        ],
        [
          {
            "params": [
              "alt_baro"
            ],
            "type": "field"
          }
        ],
        [
          {
            "params": [
              "geom_rate"
            ],
            "type": "field"
          }
        ],
        [
          {
            "params": [
              "track"
            ],
            "type": "field"
          }
        ],
        [
          {
            "params": [
              "messages"
            ],
            "type": "field"
          }
        ],
        [
          {
            "params": [
              "rssi"
            ],
            "type": "field"
          }
        ],
        [
          {
            "params": [
              "gs"
            ],
            "type": "field"
          }
        ]
      ],
      "tags": []
    }
  ],
  "timeFrom": "5m",
  "timeShift": null,
  "title": "Squawks",
  "type": "table"
}
```

## Getting help

Please feel free to [open an issue on the project's GitHub](https://github.com/mikenye/docker-adsb-to-influxdb/issues).

## Changelog

### 2020-06-07

* Initial release.

