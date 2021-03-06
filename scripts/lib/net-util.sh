#!/bin/bash

check_dev()
{
    ip link show dev $DEV >/dev/null 2>&1
}

wait_for_dev()
{
    for i in {1..100}; do
        if check_dev; then
            return
        else
            sleep .1
        fi
    done
    if ! check_dev; then
        echo "$DEV does not exist" 1>&2
        exit 41
    fi
}

IP=
PID=
DEV=eth0
ARGS="$@"

while [ "$#" -gt 0 ]; do
    case $1 in
    -p)
        shift 1
        PID=$1
        ;;
    -i)
        shift 1
        IP=$1
        ;;
    -d)
        shift 1
        DEV=$1
        ;;
    esac
    shift 1
done

if [ "$_ENTERED" != "true" ]; then
    if [[ "$PID" = "" ]]; then
        echo "Invalid PID $PID"
        exit 42
    fi
    
    if [[ ! -e /proc/$PID/ns/net && ! -e /host/proc/$PID/ns/net ]]; then
        echo "Invalid PID $PID"
        exit 43
    fi

    if [ -e /host/proc/$PID/ns/net ]; then
        NS_ARGS="--net=/host/proc/$PID/ns/net"
    fi

    _ENTERED=true exec nsenter $NS_ARGS -F -- $0 $ARGS

    # Not possible
    exit 0
fi

wait_for_dev
ip link show
ip addr show

if [ -n "$IP" ]; then
    if ! echo $IP | grep -q /; then
        # Just assume you really wanted a /24
        IP=${IP}/24
    fi

    if ! ip addr show dev $DEV  | grep '[[:space:]]*inet' | awk '{ print $2 }' | grep -q $IP; then
        echo "Adding $IP to $DEV"
        ip addr add dev $DEV $IP
        ip link show
        ip addr show
    fi

    if ! ip route show | grep -q 169.254.169.250; then
        ip route add 169.254.169.250/32 dev $DEV src $(echo $IP | cut -f1 -d'/')
    fi
fi
