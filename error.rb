# Author: Dylan Knutson
# May 9, 2014
#
# Error generation helpers for the SPARC parser

# Location in a multiline string, with an optional filename associated
Location = Struct.new(:row, :col, :fname)

def error_str_from_tok full_str, token
  ret = error_from_str full_str, token.loc, token.val.length
  fname = token.loc.fname || "<string>"
  ret = "#{fname}:#{token.loc.row + 1}:#{token.loc.col}\n" + ret
end

def error_from_str full_str, loc, length
  # break full_str by newlines
  full_str_lines = full_str.split "\n"

  # lines before and after the target
  lines_before = full_str_lines[loc.row - 3 .. loc.row - 1] || []
  lines_after  = full_str_lines[loc.row + 1 .. loc.row + 3] || []

  # remove empty lines from the front of before, and the end of after
  while lines_before[0] && lines_before[0].empty?
    lines_before.shift
  end
  while lines_after[-1] && lines_after[-1].empty?
    lines_after.pop
  end

  line = ""

  # append the lines before
  lines_before.each_with_index do |l, i|
    line += prefix_for_linenum(loc.row - lines_before.length + i) + l + "\n"
  end

  # append the actual problem line
  line += prefix_for_linenum(loc.row+1) + full_str_lines[loc.row] + "\n"
  # and underline the error location in the line
  line +=
    # same width as prefix_for_linenum
    "   :  " +
    (" " * [(loc.col), 0].max) +
    "^" +
    ("~" * (length - 1)) + "\n"

  # and finally append some lines
  lines_after.each_with_index do |l, i|
    line += prefix_for_linenum(loc.row + i) + l + "\n"
  end

  line
end

def prefix_for_linenum line_num
  "%3d:  " % [line_num]
end
