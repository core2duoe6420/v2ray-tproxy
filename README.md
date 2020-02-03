**This is an experimental image to prove some assumptions, more research to make it really useful in real world is inevitable.**

## Introduction

This is a docker image for bypass transparent proxy of v2ray, using techniques in this article: https://guide.v2fly.org/app/tproxy.html

The image uses network namespace to isolate ip route and iptables settings and accelerate deployment.

It should be deployed on a device other than router, like Raspberry Pi or NAS, using Docker network that is attched (bridged) to host physical network, there are several choices:

- macvlan: easy to deploy, but due to the limitation of macvlan, the host itself cannot connect to the container, so it can't use the transparent proxy
- bridge to host: unfortunately, docker has a very poor support for bridging to host network, it's feasible, but very tricky
- host: Docker host network just doesn't create network namespace and the script in the image will pollute host network namespace without cleaning it up, so host network is not recommended

## Deployment

Suppose the device IP address is 192.168.1.250, and the gateway is 192.168.1.254, the container's address will be 192.168.1.251.

First, create a macvlan:

```
docker network create -d macvlan \
    --subnet=192.168.1.0/24 \
    --ip-range=192.168.1.251/32 \
    --gateway=192.168.1.254 \
    -o parent=ens3 v2ray
```

Then start the container:

```
docker run -d \
	--name=v2ray \
	--privileged=true \
	--network v2ray \
	--env VMESS_SERVER=<VMESS_SERVER> \
	--env VMESS_PORT=<VMESS_PORT> \
	--env VMESS_ID=<VMESS_ID> \
	--env NETWORK=192.168.1.0/24 \
	--env ADDRESS=192.168.1.251/24 \
	--env GATEWAY=192.168.1.254 \
	core2duo/v2ray-bypass:200202
```

## Testing

After the container is running, change the default route and DNS namespace to the container address in client:

```
ip route change default via 192.168.1.251
echo "nameserver 192.168.1.251" > /etc/resolve.conf
```

The client should work then.

## Work with router

Use the container as a default route is not a good idea, as all the traffic will go through v2ray and bring extra performance pressure on it. The better way is to collaborate with the router, redirect the traffic to the proxy only when it's necessary.

The solution is to use `dnsmasq` and `ipset`. You will need a dnsmasq configuration that indicates which domain will use v2ray DNS and will be added into ipset, something like this:

```
server=/.google.com/192.168.1.251#53
ipset=/.google.com/gfwlist
```

See [gfwlist2dnsmasq](https://github.com/cokebar/gfwlist2dnsmasq) for a tool that can automatically generate the configuration.

Then on router, create the ipset if it doesn't exist.

```
ipset create gfwlist hash:ip
```

Use iptables to mark traffics to ip that is in the ipset and route them to the proxy:

```
ip rule add pref 10 fwmark 0xAA lookup 10
ip route add default via 192.168.1.251 table 10
iptables -t mangle -A PREROUTING -m set --match-set gfwlist dst -j MARK --set-mark 0xAA
```

Done, all devices connected to the router should be able to use the transparent proxy now.