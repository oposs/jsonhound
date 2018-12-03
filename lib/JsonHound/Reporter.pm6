#| A reporter presents validation results in some way. That might be output
#| to stdout/stderr, writing to syslog, or something else. A reporter may
#| also provide an exit code for the program.
role JsonHound::Reporter {
    #| Called when a file is validated successfully.
    method ok(Str $file, :@debug-messages --> Nil) { ... }

    #| Called when there is a problem with the file that prevents validation
    #| even being attempted.
    method file-error(Str $file, Str $problem --> Nil) { ... }

    #| Called when a file has validation errors.
    method validation-error(Str $file, @violations, :@debug-messages --> Nil) { ... }

    #| Called when all files have been processed, to finalize the results.
    #| By default, does nothing.
    method finalize(--> Nil) { }

    #| Called to obtain an exit code. If this reporter does not wish to
    #| contribute an exist code, it should simply not implement this method.
    method exit-code(--> Int) { Int }
}
