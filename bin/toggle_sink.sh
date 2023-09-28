#!/bin/bash

readarray -t SINK_ARRAY <<< "$(pactl list sinks short | cut -f2)"
CURRENT_SINK="$(pactl get-default-sink)"

for i in "${!SINK_ARRAY[@]}"; do
    if [[ "${SINK_ARRAY[$i]}" = "${CURRENT_SINK}" ]]; then
        INDEX="${i}";
    fi
done

((INDEX=(INDEX+1) % ${#SINK_ARRAY[@]}))

pactl set-default-sink "${SINK_ARRAY[${INDEX}]}"
