# Author: Dylan Knutson
# May 6, 2014
#
# Simple Abstract Syntax Tree for the SPARC assembly language
# Root class: Node
# Common methods on all nodes:
#   prev_comments: An array, or nil, of comments that preceded the node
#   to_pretty_s:   Pretty print the AST and its children (useful for debugging)

# root node in the ast
class Node
end

# basically an entire *.s file
class CompilationUnit < Node
  # array of nodes in the compilation unit
  attr_reader :nodes   # [Node]

  # Macros/constants
  attr_reader :defines # String[Node]

  # associate label names with the label instance in @nodes
  attr_reader :labels  # String[Node]

  def initialize opts
    @nodes   = opts[:nodes]   || raise
    @defines = opts[:defines] || raise

    # should probably build up based on nodes array
    @labels = opts[:labels]
  end

  def to_pretty_s
    ret = ""
    nodes.each do |node|
      ret += node.to_pretty_s + "\n"
    end
    ret
  end
end

class Comment < Node
  attr_reader :value

  def initialize opts
    @value = opts[:value] || raise
  end

  def to_pretty_s
    value
  end
end

# a directive (e.g. .section or .global)
class Directive < Node
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
    @name = opts[:name] || raise
    @decl = opts[:decl]
  end

  def to_pretty_s
    name
  end
end

# declaration of a label
class LabelDecl < Node
  attr_reader :name

  def initialize opts
    @name = opts[:name] || raise
  end

  def to_pretty_s
    "#{name}:"
  end
end

# generic instruction class
class Instr < Node
  # name of the operation
  attr_reader :op # String

  # arguments passed to the op
  attr_reader :args # [Node]

  def initialize opts
    @op   = opts[:op]   || raise
    @args = opts[:args] || raise
  end

  def to_pretty_s
    ret  = "\t #{op} \t"
    ret += args.map(&:to_pretty_s).join(", \t")
    ret
  end
end

# an arbitrary constant defined by the user
class ConstantDecl
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
class Constant
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
class BinOp
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
class PreUnOp
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
class BindParens
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

  def to_pretty_s
    "%#{name}"
  end
end

# end of the source (the last node in a CompilationUnit)
class Eof < Node
  def to_pretty_s
    "<EOF>"
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
