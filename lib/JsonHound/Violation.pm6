#| Details of a validation rules violation.
class JSONHound::Violation {
    #| The name of the rule that failed.
    has Str $.name is required;
}
