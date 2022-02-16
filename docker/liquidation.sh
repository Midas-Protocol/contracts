#!/usr/bin/env sh

set -e

./wait-for-hh.sh
sleep 30

pm2-runtime ecosystem.config.js --env development