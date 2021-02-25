#!/bin/bash
set -e

mkdir actions-runner && cd actions-runner
curl -O -L https://github.com/actions/runner/releases/download/v2.276.1/actions-runner-linux-x64-2.276.1.tar.gz
tar xzf ./actions-runner-linux-x64-2.276.1.tar.gz
./bin/installdependencies.sh
mkdir /_work

AUTH_HEADER="Authorization: token ${PAT}"
API_VERSION=v3
API_HEADER="Accept: application/vnd.github.${API_VERSION}+json"
_FULL_URL="https://api.github.com/repos/${ORG}/${REPO}/actions/runners/registration-token"
RUNNER_TOKEN="$(curl -XPOST -fsSL \
  -H "${AUTH_HEADER}" \
  -H "${API_HEADER}" \
  "${_FULL_URL}" \
| jq -r '.token')"

./config.sh --url https://github.com/${ORG}/${REPO} --token "${RUNNER_TOKEN}" --name "aws-runner" --work _work --labels aws --unattended --replace
./bin/runsvc.sh