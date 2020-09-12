#!/usr/bin/env bash

# This script will test that telegraf is listening on tcp port 30013
# It is used for s6-notifyoncheck in service start scripts to bring things up in order

netstat -anp | grep -E "tcp.*:30013.*LISTEN.*telegraf" > /dev/null 2>&1
exit $?
