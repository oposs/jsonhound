use Test;
use JsonHound;
use JsonHound::Violation;

# A document to test against.
my $sample-document = {
    inspections => { vlan => '10-13,20-40' },
    switch_ports => [
        { name => 'p0' },
        { name => 'p1', vlan => 12 },
        { name => 'p2', vlan => 15 },
        { name => 'p3', vlan => 13 },
        { name => 'p4', vlan => 30 },
        { name => 'p5', vlan => 42 }
    ]
}

# Identifiers for the inspection vlan and the switches.
my subset VLanInspection is json-path('$.inspections.vlan');
my subset VLanUsage is json-path('$.switch_ports[*]') where .<vlan>:exists;

# Rule that depends on both of these.
my $*JSON-HOUND-RULESET = JsonHound::RuleSet.new;
validate 'VLan in range', -> VLanInspection $inspection, VLanUsage $usage {
    $usage<vlan> (elem) any(ranges($inspection))
}
sub ranges($range-list) {
    $range-list.split(',').map({ /(\d+)['-'(\d+)]?/; +$0 .. +($1 // $0) })
}

# Check the violations are as expected.
my @violations = $*JSON-HOUND-RULESET.validate($sample-document);
is @violations.elems, 2, 'Correct number of violations detected';
nok @violations.grep(* !~~ JSONHound::Violation),
        'All violations are instances of JsonHound::Violation';
is @violations.map(*.arguments<VLanUsage>.<vlan>).sort, (15, 42),
        'Correct elements identified as not matching';

done-testing;
