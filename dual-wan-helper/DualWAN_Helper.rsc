# Dual WAN Failover Script
# More scripts available at https://github.com/martinclaro/mikrotik

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# EDIT YOUR DETAILS / CONFIGURATION HERE
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
:local emailto "youremailaddress@emailserver.com"
:local emailserver "smtp.emailserver.com"
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# END OF USER DEFINED CONFIGURATION
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

:local ifacename "N/A"
:local ifacemark "N/A"
:local ifaceaddr "N/A"
:local ifaceaddo "N/A"
:local ifaceaddn "N/A"
:local ifacegwyo "N/A"
:local ifacegwyn "N/A"
:local ifacestat true

:local actionres 0

:local getifaceaddr do={
    :local res "N/A"
    :do {
        :set res [/ip address get [/ip address find interface=$1] address]
        :log info ("getifaceaddr: Got IP address " . $res ." from ".$1)
    } on-error={
        :log error ("getifaceaddr: Unable to get IP address from ".$1)
        :set res "N/A"
    }
    :return $res
}
:local getgwaddrbymark do={
    :local res "N/A"
    :do {
        :set res [/ip route get [/ip route find routing-mark=$1] gateway]
        :log info ("getgwaddrbymark: Got GW address " . $res ." from ".$1)
    } on-error={
        :log error ("getgwaddrbymark: Unable to get GW address from ".$1)
        :set res "N/A"
    }
    :return $res
}
:local setgwaddrbymark do={
    do {
        :log info ( $1 . ": " . $3 . " @ " . $5 )
        /ip route set [/ip route find routing-mark=$2] gateway=$5
        :log info ( $1 . ": " . $4 ." != ". $5 )
    } on-error={
        :log error ("setgwaddrbymark: Failed to set route to gateway ". $5 ." for ". $2)
    }
}
:local getgwaddrppp do={
    :local res "N/A"
    :do {
        :set res [/ip address get [/ip address find interface=$1] network]
        :log info ("getgwaddrppp: Got GW address " . $res ." from ".$1)
    } on-error={
        :log error ("getgwaddrppp: Failed to get GW address to from interface=". $1)
        :set res "N/A"
    }
    :return $res
}
:local getgwaddrvrf do={
    :local res "N/A"
    :do {
        :set res [/ip route get [/ip route find vrf-interface=$1] gateway]
        :log info ("getgwaddrvrf: Got GW address " . $res ." from ".$1)
    } on-error={
        :log error ("getgwaddrvrf: Failed to get GW address to from vrf-interface=". $1)
        :set res "N/A"
    }
    :return $res
}
:local sendemail do={
    :local serveraddr "0.0.0.0"
    :do {
        :set serveraddr [/tool e-mail get address]
        if ($serveraddr != $inserver) do={
            /tool e-mail set address=$inserver
        }
        /tool e-mail send to=$into subject=$insubject body=$inbody
    } on-error={
        :log error ("Failed to send email to ". $into ." at ". $inserver)
    }
}
:local setmssbymark do={
    /ip firewall mangle set [/ip firewall mangle find comment=$1] new-mss=$2 tcp-mss=$3
}
:local smartfirewalldisable do={
    :local res 0
    :local rulslens [:len [/ip firewall mangle find comment=("OUT STA ROUTING ". $2) disabled=no]]
    :local rulslend [:len [/ip firewall mangle find comment=("OUT DYN ROUTING ". $2) disabled=no]]
    :if ($rulslens > 0 || $rulslend > 0) do={
        :log info ("smartfirewalldisable: Disabling firewall rules at " . $1 ." for ".$2)
        /ip firewall mangle set [/ip firewall mangle find comment=("OUT STA ROUTING ". $2) disabled=no] disabled=yes
        /ip firewall mangle set [/ip firewall mangle find comment=("OUT DYN ROUTING ". $2) disabled=no] disabled=yes
        :log info ( $1 . ": disabled" )
        :set res 1
    }
    :return $res
}
:local smartfirewallenable do={
    :local res 0
    :local rulslens [:len [/ip firewall mangle find comment=("OUT STA ROUTING ". $2) disabled=yes]]
    :local rulslend [:len [/ip firewall mangle find comment=("OUT DYN ROUTING ". $2) disabled=yes]]
    :if ($rulslens > 0 || $rulslend > 0) do={
        :log info ("smartfirewallenable: Enabling firewall rules at " . $1 ." for ".$2)
        /ip firewall mangle set [/ip firewall mangle find comment=("OUT STA ROUTING ". $2) disabled=yes] disabled=no
        /ip firewall mangle set [/ip firewall mangle find comment=("OUT DYN ROUTING ". $2) disabled=yes] disabled=no
        :log info ( $1 . ": enabled" )
        :set res 1
    }
    :return $res
}
:local parseipaddress do={
    :local res "N/A"
    :set res [:pick $1 0 [:find $1 "/"]]
    :return $res
}
:local getoldifaceaddr do={
    :local res "N/A"
    :local tag "WAN_$1"
    :do {
        :set res [/ip firewall address-list get [/ip firewall address-list find comment=$tag] address]
        :log info ("getoldifaceaddr: Got OLD IP address " . $res ." from ".$1)
    } on-error={
        :log error ("getoldifaceaddr: Unable to get OLD IP address from ".$1)
        :set res "N/A"
    }
    :return $res
}
:local setlocalwanaddr do={
    :local tag "WAN_$1"
    :log info ("Setting address-list for " . $tag ." to ". $2)
    /ip firewall address-list set [/ip firewall address-list find comment=$tag] address=$2
    :set tag "WAN_GW_$1"
    :log info ("Setting address-list for " . $tag ." to ". $3)
    /ip firewall address-list set [/ip firewall address-list find comment=$tag] address=$3
}
:local updatewanaddr do={
    # Update WAN address
    :log info ("Updating cloud.mikrotik.com...")
    /ip cloud force-update
    # Update Hurricane Electric IPv6 Tunnel
    # See https://github.com/martinclaro/mikrotik/tree/master/he-ipv6-helper
    # :log info ("Running IPv6_HE_Helper script...")
    # /system script run IPv6_HE_Helper
}
:local pingok do={
    :local pinghost "8.8.8.8"
    :log info ("PINGing ". $pinghost ." through ". $1 ."...")
    :local res [/ping address=$pinghost interface=$1 count=8 interval=0.5 do-not-fragment]
    :log info ("PING results: ". $res ." / 8.")
    if ($res > 0) do={
        :return true
    } else={
        :return false
    }
}

# WAN1 - HFC
:set ifacename "ether1-wan"
:set ifacemark "FIBER"
:do {
    :log info ("Checking interface ". $ifacename ." / ". $ifacemark ."...")
    :set ifacestat [/interface ethernet get $ifacename running]

    :if ($ifacestat = false) do={
        :set actionres [$smartfirewalldisable $ifacename $ifacemark]
        :if ($actionres > 0) do={
            $sendemail inserver=$emailserver into=$emailto insubject=($ifacename .": disabled") inbody=($ifacename .": disabled\n\n". "Interface not running.")
        }
    } else={
        :set ifaceaddr [$getifaceaddr $ifacename]
        :set ifacegwyo [$getgwaddrbymark $ifacemark]
        :set ifacegwyn [$getgwaddrvrf $ifacename]

        :if ($ifacegwyn != "N/A" && $ifacegwyo != $ifacegwyn) do={
            $setgwaddrbymark $ifacename $ifacemark $ifaceaddr $ifacegwyo $ifacegwyn
        }

        :if ($ifacegwyn = "192.168.100.1" || $ifacegwyn = "0.0.0.0" || $ifacegwyn = "N/A" || $ifacegwyn = "") do={
            :set actionres [$smartfirewalldisable $ifacename $ifacemark]
            :if ($actionres > 0) do={
                $sendemail inserver=$emailserver into=$emailto insubject=($ifacename .": disabled") inbody=($ifacename .": disabled")
            }
            :set ifaceaddo [$getoldifaceaddr $ifacemark]
            :set ifaceaddn [$parseipaddress $ifaceaddr]
            :if ($ifaceaddn != $ifaceaddo) do={
                $setlocalwanaddr $ifacemark $ifaceaddn $ifacegwyn
            }
        } else={
            if ([$pingok $ifacename]) do={
                :set actionres [$smartfirewallenable $ifacename $ifacemark]
                :if ($actionres > 0) do={
                    $sendemail inserver=$emailserver into=$emailto insubject=($ifacename .": enabled") inbody=($ifacename .": enabled")
                }
                :set ifaceaddo [$getoldifaceaddr $ifacemark]
                :set ifaceaddn [$parseipaddress $ifaceaddr]
                :if ($ifaceaddn != $ifaceaddo) do={
                    $setlocalwanaddr $ifacemark $ifaceaddn $ifacegwyn
                }
            } else={
                :log info ("PING failed!")
                :set actionres [$smartfirewalldisable $ifacename $ifacemark]
                :if ($actionres > 0) do={
                    $sendemail inserver=$emailserver into=$emailto insubject=($ifacename .": disabled") inbody=($ifacename .": disabled\n\n". "PING failed!")
                }
            }
        }
    }
    :if ($actionres > 0) do={
        :do {
            $updatewanaddr
        } on-error={
            :log info ("Failed to update WAN address. Continue...")
        }
    }
} on-error={
    :log error ("Failed to process ". $ifacename ." / ". $ifacemark)
    :set actionres [$smartfirewalldisable $ifacename $ifacemark]
    :if ($actionres > 0) do={
        $sendemail inserver=$emailserver into=$emailto insubject=($ifacename .": disabled") inbody=($ifacename .": disabled\n\n". "Failed to process ". $ifacename ." / ". $ifacemark)
    }
}

# WAN2 - DSL
:set ifacename "pppoe1-wan"
:set ifacemark "ARNET"
:do {
    :log info ("Checking interface ". $ifacename ." / ". $ifacemark ."...")
    :set ifacestat [/interface pppoe-client get $ifacename running]

    :if ($ifacestat = false) do={
        :set actionres [$smartfirewalldisable $ifacename $ifacemark]
        :if ($actionres > 0) do={
            $sendemail inserver=$emailserver into=$emailto insubject=($ifacename .": disabled") inbody=($ifacename .": disabled\n\n" . "Interface not running.")
        }
    } else={
        :set ifaceaddr [$getifaceaddr $ifacename]
        :set ifacegwyo [$getgwaddrbymark $ifacemark]
        :set ifacegwyn [$getgwaddrppp $ifacename]

        :if ($ifacegwyn != "N/A" && $ifacegwyo != $ifacegwyn) do={
            $setgwaddrbymark $ifacename $ifacemark $ifaceaddr $ifacegwyo $ifacegwyn
        }

        :if ($ifacegwyn = "0.0.0.0" || $ifacegwyn = "N/A" || $ifacegwyn = "") do={
            :set actionres [$smartfirewalldisable $ifacename $ifacemark]
            :if ($actionres > 0) do={
                $sendemail inserver=$emailserver into=$emailto insubject=($ifacename .": disabled") inbody=($ifacename .": disabled")
            }
            :set ifaceaddo [$getoldifaceaddr $ifacemark]
            :set ifaceaddn [$parseipaddress $ifaceaddr]
            :if ($ifaceaddn != $ifaceaddo) do={
                $setlocalwanaddr $ifacemark $ifaceaddn $ifacegwyn
            }
        } else={
            if ([$pingok $ifacename]) do={
                :set actionres [$smartfirewallenable $ifacename $ifacemark]
                :if ($actionres > 0) do={
                    $sendemail inserver=$emailserver into=$emailto insubject=($ifacename .": enabled") inbody=($ifacename .": enabled")
                }
                :set ifaceaddo [$getoldifaceaddr $ifacemark]
                :set ifaceaddn [$parseipaddress $ifaceaddr]
                :if ($ifaceaddn != $ifaceaddo) do={
                    $setlocalwanaddr $ifacemark $ifaceaddn $ifacegwyn
                }
            } else={
                :log info ("PING failed!")
                :set actionres [$smartfirewalldisable $ifacename $ifacemark]
                :if ($actionres > 0) do={
                    $sendemail inserver=$emailserver into=$emailto insubject=($ifacename .": disabled") inbody=($ifacename .": disabled\n\n". "PING failed!")
                }
            }
        }
    }
    :if ($actionres > 0) do={
        :do {
            $updatewanaddr
        } on-error={
            :log info ("Failed to update WAN address. Continue...")
        }
    }
} on-error={
    :log error ("Failed to process ". $ifacename ." / ". $ifacemark)
    :set actionres [$smartfirewalldisable $ifacename $ifacemark]
    :if ($actionres > 0) do={
        $sendemail inserver=$emailserver into=$emailto insubject=($ifacename .": disabled") inbody=($ifacename .": disabled\n\n". "Failed to process ". $ifacename ." / ". $ifacemark)
    }
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# END OF SCRIPT
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~