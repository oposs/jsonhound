# jsonHound [![Build Status](https://travis-ci.org/oposs/jsonhound.svg?branch=master)](https://travis-ci.org/oposs/jsonhound)
*a system for parsing JSON data structures and identifying anomalies* 

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

It is possible on report extra information by placing it into the validation rule's name.
This is done by:

1. Passing a block that takes named parameters and uses them to build up the name of the
   rule, which will then be reported. It's neatest to do this using the `$:name` named
   parameter placeholder syntax.
2. In case of validation failure, providing arguments for use in that reporting by passing
   them to the `report` function.

For example:

```
validate {"Wrong reauthentication value (was $:value)"}, -> Authentication $auth {
    my $value = $auth<timer><reauthenticate><value>;
    if $value == 1800 {
        True
    }
    else {
        report :$value;
        False
    }
}
```

However, since `report` returns `False`, simple rules like this may instead be written
as simply:

```
validate {"Wrong reauthentication value (was $:value)"}, -> Authentication $auth {
    my $value = $auth<timer><reauthenticate><value>;
    $value == 1800 or report :$value
}
```

It is allowed to have multiple such parameters, which may be provided with a single
call to `report` or multiple calls to `report` over time. Do as is most comfortable
for the rule being implemented.

## Disjunctions of identifiers

It's possible to use the `Either[...]` construct to produce a disjunction of two
or more identifiers. For example, given:

```
subset MegabitEthernet
        is json-path(q[$['Cisco-IOS-XE-native:native'].interface.MegabitEthernet[*]]);
subset GigabitEthernet
        is json-path(q[$['Cisco-IOS-XE-native:native'].interface.GigabitEthernet[*]]);
```

One could write a validation rule that applies to either by doing:

```
validate 'Ethernet correctly configured', -> Either[MegabitEthernet, GigabitEthernet] $eth {
    ...
}
```

If the same `Either` expression would be repeated multiple times, it may be factored
out by declaring a `constant`:

```
my constant Ethernet = Either[MegabitEthernet, GigabitEthernet];

validate 'Ethernet correctly configured', -> Ethernet $eth {
    ...
}
```

A validation rule using multiple `Either` types will be invoked for all
permutations of matches, as is usually the case with multi-parameter rules.

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

The default is to send a report to STDERR and to exit with 0 if all validation rule
passed, or 1 if there is a validation rule failure. However, this can be controlled
by passing the `--reporter=...` command line option. Valid options are:

* `cli` - the default human-friendly output to STDERR, with exit code 0 or 1 as
  appropriate
* `nagios` - Nagios plugin output and exit code
* `syslog` - Report any validation rule failures to syslog as warnings; has no
  impact on exit code

It is allowed to combine these by listing them comma-separated. However, note that
**the first reporter that provides an exit code will be the one that gets to decide
the exit code**. Thus this:

```
perl6 -Ilib bin/jsonhound --reporter=nagios,cli,syslog RuleFile.pm file1.json
```

Is probably correct (the `nagios` reporter controls the exit code), while:

```
perl6 -Ilib bin/jsonhound --reporter=cli,nagios,syslog RuleFile.pm file1.json
```

Is probably not what's wanted (however, in this case one would probably also get
away with it, in so far as `0` and `1` are quite sensible exit codes for a Nagios
plugin anyway).

## Debug messages

To produce a debug message in a validation rule, call `debug` and pass the
message (whatever is passed will be coerced to a string, if it is not one
already).

```
validate 'Missing global DHCP snooping', -> ArpInspection $inspection, GigabitEthernet $ge {
    my $vlan = $ge<switchport><Cisco-IOS-XE-switch:access><vlan><vlan>;
    debug "VLan is $vlan";
    $vlan ~~ any(ranges($inspection))
}
```

By default, these are not reported. However, they can be reported by the
`cli` reporter by passing `--debug=failed` (only report debug output from
failed validation rules) or `--debug=all` (report all debug output).

## Running with Docker

You can also run the tool with docker directly from the git checkout
without installing perl6 locally.


```
docker-compose build
docker-compose run jsonhound examples/GigabitEthernetChecks.pm6 t/00-Switch1-OK.json
```
