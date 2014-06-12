#--
# Debugger v1.2 by Solistra
# =============================================================================
# 
# Summary
# -----------------------------------------------------------------------------
#   This script provides a simple debugger with break point functionality using
# the SES Console. Essentially, you establish a series of break points on
# specific lines within scripts in the Ace Script Editor -- when the line is
# encountered, execution stops and the SES Console is opened with the active
# class at the time of the break as the context. This is primarily a scripter's
# tool.
# 
# Usage
# -----------------------------------------------------------------------------
#   The debugger may be started by pressing F6 (by default -- this is able to
# be configured in the configuration area) or by explicitly starting it through 
# the SES Console or a script call:
# 
#     SES::Debugger.start
# 
#   Once the debugger has started, it will trace Ruby code execution until one
# of the configured break points has been encountered. Once a break point is
# reached, execution is halted and control is handed to you through the SES
# Console. See the documentation for the SES Console script for more detailed
# information about the console itself.
# 
#   You may stop the debugger at any time while it is running by entering the
# following either through the SES Console or a script call:
# 
#     SES::Debugger.stop
# 
#   Break points are stored as a hash in the SES::Debugger module (aptly named
# "@breakpoints"). The instance variable storing the hash is also a reader
# method for the module, allowing you to dynamically add, remove, or modify the
# breakpoints during game execution. Break points are defined within the hash
# with the file name of the script as the key and an array of line numbers to
# serve as break points as the value.
# 
#   For example, let's assume that we want to break every time Scene_Base is
# told to update. In order to set up that break point, we could do one of two
# things (depending on when we need the break point set): we can either include
# the break point in the configuration area of the script, or we can set the
# point dynamically at some point during the game's execution (either through
# a REPL -- such as the console -- or a script call). The following examples
# demonstrate both methods:
# 
#     # Configuration area.
#     @breakpoints = {
#       'Scene_Base' => [40],
#     }
#     
#     # Dynamically adding the break point.
#     SES::Debugger.breakpoints['Scene_Base'] = [40]
# 
#   If we then decide that we need to break whenever Scene_Base performs a
# basic update, we can either add line 46 to the configuration area or add it
# during runtime like so:
# 
#     SES::Debugger.breakpoints['Scene_Base'].push(46)
# 
# License
# -----------------------------------------------------------------------------
#   This script is made available under the terms of the MIT Expat license.
# View [this page](http://sesvxace.wordpress.com/license/) for more detailed
# information.
# 
# Installation
# -----------------------------------------------------------------------------
#   This script requires the SES Core (v2.0) and SES Console (v1.0) scripts in
# order to function. Both of these scripts may be found in the SES source
# repository at the following locations:
# 
# * [Core](https://raw.github.com/sesvxace/core/master/lib/core.rb)
# * [Console](https://raw.github.com/sesvxace/console/master/lib/console.rb)
# 
# Place this script below Materials, but above Main. Place this script below
# the SES Core and SES Console, but above other custom scripts.
# 
#++
module SES
  # ===========================================================================
  # Debugger
  # ===========================================================================
  # Provides a simple debugger with break points, halting of game execution,
  # and contextual awareness.
  module Debugger
    class << self
      attr_accessor :code_lines
      attr_reader   :breakpoints
    end
      
    # Ensure that we have the minimum script requirements.
    Register.require(:Core => 2.0, :Console => 1.0)
    # =========================================================================
    # BEGIN CONFIGURATION
    # =========================================================================
    # The Input module constant to use for enabling the debugger.
    TRIGGER = Input::F6
    
    # The number of lines of code to surround break point reports with. This
    # defines the number of lines both above and below the break point to show.
    @code_lines = 5
    
    # Hash of debugging break points. Hash keys are the names of Ace scripts as
    # written in the Script Editor, values are an array of line numbers that
    # serve as the break points. Example:
    #     @breakpoints = {
    #       'Scene_Base' => [40, 46],
    #       'Scene_Map' => [60],
    #     }
    @breakpoints = {}
    # =========================================================================
    # END CONFIGURATION
    # =========================================================================
    # Tracing lambda given to 'Kernel.set_trace_func' to perform debugging
    # operations (namely break points). When a break point is encountered, the
    # game stops execution and opens the SES Console with the active class at
    # the time as the context. Once the SES Console has been exited, the
    # context is reset to the context held before the break point was
    # encountered.
    Lambda = ->(event, file, line, id, binding, class_name) do
      # Help mitigate lag by only focusing on the events needed.
      return unless ['call', 'c-call'].any? { |type| event == type }
      # Store the file number as an integer. This is used a little further into
      # the method to extract the code surrounding a break point.
      file_number = file.dup[1..4].to_i
      # Replace the useless information VX Ace gives us for file names with the
      # names of scripts as defined in the Script Editor.
      file.gsub!(/^{\d+}/, $RGSS_SCRIPTS[$1.to_i][1]) if file =~ /^{(\d+)}/
      return unless @breakpoints[file]
      if @breakpoints[file].include?(line)
        # Grab the object which called the code the break point is set for.
        context = eval('self', binding)
        puts "**  BREAK: #{file}, line #{line} (#{context_string(context)}) **"
        puts "**   CODE: \n#{script_line(file_number, line)}"
        # Store the previous REPL context and set up the console environment.
        previous_context = SES::Console.context
        SES::Console.context, SES::Console.enabled = context, true
        # Open the console; this halts the game loop until the REPL is exited.
        SES::Console.open
        # Debugging work is done, reset the context of the console.
        puts "** RETURN: Reset context to #{previous_context} **"
        SES::Console.context = previous_context
      end
    end
    
    # Returns the "context string" for the given context object. If the object
    # is a class or module, the name of the class or module is returned. If the
    # object is an instance, the name of the instance's class is returned along
    # with the hexadecimal object ID representing the individual object.
    def self.context_string(context)
      if (context.class == Class || context.class == Module)
        context.name
      else
        # Using `__id__` rather than `object_id` in order to account for the
        # possibiity of a `BasicObject` instance being the context. Same for
        # the `rescue nil` -- `BasicObject` has no `class` method.
        "#{context.class.name rescue nil} 0x#{(context.__id__ << 1).to_s(16)}"
      end
    end
    
    # Generates a stub of code from the given script number. Includes the given
    # line number surrounded by the given number of surrounding lines. Returns
    # a string of the code stub with a notice for the line of the break point.
    def self.script_line(script, line, wrap = @code_lines)
      line  -= 1
      # Grab the script's code, convert it to UTF-8 in case of an alternative
      # encoding, then split it into an array to allow the text to be wrapped.
      script = $RGSS_SCRIPTS[script].last.force_encoding('utf-8').split("\r\n")
      # Determine the starting and stopping points of the code excerpt, taking
      # low and high limits into account.
      start  = (line - wrap < 0 ? 0 : line - wrap)
      stop   = (line + wrap > script.size ? script.size - 1 : line + wrap)
      script[line] << " <--- ** BREAK POINT **"
      script[start..stop].join("\r\n")
    end
    
    # Calls `Kernel.set_trace_func` with `SES::Debugger::Lambda` as the tracing
    # block to run. Returns `true` if started, `false` otherwise.
    def self.start
      return false if @breakpoints.empty?
      Kernel.set_trace_func(Lambda)
      true
    end
    
    # Closes the SES Console, stops all `Kernel.set_trace_func` tracing, then
    # focuses on the RGSS Player. Returns `true` if stopped, `false` otherwise.
    def self.stop
      Kernel.set_trace_func(nil)
      Win32.focus(Win32::HWND::Game) unless SES::Console.enabled
      true
    rescue
      false
    end
    
    # Register this script with the SES Core.
    Description = Script.new(:Debugger, 1.2, :Solistra)
    Register.enter(Description)
  end
end
# =============================================================================
# Scene_Base
# =============================================================================
class Scene_Base
  # Only update the SES Debugger if the game is being run in test mode and the
  # console window is shown.
  if $TEST && SES::Win32::HWND::Console > 0
    alias :ses_debugger_sb_upd :update
    def update(*args, &block)
      update_ses_debugger
      ses_debugger_sb_upd(*args, &block)
    end
    
    # Start the SES Debugger if the configured `Input` key is triggered.
    def update_ses_debugger
      SES::Debugger.start if Input.trigger?(SES::Debugger::TRIGGER)
    end
  end
end