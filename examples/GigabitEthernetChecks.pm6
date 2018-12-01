use JsonHound;

subset ArpInspection
        is json-path(q[$['Cisco-IOS-XE-native:native'].ip.arp.inspection.vlan]);

subset GigabitEthernet
        is json-path(q[$['Cisco-IOS-XE-native:native'].interface.GigabitEthernet[*]])
        where {
            [&&] .keys > 1,         # Not just a name
                 .<name> ne '0/0',
                 (.<description> // '') ne '__SKIP__'
        }

# VLans that we recognize.
constant %KNOWN_VLANS := set flat 10, 20, 30..34;

# Extract VLan for a GigabitEthernet.
sub get-vlan($ge) {
    $ge<switchport><Cisco-IOS-XE-switch:access><vlan><vlan>
}

subset KnownVLan
        of GigabitEthernet
        where { get-vlan($_) (elem) %KNOWN_VLANS }

subset VLan31
        of GigabitEthernet
        where { get-vlan($_) == 31 };

subset Authentication
        is json-path(q[..['Cisco-IOS-XE-sanet:authentication']]);

validate 'Port detection failed', -> GigabitEthernet $ge {
    $ge ~~ KnownVLan
}

validate 'Missing global DHCP snooping', -> ArpInspection $inspection, GigabitEthernet $ge {
    my $vlan = $ge<switchport><Cisco-IOS-XE-switch:access><vlan><vlan>;
    debug "VLan is $vlan";
    $vlan ~~ any(ranges($inspection))
}
sub ranges($range-list) {
    $range-list.split(',').map({ /(\d+)['-'(\d+)]?/; $1 ?? (+$0 .. +$1) !! +$0 })
}

validate 'Missing auth port-control', -> Authentication $auth {
    $auth<port-control>:exists && $auth<port-control> eq 'auto'
}

validate {"Wrong reauthentication value (was $:value)"}, -> Authentication $auth {
    my $value = $auth<timer><reauthenticate><value>;
    debug "Reauthenticate value is $value";
    report :$value;
    $value == 1800
}

validate 'dot1x-not-set', -> VLan31 $ge {
    $ge<Cisco-IOS-XE-dot1x:dot1x>:exists
}

validate 'Port security not needed', -> VLan31 $ge {
    not $ge<switchport><Cisco-IOS-XE-switch:port-security>:exists
}
