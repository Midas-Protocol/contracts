#!/usr/bin/env bash

set -e

while ping -c1 e2e &>/dev/null
do
  echo "Pools are being set up..."
  sleep 5;
done;

until npx hardhat e2e:unhealthy-pools-became-healthy --network localhost &>/dev/null; do
  sleep 10;
  echo "Pools are still being liquidated...";
done

echo "Ensuring fees are seized..."
npx hardhat e2e:admin-fees-are-seized --network localhost

echo "Fees were sized and pools liquidated!"