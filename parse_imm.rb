# Author: Dylan Knutson
# May 6, 2014
#
# Immediate expression parser for SPARC assembly language
#
# Expects the following methods when included into a scope:
#   l: a lexer
#   constant_decls: a hash of strings to constant declarations (String[ConstantDecl])
#   match: match on a token type
#   error: raise a parser error

module ImmediateParser
  # parse a (possible complex nested) immediate value
  def parse_imm
    parse_or
  end

  # methods related to parsing literals
  def parse_lit
    case l.front.type
    when :str then parse_str_lit
    when :chr then parse_char_lit
    when :num then parse_num_lit
    else
      error "expected a literal"
    end
  end

  def parse_str_lit
    StrLit.new(value: match(:str).val)
  end

  def parse_char_lit
    CharLit.new(value: match(:chr).val)
  end

  def parse_num_lit
    tok = match(:num)
    NumLit.new(value: tok.extra, str_value: tok.val)
  end

private
  def parse_or
    ret   = parse_xor

    while l.front.type == :bar
      match :bar

      ret = BinOp.new(
        op: "|",
        left: ret,
        right: parse_xor)
    end

    ret
  end

  def parse_xor
    ret = parse_and

    while l.front.type == :xor
      match :xor

      ret = BinOp.new(
        op: "^",
        left: ret,
        right: parse_and)
    end

    ret
  end

  def parse_and
    ret = parse_arith

    while l.front.type == :and
      match :and

      ret = BinOp.new(
        op: "&",
        left: ret,
        right: parse_arith)
    end

    ret
  end

  def parse_arith
    ret = parse_pre_unary

    while [:add, :sub].include?(l.front.type)
      ft = l.front.type
      match ft

      op_str = (ft == :add) ? "+" : "-"
      ret = BinOp.new(
        op: op_str,
        right: ret,
        left: parse_pre_unary)
    end
    ret
  end

  def parse_pre_unary
    case l.front.type
    when :sub then
      match(:sub)
      PreUnOp.new(op: "-", child: parse_pre_unary)
    else
      parse_atomic
    end
  end

  def parse_atomic
    tok = l.front

    # Token is an identifier; needs to be a constant (not forward referenced)
    if (tok.type == :idt)
      # ensure idt is a registered constant
      if !constant_decls[tok.val]
        error "unrecognized constant #{tok.val}"
      end

      # it is a valid constant
      match(:idt)
      Constant.new(decl: constant_decls[tok.val])

    # Token type is open paren; parse bind operator
    elsif (tok.type == :opn)
      match(:opn)
      child = parse_imm
      match(:cpn)
      BindParens.new(child: child)

    # Else, parse a literal expression
    else
      # require 'pry'
      # binding.pry
      parse_lit
    end
  end
end
