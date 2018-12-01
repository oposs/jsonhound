use JSON::Path;
use JsonHound::PathMixin;
use JsonHound::ValidationResult;
use JsonHound::Violation;

#| A set of validation rules to apply to the document, along with logic
#| to apply them. Once the set of validations has been established, and
#| no longer changes, it is safe to call C<validate> concurrently.
class JsonHound::RuleSet {
    #| A single validation.
    my class Validation {
        has &.name is required;
        has &.validator is required;
        has @.identifiers;

        submethod TWEAK() {
            for &!validator.signature.params -> Parameter $param {
                my $constraint = $param.constraint_list[0];
                if $constraint.HOW ~~ Metamodel::SubsetHOW {
                    push @!identifiers, $constraint;
                }
                else {
                    my $name = quietly self!generate-name({});
                    die "Validation rule '$name' parameter '$param.name()' must " ~
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
                my %*JSON-HOUND-REPORTED;
                unless &!validator(|@args) {
                    my $name = self!generate-name(%*JSON-HOUND-REPORTED);
                    my %arguments = @!identifiers.map(*.^name) Z=> @args;
                    push @violations, JSONHound::Violation.new:
                            :$name, :%arguments, :file(&!validator.file),
                            :line(&!validator.line);
                }
            }
        }

        method !generate-name(%reported) {
            # Detect and warn about any mismatch, and then report.
            my @required = &!name.signature.params.map(|*.named_names);
            my @got = keys %reported;
            if @required (-) @got -> %missing {
                self!warn-name("missing %missing.keys().join(', ')");
            }
            if @got (-) @required -> %unwanted {
                self!warn-name("unexpected %unwanted.keys().join(', ')");
            }
            &!name(|%( @required Z=> %reported{@required}.map({ $_ // '<MISSING>' }) ))
        }

        method !warn-name($error --> Nil) {
            warn "Encountered $error when generating name for validation rule at " ~
                    "&!validator.file():&!validator.line()"
        }
    }

    #| The validations to perform.
    has Validation @!validations;

    #| The set of identifiers that are used.
    has %!identifiers is SetHash;

    #| Cache of compiled JSON::Path objects.
    has %!json-path-cache;

    #| Adds a validator to the rule set with a literal name.
    multi method add-validation(Str $name, &validator --> Nil) {
        self.add-validation(-> { $name }, &validator);
    }

    #| Adds a validator to the rule set with a name to be filled with reported
    #| data.
    multi method add-validation(&name, &validator --> Nil) {
        my $validation = Validation.new(:&name, :&validator);
        for $validation.identifiers {
            %!identifiers{$_} = True;
            with self!find-json-path($_) -> $json-path {
                %!json-path-cache{$json-path} //= JSON::Path.new($json-path);
            }
        }
        @!validations.push($validation);
    }

    #| Runs the validations, and returns a validation result.
    method validate($document --> JsonHound::ValidationResult) {
        my %identified := self!match-all-identifiers-in($document);
        my @violations;
        for @!validations -> $rule {
            $rule.add-violations(%identified, @violations)
        }
        return JsonHound::ValidationResult.new(:@violations);
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
        with self!find-json-path($type) -> $json-path {
            eager %!json-path-cache{$json-path}.paths-and-values($document)
                    .map(-> $path, $value { $value but JsonHound::PathMixin($path) })
                    .grep($type)
        }
        else {
            !!! "NYI non-json-path case of subset"
        }
    }

    #| Takes a subset type and finds the nearest json-path trait value, if
    #| any.
    method !find-json-path($type is copy) {
        while $type.HOW ~~ Metamodel::SubsetHOW {
            .return with $type.HOW.?json-path;
            $type = $type.^refinee;
        }
        return Nil;
    }
}
