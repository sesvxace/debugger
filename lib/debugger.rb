#--
# Debugger v1.3 by Solistra
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
#   This script requires the SES Core (v2.0) and SES Console (v1.3) scripts in
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

# SES
# =============================================================================
# The top-level namespace for all SES scripts.
module SES
  # Debugger
  # ===========================================================================
  # Provides a simple debugger with break points, halting of game execution,
  # and contextual awareness.
  module Debugger
    class << self
      # The number of lines of code to surround break points with.
      # @return [FixNum]
      attr_accessor :code_lines
      
      # Hash of break points. Keys are script names in the Ace Script Editor,
      # values are an array of line numbers to debug.
      # @return [Hash{String => Array<FixNum>}]
      attr_reader   :breakpoints
    end
      
    # Ensure that we have the minimum script requirements.
    Register.require(:Core => 2.0, :Console => 1.3)
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
    @breakpoints = {
      # Include your desired breakpoints here.
    }
    # =========================================================================
    # END CONFIGURATION
    # =========================================================================
    
    # Tracing lambda given to 'Kernel.set_trace_func' to perform debugging
    # operations (namely break points).
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
        object = context_string(eval('self', binding))
        puts "**  BREAK: #{file}, line #{line} (#{object}) **"
        puts "**   CODE: \n#{script_line(file_number, line)}"
        # Store the previous REPL context and set up the console environment.
        previous_context = SES::Console.context
        SES::Console.context, SES::Console.enabled = binding, true
        # Open the console; this halts the game loop until the REPL is exited.
        SES::Console.open
        # Debugging work is done, reset the context of the console.
        puts "** RETURN: Reset context to #{eval('self', previous_context)} **"
        SES::Console.context = previous_context
      end
    end
    
    # Returns the "context string" for the given context object. If the object
    # is a class or module, the name of the class or module is returned. If the
    # object is an instance, the name of the instance's class is returned along
    # with the hexadecimal object ID representing the individual object.
    # 
    # @param object [Object] the object to generate a context string for
    # @return [String] the appropriate context string
    def self.context_string(object)
      if (object.class == Class || object.class == Module)
        context.name
      else
        # Using `__id__` rather than `object_id` in order to account for the
        # possibiity of a `BasicObject` instance being the context. Same for
        # the `rescue nil` -- `BasicObject` has no `class` method.
        "#{object.class.name rescue nil} 0x#{(object.__id__ << 1).to_s(16)}"
      end
    end
    
    # Generates a stub of code from the given script number. Includes the given
    # line number surrounded by the given number of surrounding lines.
    # 
    # @param script [FixNum] the script ID to generate a code stub for
    # @param line [FixNum] the target line number
    # @param wrap [FixNum] the number of lines above and below the target to
    #   display
    # @return [String] the requested code stub with a break point notice on the
    #   targeted line
    def self.script_line(script, line, wrap = @code_lines)
      line  -= 1
      # Grab the script's code, convert it to UTF-8 in case of an alternative
      # encoding, then split it into an array to allow the text to be wrapped.
      script = $RGSS_SCRIPTS[script].last.force_encoding('utf-8').split("\r\n")
      # Determine the starting and stopping points of the code excerpt, taking
      # low and high limits into account.
      start  = (line - wrap < 0 ? 0 : line - wrap)
      stop   = (line + wrap > script.size ? script.size - 1 : line + wrap)
      script[line] << ' <--- ** BREAK POINT **'
      script[start..stop].join("\r\n")
    end
    
    # Calls `Kernel.set_trace_func` with `SES::Debugger::Lambda` as the tracing
    # block to run.
    # 
    # @return [Boolean] `true` if started, `false` otherwise
    def self.start
      return false if @breakpoints.empty?
      Kernel.set_trace_func(Lambda)
      true
    end
    
    # Closes the SES Console, stops all `Kernel.set_trace_func` tracing, then
    # focuses on the RGSS Player.
    # 
    # @return [Boolean] `true` if stopped, `false` otherwise
    def self.stop
      Kernel.set_trace_func(nil)
      Win32.focus(Win32::HWND::Game) unless SES::Console.enabled
      true
    rescue
      false
    end
    
    # Script metadata.
    Description = Script.new(:Debugger, 1.3, :Solistra)
    Register.enter(Description)
  end
end
# Scene_Base
# =============================================================================
# Superclass of all scenes within the game.
class Scene_Base
  # Aliased to update the calling conditions for starting the SES Debugger.
  # 
  # @see #update
  alias :ses_debugger_sb_upd :update
  
  # Performs scene update logic.
  # 
  # @return [void]
  def update(*args, &block)
    update_ses_debugger
    ses_debugger_sb_upd(*args, &block)
  end
  
  # Start the SES Debugger if the configured `Input` key is triggered.
  # 
  # @return [void]
  def update_ses_debugger
    SES::Debugger.start if Input.trigger?(SES::Debugger::TRIGGER)
  end
end