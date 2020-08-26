require 'readline'
require 'coderay'
require 'shellwords'

class REPL
  attr_reader :prompt
  attr_reader :commands
  attr_accessor :syntax

  def initialize(bnd)
    @binding = bnd || binding
    @prompt = '>'
    @syntax = :ruby
    @input_hooks = Hash.new
    @output_hooks = Hash.new
    @commands = Hash.new
  end

  def add_command(name, &blk)
    @commands[name] = blk
  end

  def add_input_hook(name, &blk)
    @input_hooks[name] = blk
  end

  def del_input_hook(name)
    @input_hooks.reject! {|k,v| v == name}
  end

  def add_output_hook(name, &blk)
    @output_hooks[name] = blk
  end

  def del_output_hook(name)
    @output_hooks.reject! {|k,v| v == name}
  end

  def prompt=(str=nil, &blk)
    @prompt = str if str
    @prompt = blk if blk.kind_of? Proc
  end

  def execStatement(input, debug=false)
    binding.pry if debug
      @input_hooks.each_value { |v| v.call input }
      if input[0] == '_' #local command
        cmdline = Shellwords.shellwords(input[1..-1])
        @commands[cmdline[0].to_sym].call *cmdline[1..-1]
      else
        results = @binding.eval input
      end
      @output_hooks.each_value { |v| v.call results }
      write results
    rescue StandardError, SyntaxError => e
      write_error e.class, e.message
  end

  def loop
    if @prompt.kind_of? Proc
      prompt = @prompt.call
    else
      prompt = @prompt
    end
    while input = Readline.readline("#{prompt} ", true)
      execStatement(input)
    end
  end
  alias_method :start, :loop

  private
  def write_error(cls=nil, text)
    message = "#{cls}: #{text}" if cls
    text = message if cls
    puts CodeRay.encode(text, :ruby, :terminal)
  end

  def write(text)
    puts CodeRay.encode(text, @syntax, :terminal)
  end
end