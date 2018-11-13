unit module JsonHound;
use JsonHound::RuleSet;

#| Used to attach a JSON path to a meta-object.
my role JSONPath[:$json-path] {
    method json-path() { $json-path }
}

#| Annotates a `subset` type with a JSON Path expression, to restrict where
#| in the document it will match.
multi trait_mod:<is>(Mu:U $type, :$json-path! --> Nil) is export {
    $type.HOW does JSONPath[:$json-path];
}

#| Registers a validation, along with a name to use in reporting a failure
#| or a block that will produce a name. The C<&validator> argument should
#| take one or more parameters that are subset types that will perform
#| validation on the document.
sub validate($name where Str | Block, &validator --> Nil) is export {
    if $*JSON-HOUND-RULESET ~~ JsonHound::RuleSet {
        $*JSON-HOUND-RULESET.add-validation($name, &validator);
    }
    else {
        die "No JsonHound ruleset to register validation with\n" ~
                "(this module must be used with the jsonHound tool)"
    }
}

#| Reports data to be included in the validation rule description. Returns
#| False to ease writing validation rules.
sub report(*%values) is export {
    %*JSON-HOUND-REPORTED ,= %values;
    return False;
}
