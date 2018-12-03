use JSON::Fast;
use JsonHound::Reporter;
use Terminal::ANSIColor;

class JsonHound::Reporter::CLI does JsonHound::Reporter {
    has $!failed = False;

    method ok(Str $file, :@debug-messages --> Nil) {
        my $message = "$file: " ~ colored("passed validation", "green");
        if @debug-messages {
            $message ~= "\n";
            for @debug-messages.categorize(*.name) -> (:key($name), :value(@messages)) {
                my $first = @messages[0];
                $message ~= "  " ~ colored("$name", "underline") ~
                        " $first.file.IO.basename():$first.line()\n";
                for @messages {
                    $message ~= colored("    $_.message()\n", "yellow");
                }
            }
        }
        note $message;
    }

    method file-error(Str $file, Str $problem --> Nil) {
        note "$file: " ~ colored($problem, "red");
        $!failed = True;
    }

    method validation-error(Str $file, @violations, :@debug-messages --> Nil) {
        my $message = "$file: " ~ colored("failed validation\n", "red");
        my %debugs = @debug-messages.categorize(*.name);
        for @violations -> $v {
            $message ~= "  " ~ colored("$v.name()", "underline") ~
                    " $v.file.IO.basename():$v.line()\n";
            with %debugs{$v.name} -> @messages {
                for @messages {
                    $message ~= colored("    $_.message()\n", "yellow");
                }
            }
            %debugs{$v.name}:delete;
            for $v.arguments.sort(*.key).map(|*.kv) -> $name, $json {
                $message ~= colored("    $name: ", "bold");
                $message ~= colored("$json.path()\n", "blue");
                $message ~= to-json($json).indent(6) ~ "\n";
            }
        }
        for %debugs.kv -> $name, @messages {
            my $first = @messages[0];
            $message ~= "  " ~ colored("$name", "underline") ~
                    " $first.file.IO.basename():$first.line()\n";
            for @messages {
                $message ~= colored("    $_.message()\n", "yellow");
            }
        }

        note $message;
    }

    method exit-code(--> Int) {
        $!failed ?? 1 !! 0
    }
}
