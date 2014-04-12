
Debugger v1.0 by Solistra
==============================================================================

Summary
------------------------------------------------------------------------------
  This script provides a simple debugger with break point functionality using
the SES Tracer and SES Console. Essentially, you establish a series of break
points on specific lines within scripts in the Ace Script Editor -- when the
line is encountered, execution stops and the SES Console is opened with the
active class at the time of the break as the context. This is primarily a
scripter's tool.

Usage
------------------------------------------------------------------------------
  The debugger may be started by pressing F6 (by default -- this is able to be
configured in the configuration area) or by explicitly starting it through the
SES Console or a script call:

    SES::Debugger.start

  Once the debugger has started, it will trace Ruby code execution until one
of the configured break points has been encountered. Once a break point is
reached, execution is halted and control is handed to you through the SES
Console. See the documentation for the SES Console script for more information
about the console itself.

  You may stop the debugger at any time while it is running by simply entering
the following either through the SES Console or a script call:

    SES::Debugger.stop

  Break points are stored as a hash in the SES::Debugger module (aptly named
"@breakpoints"). The instance variable storing the hash is defined as a reader
method for the module, allowing you to dynamically add, remove, or modify the
breakpoints during game execution. Break points are defined within the hash
with the file name of the script as the key and an array of line numbers to
serve as break points as the value.

  For example, let's assume that we want to break every time Scene_Base is
told to update. In order to set up that break point, we could do one of two
things (depending on when we need the break point set): we can either include
the break point in the configuration area of the script, or we can set the
point dynamically at some point during the game's execution (either through
a REPL -- such as the console -- or a script call). The following demonstrates
both methods:

    # Configuration area.
    @breakpoints = {
      'Scene_Base' => [40],
    }
    
    # Dynamically adding the break point.
    SES::Debugger.breakpoints['Scene_Base'] = [40]

  If we then decide that we need to break whenever Scene_Base performs a basic
update, we can either add line 46 to the configuration area or add it during
runtime like so:

    SES::Debugger.breakpoints['Scene_Base'].push(46)

License
------------------------------------------------------------------------------
  This script is made available under the terms of the MIT Expat license. View
[this page](http://sesvxace.wordpress.com/license/) for more information.

Installation
------------------------------------------------------------------------------
  This script requires the SES Core (v2.0), Tracer (v1.2), and Console (v1.0)
scripts in order to function. All of these scripts may be found at the
[SES VX Ace](http://sesvxace.wordpress.com/category/script-release) site.

  Place this script below Materials, but above Main. Place this script below
the SES Core, SES Console, and SES Tracer, but above all other custom scripts.

