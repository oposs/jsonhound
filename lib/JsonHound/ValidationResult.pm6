use JsonHound::DebugMessage;
use JsonHound::Violation;

#| The results of a validation.
class JsonHound::ValidationResult {
    #| Any rule violations that were found.
    has JSONHound::Violation @.violations;

    #| Any debug messages that were produced.
    has JsonHound::DebugMessage @.debug-messages;
}
