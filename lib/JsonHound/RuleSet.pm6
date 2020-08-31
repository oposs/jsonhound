use Either;
use JSON::Path;
use JsonHound::DebugMode;
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
        has @.identifiers is required;

        #| Runs the validation on the identified data items, pushing any violations
        #| on to the passed violations array.
        method add-violations(%identified, @violations, @debug-messages,
                JsonHound::DebugMode :$debug! --> Nil) {
            my @arg-tuples = @!identifiers.elems == 1
                    ?? %identified{@!identifiers[0]}.map({ ($_,) })
                    !! [X] %identified{@!identifiers}.map(*.list);
            for @arg-tuples -> @args {
                my %*JSON-HOUND-REPORTED;
                my $*JSON-HOUND-DEBUG = $debug == None ?? Nil !! [];
                my $success = &!validator(|@args);
                my $need-debug = $debug == All || $debug == Failed && !$success;
                if $need-debug || !$success {
                    my $name = generate-name(&!name, &!validator, %*JSON-HOUND-REPORTED);
                    my $line = &!validator.line;
                    my $file = &!validator.file;
                    unless $success {
                        my %arguments = @!identifiers.map(*.^name) Z=> @args;
                        push @violations, JSONHound::Violation.new:
                                :$name, :%arguments, :file($file),
                                :line($line);
                    }
                    if $need-debug {
                        append @debug-messages, $*JSON-HOUND-DEBUG.map: -> $message {
                            JsonHound::DebugMessage.new: :$name, :$line, :$file, :$message
                        }
                    }
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

    #| Adds a validator to the rule set with a literal name.
    multi method add-validation(Str $name, &validator --> Nil) {
        self.add-validation(-> { $name }, &validator);
    }

    #| Adds a validator to the rule set with a name to be filled with reported
    #| data.
    multi method add-validation(&name, &validator --> Nil) {
        for self!extract-identifier-lists(&name, &validator) -> @identifiers {
            my $validation = Validation.new(:&name, :&validator, :@identifiers);
            for $validation.identifiers {
                %!identifiers{$_} = True;
                with self!find-json-path($_) -> $json-path {
                    %!json-path-cache{$json-path} //= JSON::Path.new($json-path);
                }
            }
            @!validations.push($validation);
        }
    }

    method !extract-identifier-lists(&name, &validator) {
        my @identifiers-combinations;
        for &validator.signature.params -> Parameter $param {
            my $constraint = $param.constraint_list[0];
            my @possibles;
            collect-possibles(&name, &validator, $constraint, @possibles, $param);
            push @identifiers-combinations, @possibles;
        }
        return @identifiers-combinations.elems == 1
                ?? @identifiers-combinations[0].map({ [$_] })
                !! [X](@identifiers-combinations);
    }

    sub collect-possibles(&name, &validator, $constraint, @possibles, $param) {
        if $constraint.isa(Either) {
            for $constraint.either-types {
                collect-possibles(&name, &validator, $_, @possibles, $param);
            }
        }
        elsif $constraint.HOW ~~ Metamodel::SubsetHOW {
            push @possibles, $constraint;
        }
        else {
            my $name = quietly generate-name(&name, &validator, {});
            die "Validation rule '$name' parameter '$param.name()' must " ~
                    "have an identifier type specified as a Raku subset type";
        }
    }

    sub generate-name(&name, &validator, %reported) {
        # Detect and warn about any mismatch, and then report.
        my @required = &name.signature.params.map(|*.named_names);
        my @got = keys %reported;
        if @required (-) @got -> %missing {
            warn-name(&validator, "missing %missing.keys().join(', ')");
        }
        if @got (-) @required -> %unwanted {
            warn-name(&validator, "unexpected %unwanted.keys().join(', ')");
        }
        name(|%( @required Z=> %reported{@required}.map({ $_ // '<MISSING>' }) ))
    }

    sub warn-name(&validator, $error --> Nil) {
        warn "Encountered $error when generating name for validation rule at " ~
                "&validator.file():&validator.line()"
    }

    #| Runs the validations, and returns a validation result.
    method validate($document, JsonHound::DebugMode :$debug = None --> JsonHound::ValidationResult) {
        my %identified := self!match-all-identifiers-in($document);
        my @violations;
        my @debug-messages;
        for @!validations -> $rule {
            $rule.add-violations(%identified, @violations, @debug-messages, :$debug)
        }
        return JsonHound::ValidationResult.new(:@violations, :@debug-messages);
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
