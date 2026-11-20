#!/bin/bash
cd -P -- "$(dirname -- "$0")" || exit 1
exec /bin/bash ./netplay.sh host "$@"
