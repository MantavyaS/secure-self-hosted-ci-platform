#!/bin/bash

set -e

cd /home/runner/actions-runner

if [ -z "$GITHUB_REPO_URL" ]; then
    echo "GITHUB_REPO_URL is not set"
    exit 1
fi

if [ -z "$GITHUB_RUNNER_TOKEN" ]; then
    echo "$GITHUB_RUNNER_TOKEN is not set"
    exit 1
fi

./config.sh --url "$GITHUB_REPO_URL" --token "$GITHUB_RUNNER_TOKEN" --name "${RUNNER_NAME:-k3s-runner}" --labels "${RUNNER_LABELS:-self-hosted,k3s,linux}" --unattended --replace

cleanup() {
    echo "Removing runner"
    ./config.sh remove --unattended --token "$GITHUB_RUNNER_TOKEN"
}

trap cleanup EXIT

./run.sh