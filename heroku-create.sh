#!/bin/sh

exec heroku create --buildpack http://github.com/pnu/heroku-buildpack-perl.git "$@"
