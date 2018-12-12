use Either;
use JsonHound;
use Test;

# Sample data to validate.
my $sample-document = {
    days => [
        { distance => 10, team => ['Dave', 'Doris'] },
        { distance => 12, team => ['Dave', 'Darya', 'Daniel', 'Doris'] },
        { distance => 9, team => ['Darya'] },
        { distance => 40, team => ['Dana', 'Darya'] },
    ]
}

my subset Short is json-path('$.days[*]') where { .<distance> < 10 };
my subset Long is json-path('$.days[*]') where { .<distance> > 25 };
my subset Small is json-path('$.days[*].team') where .elems <= 1;
my subset Large is json-path('$.days[*].team') where .elems >= 4;

{
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
}

{
    my $*JSON-HOUND-RULESET = JsonHound::RuleSet.new;
    validate "Out of range", -> Either[Short, Long] $day, Either[Small, Large] $team {
        False
    }
    my @violations = $*JSON-HOUND-RULESET.validate($sample-document).violations;
    is @violations.elems, 2 * 2, 'Multiple Either[...] types produce combinations';
    is @violations.grep({ so .arguments<Short> && .arguments<Small> }).elems, 1,
            'Found Short/Small combination';
    is @violations.grep({ so .arguments<Short> && .arguments<Large> }).elems, 1,
            'Found Short/Large combination';
    is @violations.grep({ so .arguments<Long> && .arguments<Small> }).elems, 1,
            'Found Long/Small combination';
    is @violations.grep({ so .arguments<Long> && .arguments<Large> }).elems, 1,
            'Found Long/Large combination';
}

{
    my constant ShortOrLong = Either[Short, Long];
    my $*JSON-HOUND-RULESET = JsonHound::RuleSet.new;
    validate "Out of range", -> ShortOrLong $day {
        False
    }

    my @violations = $*JSON-HOUND-RULESET.validate($sample-document).violations;
    is @violations.elems, 2, 'Got expected number of violations when using constant';
    is @violations.grep(?*.arguments<Short>).elems, 1,
            'Once matched Short when using constant';
    is @violations.grep(?*.arguments<Long>).elems, 1,
            'Once matched Long when using constant';
}

done-testing;
