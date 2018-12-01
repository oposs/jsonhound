use Test;
use JsonHound;
use JsonHound::DebugMessage;
use JsonHound::DebugMode;

# Sample data to validate.
my $sample-document = {
    days => [
        { distance => 10, team => ['Dave', 'Dana'] },
        { distance => 12, team => ['Dave', 'Darya'] },
        { distance => 9, team => ['Darya'] },
        { distance => 40, team => ['Dana', 'Darya'] },
    ]
}

my subset Day is json-path('$.days[*]');
my $*JSON-HOUND-RULESET = JsonHound::RuleSet.new;
validate "Maximum daily distance is 20", -> Day $day {
    debug "Distance is $day<distance>";
    $day<distance> <= 20
}
validate "Must have a team of 2 or more", -> Day $day {
    debug "Team has $day<team>.elems() member(s)";
    $day<team>.elems >= 2
}

given $*JSON-HOUND-RULESET.validate($sample-document, :debug(None)) {
    is .debug-messages.elems, 0, 'No debug messages when debug mode is None';
}

given $*JSON-HOUND-RULESET.validate($sample-document, :debug(Failed)) {
    is .debug-messages.elems, 2,
            'In Failed mode, debug messages from failing rules';
    given .debug-messages.sort(*.name) {
        is .[0].name, "Maximum daily distance is 20",
                'First debug message from correct rule';
        is .[0].message, "Distance is 40",
                'First debug messages has correct text';
        is .[1].name, "Must have a team of 2 or more",
                'Second debug message from correct rule';
        is .[1].message, "Team has 1 member(s)",
                'Second debug messages has correct text';
    }
}

given $*JSON-HOUND-RULESET.validate($sample-document, :debug(All)) {
    is .debug-messages.elems, 8,
            'In All mode, debug messages even from passing rules';
}

done-testing;
