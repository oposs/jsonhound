# Testing

## Basics

The test device has 4 interfaces

* `interface/GigabitEthernet/name=0/0` should always be ignored
* `interface/GigabitEthernet/name=1/0/1` should be ignored because of the "magic" __SKIP__ in its description
* all empty (cisco default config) should be ignored too\
* `interface/GigabitEthernet/name=1/0/2` and `interface/GigabitEthernet/name=1/0/3` should be detected and tested

## Test Data

* `00-Switch1-OK.json` - valid configuartion
* `01-missing-global-dhcp-snooping.json` - DHCP snooping is active on part but not globally
* `02-missing-auth-port-control.json` - missing "port-control": "auto"
* `03-wrong-reauth.json` - wrong reauthentication value ... should be 240 is 1800
* `04-dot1x-not-set.json` - dot1x setting missing
* `05-port-detection-fail.json` - port Template detection should fail, no rule for detection of VLAN 201
* `06-port-security-not-needed.json` port security should not appear but present
