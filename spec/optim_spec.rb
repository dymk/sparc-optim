require 'minitest/autorun'
require 'minitest/spec'
require 'minitest/pride'

require 'optim'

describe Optimizer do
  def optim_ast_is_same first, second
    normalize(optim(parse first)).must_equal normalize(parse second)
  end

  it "moves single cycle independent instructions into branch delay slot" do

    # the bge does not rely on the mov 2, %l3
    unoptim = <<-sparc
      label1:
        mov 2,      %l3
        set 0xFFFF, %l1

        cmp %l0, %l1
        bge label2
        nop
    sparc
    should_be = <<-sparc
      label1:
        set 0xFFFF, %l1

        cmp %l0, %l1
        bge label2
        mov 2,      %l3
    sparc

    optim_ast_is_same(unoptim, should_be)
  end

  it "moves instrs into the delay slot of dependent instructions" do
    unoptim = <<-sparc
      label1:
        mov %l1, %o0
        mov 4, %o1
        call  .mul
        nop
    sparc
    should_be = <<-sparc
      label1:
        mov %l1, %o0
        call  .mul
        mov 4, %o1
    sparc

    optim_ast_is_same(unoptim, should_be)
  end

  it "does not move inelegable instructions" do
    unoptim = <<-sparc
      label1:
        set 0xFFFF, %o0
        set 0xEEEE, %o1
        call  .mul
        nop
    sparc
    should_be = unoptim.dup

    optim_ast_is_same(unoptim, should_be)
  end

  it "does not move inelegable instructions around branches" do
    unoptim = <<-sparc
      label1:
        mov 9, %l0
        cmp %l0, %l1
        bne label2
        nop

      label2:
        mov 1, %l2
    sparc
    should_be = unoptim.dup

    optim_ast_is_same(unoptim, should_be)
  end

end

# Normalize an AST's string, for easy comparision of ASTs
private
def normalize ast
  # removes all whitespace
  ast.to_pretty_s.gsub(/\s/, "")
end
