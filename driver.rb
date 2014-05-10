require_relative 'optim'

parsed = parse File.read("test_asm.s")

puts "pretty string version:"
puts parsed.to_pretty_s

optimized = optim parsed
puts "\noptmized version:"
puts optimized.to_pretty_s

