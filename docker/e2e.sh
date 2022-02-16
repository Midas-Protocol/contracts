#!/usr/bin/env bash

set -e

./wait-for-hh.sh

sleep 30

npx hardhat pools:create-unhealthy --name "test unhealthy" --network localhost