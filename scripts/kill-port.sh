#!/usr/bin/env bash
port="$1"; [ -z "$port" ] && echo "usage: kill-port <port>" && exit 64
lsof -ti tcp:"$port" | xargs -r kill
