use Test;
use JsonHound;
use JsonHound::Violation;

# A document to test against.
my $sample-document = {
    products => [
        { name => 'Foo', available => True, stock => 5 },
        { name => 'bar', available => False, stock => 0 },
        { name => 'Baz', available => True, stock => 0 },
        { name => 'Wat', available => True, stock => 0 }
    ]
}

# A couple of simple matching rules.
my subset Product is json-path('$.products[*]');
my subset AvailableProduct is json-path('$.products[*]') where .<available>;

# Add the rules (they are added contextually to the dynamic variable).
my $*JSON-HOUND-RULESET = JsonHound::RuleSet.new;
validate 'Titlecased names', -> Product $product {
    so $product<name> ~~ /^<:Lu>/
}
validate 'Available is in stock', -> AvailableProduct $product {
    $product<stock> > 0
}

# Check the violations are as expected.
my @violations = $*JSON-HOUND-RULESET.validate($sample-document);
is @violations.elems, 3, 'Got the expected number of violations';
nok @violations.grep(* !~~ JSONHound::Violation),
        'All violations are instances of JsonHound::Violation';
is @violations.grep(*.name eq 'Titlecased names').elems, 1,
        'One violation of titlecased names rule';
is @violations.grep(*.name eq 'Available is in stock').elems, 2,
        'Two violations of available is in stock rule';
given @violations.first(*.name eq 'Titlecased names') {
    is-deeply .arguments, { Product => { name => 'bar', available => False, stock => 0 } },
            'Arguments to failing rule correctly provided';
}

done-testing;
