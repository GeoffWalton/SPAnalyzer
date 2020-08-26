#!/usr/bin/ruby

require 'watir'
require 'getoptlong'
require 'pry'
require_relative 'lib/threadpool'
require_relative 'lib/repl'
require_relative 'lib/empty'

BROWSER = :firefox

$startup_options = GetoptLong.new(
    ['--help', '-h', GetoptLong::NO_ARGUMENT],
    ['--debug-loops', '-d', GetoptLong::NO_ARGUMENT],
    ['--profile', '-u', GetoptLong::REQUIRED_ARGUMENT],
    ['--proxy', '-p', GetoptLong::REQUIRED_ARGUMENT]
)

def help
  puts <<HERE
--help, -h | This help message
--proxy -p <protocol://target:port> | specify a proxy server 127.0.0.1:8080
--profile <profile> -u | select a mozilla profile
HERE
end

$proxy = nil
$profile = 'default'
$debug_loops = false

$startup_options.each do |item, value|
  case item
  when '--help'
    help;
    exit 0
  when '--proxy'
    $proxy = Hash.new
    $proxy[:http] = value
    $proxy[:ssl] = value
  when '--profile'
    $profile = value
  when '--debug-loops'
    $debug_loops = true
  else
    puts "Unknown argument #{item}"
    exit 1
  end
end

$macros = Hash.new

  interactive_browser = Watir::Browser.new BROWSER, profile: $profile, proxy: $proxy
  repl = REPL.new Empty.binding(interactive_browser)
  repl.syntax = :JavaScript
  repl.add_command(:EnableLoopDebug) { $debug_loops = true }
  repl.add_command(:DisableLoopDebug) {$debug_loops = false }
  repl.add_command(:NewMacro) { |name| $macros[name.to_sym] = Array.new }
  repl.add_command(:RecordMacro) do |name|
    puts "Macro Recording on!\nStatements with a leading space will not be included in macro..\n"
    repl.add_input_hook(:macro_rec) {|input| $macros[name.to_sym] << input unless ((input =~ /^_.*Macro/) or (input =~ /^\s/))}
  end
  repl.add_command(:StopRecordMacro) {|name| repl.del_input_hook(:macro_rec) }
  repl.add_command(:PlayMacro) {|name| $macros[name.to_sym].each {|smt| repl.execStatement(smt)}}
  repl.add_command(:PlayMacroWithSubs) do |name, replace, filename|
    File.readlines(filename).map {|x| x.chomp}.each do |line|
      escaped_line = line.gsub(/'/){ "\\\\'" }
      $macros[name.to_sym].each {|smt| repl.execStatement(smt.gsub(replace, escaped_line), $debug_loops)}
    end
  end
  repl.add_command(:ShowMacro) {|name| $macros[name.to_sym].each {|smt| puts smt}}
  repl.add_command(:help) {puts "Commands Help...\n"; repl.commands.each {|k,v| puts "#{k.to_s} - parameters #{v.parameters.map {|x| x[1]}}"}}
  repl.add_command(:SaveMacro) { |name, filename| File.write(filename, $macros[name.to_sym].join("\n")) }
  repl.add_command(:LoadMacro) { |name, filename| $macros[name.to_sym] = (File.readlines(filename).map {|x| x.chomp}) }
  repl.add_command(:BrowserMethods) do
    local_method_names = interactive_browser.methods - BasicObject.methods
    local_method_names.each do |name|
      local_method = interactive_browser.method name
      params = local_method.parameters.map {|parm| parm[0] == :opt ? [parm[1]] : parm }
      if params.length > 0
        puts "#{name} - parameters #{params}"
      else
        puts "#{name}"
      end
    end
    end
  puts "Welcome to SPAnalyzer..\n\nFor help with _Commands see _help\nFor Browser Context help see _BrowserMethods\n"
  repl.start




