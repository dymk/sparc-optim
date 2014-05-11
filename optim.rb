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
    # Branches must be ran before before basic blocks to get max number
    # of nops removed
    optimize_branches
    optimize_basic_blocks

    @root_node
  end

private
  # Optimizes by filling 'nop' operations, when the 'nop' always
  # happens (e.g. around calls)
  def optimize_basic_blocks
    root_node = @root_node.root_node

    # nops that couldn't be removed using this strategy
    unremovable = Set.new

    while true

      # find the first nop
      nop_node = find_nop_instr_not_in_set(root_node, unremovable)

      # no more nops to work with
      if nop_node == nil || !nop_node.prev_node.prev_node
        break
      end

      # does the instr before this have a delay slot?
      one_ago = nop_node.prev_node

      if (one_ago) &&
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
        fill_delay_with =
          get_independent_delay_slotable_before(nop_node.prev_node.prev_node, branch_deps)

        if fill_delay_with
          # can replace the nop with the fill_delay_with node
          # insert at the location of the nop node
          remove_node fill_delay_with
          insert_before nop_node, fill_delay_with
          insert_before nop_node, Newline.new
          remove_node   nop_node

        else
          # nop isn't removable
          unremovable.add nop_node
        end

      else
        # 'nop' can be removed safely (pointless nop, as it's after a single
        # instruction without a delay slot)
        remove_node nop_node
      end
    end # while true

    # return optimized root node
    @root_node
  end

  def get_independent_delay_slotable_before node, additional_dep = []

    # registers that have been modified (written to)
    # while traversing backwards
    changing_regs = Set.new(additional_dep)

    while node
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

        return node

      elsif (node.is_a? Instr)
        # Add this instruction's modfied registers to the changing_regs
        # set
        changing_regs.merge  node.modified_regs
        changing_regs.merge  node.depends_on_regs
      end

      # go back one more in the linked list
      node = node.prev_node
    end

    # no usable node found
    nil
  end

  def optimize_branches
    # nops that couldn't be removed using this strategy
    unremovable = Set.new
    root_node = @root_node.root_node

    while true
      # find the first nop
      nop_node = find_nop_instr_not_in_set(root_node, unremovable)
      break if nop_node == nil

      # check if it has a branch before it
      one_ago = nop_node.prev_node

      unless (one_ago) &&
             (one_ago.is_a?(Instr)) &&
             (one_ago.is_branch?)

        # not a branch instruction before the nop
        unremovable.add nop_node

      else
        # is a branch instruction, find the label that it jumps to
        # branch_label: Label
        branch_label = one_ago.args[0]

        # if the target label is a .global or doesn't have a declaration, can't
        # perform the optimization
        branch_decl = branch_label.decl
        if !branch_decl || is_global_decl?(branch_decl)
          unremovable.add nop_node
          next
        end

        # check that instr after branch decl can be put into a delay slot
        unless branch_decl.next_node.single_cycle?
          unremovable.add nop_node
          next
        end

        # so far so good, just have to find all branches in the AST that
        # branch to `branch_decl`, and set their delay slot to the first
        # instruction after branch_decl, and move the first instruction of
        # branch_decl before it
        all_branches_to_label = all_branches_for branch_label.name

        # ensure all branches to the label are followed by a nop and are not annuled
        if all_branches_to_label.any? { |branch|
          (branch.is_annuled?) ||
          (!branch.next_node.is_a? Instr) ||
          (branch.next_node.op != "nop") }

          unremovable.add nop_node
          next
        end

        # first instruction after the label
        first_block_instr = branch_decl.next_node
        remove_node first_block_instr

        # move the decl's first instruction before the
        # declaration
        insert_before branch_decl, first_block_instr.dup

        # replace nop after branches with first_block_instr and annul them
        all_branches_to_label.each do |branch|
          branch_nop = branch.next_node
          # sanity check
          raise unless branch_nop.is_a?(Instr) && branch_nop.op == "nop"
          remove_node branch_nop

          # insert the instruction and annul the branch
          branch.annuled = true
          insert_after branch, first_block_instr.dup
          insert_after branch.next_node, Newline.new
        end

      end
    end
  end

  # Find a the next nop instruction in an array of nodes,
  # where the nop is not part of an ignore set
  def find_nop_instr_not_in_set node, ignored_nops

    while node
      if (!ignored_nops.include?(node)) &&
         (node.is_a? Instr) &&
         (node.op == "nop")

        return node
      end

      node = node.next_node
    end

    nil
  end

private

  # Returns all branch instructions that branch to 'label_name'
  def all_branches_for label_name
    node = @root_node.root_node
    ret = []

    while node
      if (node.is_a?(Instr)) &&
         (node.is_branch?) &&
         (node.args[0].name == label_name)

         ret << node
      end

      node = node.next_node
    end

    ret
  end

  # Is label_decl declared as .global?
  def is_global_decl? label_decl
    gloabl_directives.any? { |gd|
      gd.param.name == label_decl.name
    }
  end

  # Array of all `.global` directives
  def gloabl_directives
    @gloabl_directives ||= begin
      ret = []

      node = @root_node.root_node
      while node
        if node.is_a?(Directive) && node.name == "global"
          ret << node
        end

        node = node.next_node
      end

      ret
    end
  end

  # insert 'this' into the prev slot of 'node'
  def insert_before node, before
    before.prev_node = node.prev_node
    before.next_node = node

    if node.prev_node
      node.prev_node.next_node = before
    end

    node.prev_node = before
  end

  # inserts 'this' after the node
  def insert_after node, after
    after.prev_node = node
    after.next_node = node.next_node

    if node.next_node
      node.next_node.prev_node = after
    end

    node.next_node = after
  end

  # removes 'node' from the linked list
  def remove_node node
    prev_node = node.prev_node
    next_node = node.next_node

    node.next_node = nil
    node.prev_node = nil

    if prev_node
      prev_node.next_node = next_node
    end

    if next_node
      next_node.prev_node = prev_node
    end

    node
  end
end
