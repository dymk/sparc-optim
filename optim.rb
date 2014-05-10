# Author: Dylan Knutson
# May 6, 2014
#
# Peephole optimizer for SPARC assembly language
# Method of interest:
#   `optim`
#     Takes a CompilationUnit AST node, and performs 'nop' removal
#     optimizations where possible
require_relative 'parse'

def optim root_node
  Optimizer.new(root_node).optimize
end

class Optimizer
  def initialize root_node
    @root_node = root_node
    unless @root_node.is_a? CompilationUnit
      raise "Optimizer needs a CompilationUnit as a root node"
    end
  end

  def optimize
    optimize_basic_blocks
  end

private
  # Optimizes by filling 'nop' operations, when the 'nop' always
  # happens (e.g. around calls)
  def optimize_basic_blocks
    nodes = @root_node.nodes

    # nops that couldn't be removed using this strategy
    unremovable = Set.new

    while true

      # find the first nop
      nop_node, index = nodes.each_with_index.detect do |node, i|
        if unremovable.include? node
          false
        else
          (node.is_a? Instr) && (node.op == "nop")
        end
      end

      # no more nops to work with
      if index == nil || index < 2
        break
      end

      # does the instr before this have a delay slot?
      one_ago = nodes[index - 1]

      if one_ago &&
        (one_ago.is_a? Instr) &&
        (one_ago.has_delay_slot?)

        # if the instruction is a branch, then get its dependencies,
        # as a branch's deps must be evaluated before the branch itself
        branch_deps = if one_ago.is_branch?
          one_ago.depends_on_regs
        else
          []
        end

        # get an instruction that can fill a delay slot
        # (and does not use certain registers)
        fill_delay_with, fd_index = get_independent_delay_slotable_before(index - 2, branch_deps)

        if fill_delay_with
          # can replace the nop with the fill_delay_with node
          # insert at the location of the nop node
          nodes.insert index, fill_delay_with
          nodes.delete_at index+1 # remove nop

          # insert a newline for readability
          nodes.insert index+1, Newline.new

          nodes.delete_at fd_index # fd was moved to 'index'
        else
          # nop isn't removable
          unremovable.add nop_node
        end
      else
        # 'nop' can be removed safely (pointless nop)
        nodes.delete_at index
      end

    end # while true

    # return optimized root node
    @root_node
  end

  def get_independent_delay_slotable_before index, addition_deps = []
    raise "invalid index #{index}" if index < 0

    # registers that have been modified (written to)
    # while traversing backwards
    changing_regs = Set.new addition_deps

    @root_node.nodes[0 .. index].to_enum.with_index.reverse_each do |node, i|

      # Can't optimize across label declarations
      if node.is_a? LabelDecl
        break
      end

      # Can't optimize across branches
      if node.is_a?(Instr) && node.is_branch?
        break
      end

      if (node.is_a? Instr) &&
         # Instruction does not have its own delay slot
         (!node.has_delay_slot?) &&
         # Instruction can fit in a delay slot
         (node.single_cycle?) &&
         # Instruction has no dependencies on later modified registers,
         # and does not modify any of the later modified registers
         ((node.depends_on_regs & changing_regs).length == 0) &&
         ((node.modified_regs   & changing_regs).length == 0)

        return [node, i]

      elsif (node.is_a? Instr)
        # Add this instruction's modfied registers to the changing_regs
        # set
        changing_regs.merge  node.modified_regs
        changing_regs.merge  node.depends_on_regs
      end
    end

    # no usable node found
    [nil, nil]
  end

private
  def instr_before_i index
    # start at index and work backwards until an instruction is found
  end

  def instr_after_i index
  end
end
