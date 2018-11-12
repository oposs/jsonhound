use JsonHound::Reporter;

class JsonHound::Reporter::Nagios does JsonHound::Reporter {
    has @!problems;

    method ok(Str $file --> Nil) {
        # Nothing to do
    }

    method file-error(Str $file, Str $problem --> Nil) {
        push @!problems, "$file: $problem";
    }

    method validation-error(Str $file, @violations --> Nil) {
        for @violations -> $v {
            push @!problems, "$file: $v.name()";
        }
    }

    method finalize(--> Nil) {
        if @!problems {
            say "Validation failed";
            .say for @!problems;
        }
        else {
            say "Validation passed";
        }
    }

    method exit-code(--> Int) {
        @!problems ?? 1 !! 0
    }
}
