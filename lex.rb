# Author: Dylan Knutson
# May 6, 2014
#
# Quick and dirty (and somewhat incomplete) lexer implementation for
# SPARC assembly language

# Returns an enumerator, which yields tokens, taking the form of a
# 2 element array:
#     [:sym, value]
# where :sym is a symbol, which can be one of:
#   :cmt => A single or multiline comment
#   :per => literal '%'
#   :cln => literal ':'
#   :dot => literal '.'
#   :cma => literal ','
#   :asn => literal '='
#   :obr => literal '['
#   :cbr => literal ']'
#   :opn => literal '('
#   :cpn => literal ')'
#   :add => literal '+'
#   :sub => literal '-'
#   :and => literal '&'
#   :str => A string literal
#   :chr => A character literal
#   :num => A number literal
#   :idt => An identifier
#   :eof => end of input
#
# and "value" is the string, or numerical, representation of the token.
# In the case of :cmt, :per, :dot, :str, :chr, and :idt, the value is
# a string type. For :str, the value is the value of the string literal
# (e.g. no wrapping "" and it has been unescaped)
#
# For :num types, the "value" is also the string representation as it exists
# in the lexed source code, and an additional Fixnum element is added to
# the return value, which is the integer value of the token

require 'pry'
require_relative 'error'

def lex sparc_str
  return TokenEnumerator.new(sparc_str)
end

Token = Struct.new(:type, :val, :extra, :loc) do
  def ==(other)
    # compare all members but location
    return other.is_a?(Token) &&
      (other.type == type) &&
      (other.val == val) &&
      (other.extra == extra)
  end
end
ID_REGEX = /\A\.?[a-zA-Z\_]+[a-zA-Z\_0-9]*/

class TokenEnumerator
  include Enumerable

  attr_reader :sparc_str
  attr_reader :full_str

  # Initialize with an optional file name
  def initialize sparc_str, fname = nil
    # reference to the full length string kept for generating errors
    @full_str    = sparc_str
    @sparc_str   = sparc_str

    # cursor location that the head of @sparc_str points to
    @current_loc = Location.new(0, 0, fname)
  end

  # Goes to the next token in the input string
  def next

    # check if we start with a comment
    stripped = @sparc_str.lstrip
    if stripped.start_with?('!') || stripped.start_with?("/*")
      return @front = token(:cmt, comment)
    end

    # no comment, skip ahead to content
    amt_skipped = @sparc_str.length - stripped.length
    skip amt_skipped

    # dup current location again, after skipping whitespace
    @prev_loc = @current_loc.dup

    # check if we're at end of file
    if empty?
      return @front = token(:eof, nil)
    end

    # any other identifiers
    if ID_REGEX.match(@sparc_str)
      return @front = token(:idt, ident)
    end

    # determine what to do based on first char
    @front = case @sparc_str[0]
    # single length tokens
    when "%" then token(:per, single)
    when ":" then token(:cln, single)
    when "." then token(:dot, single)
    when "," then token(:cma, single)
    when "[" then token(:obr, single)
    when "]" then token(:cbr, single)
    when "(" then token(:opn, single)
    when ")" then token(:cpn, single)
    when "+" then token(:add, single)
    when "-" then token(:sub, single)
    when "&" then token(:and, single)
    when "|" then token(:bar, single)
    when "^" then token(:xor, single)
    when "=" then token(:asn, single)

    # string/char literals
    when '"' then token(:str, string_lit)
    when "'" then token(:chr, char_lit)

    # Number literals
    when /[0-9]/ then token(:num, *(number.flatten))

    # fail fast on unexpected input
    else
      raise RuntimeError.new(
        "Unexpected first char for @sparc_str: ---\n#{@sparc_str}\n---")
    end
  end

  # Returns the token the lexer is currently on
  def front
    @front ||= self.next
  end

  # Is the current token range empty?
  def empty?
    @sparc_str == ""
  end

  # for 'Enumerable' mixin
  def each
    begin
      yield self.next
    end until empty?
  end

  def dup
    # ret = super
    # ret.instance_variable_set("@current_loc", @current_loc.dup)
    # ret.instance_variable_set("@prev_loc",    @prev_loc.dup)
    Marshal.load( Marshal.dump(self) )
  end

private

  # construct a token from a type and value
  # (with optional extra value)
  def token type, val, extra = nil
    Token.new(type, val, extra, @prev_loc)
  end

  # skips n chars in the sparc string, updating @current_loc as
  # it moves
  def skip n
    n.times do
      first = @sparc_str[0]

      if first == nil
        raise RuntimeError.new("Skipping, but @sparc_str is empty")
      elsif first == "\n"
        @current_loc.row += 1
        @current_loc.col  = 0
      else
        @current_loc.col += 1
      end

      @sparc_str = @sparc_str[1 .. -1]
    end
  end

  # a single character literal
  def single
    ret = @sparc_str[0]
    skip 1
    ret
  end

  # Parse a comment, incluing its whitespace and newlines
  def comment
    ret = ""

    until @sparc_str.start_with?('!') || @sparc_str.start_with?("/*")
      ret << single
    end

    # comment starts here, save the starting location
    @prev_loc = @current_loc.dup

    if @sparc_str.start_with?('!')
      # Handle single line comment
      # until @sparc_str.empty? || ret.end_with?("\n")
      until @sparc_str.start_with?("\n") || @sparc_str.empty?
        ret << single
      end

      if @sparc_str.start_with?("\n")
        single
      end

    elsif @sparc_str.start_with? "/*"
      # Handle multiline comment
      until @sparc_str.empty? || ret.end_with?("*/")
        ret << single
      end

      # # get a trailing newline from the comment too, if present
      # if @sparc_str.end_with?("\n")
      #   ret << single
      # end

    else
      raise RuntimeError.new(
        "Internal error handling comment: #{@sparc_str}, ret: #{ret}")
    end

    ret
  end

  # Parse arbitrary identifier
  def ident
    # first whole word
    id = @sparc_str[ID_REGEX]
    skip id.length
    id
  end

  # Parse a string literal
  def string_lit
    # Doesn't do backslash escape stuff yet (that's on the TODO list)
    ret = ""

    # shift off front '"'
    unless (r = single) == '"'
      raise RuntimeError.new("Expected string to start with double quotes, not '#{r}'")
    end

    until @sparc_str.start_with?('"')
      if @sparc_str == ""
        raise RuntimeError.new("unmatched double quote (#{@sparc_str}, #{ret})")
      end

      if @sparc_str.start_with?('\\')
        raise RuntimeError.new("no backslash yet")
      end

      ret << single
    end

    # throw away trailing '"'
    single

    ret
  end

  # Parses a number literal
  def number
    num_str = @sparc_str[/\A(0x[0-9A-F]+)|[0-9]+/]
    skip num_str.length
    [num_str, Integer(num_str)]
  end

  # Parse a character literal
  def parse_char
    raise RuntimeError.new("not implemented")
  end
end
