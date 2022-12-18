#!/bin/sh

exec plackup --port ${PORT:-8080} "$@"

