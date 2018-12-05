use Either;
use JsonHound;
use Test;

# Sample data to validate.
my $sample-document = {
    days => [
        { distance => 10, team => ['Dave', 'Dana'] },
        { distance => 12, team => ['Dave', 'Darya'] },
        { distance => 9, team => ['Darya'] },
        { distance => 40, team => ['Dana', 'Darya'] },
    ]
}

my subset Short is json-path('$.days[*]') where { .<distance> < 10 };
my subset Long is json-path('$.days[*]') where { .<distance> > 25 };

my $*JSON-HOUND-RULESET = JsonHound::RuleSet.new;
validate "Out of range", -> Either[Short, Long] $day {
    False
}

my @violations = $*JSON-HOUND-RULESET.validate($sample-document).violations;
is @violations.elems, 2, 'Got expected number of violations';
is @violations.grep(?*.arguments<Short>).elems, 1,
        'Once matched Short';
is @violations.grep(?*.arguments<Long>).elems, 1,
        'Once matched Long';

done-testing;
