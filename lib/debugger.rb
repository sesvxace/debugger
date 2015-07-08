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
#   Break points are set using the debugger by specifying the desired class or
# module and method which should act as a trigger using a string written in the
# Ruby standard notation for class and instance methods. For example, adding a
# break point for the `update` instance method of `Scene_Base` is specified
# with `'Scene_Base#update'`, while the `return` class method of `SceneManager`
# is specified with `'SceneManager.return'`.
# 
#   **NOTE:** It is perfectly valid to include break points for objects defined
# in scripts that have been included below the debugger.
# 
#   For example, let's assume that we want to break every time `Scene_Base` is
# told to update. In order to set up that break point, we could do one of two
# things (depending on when we need the break point set): we can either include
# the break point in the configuration area of the script, or we can set the
# point dynamically at some point during the game's execution (either through
# a REPL -- such as the console -- or a script call). The following examples
# demonstrate both methods:
# 
#     # Configuration area.
#     @breakpoints = [
#       'Scene_Base#update',
#     ]
#     
#     # Dynamically adding the break point.
#     SES::Debugger.add('Scene_Base#update')
#     
#     # Alternative syntax for dynamically adding a break point.
#     SES::Debugger << 'Scene_Base#update'
# 
#   Note that you can also add multiple break points at once if desired:
# 
#     SES::Debugger.add('Scene_Base#update', 'SceneManager.return', ...)
# 
#   Since version 1.3 of the SES Debugger, you may also dynamically set break
# points in your code via the `Kernel#breakpoint` method which will create a
# break point for the line where the method call was placed. This is
# particularly useful when debugging your own code and you only require break
# points for temporary testing purposes.
# 
#   **NOTE**: Using the `Kernel#breakpoint` method does not automatically start
# the SES Debugger when the method is encountered -- it simply creates the
# break point. It is still up to you to enable debugging when you require it.
# 
# License
# -----------------------------------------------------------------------------
#   This script is made available under the terms of the MIT Expat license.
# View [this page](http://sesvxace.wordpress.com/license/) for more detailed
# information.
# 
# Installation
# -----------------------------------------------------------------------------
#   This script requires the SES Core (v2.0) and SES Console (v1.6) scripts in
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
    # =========================================================================
    # BEGIN CONFIGURATION
    # =========================================================================
    
    # The Input module constant to use for enabling the debugger.
    TRIGGER = Input::F6
    
    # The number of lines of code to surround break point reports with. This
    # defines the number of lines both above and below the break point to show.
    @code_lines = 5
    
    # Array of debugging break points. Populate this array with representative
    # strings for methods; for example, the `update` instance method of the
    # `Scene_Base` class would be represented as "Scene_Base#update`, while the
    # `setup` class method of `BattleManager` would be "BattleManager.setup".
    # Example:
    #     @breakpoints = [
    #       'Scene_Map#update',
    #       'BattleManager.setup',
    #       'Game_Party#gain_item',
    #       'SceneManager.return',
    #     ]
    @breakpoints = [
      # Include your desired break points here.
    ]
    
    # Determines the format of the output written while debugging code with the
    # SES Debugger. Each of the keys defined here contains a string value which
    # is populated with information via `sprintf`.
    @format = {
      :start      => '**  BREAK: %s, line %d (%s)',
      :code       => "** SCRIPT: \n%s",
      :breakpoint => '->',
      :reset      => '** RETURN: Reset context (%s)'
    }
    # =========================================================================
    # END CONFIGURATION
    # =========================================================================
    
    class << self
      # @return [Fixnum] the number of lines of code to surround break points
      #   with
      attr_accessor :code_lines
      
      # @return [Boolean] whether or not the SES Debugger has been enabled
      attr_reader  :enabled
      alias_method :enabled?, :enabled
      
      # @return [Hash{Symbol => String}] hash of strings used to format the SES
      #   Debugger's output while using the debugger
      attr_reader :format
      
      # @return [Hash{Module => Array<Fixnum>}] hash of break points; keys are
      #   constants, values are an array of line numbers to debug
      attr_reader :breakpoints
    end
    
    # Explicitly assign `false` as the default enabled status.
    @enabled = false
        
    # Ensure that we have the minimum script requirements.
    Register.require(:Core => 2.0, :Console => 1.6)
    
    # Tracing lambda given to `Kernel.set_trace_func` to perform debugging
    # operations (namely break points).
    Lambda = ->(event, file, line, _, binding, klass) do
      return unless event == 'line' && @breakpoints[klass] &&
        @breakpoints[klass].include?(line)
      filename = file.sub(/^{(\d+)}/) { $RGSS_SCRIPTS[$1.to_i][1] }
      puts @format[:start] % [filename, line, eval('self', binding)]
      puts @format[:code]  % script_line(file.dup[1..4].to_i, line)
      previous_context     = SES::Console.context
      SES::Console.context = binding
      SES::Console.enabled = true
      SES::Console.open
      puts @format[:reset] % eval('self', previous_context)
      SES::Console.context = previous_context
    end
    
    # Generates a stub of code from the given script number. Includes the given
    # line number surrounded by the given number of surrounding lines.
    # 
    # @param script [Fixnum] the script ID to generate a code stub for
    # @param line [Fixnum] the target line number
    # @param wrap [Fixnum] the number of lines above and below the target to
    #   display
    # @return [String] the requested code stub with a break point notice on the
    #   targeted line
    def self.script_line(script, line, wrap = @code_lines)
      line  -= 1
      script = $RGSS_SCRIPTS[script][3].force_encoding('utf-8').split("\r\n")
      start  = (line - wrap < 0 ? 0 : line - wrap)
      script[line][0...@format[:breakpoint].size] = @format[:breakpoint]
      script[start..line + wrap].join("\n")
    end
    class << self ; private :script_line ; end
    
    # Dynamically adds a break point to the SES Debugger given as a string
    # representing the desired instance or class method.
    # 
    # @example
    #     SES::Debugger.add('Scene_Map#start')
    #     SES::Debugger << 'SceneManager.return'
    # 
    # @param points [Array<String>] an array of strings representing classes or
    #   modules and the desired instance or class methods to add break points
    #   for
    # @return [Hash{Module=>Fixnum}] hash of the break points added to the
    #   debugger
    def self.add(*points)
      return_value = {}
      points.each do |point|
        klass, method = *convert_breakpoint(point)
        breakpoints   = @breakpoints[klass] ||= []
        line          = method.source_location[1] + 1
        unless breakpoints.include?(line)
          (return_value[klass] ||= []) << line
          breakpoints << line
        end
      end
      return_value
    end
    class << self ; alias_method :<<, :add ; end
    
    # Converts the user-configurable array of debugging break points into the
    # hash structure consumed by the debugging process.
    # 
    # @note While this method is publicly available, it is _not_ intended to
    #   be called by individual users; as such, it should be seen as private.
    # 
    # @return [void]
    def self.convert_breakpoints
      return unless @breakpoints.kind_of?(Array)
      breakpoints  = @breakpoints.dup
      @breakpoints = {}
      breakpoints.each(&method(:add))
    end
    
    # Converts a string representing a class and method (whether defined as an
    # instance or class method) into an array containing the actual `Class`
    # object and its unbound method.
    # 
    # @param point [String] a string representing a class or module and the
    #   desired instance or class method
    # @return [Array<Module, UnboundMethod>] the resolved `Class` or `Module`
    #   object and its associated `UnboundMethod`
    def self.convert_breakpoint(point)
      k, m = point.include?('#') ? point.split('#') : point.split('.')
      klass = k.split('::').reduce(Object) { |obj, con| obj.const_get(con) }
      method = if point.include?('#')
        klass.instance_method(m)
      else
        klass.method(m) rescue klass.instance_method(m)
      end
      [klass, method]
    end
    class << self ; private :convert_breakpoint ; end
    
    # Calls `Kernel.set_trace_func` with {SES::Debugger::Lambda} as the tracing
    # block to run.
    # 
    # @return [void]
    def self.start
      @enabled = true
      Kernel.set_trace_func(Lambda)
      puts 'SES Debugger started.'
    end
    
    # Stops all `Kernel.set_trace_func` tracing, effectively stopping the SES
    # Debugger.
    # 
    # @return [void]
    def self.stop
      @enabled = false
      Kernel.set_trace_func(nil)
      puts 'SES Debugger stopped.'
    end
    
    # Script metadata.
    Description = Script.new(:Debugger, 1.3, :Solistra)
    Register.enter(Description)
  end
end
# Graphics
# =============================================================================
# Module which handles all GDI+ screen drawing.
class << Graphics
  # Aliased to update the calling conditions for starting and stopping the SES
  # Debugger.
  # 
  # @see #update
  alias_method :ses_debugger_gfx_update, :update
  
  # Performs graphical updates and provides the global logic timer; in addition
  # to this, starts or stops the SES Debugger if the configured `Input` key is
  # triggered.
  # 
  # @return [void]
  def update
    if Input.trigger?(SES::Debugger::TRIGGER)
      SES::Debugger.enabled? ? SES::Debugger.stop : SES::Debugger.start
    end
    ses_debugger_gfx_update
  end
end
# DataManager
# =============================================================================
# The singleton class of the default RPG Maker module for handling data.
class << DataManager
  # Aliased to automatically convert user-configured break points into the
  # appropriate hash structure for the SES Debugger on game start.
  # 
  # @see #init
  alias_method :ses_debugger_dm_init, :init
  
  # Converts the user-configurable break points for the SES debugger and 
  # initializes all of the data used by the game.
  # 
  # @note Break point conversion is done here so that the SES Debugger may be
  #   configured to set break points in scripts included _below_ it in the Ace
  #   script editor without raising errors.
  # 
  # @return [void]
  def init
    SES::Debugger.convert_breakpoints
    ses_debugger_dm_init
  end
end
# Kernel
# =============================================================================
# Methods defined here are automatically available to all Ruby objects.
module Kernel
  # Dynamically sets a break point for the SES Debugger at the line following
  # the line this method is placed on. Particularly useful when a break point
  # is only temporarily required.
  # 
  # @return [void]
  def breakpoint
    klass = is_a?(Module) ? self : self.__class__
    line  = caller[0].split(':')[1].to_i
    breakpoints = SES::Debugger.breakpoints[klass] ||= []
    breakpoints << line unless breakpoints.include?(line)
  end
end
