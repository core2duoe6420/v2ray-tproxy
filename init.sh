#!/bin/bash

checkEnv() {
    var=$1
    if [ "${!var}" = "" ]; then
        echo "${var} is not given"
        exit 1
    fi
}

checkEnv NETWORK
checkEnv ADDRESS
checkEnv GATEWAY
checkEnv VMESS_SERVER
checkEnv VMESS_PORT
checkEnv VMESS_ID

echo 1 > /proc/sys/net/ipv4/ip_forward

if [ $? -ne 0 ]; then
    echo "no root permission"
    exit 1
fi

ip addr flush dev eth0
ip addr add ${ADDRESS} dev eth0
ip route add default via ${GATEWAY}

iptables -t filter -F
iptables -t nat -F
iptables -t mangle -F

# 设置策略路由
ip rule add fwmark 1 table 100
ip route add local 0.0.0.0/0 dev lo table 100

# 代理局域网设备
iptables -t mangle -N V2RAY
iptables -t mangle -A V2RAY -d 127.0.0.1/32 -j RETURN
iptables -t mangle -A V2RAY -d 224.0.0.0/4 -j RETURN 
iptables -t mangle -A V2RAY -d 255.255.255.255/32 -j RETURN 
iptables -t mangle -A V2RAY -d ${NETWORK} -p tcp -j RETURN
iptables -t mangle -A V2RAY -d ${NETWORK} -p udp ! --dport 53 -j RETURN
iptables -t mangle -A V2RAY -p udp -j TPROXY --on-port 12345 --tproxy-mark 1
iptables -t mangle -A V2RAY -p tcp -j TPROXY --on-port 12345 --tproxy-mark 1
iptables -t mangle -A PREROUTING -j V2RAY

# 代理网关本机
iptables -t mangle -N V2RAY_MASK 
iptables -t mangle -A V2RAY_MASK -d 224.0.0.0/4 -j RETURN 
iptables -t mangle -A V2RAY_MASK -d 255.255.255.255/32 -j RETURN 
iptables -t mangle -A V2RAY_MASK -d ${NETWORK} -p tcp -j RETURN
iptables -t mangle -A V2RAY_MASK -d ${NETWORK} -p udp ! --dport 53 -j RETURN
iptables -t mangle -A V2RAY_MASK -j RETURN -m mark --mark 0xff
iptables -t mangle -A V2RAY_MASK -p udp -j MARK --set-mark 1
iptables -t mangle -A V2RAY_MASK -p tcp -j MARK --set-mark 1
iptables -t mangle -A OUTPUT -j V2RAY_MASK

envsubst < /opt/v2ray/config.json.template > /opt/v2ray/config.json

exec /opt/v2ray/v2ray -config=/opt/v2ray/config.json
