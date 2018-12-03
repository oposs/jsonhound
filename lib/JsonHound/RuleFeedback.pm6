#| Factors out the common information shared between various kinds
#| of validation rule feedback (e.g. violations and debug messages).
role JsonHound::RuleFeedback {
    #| The name of the rule that failed.
    has Str $.name is required;

    #| The file where the validation rule was declared.
    has Str $.file is required;

    #| The line where the validation rule was declared.
    has Int $.line is required;
}
