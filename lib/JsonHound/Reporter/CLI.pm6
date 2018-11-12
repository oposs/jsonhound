use JSON::Fast;
use JsonHound::Reporter;
use Terminal::ANSIColor;

class JsonHound::Reporter::CLI does JsonHound::Reporter {
    has $!failed = False;

    method ok(Str $file --> Nil) {
        note "$file: " ~ colored("passed validation", "green");
    }

    method file-error(Str $file, Str $problem --> Nil) {
        note "$file: " ~ colored($problem, "red");
        $!failed = True;
    }

    method validation-error(Str $file, @violations --> Nil) {
        my $message = "$file: " ~ colored("failed validation\n", "red");
        for @violations -> $v {
            $message ~= "  " ~ colored("$v.name()", "underline") ~
                    " $v.file.IO.basename():$v.line()\n";
            for $v.arguments.sort(*.key).map(|*.kv) -> $name, $json {
                $message ~= colored("    $name: ", "bold");
                $message ~= colored("$json.path()\n", "blue");
                $message ~= to-json($json).indent(6) ~ "\n";
            }
        }
        note $message;
    }

    method exit-code(--> Int) {
        $!failed ?? 1 !! 0
    }
}
