#--
# Debugger v1.0 by Solistra
# =============================================================================
# 
# Summary
# -----------------------------------------------------------------------------
#   This script provides a simple debugger with break point functionality using
# the SES Tracer and SES Console. Essentially, you establish a series of break
# points on specific lines within scripts in the Ace Script Editor -- when the
# line is encountered, execution stops and the SES Console is opened with the
# active class at the time of the break as the context. This is primarily a
# scripter's tool.
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
#   This script requires the SES Core (v2.0), Tracer (v1.2), and Console (v1.0)
# scripts in order to function. All of these scripts may be found at the
# [SES VX Ace](http://sesvxace.wordpress.com/category/script-release) site.
# 
#   Place this script below Materials, but above Main. Place this script below
# the SES Core, SES Console, and SES Tracer, but above other custom scripts.
# 
#++
module SES
  # ===========================================================================
  # Debugger
  # ===========================================================================
  # Defines operation of the SES Debugger.
  module Debugger
    class << self
      attr_accessor :code_lines
      attr_reader   :breakpoints, :scripts
    end
      
    # Ensure that we have the minimum script requirements.
    Register.require(:Console => 1.0, :Tracer => 1.2)
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
    # Stores the entire text of the scripts present in the Ace Script Editor.
    # These scripts are normally stored as compressed data, so we have to
    # decompress the data in order to have access to the uncompressed text.
    @scripts = load_data('Data/Scripts.rvdata2').map! do |script|
      Zlib::Inflate.inflate(script.last)
    end
    
    # Tracing lambda given to 'Kernel.set_trace_func' to perform debugging
    # operations (namely break points). When a break point is encountered, the
    # game stops execution and opens the SES Console with the active class at
    # the time as the context. Once the SES Console has been exited, the
    # context is reset to the context held before the break point was
    # encountered.
    Lambda = ->(event, file, line, id, binding, class_name) do
      # Store the file number as an integer. This is used a little further into
      # the method to extract the code surrounding a break point.
      file_number = file.dup[1..4].to_i
      # Replace the useless information VX Ace gives us for file names with the
      # names of scripts as defined in the Script Editor.
      file.gsub!(/^{\d+}/, SES::Tracer.scripts[$1.to_i]) if file =~ /^{(\d+)}/
      return unless @breakpoints[file]
      if @breakpoints[file].include?(line)
        # Store the object in operation during the break point. This is used to
        # provide a useful context to the SES Console.
        context = eval('self', binding)
        puts "**  BREAK: #{file}, line #{line} (#{context_string(context)}) **"
        puts "**   LINE: \n#{script_line(file_number, line)}"
        # Store the previous SES Console context so we can restore it later.
        previous_context = SES::Console.context
        SES::Console.context, SES::Console.enabled = context, true
        SES::Console.open
        # Debugging session for this break point is finished, restore context
        # for the SES Console.
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
        "#{context.class.name} 0x#{(context.object_id << 1).to_s(16)}"
      end
    end
    
    # Generates a stub of code from the given script number. Includes the given
    # line number surrounded by the given number of surrounding lines.
    def self.script_line(script, line, surrounding = @code_lines)
      string, script = '', @scripts[script].split("\r\n")
      surrounding.times do |i|
        # Obtain the lines of code directly above the given line.
        string << script[(line - 1) - (surrounding - i)] << "\n"
      end
      string << "#{script[line - 1]} <--- ** BREAK POINT **\n"
      # Obtain the lines of code directly below the given line.
      surrounding.times { |i| string << script[(line) + i] << "\n" }
      string
    end
    
    # Starts the SES Tracer with Debugger::Lambda as the tracing block to run.
    def self.start
      SES::Tracer.start(Lambda)
    end
    
    # Closes the SES Console, defers to the SES Tracer's +stop+ method, then
    # focuses the RGSS Player.
    def self.stop
      SES::Console.enabled = false
      SES::Tracer.stop
      Win32.focus(Win32::HWND::Game)
    end
    
    # Register this script with the SES Core.
    Description = Script.new(:Debugger, 1.0, :Solistra)
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
    
    # Start the SES Debugger if the configured Input key is triggered.
    def update_ses_debugger
      SES::Debugger.start if Input.trigger?(SES::Debugger::TRIGGER)
    end
  end
end