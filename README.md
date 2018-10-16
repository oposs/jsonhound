# jsonHound
*a system for parsing JSON data structures and identifying anomalies*

While the name and the structure of this tool is very generic, it was built for a highly specific purpose:
Modern Cisco Switches allow export of their configuration in JSON format. The purpose of the jsonHound is
to identify misconfiguration of the switches. It does that by identifying *interesting* data structures,
like interfaces, and then choosing a set of checks to verify that they are properly configured. The
checks are chosen by looking at features of the interface or the configuration as a whole. For example,
if an interface is part of VLAN 643 we *know* that this is part of your IP Telefony VLAN and will thus
require a particular set of configuration options to be active.

The configuration of the jsonHound works on 3 levels.

* level 1 identifies the 'interesting structures'
* level 2 applies a set of checks to these structures
* level 3 consist of programming custom checkers which can then be used in level 2

JsonHound is written in Perl6.
