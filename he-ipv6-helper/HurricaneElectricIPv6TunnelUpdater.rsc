# Update Hurricane Electric IPv6 Tunnel Client IPv4 address

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# EDIT YOUR DETAILS / CONFIGURATION HERE
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
:local HETunnelIface "sit1"

:local HETunnelHostname "username-1.tunnel.server.pop.ipv6.he.net"
:local HETunnelUsername "username"
:local HETunnelPassword "plain-text-password"

:local HEWanIface1 "ether1-wan"
:local HEWanIface2 "pppoe1-wan"

:local HELogHeader "[HE IPv6 Tunnel] "
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# END OF USER DEFINED CONFIGURATION
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

:local henetupdatenic do={
    :local fqdn "ipv4.tunnelbroker.net"
    :local fullurl ("https://ipv4.tunnelbroker.net/nic/update" . \
                      "?username=" . $username . \
                      "&password=" . $password . \
                      "&hostname=" . $hostname . \
                      "&myip=" . $ipv4addr)
    :local outfile ("he-" . $hostname . ".txt")
    /tool fetch mode=https host=$fqdn url=$fullurl dst-path=$outfile
    :log info ("he.net response: " . [/file get $outfile contents])
    /file remove $outfile
}

# Internal processing below...
:local HEIpv4Addr

# Get WAN interface IP address
:set HEIpv4Addr [/ip address get [/ip address find interface=$HEWanIface1] address]
:set HEIpv4Addr [:pick [:tostr $HEIpv4Addr] 0 [:find [:tostr $HEIpv4Addr] "/"]]

:if ([:len $HEIpv4Addr] = 0) do={
    :log error ($HELogHeader . "Could not get IP for interface " . $HEWanIface1)
    :error ($HELogHeader . "Could not get IP for interface " . $HEWanIface1)

    :set HEIpv4Addr [/ip address get [/ip address find interface=$HEWanIface2] address]
    :set HEIpv4Addr [:pick [:tostr $HEIpv4Addr] 0 [:find [:tostr $HEIpv4Addr] "/"]]
    :if ([:len $HEIpv4Addr] = 0) do={
        :log error ($HELogHeader . "Could not get IP for interface " . $HEWanIface2)
        :error ($HELogHeader . "Could not get IP for interface " . $HEWanIface2)
    } else={
        :log info ($HELogHeader . "Using interface ". $HEWanIface2)
    }
} else={
    :log info ($HELogHeader . "Using interface ". $HEWanIface1)
}

# Update the HETunnelIface with WAN IP
/interface 6to4 {
    :if ([get ($HETunnelIface) local-address] != $HEIpv4Addr) do={
        :log info ($HELogHeader . "Updating " . $HETunnelIface . " local-address with new IP " . $HEIpv4Addr . "...")
        set ($HETunnelIface) local-address=$HEIpv4Addr
    } else={
        :log error ($HELogHeader . "Tunnel address already set to " . $HEIpv4Addr)
        :error ($HELogHeader . "Tunnel address already set to " . $HEIpv4Addr)
   }
}

$henetupdatenic username=$HETunnelUsername \
                password=$HETunnelPassword \
                hostname=$HETunnelHostname

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# END OF SCRIPT
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
