#!/bin/bash

function echoerr() { echo -e "\033[1;31m${@}\033[0m" 1>&2; }

function check_env_exist() {
  envs=($@)
  for env in ${envs[@]} ; do
    eval [[ "X\$${env}" == "X" ]] && echoerr "env \"${env}\" not set" && return 1
  done
  return 0
}

check_env_exist PRIVATE_KEY NETWORK ETHERSCAN_API_KEY || exit 1
[[ "X$REPORT_GAS" == "X" ]] && export REPORT_GAS=false
[[ "X$DEPLOY_DIR" == "X" ]] && export DEPLOY_DIR="./.deploy/bsc_test"


[[ -d ${DEPLOY_DIR} ]] && mv ${DEPLOY_DIR} "${DEPLOY_DIR}.$(date +%Y%m%d%H%M%S)"
mkdir -p "${DEPLOY_DIR}"
[[ ! -d ${DEPLOY_DIR} ]] && echoerr "${DEPLOY_DIR} existed but not dir" && exit 1

npx hardhat compile \
&& \
npx hardhat run --network ${NETWORK} scripts/deploy.js | tee "${DEPLOY_DIR}/deploy.info" \
&& \
export contract=$(cat "${DEPLOY_DIR}/deploy.info" | sed -n "s/contract CNYD deployed to: \(.*\)/\1/p") \
&& [[ "X${contract}" != "X" ]] && \
npx hardhat verify --network ${NETWORK} ${contract} | tee -a "${DEPLOY_DIR}/deploy.info"  \
&& \
export contract_explorer=$(cat "${DEPLOY_DIR}/deploy.info" | sed -n "s/.*\(https*:[^#]*\).*/\1/p" ) \
&& \
cat <<EOF | tee "${DEPLOY_DIR}/contract.info"
## Deploy success!
contract=${contract}
explorer=${contract_explorer}
EOF

[[ $? -ne 0 ]] && echoerr "Deploy failed" && exit 1
