#| Details of a validation rules violation.
class JSONHound::Violation {
    #| The name of the rule that failed.
    has Str $.name is required;

    #| The file where the validation rule was declared.
    has Str $.file is required;

    #| The line where the validation rule was declared.
    has Int $.line is required;

    #| Mapping of the name of the identified subest taken as a parameter in
    #| the failing rule to the JSON that was unacceptable.
    has %.arguments;
}
