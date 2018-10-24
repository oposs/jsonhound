# jsonHound
*a system for parsing JSON data structures and identifying anomalies* [![Build Status](https://travis-ci.org/oposs/jsonhound.svg?branch=master)](https://travis-ci.org/oposs/jsonhound)

While the name and the structure of this tool is very generic, it was built for a highly specific purpose:
Modern Cisco Switches allow export of their configuration in JSON format. The purpose of the jsonHound is
to identify misconfiguration of the switches. It does that by identifying *interesting* data structures,
like interfaces, and then choosing a set of checks to verify that they are properly configured. The
checks are chosen by looking at features of the interface or the configuration as a whole. For example,
if an interface is part of VLAN 643 we *know* that this is part of your IP Telefony VLAN and will thus
require a particular set of configuration options to be active.

The configuration of the jsonHound works in 3 stages:

* Stage 1 identifies the "interesting structures"
* Stage 2 applies a set of checks to these structures

jsonHound is implemented in in Perl 6, and Perl 6 is also used to write the jsonHound rule files.

## The jsonHound rule files

A jsonHound rule file is just a Perl 6 module that does `use JsonHound` at the top, and contains
identification and validation setup. It's fine to use Perl 6 language features to help factor out
re-use within the ruleset, and even to spread the rules over multiple modules, and `use` those.

## Identification

The identification state is set up by declaring Perl 6 `subset` types, which pick out "subsets"
of the JSON document to check. The simplest way to identify part of the document that should be
considered is by using JSONPath:

```
subset ArpInspection
        is json-path(q[$['Cisco-IOS-XE-native:native'].ip.arp.inspection.vlan]);
```

A `where` clause can be applied in order to further constrain what is matched, by looking
into the deserialized JSON that was matched by the JSONPath query.

```
subset GigabitEthernet
        is json-path(q[$['Cisco-IOS-XE-native:native'].interface.GigabitEthernet[*]])
        where {
            [&&] .keys > 1,         # Not just a name
                 .<name> ne '0/0',
                 (.<description> // '') ne '__SKIP__'
        }
```

It's also possible to add further constraints (but *not* further JSONPath) using a
derived `subset` type:

```
sub get-vlan($ge) {
    $ge<switchport><Cisco-IOS-XE-switch:access><vlan><vlan>
}
subset VLan31
        of GigabitEthernet
        where { get-vlan($_) == 31 };
```

## Validations

Validations are set up by calling the `validate` sub, passing it a name for the validation
(to be displayed upon failure) and one or more identified document sections. For example:

```
validate 'dot1x-not-set', -> VLan31 $ge {
    $ge<Cisco-IOS-XE-dot1x:dot1x>:exists
}
```

The block should evaluate to a true value if the validation is successful. If it evalutes
to a false value, then validation fails and this will be reported. The JSON that was
matched in the identification phase is passed using the variable declared in the signature.

The `validate` block will be called once for each matching item. In the event that multiple
parameters are specified, then it will be called with the product of them (e.g. all of the
combinations). For example, given:

```
validate 'Missing global DHCP snooping', -> ArpInspection $inspection, GigabitEthernet $ge {
    $ge<switchport><Cisco-IOS-XE-switch:access><vlan><vlan> ~~ any(ranges($inspection))
}
sub ranges($range-list) {
    $range-list.split(',').map({ /(\d+)['-'(\d+)]?/; $1 ?? (+$0 .. +$1) !! +$0 })
}
```

If `ArpInspection` matches 1 time and `GigabitEthernet` matches 4 times, then it will be
called `1 * 4 = 4` times (the most typical use here is to pick out sections to match up
with some global value).

## The command line interface

Once installed, run with:

```
jsonhound RuleFile.pm6 file1.json file2.json
```

To run it within the repository (e.g. for development), do:

```
perl6 -Ilib bin/jsonhound RuleFile.pm file1.json file2.json
```

If more than one JSON input file is specified, then they will be parsed and validated
in parallel.

## Running with Docker

You can also run the tool with docker directly from the git checkout
without installing perl6 locally.


```
docker-compose build
docker-compose run jsonhound examples/GigabitEthernetChecks.pm6 t/00-Switch1-OK.json
```
