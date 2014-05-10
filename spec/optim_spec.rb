require 'minitest/autorun'
require 'minitest/spec'
require 'minitest/pride'

require 'optim'

describe Optimizer do

  it "moves single cycle independent instructions into branch delay slot" do

    # the bge does not rely on the mov 2, %l3
    ast = parse <<-sparc
      label1:
        mov 2,      %l3
        set 0xFFFF, %l1

        cmp %l0, %l1
        bge label2
        nop
    sparc

    should_be_ast = parse <<-sparc
      label1:
        set 0xFFFF, %l1

        cmp %l0, %l1
        bge label2
        mov 2,      %l3
    sparc

    ast = optim ast
    # binding.pry

    ast.to_pretty_s.gsub(/\s/, "").must_equal should_be_ast.to_pretty_s.gsub(/\s/, "")
  end
end
