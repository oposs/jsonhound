use Test;
use JsonHound;
use JsonHound::Violation;

# A document to test against.
my $sample-document = {
    switch_ports => [
        { name => 'p0' },
        { name => 'p1', vlan => 12 },
        { name => 'p2', vlan => 15, problem => 1 },
        { name => 'p3', vlan => 13 },
        { name => 'p4', vlan => 30 },
        { name => 'p5', vlan => 42, problem => 1 }
    ]
}

my subset VLanUsage is json-path('$.switch_ports[*]') where .<vlan>:exists;
my subset KnownVLan of VLanUsage where .<vlan> <= 30;

my $*JSON-HOUND-RULESET = JsonHound::RuleSet.new;
validate 'Problem on known vlan', -> KnownVLan $port {
    not $port<problem>:exists
}

my @violations = $*JSON-HOUND-RULESET.validate($sample-document).violations;
is @violations.elems, 1, 'Only one violation found';
given @violations[0] {
    isa-ok $_, JSONHound::Violation, 'Got a violation object';
    is .arguments<KnownVLan><vlan>, 15, 'Expected violation was found';
}

done-testing;
