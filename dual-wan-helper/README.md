mikrotik :: Dual Wan Helper
===========================

MikroTik Script for easy failover between 2 (or more) WAN interfaces.

# Installation

Run the following commands before running the script.
```

/ip dns
set allow-remote-requests=yes servers=208.67.222.222,208.67.220.220,2620:0:ccc::2,2620:0:ccd::2

/interface ethernet
set [ find default-name=ether1 ] comment=FIBER name=ether1-wan speed=1Gbps

/ip dhcp-client
add dhcp-options=hostname,clientid disabled=no interface=ether1-wan use-peer-dns=no use-peer-ntp=no

/ppp profile
add change-tcp-mss=no comment=ARNET name=pppoe-arnet

/interface pppoe-client
add add-default-route=yes comment="ARNET PPPOE" default-route-distance=2 disabled=no interface=ether2-wan max-mru=1492 max-mtu=1492 name=pppoe1-wan password=telecom profile=pppoe-arnet user=telecom@telecom

/ip firewall address-list
add address=192.168.86.0/24 comment=LAN list=loc
# WAN addresses will be updated by the helper script automatically.
add address=1.0.0.1 comment=WAN_ARNET list=loc
add address=1.0.0.2 comment=WAN_FIBER list=loc
# Gateway addresses will be updated by the helper script automatically.
add address=1.0.0.3 comment=WAN_GW_ARNET list=wan_arnet
add address=1.0.0.4 comment=WAN_GW_FIBER list=wan_fiber

/ip route
# Gateway addresses will be updated by the helper script automatically.
add distance=1 gateway=1.0.0.3 routing-mark=ARNET
add distance=1 gateway=1.0.0.4 routing-mark=FIBER

/ip firewall mangle
add action=mark-connection chain=output comment="OUT STA ROUTING ARNET" connection-mark=no-mark dst-address-list=wan_arnet new-connection-mark=CX_ARNET passthrough=yes src-address-type=local
add action=mark-connection chain=output comment="OUT STA ROUTING FIBER" connection-mark=no-mark dst-address-list=wan_fiber new-connection-mark=CX_FIBER passthrough=yes src-address-type=local

add action=mark-connection chain=output comment="OUT DYN ROUTING ARNET" connection-mark=no-mark dst-address-list=!loc new-connection-mark=CX_ARNET passthrough=yes per-connection-classifier=both-addresses:2/1 src-address-type=local
add action=mark-connection chain=output comment="OUT DYN ROUTING FIBER" connection-mark=no-mark dst-address-list=!loc new-connection-mark=CX_FIBER passthrough=yes per-connection-classifier=both-addresses:2/0 src-address-type=local

add action=mark-routing chain=output comment="ROUTING MARK ARNET" connection-mark=CX_ARNET dst-address-list=!loc new-routing-mark=ARNET passthrough=no src-address-type=local
add action=mark-routing chain=output comment="ROUTING MARK FIBER" connection-mark=CX_FIBER dst-address-list=!loc new-routing-mark=FIBER passthrough=no src-address-type=local

add action=mark-connection chain=prerouting comment="INB ROUTING ARNET" in-interface=pppoe1-wan new-connection-mark=CX_ARNET passthrough=yes
add action=mark-connection chain=prerouting comment="INB ROUTING FIBER" in-interface=ether1-wan new-connection-mark=CX_FIBER passthrough=yes

add action=mark-connection chain=prerouting comment="OUT XDSL MODEM" connection-mark=no-mark dst-address=10.0.0.2 new-connection-mark=CX_ETH01 passthrough=yes src-address-list=loc
add action=mark-connection chain=prerouting comment="INB XDSL MODEM" connection-mark=no-mark dst-address-list=loc new-connection-mark=CX_ETH01 passthrough=yes src-address=10.0.0.2

add action=mark-connection chain=prerouting comment="OUT STA ROUTING ARNET" connection-mark=no-mark dst-address-list=wan_arnet new-connection-mark=CX_ARNET passthrough=yes src-address-list=loc
add action=mark-connection chain=prerouting comment="OUT STA ROUTING FIBER" connection-mark=no-mark dst-address-list=wan_fiber new-connection-mark=CX_FIBER passthrough=yes src-address-list=loc

add action=mark-connection chain=prerouting comment="OUT STA ROUTING ARNET" connection-mark=no-mark dst-address-list=!loc new-connection-mark=CX_ARNET passthrough=yes src-address-list=lan_arnet
add action=mark-connection chain=prerouting comment="OUT STA ROUTING FIBER" connection-mark=no-mark dst-address-list=!loc new-connection-mark=CX_FIBER passthrough=yes src-address-list=lan_fiber

add action=mark-connection chain=prerouting comment="OUT DYN ROUTING ARNET" connection-mark=no-mark dst-address-list=!loc new-connection-mark=CX_ARNET passthrough=yes per-connection-classifier=both-addresses:8/0 src-address-list=loc
add action=mark-connection chain=prerouting comment="OUT DYN ROUTING FIBER" connection-mark=no-mark dst-address-list=!loc new-connection-mark=CX_FIBER passthrough=yes per-connection-classifier=both-addresses:8/1 src-address-list=loc
add action=mark-connection chain=prerouting comment="OUT DYN ROUTING FIBER" connection-mark=no-mark dst-address-list=!loc new-connection-mark=CX_FIBER passthrough=yes per-connection-classifier=both-addresses:8/2 src-address-list=loc
add action=mark-connection chain=prerouting comment="OUT DYN ROUTING FIBER" connection-mark=no-mark dst-address-list=!loc new-connection-mark=CX_FIBER passthrough=yes per-connection-classifier=both-addresses:8/3 src-address-list=loc
add action=mark-connection chain=prerouting comment="OUT DYN ROUTING FIBER" connection-mark=no-mark dst-address-list=!loc new-connection-mark=CX_FIBER passthrough=yes per-connection-classifier=both-addresses:8/4 src-address-list=loc
add action=mark-connection chain=prerouting comment="OUT DYN ROUTING FIBER" connection-mark=no-mark dst-address-list=!loc new-connection-mark=CX_FIBER passthrough=yes per-connection-classifier=both-addresses:8/5 src-address-list=loc
add action=mark-connection chain=prerouting comment="OUT DYN ROUTING FIBER" connection-mark=no-mark dst-address-list=!loc new-connection-mark=CX_FIBER passthrough=yes per-connection-classifier=both-addresses:8/6 src-address-list=loc
add action=mark-connection chain=prerouting comment="OUT DYN ROUTING FIBER" connection-mark=no-mark dst-address-list=!loc new-connection-mark=CX_FIBER passthrough=yes per-connection-classifier=both-addresses:8/7 src-address-list=loc

add action=mark-routing chain=prerouting comment="ROUTING MARK ETH01" connection-mark=CX_ETH01 dst-address-list=!loc new-routing-mark=OTHER passthrough=no src-address-list=loc
add action=mark-routing chain=prerouting comment="ROUTING MARK ARNET" connection-mark=CX_ARNET dst-address-list=!loc new-routing-mark=ARNET passthrough=no src-address-list=loc
add action=mark-routing chain=prerouting comment="ROUTING MARK FIBER" connection-mark=CX_FIBER dst-address-list=!loc new-routing-mark=FIBER passthrough=no src-address-list=loc

add action=change-mss chain=forward comment="ADSL MSS" in-interface=pppoe1-wan new-mss=1452 passthrough=yes protocol=tcp tcp-flags=syn tcp-mss=1453-65535
add action=change-mss chain=forward comment="ADSL MSS" new-mss=1452 out-interface=pppoe1-wan passthrough=yes protocol=tcp tcp-flags=syn tcp-mss=1453-65535

/ip firewall nat
add action=masquerade chain=srcnat comment="ARNET MODEM" dst-address=10.0.0.0/24 out-interface=ether2-wan
add action=masquerade chain=srcnat comment=FIBER out-interface=ether1-wan
add action=masquerade chain=srcnat comment=ARNET out-interface=pppoe1-wan

/tool e-mail
set address=smtp.gmail.com from=user@gmail.com password="my-secret-password" port=587 start-tls=yes user=user@gmail.com

```

# Post-Installation
Run the following commands to run the script every minute.
```
/system scheduler
add interval=1m name=Tsk_DualWAN_Helper on-event=DualWAN_Helper policy=reboot,read,write,policy,test,password,sniff,sensitive start-time=startup
```
