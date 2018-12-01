use JsonHound::RuleFeedback;

#| Details of a validation rules violation.
class JSONHound::Violation does JsonHound::RuleFeedback {
    #| Mapping of the name of the identified subest taken as a parameter in
    #| the failing rule to the JSON that was unacceptable.
    has %.arguments;
}
