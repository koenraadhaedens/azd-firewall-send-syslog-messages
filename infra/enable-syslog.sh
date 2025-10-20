#!/bin/bash
set -e

RSYSLOG_CONF="/etc/rsyslog.conf"

# Maak een backup
cp $RSYSLOG_CONF ${RSYSLOG_CONF}.bak

# Verwijder de '#' voor de imudp en imtcp regels
sed -i 's/^#module(load="imudp")/module(load="imudp")/' $RSYSLOG_CONF
sed -i 's/^#input(type="imudp" port="514")/input(type="imudp" port="514")/' $RSYSLOG_CONF
sed -i 's/^#module(load="imtcp")/module(load="imtcp")/' $RSYSLOG_CONF
sed -i 's/^#input(type="imtcp" port="514")/input(type="imtcp" port="514")/' $RSYSLOG_CONF

# rsyslog herstarten
systemctl restart rsyslog

echo "rsyslog UDP/TCP listener enabled."
