#!/usr/bin/env bash

set -e

./wait-for-hh.sh

npx hardhat deploy --network localhost && npx hardhat pools:create-unhealthy --name "test unhealthy" --network localhost