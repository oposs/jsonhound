#| Details of a validation rules violation.
class JSONHound::Violation {
    #| The name of the rule that failed.
    has Str $.name is required;

    #| Mapping of the name of the identified subest taken as a parameter in
    #| the failing rule to the JSON that was unacceptable.
    has %.arguments;
}
