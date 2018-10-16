use JSON::Path;
use JsonHound::Violation;

#| A set of validation rules to apply to the document, along with logic
#| to apply them. Once the set of validations has been established, and
#| no longer changes, it is safe to call C<validate> concurrently.
class JsonHound::RuleSet {
    #| A single validation.
    my class Validation {
        has $.name is required;
        has &.validator is required;
        has @.identifiers;

        submethod TWEAK() {
            for &!validator.signature.params -> Parameter $param {
                my $constraint = $param.constraint_list[0];
                if $constraint.HOW ~~ Metamodel::SubsetHOW {
                    push @!identifiers, $constraint;
                }
                else {
                    die "Validation rule '$!name' parameter '$param.name()' must " ~
                            "have an identifier type specified as a Perl 6 subset type";
                }
            }
        }

        #| Runs the validation on the identified data items, pushing any violations
        #| on to the passed violations array.
        method add-violations(%identified, @violations) {
            my @arg-tuples = @!identifiers.elems == 1
                    ?? %identified{@!identifiers[0]}.map({ ($_,) })
                    !! [X] %identified{@!identifiers}.map(*.list);
            for @arg-tuples -> @args {
                unless &!validator(|@args) {
                    push @violations, JSONHound::Violation.new(:$!name);
                }
            }
        }
    }

    #| The validations to perform.
    has Validation @!validations;

    #| The set of identifiers that are used.
    has %!identifiers is SetHash;

    #| Cache of compiled JSON::Path objects.
    has %!json-path-cache;

    #| Adds a validator to the rule set.
    method add-validation(Str $name, &validator --> Nil) {
        my $validation = Validation.new(:$name, :&validator);
        for $validation.identifiers {
            %!identifiers{$_} = True;
            with .HOW.?json-path -> $json-path {
                %!json-path-cache{$json-path} //= JSON::Path.new($json-path);
            }
        }
        @!validations.push($validation);
    }

    #| Runs the validations, and returns a list of violations.
    method validate($document --> Array) {
        my %identified := self!match-all-identifiers-in($document);
        my @violations;
        for @!validations -> $rule {
            $rule.add-violations(%identified, @violations)
        }
        @violations
    }

    #| Takes a parsed JSON document and identifies all of the places that the given
    #| identifier types match.
    method !match-all-identifiers-in($document) {
        my %found{Mu};
        for %!identifiers.keys -> $type {
            %found{$type} = self!match-identifier-in($type, $document);
        }
        return %found;
    }

    #| Takes a parsed JSON document and matches a given identifier type in it.
    method !match-identifier-in($type, $document --> List) {
        with $type.HOW.?json-path -> $json-path {
            eager %!json-path-cache{$json-path}.values($document).grep($type)
        }
        else {
            !!! "NYI non-json-path case of subset"
        }
    }
}
