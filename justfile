set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

start:
    ./start-with-vnc.sh

stop:
    ./stop-vnc.sh

status:
    ./status-vnc.sh

vpn *args="":
    ./start-vpn.sh {{args}}

vpn-stop:
    ./stop-vpn.sh
