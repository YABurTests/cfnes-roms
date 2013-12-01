AddressingMode =
    Implied:          1
    Accumulator:      2
    Immediate:        3
    ZeroPage:         4
    IndexedXZeroPage: 5
    IndexedYZeroPage: 6
    Absolute:         7
    IndexedXAbsolute: 8
    IndexedYAbsolute: 9
    Relative:         10
    Indirect:         11
    IndexedXIndirect: 12
    IndirectIndexedY: 13

Instruction = 
    ADC:  1
    AND:  2
    ASL:  3
    BCC:  4
    BCS:  5
    BEQ:  6
    BIT:  7
    BMI:  8
    BNE:  9
    BPL: 10
    BRK: 11
    BVC: 12
    BVS: 13
    CLC: 14
    CLD: 15
    CLI: 16
    CLV: 17
    CMP: 18
    CPX: 19
    CPY: 20

Interrupt =
    IRQ:   1
    NMI:   2
    Reset: 3

class CPU
    constructor: (@memory, @ppu, @apu) ->
        @init()
        @powerUp()

    init: ->
        @initAddressingModesTable()
        @initInstructionsTable()
        @initOperationsTable()

    initAddressingModesTable: ->
        @addressingModesTable = []

        @registerAddressingMode AddressingMode.Implied, ->
            @tick()

        @registerAddressingMode AddressingMode.Accumulator, ->
            @tick()

        @registerAddressingMode AddressingMode.Immediate, ->
            @tick()
            @programCounter++

        @registerAddressingMode AddressingMode.ZeroPage, ->
            @readNextProgramByte()

        @registerAddressingMode AddressingMode.IndexedXZeroPage, ->
            @computeIndexedAddressByte @readNextProgramByte(), @registerX

        @registerAddressingMode AddressingMode.IndexedXZeroPage, ->
            @computeIndexedAddressByte @readNextProgramByte(), @registerY

        @registerAddressingMode AddressingMode.Absolute, ->
            @readNextProgramWord()

        @registerAddressingMode AddressingMode.IndexedXAbsolute, ->
            @computeIndexedAddressWord  @readNextProgramWord(), @registerX

        @registerAddressingMode AddressingMode.IndexedXAbsolute, ->
            @computeIndexedAddressWord  @readNextProgramWord(), @registerY

        @registerAddressingMode AddressingMode.Relative, ->
            offset = @toSigned @readNextProgramByte()
            @computeIndexedAddressWord @programCounter, offset

        @registerAddressingMode AddressingMode.Indirect, ->
            @readWord @readNextProgramWord()

        @registerAddressingMode AddressingMode.IndexedXIndirect, ->
            address = @computeIndexedAddressByte @readNextProgramByte(), @registerX
            @readWord address

        @registerAddressingMode AddressingMode.IndirectIndexedY, ->
            base = @readWord @readNextProgramByte()
            @computeIndexedAddressWord base, @registerY

    computeIndexedAddressByte: (base, offset) ->
        (base + offset) & 0xFF

    computeIndexedAddressWord : (base, offset) ->
        @checkPageCrossed base, offset
        (base + offset) & 0xFFFF

    checkPageCrossed: (base, offset) ->
        @tick() if base & 0xFF00 != (base + offset) & 0xFF00

    registerAddressingMode: (addressingMode, computation) ->
        @addressingModesTable[addressingMode] = computation

    initInstructionsTable: ->
        @instructionsTable = []

        @registerInstruction Instruction.ADC, (address) ->
            operand = @readByte address
            result = @accumulator + operand + @carryFlag
            @computeCarryFlag result
            @computeZeroFlag result
            @computeOverflowFlag @accumulator, operand, @result
            @computeNegativeFlag result
            @accumulator = result & 0xFF

        @registerInstruction Instruction.AND, (address) ->
            @accumulator = @accumulator & @readByte address
            @computeZeroFlag @accumulator
            @computeNegativeFlag @accumulator

        @registerInstruction Instruction.ASL, (address) ->
            if address?
                result = (@readByte address) << 1
                @computeCarryFlag result
                @computeZeroFlag result
                @computeNegativeFlag result
                @writeByte address, result & 0xFF
            else
                result = @accumulator << 1
                @computeCarryFlag result
                @computeZeroFlag result
                @computeNegativeFlag result
                @accumulator = result & 0xFF

        @registerInstruction Instruction.BCC, (address) ->
            @branchIfTrue @carryFlag == 0, address

        @registerInstruction Instruction.BCS, (address) ->
            @branchIfTrue @carryFlag == 1, address

        @registerInstruction Instruction.BEQ, (address) ->
            @branchIfTrue @zeroFlag == 1,  address

        @registerInstruction Instruction.BIT, (address) ->
            operand = @readByte address
            result = @accumulator & operand 
            @computeZeroFlag result
            @overflowFlag = (result >> 7) & 1 # Exception on overflow computation
            @computeNegativeFlag result

        @registerInstruction Instruction.BMI, (address) ->
            @branchIfTrue @negativeFlag == 1, address

        @registerInstruction Instruction.BNE, (address) ->
            @branchIfTrue @zeroFlag == 0,  address

        @registerInstruction Instruction.BPL, (address) ->
            @branchIfTrue @negativeFlag == 0,  address

        @registerInstruction Instruction.BRK, ->
            @breakCommand = 1
            @handleInterrupt 0xFFFE

        @registerInstruction Instruction.BVC, (address) ->
            @branchIfTrue @overflowFlag == 0,  address

        @registerInstruction Instruction.BVS, (address) ->
            @branchIfTrue @overflowFlag == 1,  address

        @registerInstruction Instruction.CLC, ->
            @carryFlag = 0

        @registerInstruction Instruction.CLD, ->
            @decimalMode = 0

        @registerInstruction Instruction.CLI, ->
            @interruptDisable = 0

        @registerInstruction Instruction.CLV, ->
            @overflowFlag = 0

        @registerInstruction Instruction.CMP, (address) ->
            @compareRegisterAndMemory @accumulator, address
            
        @registerInstruction Instruction.CPX, ->
            @compareRegisterAndMemory @registerX, address

        @registerInstruction Instruction.CPY, ->
            @compareRegisterAndMemory @registerY, address

    computeCarryFlag: (result) ->
        @carryFlag = if result > 0xFF then 1 else 0

    computeZeroFlag: (result) ->
        @zeroFlag = if (result & 0xFF) != 0 then 1 else 0

    computeOverflowFlag: (operand1, operand2, result) ->
        @overflowFlag = if (operand1 ^ result) & (operand2 ^ result) & 0x80 != 0 then 1 else 0

    computeNegativeFlag: (result) ->
        @negativeFlag = (result >> 7) & 1

    branchIfTrue: (condition, address) ->
        if condition
            @programCounter = address
            @tick()

    compareRegisterAndMemory: (register, address) -> 
        operand = @readByte address
        result = register - operand 
        @carryFlag = if result >= 0 then 1 else 0 # Exception on carry computation
        @computeZeroFlag result
        @computeNegativeFlag result

    registerInstruction: (instruction, execution) ->
        @instructionsTable[instruction] = execution

    initOperationsTable: ->
        @operationsTable = []

        @registerOperation 0x69, Instruction.ADC, AddressingMode.Immediate
        @registerOperation 0x65, Instruction.ADC, AddressingMode.ZeroPage
        @registerOperation 0x75, Instruction.ADC, AddressingMode.IndexedXZeroPage
        @registerOperation 0x6D, Instruction.ADC, AddressingMode.Absolute
        @registerOperation 0x7D, Instruction.ADC, AddressingMode.IndexedXAbsolute
        @registerOperation 0x79, Instruction.ADC, AddressingMode.IndexedYAbsolute
        @registerOperation 0x61, Instruction.ADC, AddressingMode.IndexedXIndirect
        @registerOperation 0x71, Instruction.ADC, AddressingMode.IndirectIndexedY

        @registerOperation 0x29, Instruction.AND, AddressingMode.Immediate
        @registerOperation 0x25, Instruction.AND, AddressingMode.ZeroPage
        @registerOperation 0x35, Instruction.AND, AddressingMode.IndexedXZeroPage
        @registerOperation 0x2D, Instruction.AND, AddressingMode.Absolute
        @registerOperation 0x3D, Instruction.AND, AddressingMode.IndexedXAbsolute
        @registerOperation 0x39, Instruction.AND, AddressingMode.IndexedYAbsolute
        @registerOperation 0x21, Instruction.AND, AddressingMode.IndexedXIndirect
        @registerOperation 0x31, Instruction.AND, AddressingMode.IndirectIndexedY
        
        @registerOperation 0x0A, Instruction.ASL, AddressingMode.Accumulator
        @registerOperation 0x06, Instruction.ASL, AddressingMode.ZeroPage
        @registerOperation 0x16, Instruction.ASL, AddressingMode.IndexedXZeroPage
        @registerOperation 0x0E, Instruction.ASL, AddressingMode.Absolute
        @registerOperation 0x1E, Instruction.ASL, AddressingMode.IndexedXAbsolute

        @registerOperation 0x90, Instruction.BCC, AddressingMode.Relative

        @registerOperation 0xB0, Instruction.BCS, AddressingMode.Relative

        @registerOperation 0xB0, Instruction.BEQ, AddressingMode.Relative

        @registerOperation 0x24, Instruction.BIT, AddressingMode.ZeroPage
        @registerOperation 0x2C, Instruction.BIT, AddressingMode.Absolute

        @registerOperation 0x30, Instruction.BMI, AddressingMode.Relative

        @registerOperation 0xD0, Instruction.BNE, AddressingMode.Relative

        @registerOperation 0x10, Instruction.BPL, AddressingMode.Relative

        @registerOperation 0x00, Instruction.BRK, AddressingMode.Implied

        @registerOperation 0x50, Instruction.BVC, AddressingMode.Relative

        @registerOperation 0x70, Instruction.BVS, AddressingMode.Relative

        @registerOperation 0x18, Instruction.CLC, AddressingMode.Implied

        @registerOperation 0xD8, Instruction.CLD, AddressingMode.Implied

        @registerOperation 0x58, Instruction.CLI, AddressingMode.Implied

        @registerOperation 0xB8, Instruction.CLV, AddressingMode.Implied

        @registerOperation 0xC9, Instruction.CMP, AddressingMode.Immediate
        @registerOperation 0xC5, Instruction.CMP, AddressingMode.ZeroPage
        @registerOperation 0xD5, Instruction.CMP, AddressingMode.IndexedXZeroPage
        @registerOperation 0xCD, Instruction.CMP, AddressingMode.Absolute
        @registerOperation 0xDD, Instruction.CMP, AddressingMode.IndexedXAbsolute
        @registerOperation 0xD9, Instruction.CMP, AddressingMode.IndexedYAbsolute
        @registerOperation 0xC1, Instruction.CMP, AddressingMode.IndexedXIndirect
        @registerOperation 0xD1, Instruction.CMP, AddressingMode.IndirectIndexedY

        @registerOperation 0xE0, Instruction.CPX, AddressingMode.Immediate
        @registerOperation 0xE4, Instruction.CPX, AddressingMode.ZeroPage
        @registerOperation 0xEC, Instruction.CPX, AddressingMode.Absolute

        @registerOperation 0xC0, Instruction.CPX, AddressingMode.Immediate
        @registerOperation 0xC4, Instruction.CPX, AddressingMode.ZeroPage
        @registerOperation 0xCC, Instruction.CPX, AddressingMode.Absolute

    registerOperation: (operationCode, instruction, addressingMode) ->
        @operationsTable[operationCode] = 
            instruction: instruction
            addressingMode: addressingMode

    powerUp: ->
        @resetRegistres()
        @resetFlags()
        @resetVariables()
        @resetMemory()

    resetRegistres: ->
        @programCounter = 0  # 16-bit
        @stackPointer = 0xFD # 8-bit
        @accumulator = 0     # 8-bit
        @registerX = 0       # 8-bit
        @registerY = 0       # 8-bit

    resetFlags: ->
        @carryFlag = 0        # bit 0
        @zeroFlag = 0         # bit 1
        @interruptDisable = 1 # bit 2
        @decimalMode = 0      # bit 3
        @breakCommand = 1     # bit 4
        @overflowFlag = 0     # bit 6
        @negativeFlag = 0     # bit 7

    resetVariables: ->
        @cycle = 0
        @requestedInterrupt = null

    resetMemory: ->
        @writeByte address, 0xFF for address in [0...0x0800]
        @writeByte 0x0008, 0xF7
        @writeByte 0x0009, 0xEF
        @writeByte 0x000A, 0xDF
        @writeByte 0x000F, 0xBF
        @writeByte 0x4017, 0x00
        @writeByte 0x4015, 0x00
        @writeByte address, 0x00 for address in [0x4000...0x4010]

    tick: ->
        @cycle++
        @ppu.tick() for [1...3]
        @apu.tick()
        undefined

    step: ->
        @checkInterrupt()
        operation = @readOperation()
        address = @computeAddress operation.addressingMode
        @executeInstruction operation.instruction address

    checkInterrupt: ->
        if @requestedInterrupt? and not @interruptDisable
            switch @requestedInterrupt
                when Interrupt.IRQ   then @handleInterrupt 0xFFFE
                when Interrupt.NMI   then @handleInterrupt 0xFFFA
                when Interrupt.Reset then @handleInterrupt 0xFFFC
            requestedInterrupt = null
            @tick()
            @tick()

    handleInterrupt: (interruptVectorAddress)->
        @pushWord @programCounter
        @pushByte @getStatus()
        @interruptDisable = 1
        @programCounter = @readWord interruptVectorAddress

    readOperation: ->
        operationCode = @readNextProgramByte()
        @operationsTable[operationCode]

    readNextProgramByte: ->
        @readByte @programCounter++

    readNextProgramWord: ->
        result = @readWord @programCounter
        @programCounter += 2
        result

    computeAddress: (addressingMode) ->
        @addressingModesTable[addressingMode]()

    executeInstruction: (instruction, address) ->
        @instructionsTable[instruction](address)

    pushByte: (value) ->
        @stackPointer = (@stackPointer - 1) & 0xFF
        @writeByte 0x100 + @stackPointer, value

    pushWord: (value) ->
        @pushByte (value >> 8) & 0xFF
        @pushByte value & 0xFF

    popByte: ->
        @stackPointer = (@stackPointer + 1) & 0xFF
        @readByte 0x100 + @stackPointer

    popWord: ->
        result = @popByte()
        result |= @popByte() << 8

    readByte: (address) ->
        @tick()
        @memory.read address

    readWord: (address) ->
        (@readByte address + 1) << 8 | @readByte address

    writeByte: (address, value) ->
        @tick()
        @memory.write address, value

    writeWord: (address, value) ->
        @writeByte address, value & 0xFF
        @writeByte address + 1, value >> 8

    toSigned: (value) ->
        if value < 0x80 then value else value - 0xFF

    getStatus: ->
        status = @carryFlag
        status |= @zeroFlag << 1 
        status |= @interruptDisable << 2
        status |= @decimalMode << 3 
        status |= @breakCommand << 4
        status |= @overflowFlag << 6
        status |= @negativeFlag << 7

    setStatus: (status) ->
        @carryFlag = status & 1
        @zeroFlag = (status >> 1) & 1
        @interruptDisable = (status >> 2) & 1
        @decimalMode = (status >> 3) & 1
        @breakCommand = (status >> 4) & 1
        @overflowFlag = (status >> 6) & 1
        @negativeFlag = (status >> 7) & 1

    reset: ->
        @setRequestedInterrupt Interrupt.Reset

    requestNonMaskableInterrupt: ->
        @setRequestedInterrupt Interrupt.NMI

    setRequestedInterrupt: (type) ->
        if @requestedInterrupt == null or type > @requestedInterrupt
            @requestedInterrupt = type 

module.exports = CPU
