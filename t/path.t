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

# Add the rules (they are added contextually to the dynamic variable).
my $*JSON-HOUND-RULESET = JsonHound::RuleSet.new;
validate 'Path with index 1 not present', -> Product $product {
    so $product.path ~~ /^ '$.products[' <[023]> ']' $/
}

# Check the violations are as expected.
my @violations = $*JSON-HOUND-RULESET.validate($sample-document).violations;
is @violations.elems, 1, 'Got the expected number of violations';
given @violations[0] {
    isa-ok $_, JSONHound::Violation, 'Violation based on checking path worked';
    is .name, 'Path with index 1 not present', 'Correct violation name';
    is .arguments<Product><name>, 'bar', 'Correct argument';
    is .arguments<Product>.path, '$.products[1]', 'Correct path';
}

done-testing;
