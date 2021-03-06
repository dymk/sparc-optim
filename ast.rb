# Author: Dylan Knutson
# May 6, 2014
#
# Simple Abstract Syntax Tree for the SPARC assembly language
# Root class: Node
# Common methods on all nodes:
#   prev_comments: An array, or nil, of comments that preceded the node
#   to_pretty_s:   Pretty print the AST and its children (useful for debugging)
# See ast_instr for the AST node for instructions


# Parent node class for all AST nodes
class Node
end

# Node which can appear in the 'nodes'
# array of CompilationUnit
# Acts as a linked list of nodes
class RootNode < Node
  attr_accessor :prev_node, :next_node
  def initialize opts
    @prev_node ||= opts[:prev_node]
    @next_node ||= opts[:next_node]
  end

  def to_s
    pn = @prev_node
    nn = @next_node
    @prev_node = pn ? pn.to_pretty_s : nil
    @next_node = nn ? nn.to_pretty_s : nil

    ret = super

    @prev_node = pn
    @next_node = nn

    ret
  end
end

# include instruction AST node
require_relative 'ast_instr'

# basically an entire *.s file
class CompilationUnit < Node
  # array of nodes in the compilation unit
  attr_reader :root_node   # RootNode

  # Macros/constants
  # attr_reader :defines # String[Node]

  def initialize opts = {}
    @root_node = opts[:root_node]
    @last_node = @root_node
    if @root_node && !@root_node.is_a?(RootNode)
      raise("@root_node not a RootNode") unless root_node.is_a?(RootNode)
    end
  end

  # Append a RootNode onto the linked list of nodes
  def << node
    raise unless node.is_a?(RootNode)

    unless @root_node
      @root_node = node
      @last_node = node
    end

    @last_node.next_node = node
    node.prev_node = @last_node
    @last_node = node
  end

  def to_pretty_s
    ret = ""

    node = root_node
    while node
      ret += node.to_pretty_s + "\n"
      node = node.next_node
    end

    ret
  end
end

class Comment < RootNode
  attr_reader :value

  def initialize opts
    @value = opts[:value] || raise
  end

  def to_pretty_s
    # remove a newline if it starts with one immediatly
    if value[0] == "\n"
      value[1 .. -1]
    else
      value
    end
  end

end

# a directive (e.g. .section or .global)
class Directive < RootNode
  attr_reader :name  # String
  attr_reader :param # Node

  def initialize opts
    @name  = opts[:name]   || raise
    @param = opts[:param]  || raise
  end

  def to_pretty_s
    ret  = "\t.#{name}"
    if param
      ret += " #{param.to_pretty_s}"
    end
  end
end

# a label that can be branched/jumped to
class Label < Node
  attr_reader :name   # String
  attr_accessor :decl # LabelDecl (optional)

  def initialize opts
    @name  = opts[:name] || raise

    # label declaration (if exists, attempts to be filled in after parsing)
    @decl  = opts[:decl]
  end

  def to_pretty_s
    name
  end
end

# declaration of a label
class LabelDecl < RootNode
  attr_reader :name

  def initialize opts
    @name = opts[:name] || raise
  end

  def to_pretty_s
    "\n#{name}:"
  end

end

# an arbitrary constant defined by the user
class ConstantDecl < RootNode
  attr_reader :name  # String
  attr_reader :value # Node

  def initialize opts
    @name  = opts[:name]  || raise
    @value = opts[:value] || raise
  end

  def to_pretty_s
    "#{name} = #{value.to_pretty_s}"
  end
end

# represents the use of a constant declaration in an expression
class Constant < Node
  attr_reader :decl # ConstantDecl

  def initialize opts
    @decl = opts[:decl] || raise
  end

  def name
    decl.name
  end

  def value
    decl.value
  end

  def to_pretty_s
    name
  end
end

# literals (number, string, char)
class Literal < Node
  attr_reader :value # String/Fixnum

  def initialize opts
    @value = opts[:value] || raise
  end
end

class NumLit < Literal
  attr_reader :str_value
  def initialize opts
    super
    @str_value = opts[:str_value]
  end

  def to_pretty_s
    str_value
  end
end

class StrLit < Literal
  def to_pretty_s
    '"' + value.split("").map { |c| escape_char(c) }.join("") + '"'
  end
end

class CharLit < Literal
  def to_pretty_s
    "'#{escape_char(value)}'"
  end
end

# Binary operator
class BinOp < Node
  attr_reader :op           # String
  attr_reader :left, :right # Node

  def initialize opts
    @op    = opts[:op]    || raise
    @left  = opts[:left]  || raise
    @right = opts[:right] || raise
  end

  def to_pretty_s
    "#{left.to_pretty_s} #{op} #{@right.to_pretty_s}"
  end
end

# Prefix unary operator
class PreUnOp < Node
  attr_reader :op    # String
  attr_reader :child # Node

  def initialize opts
    @op    = opts[:op]    || raise
    @child = opts[:child] || raise
  end

  def to_pretty_s
    "#{op}#{child.to_pretty_s}"
  end
end

# parenthesis for explicity binding binary operations
class BindParens < Node
  # the node that has its parens bound
  attr_reader :child # Node

  def initialize opts
    @child = opts[:child] || raise
  end

  def to_pretty_s
    "(#{child.to_pretty_s})"
  end
end

# a register (global, input, local, output, fp, sp)
class Register < Node
  attr_reader :name

  def initialize opts
    @name = opts[:name] || raise
  end

  # Register representing the condition code registers
  def self.nzvc; @@nzvc ||= Register.new(name: "nzvc"); end
  def self.o0;   @@o0   ||= Register.new(name: "o0"); end
  def self.o1;   @@o1   ||= Register.new(name: "o1"); end
  def self.o2;   @@o2   ||= Register.new(name: "o2"); end
  def self.o3;   @@o3   ||= Register.new(name: "o3"); end
  def self.o4;   @@o4   ||= Register.new(name: "o4"); end
  def self.o5;   @@o5   ||= Register.new(name: "o5"); end
  # All input, local, and output registers
  def self.all_i_l_o
    @@all_i_l_o ||= ["i", "l", "o"].map do |r|
      (0 .. 8).map do |i|
        Register.new(name: "#{r}#{i}")
      end
    end.flatten
  end

  def to_pretty_s
    "%#{name}"
  end

  # Needed for comparison within a Set
  def ==(other)
    unless other.is_a? Register
      return false
    end

    return name == other.name
  end
  def eql? other
    self == other
  end
  def hash
    name.hash
  end
end

# Address node in the form of '[REG (+/- (IMM|REG))?]'
class Address < Node
  attr_reader :reg       # Register
  attr_reader :offset    # Optional offset of the address (immediate or register)
  attr_reader :direction # Optional offset direction (:- or :+)

  def initialize opts
    @reg       = opts[:reg] || raise
    @direction = opts[:direction]
    @offset    = opts[:offset] || (raise if @direction)
  end

  # Returns the list of registers that the address node contains
  def references_regs
    ret = [@reg]
    if @offset.is_a? Register
      ret <<  @offset
    end
    ret
  end

  def to_pretty_s
    offset_str = if direction
      " #{direction} #{@offset.to_pretty_s}"
    else
      ""
    end
    "[#{reg.to_pretty_s}#{offset_str}]"
  end
end

# end of the source (the last node in a CompilationUnit)
class Eof < RootNode
  def initialize
  end

  def to_pretty_s
    ""
  end
end

# TODO: Probably won't be used; remove at some point
# For formatting the AST when it's printed out
class Newline < RootNode
  def initialize
  end

  def to_pretty_s
    ""
  end
end

private
def escape_char c
  if c.length != 1
    raise ArgumentError.new("c must be len 1")
  end

  case c
  when "\\" then "\\"
  when "\n" then "\\n"
  when "\t" then "\\t"
  else
    c
  end
end
