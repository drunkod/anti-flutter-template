set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

start:
    ./start-with-vnc.sh

stop:
    ./stop-vnc.sh

status:
    ./status-vnc.sh

vpn config="":
    if [ -n "{{config}}" ]; then
        ./start-vpn.sh "{{config}}"
    else
        ./start-vpn.sh
    fi

vpn-stop:
    ./stop-vpn.sh
