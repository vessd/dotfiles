#!/bin/bash

request="https://wttr.in/Санкт-Петербург?format=1"
for i in {1..30}; do wget -q --spider "$request" && break; sleep 1; done
curl -H "Accept-Language: ru" --compressed "$request"
