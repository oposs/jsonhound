use JsonHound::RuleFeedback;

#| A debug message produced during validation.
class JsonHound::DebugMessage does JsonHound::RuleFeedback {
    #| The debug message.
    has Str $.message is required;
}
