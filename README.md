
Debugger v1.3 by Solistra
=============================================================================

Summary
-----------------------------------------------------------------------------
  This script provides a simple debugger with break point functionality using
the SES Console. Essentially, you establish a series of break points on
specific lines within scripts in the Ace Script Editor -- when the line is
encountered, execution stops and the SES Console is opened with the active
class at the time of the break as the context. This is primarily a scripter's
tool.

Usage
-----------------------------------------------------------------------------
  The debugger may be started by pressing F6 (by default -- this is able to
be configured in the configuration area) or by explicitly starting it through 
the SES Console or a script call:

    SES::Debugger.start

  Once the debugger has started, it will trace Ruby code execution until one
of the configured break points has been encountered. Once a break point is
reached, execution is halted and control is handed to you through the SES
Console. See the documentation for the SES Console script for more detailed
information about the console itself.

  You may stop the debugger at any time while it is running by entering the
following either through the SES Console or a script call:

    SES::Debugger.stop

  Break points are set using the debugger by specifying the desired class or
module and method which should act as a trigger using a string written in the
Ruby standard notation for class and instance methods. For example, adding a
break point for the `update` instance method of `Scene_Base` is specified
with `'Scene_Base#update'`, while the `return` class method of `SceneManager`
is specified with `'SceneManager.return'`.

  **NOTE:** It is perfectly valid to include break points for objects defined
in scripts that have been included below the debugger.

  For example, let's assume that we want to break every time `Scene_Base` is
told to update. In order to set up that break point, we could do one of two
things (depending on when we need the break point set): we can either include
the break point in the configuration area of the script, or we can set the
point dynamically at some point during the game's execution (either through
a REPL -- such as the console -- or a script call). The following examples
demonstrate both methods:

    # Configuration area.
    @breakpoints = [
      'Scene_Base#update',
    ]
    
    # Dynamically adding the break point.
    SES::Debugger.add('Scene_Base#update')
    
    # Alternative syntax for dynamically adding a break point.
    SES::Debugger << 'Scene_Base#update'

  Note that you can also add multiple break points at once if desired:

    SES::Debugger.add('Scene_Base#update', 'SceneManager.return', ...)

  Since version 1.3 of the SES Debugger, you may also dynamically set break
points in your code via the `Kernel#breakpoint` method which will create a
break point for the line where the method call was placed. This is
particularly useful when debugging your own code and you only require break
points for temporary testing purposes.

  **NOTE**: Using the `Kernel#breakpoint` method does not automatically start
the SES Debugger when the method is encountered -- it simply creates the
break point. It is still up to you to enable debugging when you require it.

License
-----------------------------------------------------------------------------
  This script is made available under the terms of the MIT Expat license.
View [this page](http://sesvxace.wordpress.com/license/) for more detailed
information.

Installation
-----------------------------------------------------------------------------
  This script requires the SES Core (v2.0) and SES Console (v1.6) scripts in
order to function. Both of these scripts may be found in the SES source
repository at the following locations:

* [Core](https://raw.github.com/sesvxace/core/master/lib/core.rb)
* [Console](https://raw.github.com/sesvxace/console/master/lib/console.rb)

Place this script below Materials, but above Main. Place this script below
the SES Core and SES Console, but above other custom scripts.

