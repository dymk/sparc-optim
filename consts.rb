# all conditional branching ops
BRANCH_OPS = ["bne", "be", "ba", "bn", "bge", "bg", "ble", "bl"].freeze

# operations which have a delay slot
DELAY_SLOT_OPS = [*BRANCH_OPS, "call", "ret"].freeze

# operations which take two cycles (and thus can't go in a delay slot)
TWO_CYCLE_OPS = [*DELAY_SLOT_OPS, "set"].freeze

# Directive strings
DIRECTIVES = [".section", ".global", ".align"].freeze

# filters 'args' so it contains only register
# nodes
def only_regs *args
  args = args.flatten
  args.select do |arg|
    arg.is_a? Register
  end
end
