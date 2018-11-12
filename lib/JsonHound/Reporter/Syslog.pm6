use JsonHound::Reporter;
use Log::Syslog::Native;

class JsonHound::Reporter::Syslog does JsonHound::Reporter {
    has Log::Syslog::Native $!syslog .= new(:ident<jsonhound>);

    method ok(Str $file --> Nil) { }

    method file-error(Str $file, Str $problem --> Nil) {
        $!syslog.warning("$file: $problem")
    }

    method validation-error(Str $file, @violations --> Nil) {
        for @violations -> $v {
            $!syslog.warning("$file: $v.name()");
        }
    }
}
