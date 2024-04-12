# Hardware class that stores all the memory, registers, symbols, etc
class Hardware
  attr_accessor :memory, :accumulator, :data_register, :program_counter, :zero_bit, :overflow_bit, :symbols, :next_available_address

  def initialize
    @memory = Array.new(256, 0)
    @accumulator = 0 # A register
    @data_register = 0 # B register
    @program_counter = 0
    @zero_bit = false
    @overflow_bit = false
    @symbols = {} # Hash to store symbolic variables and their addresses
    @next_available_address = 128 # Variable to check available data memory
  end

  # Method to load a SAL program into memory array
  def load_program(program)
    program.each_with_index do |instruction, index|
      @memory[index] = instruction
    end
  end

  # Method to read from memory array
  def read_memory(address)
    @memory[address]
  end

  # Method to write to memory array
  def write_memory(address, value)
    @memory[address] = value
  end

  def print_registers_and_flags
    puts "Registers and Flags:"
    puts "Accumulator: #{@accumulator}"
    puts "Data Register: #{@data_register}"
    puts "Program Counter: #{@program_counter}"
    puts "Zero Bit: #{@zero_bit}"
    puts "Overflow Bit: #{@overflow_bit}"
  end

  def print_memory
    puts "Memory:"
    @memory.each_with_index do |value, address|
      puts "Address #{address}: #{value}" if value != 0
    end
  end

  def print_symbols_table
    puts "Symbols Table(Symbol:Address):"
    symbols.each do |symbol, address|
      puts "#{symbol}: #{address}"
    end
  end
end

# Class to read in file to program array
class FileReader
  def self.read_program(file_name)
    begin
      program = []
      File.open(file_name, "r") do |file|
        file.each_line do |line|
          program << line.chomp
        end
      end
      program
    rescue Errno::ENOENT
      puts "File '#{file_name}' not found."
      exit
    end
  end
end

class Command
  attr_reader :opcode

  def initialize(opcode)
    @opcode = opcode
  end

  # Abstract method, to be implemented by concrete subclasses
  def execute(hardware)
    raise NotImplementedError, "Subclasses must implement the execute() method"
  end
end

# DEC command: Declares a symbolic variable consisting of a sequence of letters (e.g., sum). The
# variable is stored at an available location in data memory.
class DEC < Command
  def initialize(symbol)
    super("DEC")
    @symbol = symbol
  end

  def execute(hardware)
    address = hardware.next_available_address
    hardware.symbols[@symbol] = address # Store the symbol with it's address
    hardware.next_available_address += 1
  end
end

#LDA Command: Loads word at data memory address of symbol into the accumulator.
class LDA < Command
  def initialize(symbol)
    super("LDA")
    @symbol = symbol
  end

  def execute(hardware)
    address = hardware.symbols[@symbol]
    hardware.accumulator = hardware.read_memory(address).to_i
  end
end

#LDI Command: Loads the integer value into the accumulator register. The value could be negative.
class LDI < Command
  def initialize(value)
    super("LDI")
    @value = value
  end
  def execute(hardware)
    hardware.accumulator = @value
  end
end

#STR Command: Stores content of accumulator into data memory at address of symbol.
class STR < Command
  def initialize(symbol)
    super("STR")
    @symbol = symbol
  end

  def execute(hardware)
    address = hardware.symbols[@symbol]
    hardware.write_memory(address, hardware.accumulator.to_s)
  end
end

#XCH Command: Exchanges the content registers A and B.
class XCH < Command
  def initialize
    super("XCH")
  end

  def execute(hardware)
    hardware.accumulator, hardware.data_register = hardware.data_register, hardware.accumulator
  end
end

#JMP Command: Transfers control to instruction at address number in program memory.
class JMP < Command
  def initialize(address)
    super("JMP")
    @address = address
  end

  def execute(hardware)
    hardware.program_counter = @address - 1
  end
end

#JZS Command: Transfers control to instruction at address number if the zero-result bit is set.
class JZS < Command
  def initialize(address)
    super("JZS")
    @address = address
  end

  def execute(hardware)
    if hardware.zero_bit
      hardware.program_counter = @address - 1
    end
  end
end

#JVS Command: Transfers control to instruction at address number if the overflow bit is set.
class JVS < Command
  def initialize(address)
    super("JVS")
    @address = address
  end

  def execute(hardware)
    if hardware.overflow_bit
      hardware.program_counter = @address - 1
    end
  end
end

#ADD Command: Adds the content of registers A and B. The sum is stored in A. The overflow and
# zero-result bits are set or cleared as needed.
class ADD < Command
  def initialize
    super("ADD")
  end

  def execute(hardware)
    result = hardware.accumulator + hardware.data_register

    # Check for overflow
    if result > 2**31 - 1 || result < -2**31
      hardware.overflow_bit = true
    else
      hardware.overflow_bit = false
    end

    hardware.accumulator = result
    hardware.zero_bit = (result == 0)
  end
end

#SUB Command: The content of register B is subtracted from A. The difference is stored in A.
# The overflow and zero-result bits are set or cleared as needed.
class SUB < Command
  def initialize
    super("SUB")
  end

  def execute(hardware)
    result = hardware.accumulator - hardware.data_register

    # Check for overflow
    if result > 2**31 - 1 || result < -2**31
      hardware.overflow_bit = true
    else
      hardware.overflow_bit = false
    end

    hardware.accumulator = result
    hardware.zero_bit = (result == 0)
  end
end

#HLT Command: Terminates program execution.
class HLT < Command
  def initialize
    super("HLT")
  end

  def execute(hardware)
    hardware.print_registers_and_flags
    hardware.print_memory
    hardware.print_symbols_table
    puts "Program Terminated"
    exit(0)
  end
end

class ALI
  #Execute step instruction
  def execute_single_instruction(hardware)
    instruction_str = hardware.read_memory(hardware.program_counter)
    opcode, *args = instruction_str.split(" ")

    case opcode
    when "DEC"
      symbol = args[0]
      DEC.new(symbol).execute(hardware)
    when "LDA"
      symbol = args[0]
      LDA.new(symbol).execute(hardware)
    when "LDI"
      value = args[0].to_i
      LDI.new(value).execute(hardware)
    when "STR"
      symbol = args[0]
      STR.new(symbol).execute(hardware)
    when "XCH"
      XCH.new.execute(hardware)
    when "JMP"
      address = args[0].to_i
      JMP.new(address).execute(hardware)
    when "JZS"
      address = args[0].to_i
      JZS.new(address).execute(hardware)
    when "JVS"
      address = args[0].to_i
      JVS.new(address).execute(hardware)
    when "ADD"
      ADD.new.execute(hardware)
    when "SUB"
      SUB.new.execute(hardware)
    when "HLT"
      HLT.new.execute(hardware)
    else
      # Invalid instruction
      raise StandardError, "Invalid instruction encountered"
    end

    hardware.program_counter += 1
    hardware.print_registers_and_flags
    hardware.print_memory
    hardware.print_symbols_table
  end

  #Execute a command
  def execute_all_instructions(hardware)
    instruction_count = 0
    continue_execution = true

    while continue_execution && instruction_count < 1000
      instruction_str = hardware.read_memory(hardware.program_counter)
      opcode, *args = instruction_str.split(" ")

      case opcode
      when "DEC"
        symbol = args[0]
        DEC.new(symbol).execute(hardware)
      when "LDA"
        symbol = args[0]
        LDA.new(symbol).execute(hardware)
      when "LDI"
        value = args[0].to_i
        LDI.new(value).execute(hardware)
      when "STR"
        symbol = args[0]
        STR.new(symbol).execute(hardware)
      when "XCH"
        XCH.new.execute(hardware)
      when "JMP"
        address = args[0].to_i
        JMP.new(address).execute(hardware)
      when "JZS"
        address = args[0].to_i
        JZS.new(address).execute(hardware)
      when "JVS"
        address = args[0].to_i
        JVS.new(address).execute(hardware)
      when "ADD"
        ADD.new.execute(hardware)
      when "SUB"
        SUB.new.execute(hardware)
      when "HLT"
        HLT.new.execute(hardware)
      else
        # Invalid instruction
        raise StandardError, "Invalid instruction encountered"
      end

      instruction_count += 1
      hardware.program_counter += 1

      if instruction_count == 1000 && continue_execution
        hardware.print_registers_and_flags
        hardware.print_memory
        hardware.print_symbols_table
        print "Maximum instruction count reached. Do you want to continue execution? (y/n): "
        input = gets.chomp.downcase
        continue_execution = (input == 'y')
        instruction_count = 0
      end
    end
    hardware.print_registers_and_flags
    hardware.print_memory
    hardware.print_symbols_table
  end
end

def main
  hardware = Hardware.new
  ali = ALI.new

  print "Enter the filename: "
  file_name = gets.chomp

  program = FileReader.read_program(file_name)
  hardware.load_program(program)

  loop do
    print_prompt
    command = gets.chomp.downcase
    case command
    when 's'
      ali.execute_single_instruction(hardware)
    when 'a'
      ali.execute_all_instructions(hardware)
    when 'q'
      break
    else
      puts "Invalid command. Please enter 's', 'a', or 'q'."
    end
  end
end

def print_prompt
  puts "Enter command ('s' to execute single instruction, 'a' to execute all instructions, 'q' to quit):"
  print "> "
end

main