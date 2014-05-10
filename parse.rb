# Author: Dylan Knutson
# May 6, 2014
#
# Parser (more or less) for SPARC assembly language
# Method of interest:
#   `parse`
#    Takes a String, returns a CompilationUnit (defined in ast.rb)
#
# Because it's a pretty large amount of code, the logic for immediate parsing
# is found in 'parse_imm.rb'.

require_relative 'ast'
require_relative 'lex'
require_relative 'parse_imm'
require_relative 'consts'

# Parse sparc_str into an AST (as defined in 'ast.rb')
def parse sparc_str
  l = lex sparc_str
  Parser.new(l).parse_root
end

class Parser
  include ImmediateParser

  def initialize lexer
    @lexer = lexer

    # maps constant name (String) to a ConstantDecl
    @constant_decls = {}

    # maps label names (String) to a LabelDecl
    @label_decls = {}
  end

  # Parses an entire compilation unit and returns a CompilationUnit node
  def parse_root
    return @compilation_unit if @compilation_unit

    root_nodes = []
    until l.empty?
      root_nodes << (parse_root_node || error("ICE: got nil node"))
    end
    root_nodes << parse_eof

    # fix up labels to point to their label declaration
    root_nodes.select do |node|
      node.is_a? Label
    end.each do |label|
      label.decl = @label_decls[label.name]
    end

    @compilation_unit =
      CompilationUnit.new(
        nodes: root_nodes,
        defines: [])
  end

private
  attr_accessor :constant_decls

  # parses a root node
  # (label, directive, instruction)
  def parse_root_node

    tok = l.front
    case tok.type
    when :cmt then parse_comment
    when :idt then parse_directive_or_instr_or_label_decl_or_const
    when :eof then parse_eof
    else
      error "unexpected token: #{tok}"
    end
  end

  # parses a directive, such as `.global my_label`
  def parse_directive
    directive_name = match(:idt).val

    # parameter the directive takes
    require 'pry'
    directive_param =
      case directive_name
      when ".section" then parse_str_lit # .section ".data"
      when ".global"  then parse_label   # .global my_label
      else
        error "unknown/unimplemented directive '#{directive_name}'"
      end

    Directive.new(
      name: directive_name[1..-1],
      param: directive_param)
  end

  # Parse EOF (just to get the comments at the end of the file)
  def parse_eof
    match(:eof)
    Eof.new
  end

  def parse_label_decl
    lbl_tok = match(:idt)
    name = lbl_tok.val
    match(:cln)
    ret = LabelDecl.new(name: name)
    register_label ret, lbl_tok
    ret
  end

  def parse_comment
    Comment.new(value: match(:cmt).val)
  end

  def parse_directive_or_instr_or_label_decl_or_const
    # symbol starts with a dot; check if it matches any directive values
    if DIRECTIVES.include? l.front.val
      return parse_directive
    end


    # ident followed by colon: label decl
    # else: an instr
    saved = l.dup
    match(:idt)

    # thing:
    if l.front.type == :cln
      @lexer = saved
      parse_label_decl

    # thing=
    elsif l.front.type == :asn
      @lexer = saved
      parse_const_decl

    else
      @lexer = saved
      parse_instr
    end
  end

  def parse_instr
    # A note on parameter matching:
    # ':reg' matches on a provided register
    # ':imm' matches on an expression which can be evaluated to an immediate
    # ':lbl' matches on a label
    # ':adr' matches an address in the form of `\[:reg ([+-] :imm)? \]`

    tok = match(:idt)
    op = tok.val
    args = case op
    when "mov"  then parse_args(op, [:reg, :imm],  :reg)
    when "set"  then parse_args(op,  :imm, :reg)
    when "cmp"  then parse_args(op,  :reg,        [:reg, :imm])
    when "save" then parse_args(op,  :reg, [:reg, :imm], :reg)
    when "call" then parse_args(op,  :lbl )

    # early return for branch instructions (which have specialized parsing)
    when *BRANCH_OPS then
      return parse_branch_instr(tok)

    when
      "ld", "ldub", "ldsb", "lduh", "ldsh"
      then parse_args(op, :adr, :reg)
    when
      "st", "sth", "stb"
      then parse_args(op, :reg, :adr)

    when "add", "sub"
      then parse_args(op, :reg, [:reg, :imm], :reg)

    when "srl", "sll", "sla"
      then parse_args(op, :reg, [:reg, :imm], :reg)

    when "nop", "ret", "restore" then []
    else
      error "unrecognized/unimplemented instruction '#{op}'", tok
    end

    Instr.new(op: op, args: args)
  end

  # Parse a branch instruction (handling annuled branches)
  # Note that it takes branch_tok, which is the token that
  # would have been at the front of the lexer
  def parse_branch_instr branch_tok
    annuled = if l.front.type == :cma
      match(:cma)
      a = match(:idt)
      unless a.val == "a"
        error("expected 'a' signifying annuled branch after comma", a)
      end

      true
    else
      false
    end

    ret = Instr.new(
      op: branch_tok.val,
      annuled: annuled,
      args: parse_args(branch_tok.val, :lbl))
    error("ICE: parsed non-branch as a branch instr '#{op}'") unless ret.is_branch?
    ret
  end

  # Parse a list of comma separated arguments for op 'op'
  # Accepted types of arguments for each position is defined by
  # 'arg_lists', which is an array of arrays.
  # For instance, arg_lists = [
  #   [:reg, :imm],
  #   :reg
  # ]
  # would allow a register or immediate as the first argument parsed,
  # and only a register as the second argument parsed
  def parse_args op, *arg_lists
    arg_lists.each_with_index.map do |accepted, i|
      # not the first param, then match on a comma
      match(:cma) if (i != 0)

      # ensure accepted is an array of valid argument types
      accepted = [*accepted]
      unless accepted.all? { |a| [:reg, :imm, :lbl, :adr].freeze.include?(a) }
        error("ICE: invalid argument parse type in list '#{accepted}'")
      end

      ft = l.front.type

      # starts with '['
      if (ft == :obr) && accepted.include?(:adr)
        next parse_adr_arg
      end

      # starts with '%'
      if (ft == :per) && accepted.include?(:reg)
        next parse_reg
      end

      # starts with an arbitrary identifier
      # (which also isn't a defined constant)
      if (ft == :idt) && !@constant_decls[l.front.val] && accepted.include?(:lbl)
        next parse_label
      end

      # none of the above, try parsing as an immediate value
      if accepted.include?(:imm)
        next parse_imm
      end

      # at this point none match, meaning syntax error
      error "expected argument #{i+1} for instruction '#{op}' to be of type #{accepted}, but started with #{ft}"
    end
  end

  # Parse a register
  def parse_reg
    match(:per)
    name = match(:idt).val
    Register.new(name: name);
  end

  # Parse a label (not a label decl)
  def parse_label
    tok = match(:idt)
    Label.new(name: tok.val)
  end

  # Parse a constant declaration, e.g
  # MY_CONST = 123
  def parse_const_decl
    name = match(:idt).val
    match(:asn)
    value = parse_imm
    cd = ConstantDecl.new(name: name, value: value)
    register_constant cd
    cd
  end

  # raise a generic parser error
  def error str, tok = nil
    STDERR.puts "Error parsing: #{str}"
    STDERR.puts error_str_from_tok(l.full_str, tok || l.front)
    STDERR.puts ""
    exit 1
  end

  # Match 'type' at the front of the lexer, and move to the next token.
  # Raise a parser error unless 'type' is the front of the lexer
  def match type
    tok = l.front

    if tok.type != type
      error "unexpected token '#{tok.val}' of type '#{tok.type}', expected a #{type}"
    end

    # was the right type, shift the lexer
    l.next

    # and return the matched token
    tok
  end

  # register a constant in the compilation unit scope
  def register_constant cd
    if @constant_decls[cd.name]
      error "constant with name #{cd.name} defined more than once"
    end

    if @label_decls[cd.name]
      error "label with name #{cd.name} already defined"
    end

    @constant_decls[cd.name] = cd
  end

  # Registers a label declaration, with an optional 'tok'
  # for generating better error messages
  def register_label lb, tok = nil
    if @label_decls[lb.name]
      error("label with name #{lb.name} already declared", tok)
    end

    if @constant_decls[lb.name]
      error("constant with name #{lb.name} already declared", tok)
    end

    @label_decls[lb.name] = lb
  end

  # shorthand for @lexer
  def l
    @lexer
  end
end
