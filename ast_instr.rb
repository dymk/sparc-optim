# Author: Dylan Knutson
# May 10, 2014
#
# AST node representing an instruction
#
# A separate file as it contains instruction specific behavior, and thus is
# is quite large compared to other ast nodes.

# generic instruction class
class Instr < Node
  # name of the operation
  attr_reader :op # String

  # arguments passed to the op
  attr_reader :args # [Node]

  def initialize opts
    @op      = opts[:op]      || raise
    @args    = opts[:args]    || raise
    @annuled = opts[:annuled]
  end

  def to_pretty_s
    anl_str = if is_branch? && is_annuled?
      ",a"
    else
      ""
    end

    ret  = "\t #{op}#{anl_str} \t"
    ret += args.map(&:to_pretty_s).join(", \t")
    ret
  end

  def single_cycle?
    !two_cycle?
  end

  def is_branch?
    BRANCH_OPS.include?(op)
  end

  def is_annuled?
    raise("is_annuled? called on non-branch op '#{op}'") unless is_branch?
    @annuled
  end

  def two_cycle?
    TWO_CYCLE_OPS.include?(op)
  end

  def has_delay_slot?
    DELAY_SLOT_OPS.include?(op)
  end

  # array of registers that this instruction uses
  def registers
    @args.select { |arg| arg.is_a? Register }
  end

  # registers that this instruction modifies when executed
  def modified_regs
    Set.new(case op
    when "nop", "ret", "restore" then
      []

    # last operand in mov/set is always a register
    when "mov", "set" then
      [ args[1] ]

    when "save" then
      [ args[2], *Register.all_i_l_o ]

    when "sll", "srl", "sra" then
      [ args[2] ]

    # call only affects register o0
    when "call" then [ Register.o0 ]

    # cmp affects the condition code regs
    when "cmp" then
      [ Register.new(name: "nzvc") ]

    # last arg in add/sub modified
    when "add", "sub" then
      [ args[2] ]

    # else, assume it doesn't modify any
    # TODO:
    # all the srl, sra, ld, st, etc
    else
      # no modified registers
      raise "#modified_regs for '#{op}' not implemented yet"
    end)
  end

  def depends_on_regs
    Set.new(case op

    when "nop", "ret", "restore"
      []

    when "save" then
      only_regs(args[0], args[1])

    when "mov", "set" then
      only_regs(args[0])

    when "sll", "srl", "sra" then
      only_regs(args[0], args[1])

    when "add", "sub" then
      only_regs(args[0], args[1])

    when "cmp" then
      only_regs(args[0], args[1])

    # call depends on output regs %o0 - %o5
    when "call" then
      [ Register.o0, Register.o1, Register.o2,
        Register.o3, Register.o4, Register.o5]

    when *BRANCH_OPS then
      [ Register.nzvc ]

    else
      raise "#depends_on_regs for '#{op}' not implemented yet"
    end)
  end
end
