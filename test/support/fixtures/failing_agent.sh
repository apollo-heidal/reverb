#!/usr/bin/env bash
# Fake agent CLI that always fails, for circuit breaker testing.
echo "ERROR: simulated failure"
exit 1
