use Test;
use JsonHound;
use JsonHound::Violation;

# Sample data to validate.
my $sample-document = {
    days => [
        { distance => 10, team => ['Dave', 'Dana'] },
        { distance => 12, team => ['Dave', 'Darya'] },
        { distance => 9, team => ['Darya'] },
        { distance => 40, team => ['Dana', 'Darya'] },
    ]
}

# Matcher and rules with data included in the names.
my subset Day is json-path('$.days[*]');
my $*JSON-HOUND-RULESET = JsonHound::RuleSet.new;
validate {"Maximum daily distance is 20, but got $:distance"}, -> Day $day {
    if $day<distance> > 20 {
        report distance => $day<distance>;
        False
    }
    else {
        True
    }
}
validate {"Must have a team of 2 or more (have $:who)"}, -> Day $day {
    if $day<team>.elems < 2 {
        report who => $day<team>[0] // 'nobody';
        False
    }
    else {
        True
    }
}
validate {"May forget $:something and not crash!"}, -> Day $day {
    report bogus => 'value';
    $day<distance> >= 10
}

# Check the violations are produced as expected, and problems warned about.
my $warning;
CONTROL {
    when CX::Warn {
        $warning ~= .Str;
        .resume;
    }
}
my @violations = $*JSON-HOUND-RULESET.validate($sample-document);
is @violations.elems, 3, 'Got the expected number of violations';
nok @violations.grep(* !~~ JSONHound::Violation),
        'All violations are instances of JsonHound::Violation';
is @violations.grep(*.name eq 'Maximum daily distance is 20, but got 40').elems, 1,
        'Produced name correctly (1)';
is @violations.grep(*.name eq 'Must have a team of 2 or more (have Darya)').elems, 1,
        'Produced name correctly (2)';
is @violations.grep(*.name eq 'May forget <MISSING> and not crash!').elems, 1,
        'If reported data is missing, we still report the rule failure';
like $warning, /something/, 'Got warning about missing reported data';
like $warning, /bogus/, 'Got warning about unexpected reported data';

done-testing;
