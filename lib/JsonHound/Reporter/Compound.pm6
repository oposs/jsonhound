use JsonHound::Reporter;

#| Allows the use for multiple reporters, by delegating to them in turn.
#| For exit code, the first one providing an exit code wins.
class JsonHound::Reporter::Compound does JsonHound::Reporter {
    has JsonHound::Reporter @.reporters;

    method ok(Str $file --> Nil) {
        .ok($file) for @!reporters;
    }

    method file-error(Str $file, Str $problem --> Nil) {
        .file-error($file, $problem) for @!reporters;
    }

    method validation-error(Str $file, @violations --> Nil) {
        .validation-error($file, @violations) for @!reporters;
    }

    method finalize(--> Nil) {
        .finalize for @!reporters;
    }

    method exit-code(--> Int) {
        for @!reporters -> $reporter {
            .return with $reporter.exit-code;
        }
        return Int;
    }
}
