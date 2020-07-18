#!/usr/bin/env bash
set -e

EXITCODE=0

# ========== readsb is updating ==========

if [ -f "/run/readsb/aircraft.json" ]; then

    # get latest timestamp of readsb json update
    TIMESTAMP_LAST_READSB_UPDATE=$(jq '.now' < /run/readsb/aircraft.json)

    # get current timestamp
    TIMESTAMP_NOW=$(date +"%s.%N")

    # makse sure readsb has updated json in past 60 seconds
    TIMEDELTA=$(echo "$TIMESTAMP_NOW - $TIMESTAMP_LAST_READSB_UPDATE" | bc)
    if [ "$(echo "$TIMEDELTA" \< 60 | bc)" -ne 1 ]; then
        echo "readsb last updated: ${TIMESTAMP_LAST_READSB_UPDATE}, now: ${TIMESTAMP_NOW}, delta: ${TIMEDELTA}. UNHEALTHY"
        EXITCODE=1
    else
        echo "readsb last updated: ${TIMESTAMP_LAST_READSB_UPDATE}, now: ${TIMESTAMP_NOW}, delta: ${TIMEDELTA}. HEALTHY"
    fi

else

    echo "ERROR: Cannot find /run/readsb/aircraft.json!"
    EXITCODE=1

fi

# ========== DEATH COUNTS ==========

# death count for telegraf
# shellcheck disable=SC2126
TELEGRAF_DEATHS=$(s6-svdt /run/s6/services/telegraf | grep -v "exitcode 0" | wc -l)
if [ "$TELEGRAF_DEATHS" -ge 1 ]; then
    echo "telegraf deaths: $TELEGRAF_DEATHS. UNHEALTHY"
    EXITCODE=1
else
    echo "telegraf deaths: $TELEGRAF_DEATHS. HEALTHY"
fi
s6-svdt-clear /run/s6/services/telegraf

# death count for readsb
# shellcheck disable=SC2126
READSB_DEATHS=$(s6-svdt /run/s6/services/readsb | grep -v "exitcode 0" | wc -l)
if [ "$READSB_DEATHS" -ge 1 ]; then
    echo "readsb deaths: $READSB_DEATHS. UNHEALTHY"
    EXITCODE=1
else
    echo "readsb deaths: $READSB_DEATHS. HEALTHY"
fi
s6-svdt-clear /run/s6/services/readsb

# ========== NETWORK CONNECTIONS ==========

# Make sure the local readsb has a connection to the ADSBHOST:ADSBPORT
if netstat -anp | grep -E "tcp.*$(s6-dnsip4 $ADSBHOST):$ADSBPORT.*ESTABLISHED.*readsb" > /dev/null 2>&1; then
    echo "local readsb is connected to $ADSBHOST:$ADSBPORT. HEALTHY"
else
    echo "local readsb is NOT connected to $ADSBHOST:$ADSBPORT. UNHEALTHY"
    EXITCODE=1
fi

# Make sure the local readsb has a connection to telegraf
if netstat -anp | grep -E "tcp.*127.0.0.1:30013.*127.0.0.1:.*ESTABLISHED.*telegraf" > /dev/null 2>&1; then
    echo "local telegraf has a connection from local readsb. HEALTHY"
else
    echo "local telegraf DOES NOT have a connection from local readsb. UNHEALTHY"
    EXITCODE=1
fi
if netstat -anp | grep -E "tcp.*127.0.0.1:.*127.0.0.1:30013.*ESTABLISHED.*readsb" > /dev/null 2>&1; then
    echo "local readsb has a connection to local telegraf. HEALTHY"
else
    echo "local readsb DOES NOT have a connection to local telegraf. UNHEALTHY"
    EXITCODE=1
fi

# If using MLATHOST, then make sure we have a connection
if [ -n "$MLATHOST" ]; then 
    if netstat -anp | grep -E "tcp.*$(s6-dnsip4 $MLATHOST):$MLATPORT.*ESTABLISHED.*readsb" > /dev/null 2>&1; then
        echo "local readsb is connected to $MLATHOST:$MLATPORT. HEALTHY"
    else
        echo "local readsb is NOT connected to $MLATHOST:$MLATPORT. UHEALTHY"
        EXITCODE=1
    fi
fi

# Make sure influxdb is reachable
if curl --location --fail "$INFLUXDBURL/ping" > /dev/null 2>&1; then
    echo "InfluxDB is reachable at $INFLUXDBURL. HEALTHY"
else
    echo "InfluxDB is not reachable at $INFLUXDBURL. UNHEALTHY"
    EXITCODE=1
fi

exit $EXITCODE
