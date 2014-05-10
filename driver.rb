require_relative 'optim'

if ARGV.length != 1
  puts <<-usage
  usage:
    ruby driver.rb <file>
      <file>: The SPARC asm file to optimize
      Output is written to stdout
  usage
  exit 1
end

parsed = parse File.read(ARGV.last)
optimized = optim parsed
puts optimized.to_pretty_s
