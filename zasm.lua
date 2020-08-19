----------------------------------------------------------
--
-- ZASM.LUA
--
-----------------------------------------------------------

--OPTIONS
commentChar = 0x23 --- # = 0x23, ; = 0x3B

--REGS
local registers = {}
registers.ZERO = 0x00
registers.R0 = 0x00
registers.AT = 0x01
registers.V0 = 0x02
registers.V1 = 0x03
registers.A0 = 0x04
registers.A1 = 0x05
registers.A2 = 0x06
registers.A3 = 0x07

registers.T0 = 0x08
registers.T1 = 0x09
registers.T2 = 0x0A
registers.T3 = 0x0B
registers.T4 = 0x0C
registers.T5 = 0x0D
registers.T6 = 0x0E
registers.T7 = 0x0F

registers.S0 = 0x10
registers.S1 = 0x11
registers.S2 = 0x12
registers.S3 = 0x13
registers.S4 = 0x14
registers.S5 = 0x15
registers.S6 = 0x16
registers.S7 = 0x17

registers.T8 = 0x18
registers.T9 = 0x19
registers.K0 = 0x1A
registers.K1 = 0x1B
registers.GP = 0x1C
registers.SP = 0x1D
registers.S8 = 0x1E
registers.RA = 0x1F

local errors = {}

errors.INVALID_ARGUMENTS = 0x01
errors.INVALID_REGISTER  = 0x02
errors.INVALID_BASEOFFSET_PAIR = 0x03
errors.INVALID_COMMAND = 0x04
errors.INVALID_VALUE = 0x05
errors.NO_COMMAND_FOUND = 0x06
errors.INVALID_USE_OF_HI_LO = 0x07

local warnids = {}

warnids.CODE_AFTER_LABEL = 0x00
warnids.INVALID_FORMAT = 0x01
warnids.UNABLE_TO_OPEN_FILE = 0x02

local fns = {}
local warnings = {}
local isError = false
local useRom = false

local function throw(errid, msg, caller)
	isError = true
	print(caller .. ": " .. msg .. " (Error " .. errid .. ")")
    printWarnings()
    os.exit()
end

local function warn(warnid, msg, caller)
	local warning = {}
	warning.id = warnid
	warning.caller = caller
	warning.msg = msg
	table.insert(warnings, warning)
end

local function isreg(v)
	return (v >= registers.R0 and v <= registers.RA)
end

local function computeAddress(dest, src)
	return dest-src-0x04
end

--ADD
function fns.mips_add(dest, src0, src1)
	if (not(isreg(dest) and isreg(src0) and isreg(src1))) then 
		throw(errors.INVALID_ARGUMENTS, "Invalid arguments given!", "ADD")
		return -1;
	end
	local res = bit.lshift(src0, 21)
	res = res + bit.lshift(src1, 16)
	res = res + bit.lshift(dest, 11)
	res = res + 0x20
	return res
end

--ADDI
function fns.mips_addi(dest, src, imm)
	local res = bit.lshift(0x08, 26)
	res = res + bit.lshift(src, 21)
	res = res + bit.lshift(dest, 16)
	res = res + bit.band(imm, 0xFFFF)
	return res
end

--ADDIU
function fns.mips_addiu(dest, src, imm)
	local res = bit.lshift(0x09, 26)
	res = res + bit.lshift(src, 21)
	res = res + bit.lshift(dest, 16)
	res = res + bit.band(imm, 0xFFFF)
	return res
end

--ADDU
function fns.mips_addu(dest, src0, src1)
	local res = bit.lshift(src0, 21)
	res = res + bit.lshift(src1, 16)
	res = res + bit.lshift(dest, 11)
	res = res + 0x21
	return res
end

--AND
function fns.mips_and (dest, src0, src1)
	local res = bit.lshift(src0, 21)
	res = res + bit.lshift(src1, 16)
	res = res + bit.lshift(dest, 11)
	res = res + 0x24
	return res
end

--ANDI
function fns.mips_andi(dest, src, imm)
	local res = bit.lshift(0x0C, 26)
	res = res + bit.lshift(src, 21)
	res = res + bit.lshift(dest, 16)
	res = res + bit.band(imm, 0xFFFF)
	return res
end

--B
function fns.mips_b(dest, unused0, unused1, src)
	return fns.mips_beq(0, 0, dest, src)
end

--BEQ
-- note that the address to jump is pc-relative thus a signed offset
function fns.mips_beq(c0, c1, dest, src)
	local offset = computeAddress(dest, src)
	local res = bit.lshift(0x04, 26)
	res = res + bit.lshift(c0, 21)
	res = res + bit.lshift(c1, 16)
	res = res + bit.band(bit.rshift(offset, 2), 0xFFFF)
	return res
end

--BEQL
function fns.mips_beql(c0, c1, dest, src)
	local offset = computeAddress(dest, src)
	local res = bit.lshift(0x14, 26)
	res = res + bit.lshift(c0, 21)
	res = res + bit.lshift(c1, 16)
	res = res + bit.band(bit.rshift(offset, 2), 0xFFFF)
	return res
end

--BGEZ
function fns.mips_bgez(c0, dest, unused, src)
	local offset = computeAddress(dest, src)
	local res = bit.lshift(0x01, 26)
	res = res + bit.lshift(c0, 21)
	res = res + bit.lshift(0x01, 16)
	res = res + bit.band(bit.rshift(offset, 2), 0xFFFF)
	return res
end

--BGEZAL
function fns.mips_bgezal(c0, dest, unused, src)
	local offset = computeAddress(dest, src)
	local res = bit.lshift(0x01, 26)
	res = res + bit.lshift(c0, 21)
	res = res + bit.lshift(0x11, 16)
	res = res + bit.band(bit.rshift(offset, 2), 0xFFFF)
	return res
end

--BGEZALL
function fns.mips_bgezall(c0, dest, unused, src)
	local offset = computeAddress(dest, src)
	local res = bit.lshift(0x01, 26)
	res = res + bit.lshift(c0, 21)
	res = res + bit.lshift(0x13, 16)
	res = res + bit.band(bit.rshift(offset, 2), 0xFFFF)
	return res
end

--BGEZL
function fns.mips_bgezl(c0, dest, unused, src)
	local offset = computeAddress(dest, src)
	local res = bit.lshift(0x01, 26)
	res = res + bit.lshift(c0, 21)
	res = res + bit.lshift(0x03, 16)
	res = res + bit.band(bit.rshift(offset, 2), 0xFFFF)
	return res
end

--BGTZ
function fns.mips_bgtz(c0, dest, unused, src)
	local offset = computeAddress(dest, src)
	local res = bit.lshift(0x07, 26)
	res = res + bit.lshift(c0, 21)
	res = res + bit.band(bit.rshift(offset, 2), 0xFFFF)
	return res
end

--BGTZL
function fns.mips_bgtzl(c0, dest, unused, src)
	local offset = computeAddress(dest, src)
	local res = bit.lshift(0x17, 26)
	res = res + bit.lshift(c0, 21)
	res = res + bit.band(bit.rshift(offset, 2), 0xFFFF)
	return res
end

--BLEZ
function fns.mips_blez(c0, dest, unused, src)
	local offset = computeAddress(dest, src)
	local res = bit.lshift(0x06, 26)
	res = res + bit.lshift(c0, 21)
	res = res + bit.band(bit.rshift(offset, 2), 0xFFFF)
	return res
end

--BLEZL
function fns.mips_blezl(c0, dest, unused, src)
	local offset = computeAddress(dest, src)
	local res = bit.lshift(0x16, 26)
	res = res + bit.lshift(c0, 21)
	res = res + bit.band(bit.rshift(offset, 2), 0xFFFF)
	return res
end

--BLTZ
function fns.mips_bltz(c0, dest, unused, src)
	local offset = computeAddress(dest, src)
	local res = bit.lshift(0x01, 26)
	res = res + bit.lshift(c0, 21)
	res = res + bit.band(bit.rshift(offset, 2), 0xFFFF)
	return res
end

--BLTZAL
function fns.mips_bltzal(c0, dest, unused, src)
	local offset = computeAddress(dest, src)
	local res = bit.lshift(0x01, 26)
	res = res + bit.lshift(c0, 21)
	res = res + bit.lshift(0x10, 16)
	res = res + bit.band(bit.rshift(offset, 2), 0xFFFF)
	return res
end

--BLTZALL
function fns.mips_bltzall(c0, dest, unused, src)
	local offset = computeAddress(dest, src)
	local res = bit.lshift(0x01, 26)
	res = res + bit.lshift(c0, 21)
	res = res + bit.lshift(0x12, 16)
	res = res + bit.band(bit.rshift(offset, 2), 0xFFFF)
	return res
end

--BLTZL
function fns.mips_bltzl(c0, dest, unused, src)
	local offset = computeAddress(dest, src)
	local res = bit.lshift(0x01, 26)
	res = res + bit.lshift(c0, 21)
	res = res + bit.lshift(0x02, 16)
	res = res + bit.band(bit.rshift(offset, 2), 0xFFFF)
	return res
end

--BNE
function fns.mips_bne(c0, c1, dest, src)
	local offset = computeAddress(dest, src)
	local res = bit.lshift(0x05, 26)
	res = res + bit.lshift(c0, 21)
	res = res + bit.lshift(c1, 16)
	res = res + bit.band(bit.rshift(offset, 2), 0xFFFF)
	return res
end

--BNEL
function fns.mips_bnel(c0, c1, dest, src)
	local offset = computeAddress(dest, src)
	local res = bit.lshift(0x15, 26)
	res = res + bit.lshift(c0, 21)
	res = res + bit.lshift(c1, 16)
	res = res + bit.band(bit.rshift(offset, 2), 0xFFFF)
	return res
end

--BREAK
-- code option is omitted
function fns.mips_break()
	return 0x0000000D
end

--COPz FIXME

--DADD
function fns.mips_dadd(dest, src0, src1)
	local res = bit.lshift(src0, 21)
	res = res + bit.lshift(src1, 16)
	res = res + bit.lshift(dest, 11)
	res = res + 0x2C
	return res
end

--DADDI
function fns.mips_daddi(dest, src, imm)
	local res = bit.lshift(0x18, 26)
	res = res + bit.lshift(src, 21)
	res = res + bit.lshift(dest, 16)
	res = res + bit.band(imm, 0xFFFF)
	return res
end

--DADDIU
function fns.mips_daddiu(dest, src, imm)
	local res = bit.lshift(0x19, 26)
	res = res + bit.lshift(src, 21)
	res = res + bit.lshift(dest, 16)
	res = res + bit.band(imm, 0xFFFF)
	return res
end

--DADDU
function fns.mips_daddu(dest, src0, src1)
	local res = bit.lshift(src0, 21)
	res = res + bit.lshift(src1, 16)
	res = res + bit.lshift(dest, 11)
	res = res + 0x2D
	return res
end

--DDIV
function fns.mips_ddiv(v, divider)
	local res = bit.lshift(v, 21)
	res = res + bit.lshift(divider, 16)
	res = res + 0x1E
	return res
end

--DDIVU
function fns.mips_ddivu(v, divider)
	local res = bit.lshift(v, 21)
	res = res + bit.lshift(divider, 16)
	res = res + 0x1F
	return res
end

--DIV
function fns.mips_div(v, divider)
	local res = bit.lshift(v, 21)
	res = res + bit.lshift(divider, 16)
	res = res + 0x1A
	return res
end

--DIVU
function fns.mips_divu(v, divider)
	local res = bit.lshift(v, 21)
	res = res + bit.lshift(divider, 16)
	res = res + 0x1B
	return res
end

--DMULT
function fns.mips_dmult(f0, f1)
	local res = bit.lshift(f0, 21)
	res = res + bit.lshift(f1, 16)
	res = res + 0x1C
	return res
end

--DMULTU
function fns.mips_dmultu(f0, f1)
	local res = bit.lshift(f0, 21)
	res = res + bit.lshift(f1, 16)
	res = res + 0x1D
	return res
end

--DSLL
function fns.mips_dsll(dest, src, bits)
	local res = bit.lshift(src, 16)
	res = res + bit.lshift(dest, 11)
	res = res + bit.lshift(bit.band(bits, 0x1F), 6)
	res = res + 0x38
	return res
end

--DSLL32
function fns.mips_dsll32(dest, src, bits)
	local res = bit.lshift(src, 16)
	res = res + bit.lshift(dest, 11)
	res = res + bit.lshift(bit.band(bits, 0x1F), 6)
	res = res + 0x3C
	return res
end

--DSLLV
function fns.mips_dsllv(dest, src, var)
	local res = bit.lshift(var, 21)
	res = res + bit.lshift(src, 16)
	res = res + bit.lshift(dest, 11)
	res = res + 0x18
	return res
end

--DSRA
function fns.mips_dsra(dest, src, bits)
	local res = bit.lshift(src, 16)
	res = res + bit.lshift(dest, 11)
	res = res + bit.lshift(bit.band(bits, 0x1F), 6)
	res = res + 0x3B
	return res
end

--DSRA32
function fns.mips_dsra32(dest, src, bits)
	local res = bit.lshift(src, 16)
	res = res + bit.lshift(dest, 11)
	res = res + bit.lshift(bit.band(bits, 0x1F), 6)
	res = res + 0x3F
	return res
end

--DSRAV
function fns.mips_dsrav(dest, src, var)
	local res = bit.lshift(var, 21)
	res = res + bit.lshift(src, 16)
	res = res + bit.lshift(dest, 11)
	res = res + 0x17
	return res
end

--DSRL
function fns.mips_dsrl(dest, src, bits)
	local res = bit.lshift(src, 16)
	res = res + bit.lshift(dest, 11)
	res = res + bit.lshift(bit.band(bits, 0x1F), 6)
	res = res + 0x3A
	return res
end

--DSRL32
function fns.mips_dsrl32(dest, src, bits)
	local res = bit.lshift(src, 16)
	res = res + bit.lshift(dest, 11)
	res = res + bit.lshift(bit.band(bits, 0x1F), 6)
	res = res + 0x3E
	return res
end

--DSRLV
function fns.mips_dsrlv(dest, src, var)
	local res = bit.lshift(var, 21)
	res = res + bit.lshift(src, 16)
	res = res + bit.lshift(dest, 11)
	res = res + 0x16
	return res
end

--DSUB
function fns.mips_dsub(dest, src, subtract)
	local res = bit.lshift(src, 21)
	res = res + bit.lshift(subtract, 16)
	res = res + bit.lshift(dest, 11)
	res = res + 0x2E
	return res
end

--DSUBU
function fns.mips_dsubu(dest, src, subtract)
	local res = bit.lshift(src, 21)
	res = res + bit.lshift(subtract, 16)
	res = res + bit.lshift(dest, 11)
	res = res + 0x2F
	return res
end

--J
function fns.mips_j(addr)
	local res = bit.lshift(0x02, 26)
	res = res + bit.band(bit.rshift(addr, 2), 0x03FFFFFF)
	return res
end

--JAL
function fns.mips_jal(addr)
	local res = bit.lshift(0x03, 26)
	res = res + bit.band(bit.rshift(addr, 2), 0x03FFFFFF)
	return res
end

--JALR
-- note that on "JALR rd, rs" , target=rs and return_addr=rd
function fns.mips_jalr(target, return_addr)
	-- case JALR rs (rd = 31 implied)
	if return_addr == nil then return_addr = registers.RA end
	
	local res = bit.lshift(target, 21)
	res = res + bit.lshift(return_addr, 11)
	res = res + 0x09
	return res
end

--JR
function fns.mips_jr(reg)
	local res = bit.lshift(reg, 21)
	res = res + 0x08
	return res
end

--LB
function fns.mips_lb(reg, base, offset)
	local res = bit.lshift(0x20, 26)
	res = res + bit.lshift(base, 21)
	res = res + bit.lshift(reg, 16)
	res = res + bit.band(offset, 0xFFFF)
	return res
end

--LBU
function fns.mips_lbu(reg, base, offset)
	local res = bit.lshift(0x24, 26)
	res = res + bit.lshift(base, 21)
	res = res + bit.lshift(reg, 16)
	res = res + bit.band(offset, 0xFFFF)
	return res
end

--LD
function fns.mips_ld(reg, base, offset)
	local res = bit.lshift(0x37, 26)
	res = res + bit.lshift(base, 21)
	res = res + bit.lshift(reg, 16)
	res = res + bit.band(offset, 0xFFFF)
	return res
end

--LDCz
-- FIXME: implement me

--LDL
function fns.mips_ldl(reg, base, offset)
	local res = bit.lshift(0x1A, 26)
	res = res + bit.lshift(base, 21)
	res = res + bit.lshift(reg, 16)
	res = res + bit.band(offset, 0xFFFF)
	return res
end

--LDR
function fns.mips_ldr(reg, base, offset)
	local res = bit.lshift(0x1B, 26)
	res = res + bit.lshift(base, 21)
	res = res + bit.lshift(reg, 16)
	res = res + bit.band(offset, 0xFFFF)
	return res
end

--LH
function fns.mips_lh(reg, base, offset)
	local res = bit.lshift(0x21, 26)
	res = res + bit.lshift(base, 21)
	res = res + bit.lshift(reg, 16)
	res = res + bit.band(offset, 0xFFFF)
	return res
end

--LHU
function fns.mips_lhu(reg, base, offset)
	local res = bit.lshift(0x25, 26)
	res = res + bit.lshift(base, 21)
	res = res + bit.lshift(reg, 16)
	res = res + bit.band(offset, 0xFFFF)
	return res
end

--LL
function fns.mips_ll(reg, base, offset)
	local res = bit.lshift(0x30, 26)
	res = res + bit.lshift(base, 21)
	res = res + bit.lshift(reg, 16)
	res = res + bit.band(offset, 0xFFFF)
	return res
end

--LLD
function fns.mips_lld(reg, base, offset)
	local res = bit.lshift(0x34, 26)
	res = res + bit.lshift(base, 21)
	res = res + bit.lshift(reg, 16)
	res = res + bit.band(offset, 0xFFFF)
	return res
end

--LUI
function fns.mips_lui(reg, imm)
	local res = bit.lshift(0x0F, 26)
	res = res + bit.lshift(reg, 16)
	res = res + bit.band(imm, 0xFFFF)
	return res
end

--LW
function fns.mips_lw(reg, base, offset)
	local res = bit.lshift(0x23, 26)
	res = res + bit.lshift(base, 21)
	res = res + bit.lshift(reg, 16)
	res = res + bit.band(offset, 0xFFFF)
	return res
end

--LWCz
-- FIXME: implement this

--LWL
function fns.mips_lwl(reg, base, offset)
	local res = bit.lshift(0x22, 26)
	res = res + bit.lshift(base, 21)
	res = res + bit.lshift(reg, 16)
	res = res + bit.band(offset, 0xFFFF)
	return res
end

--LWR
function fns.mips_lwr(reg, base, offset)
	local res = bit.lshift(0x26, 26)
	res = res + bit.lshift(base, 21)
	res = res + bit.lshift(reg, 16)
	res = res + bit.band(offset, 0xFFFF)
	return res
end

--LWU
function fns.mips_lwu(reg, base, offset)
	local res = bit.lshift(0x27, 26)
	res = res + bit.lshift(base, 21)
	res = res + bit.lshift(reg, 16)
	res = res + bit.band(offset, 0xFFFF)
	return res
end

--MFHI
function fns.mips_mfhi(reg)
	local res = bit.lshift(reg, 11)
	res = res + 0x10
	return res
end

--MFLO
function fns.mips_mflo(reg)
	local res = bit.lshift(reg, 11)
	res = res + 0x12
	return res
end

--MOVN
function fns.mips_movn(dest, src, c0)
	local res = bit.lshift(src, 21)
	res = res + bit.lshift(c0, 16)
	res = res + bit.lshift(dest, 11)
	res = res + 0x0B
	return res
end

--MOVZ
function fns.mips_movz(dest, src, c0)
	local res = bit.lshift(src, 21)
	res = res + bit.lshift(c0, 16)
	res = res + bit.lshift(dest, 11)
	res = res + 0x0A
	return res
end

--MTHI
function fns.mips_mthi(reg)
	local res = bit.lshift(reg, 21)
	res = res + 0x11
	return res
end

--MTLO
function fns.mips_mtlo(reg)
	local res = bit.lshift(reg, 21)
	res = res + 0x13
	return res
end

--MULT
function fns.mips_mult(f0, f1)
	local res = bit.lshift(f0, 21)
	res = res + bit.lshift(f1, 16)
	res = res + 0x18
	return res
end

--MULTU
function fns.mips_multu(f0, f1)
	local res = bit.lshift(f0, 21)
	res = res + bit.lshift(f1, 16)
	res = res + 0x19
	return res
end

--NOR
function fns.mips_nor(dest, src0, src1)
	local res = bit.lshift(src0, 21)
	res = res + bit.lshift(src1, 16)
	res = res + bit.lshift(dest, 11)
	res = res + 0x27
	return res
end

--OR
function fns.mips_or(dest, src0, src1)
	local res = bit.lshift(src0, 21)
	res = res + bit.lshift(src1, 16)
	res = res + bit.lshift(dest, 11)
	res = res + 0x25
	return res
end

--ORI
function fns.mips_ori(dest, src, imm)
	local res = bit.lshift(0x0D, 26)
	res = res + bit.lshift(src, 21)
	res = res + bit.lshift(dest, 16)
	res = res + bit.band(imm, 0xFFFF)
	return res
end

--PREF
function fns.mips_pref(hint, base, offset)
	local res = bit.lshift(0x33, 26)
	res = res + bit.lshift(base, 21)
	res = res + bit.lshift(bit.band(hint, 0x1F), 16)
	res = res + bit.band(imm, 0xFFFF)
	return res
end

--SB
function fns.mips_sb(reg, base, offset)
	local res = bit.lshift(0x28, 26)
	res = res + bit.lshift(base, 21)
	res = res + bit.lshift(reg, 16)
	res = res + bit.band(offset, 0xFFFF)
	return res
end

--SC
function fns.mips_sc(reg, base, offset)
	local res = bit.lshift(0x38, 26)
	res = res + bit.lshift(base, 21)
	res = res + bit.lshift(reg, 16)
	res = res + bit.band(offset, 0xFFFF)
	return res
end

--SCD
function fns.mips_scd(reg, base, offset)
	local res = bit.lshift(0x3C, 26)
	res = res + bit.lshift(base, 21)
	res = res + bit.lshift(reg, 16)
	res = res + bit.band(offset, 0xFFFF)
	return res
end

--SD
function fns.mips_sd(reg, base, offset)
	local res = bit.lshift(0x3F, 26)
	res = res + bit.lshift(base, 21)
	res = res + bit.lshift(reg, 16)
	res = res + bit.band(offset, 0xFFFF)
	return res
end

--SDCz
-- FIXME: implement me

--SDL
function fns.mips_sdl(reg, base, offset)
	local res = bit.lshift(0x2C, 26)
	res = res + bit.lshift(base, 21)
	res = res + bit.lshift(reg, 16)
	res = res + bit.band(offset, 0xFFFF)
	return res
end

--SDR
function fns.mips_sdl(reg, base, offset)
	local res = bit.lshift(0x2D, 26)
	res = res + bit.lshift(base, 21)
	res = res + bit.lshift(reg, 16)
	res = res + bit.band(offset, 0xFFFF)
	return res
end

--SH
function fns.mips_sh(reg, base, offset)
	local res = bit.lshift(0x29, 26)
	res = res + bit.lshift(base, 21)
	res = res + bit.lshift(reg, 16)
	res = res + bit.band(offset, 0xFFFF)
	return res
end

--SLL
function fns.mips_sll(dest, src, bits)
	local res = bit.lshift(src, 16)
	res = res + bit.lshift(dest, 11)
	res = res + bit.lshift(bit.band(bits, 0x1F), 6)
	return res
end

--SLLV
function fns.mips_sllv(dest, src, var)
	local res = bit.lshift(var, 21)
	res = res + bit.lshift(src, 16)
	res = res + bit.lshift(dest, 11)
	res = res + 0x04
	return res
end

--SLT
function fns.mips_slt(dest, c0, c1)
	local res = bit.lshift(c0, 21)
	res = res + bit.lshift(c1, 16)
	res = res + bit.lshift(dest, 11)
	res = res + 0x2A
	return res
end

--SLTI
function fns.mips_slti(dest, c0, imm)
	local res = bit.lshift(0x0A, 26)
	res = res + bit.lshift(c0, 21)
	res = res + bit.lshift(dest, 16)
	res = res + bit.band(imm, 0xFFFF)
	return res
end

--SLTIU
function fns.mips_sltiu(dest, c0, imm)
	local res = bit.lshift(0x0B, 26)
	res = res + bit.lshift(c0, 21)
	res = res + bit.lshift(dest, 16)
	res = res + bit.band(imm, 0xFFFF)
	return res
end

--SLTU
function fns.mips_sltu(dest, c0, c1)
	local res = bit.lshift(c0, 21)
	res = res + bit.lshift(c1, 16)
	res = res + bit.lshift(dest, 11)
	res = res + 0x2B
	return res
end

--SRA
function fns.mips_sra(dest, src, bits)
	local res = bit.lshift(src, 16)
	res = res + bit.lshift(dest, 11)
	res = res + bit.lshift(bit.band(bits, 0x1F), 6)
	res = res + 0x03
	return res
end

--SRAV
function fns.mips_srav(dest, src, var)
	local res = bit.lshift(var, 21)
	res = res + bit.lshift(src, 16)
	res = res + bit.lshift(dest, 11)
	res = res + 0x07
	return res
end

--SRL
function fns.mips_srl(dest, src, bits)
	local res = bit.lshift(src, 16)
	res = res + bit.lshift(dest, 11)
	res = res + bit.lshift(bit.band(bits, 0x1F), 6)
	res = res + 0x02
	return res
end

--SRLV
function fns.mips_srlv(dest, src, var)
	local res = bit.lshift(var, 21)
	res = res + bit.lshift(src, 16)
	res = res + bit.lshift(dest, 11)
	res = res + 0x06
	return res
end

--SUB
function fns.mips_sub(dest, src, subtract)
	local res = bit.lshift(src, 21)
	res = res + bit.lshift(subtract, 16)
	res = res + bit.lshift(dest, 11)
	res = res + 0x22
	return res
end

--SUBU
function fns.mips_subu(dest, src, subtract)
	local res = bit.lshift(src, 21)
	res = res + bit.lshift(subtract, 16)
	res = res + bit.lshift(dest, 11)
	res = res + 0x23
	return res
end

--SW
function fns.mips_sw(reg, base, offset)
	local res = bit.lshift(0x2B, 26)
	res = res + bit.lshift(base, 21)
	res = res + bit.lshift(reg, 16)
	res = res + bit.band(offset, 0xFFFF)
	return res
end

--SWCz
-- FIXME: implement me

--SWL
function fns.mips_swl(reg, base, offset)
	local res = bit.lshift(0x2A, 26)
	res = res + bit.lshift(base, 21)
	res = res + bit.lshift(reg, 16)
	res = res + bit.band(offset, 0xFFFF)
	return res
end

--SWR
function fns.mips_swr(reg, base, offset)
	local res = bit.lshift(0x2E, 26)
	res = res + bit.lshift(base, 21)
	res = res + bit.lshift(reg, 16)
	res = res + bit.band(offset, 0xFFFF)
	return res
end

--SYNC
function fns.mips_sync(stype)
	-- case SYNC
	if stype == nil then stype = 0 end
	
	local res = bit.lshift(bit.band(stype, 0x1F), 6)
	res = res + 0x0F
	return res
end

--SYSCALL
-- code option is omitted
function fns.mips_syscall()
	return 0x0000000C
end

--TEQ
-- code option is omitted
function fns.mips_teq(c0, c1)
	local res = bit.lshift(c0, 21)
	res = res + bit.lshift(c1, 16)
	res = res + 0x34
	return res
end

--TEQI
function fns.mips_teqi(c0, imm)
	local res = bit.lshift(0x01, 26)
	res = res + bit.lshift(c0, 21)
	res = res + bit.lshift(0x0C, 16)
	res = res + bit.band(imm, 0xFFFF)
	return res
end

--TGE
-- code option is omitted
function fns.mips_tge(c0, c1)
	local res = bit.lshift(c0, 21)
	res = res + bit.lshift(c1, 16)
	res = res + 0x30
	return res
end

--TGEI
function fns.mips_tgei(c0, imm)
	local res = bit.lshift(0x01, 26)
	res = res + bit.lshift(c0, 21)
	res = res + bit.lshift(0x08, 16)
	res = res + bit.band(imm, 0xFFFF)
	return res
end

--TGEIU
function fns.mips_tgeiu(c0, imm)
	local res = bit.lshift(0x01, 26)
	res = res + bit.lshift(c0, 21)
	res = res + bit.lshift(0x09, 16)
	res = res + bit.band(imm, 0xFFFF)
	return res
end

--TGEU
-- code option is omitted
function fns.mips_tgeu(c0, c1)
	local res = bit.lshift(c0, 21)
	res = res + bit.lshift(c1, 16)
	res = res + 0x31
	return res
end

--TLT
-- code option is omitted
function fns.mips_tlt(c0, c1)
	local res = bit.lshift(c0, 21)
	res = res + bit.lshift(c1, 16)
	res = res + 0x32
	return res
end

--TLTI
function fns.mips_tlti(c0, imm)
	local res = bit.lshift(0x01, 26)
	res = res + bit.lshift(c0, 21)
	res = res + bit.lshift(0x0A, 16)
	res = res + bit.band(imm, 0xFFFF)
	return res
end

--TLTIU
function fns.mips_tltiu(c0, imm)
	local res = bit.lshift(0x01, 26)
	res = res + bit.lshift(c0, 21)
	res = res + bit.lshift(0x0B, 16)
	res = res + bit.band(imm, 0xFFFF)
	return res
end

--TLTU
-- code option is omitted
function fns.mips_tltu(c0, c1)
	local res = bit.lshift(c0, 21)
	res = res + bit.lshift(c1, 16)
	res = res + 0x32
	return res
end

--TNE
-- code option is omitted
function fns.mips_tne(c0, c1)
	local res = bit.lshift(c0, 21)
	res = res + bit.lshift(c1, 16)
	res = res + 0x36
	return res
end

--TNEI
function fns.mips_tnei(c0, imm)
	local res = bit.lshift(0x01, 26)
	res = res + bit.lshift(c0, 21)
	res = res + bit.lshift(0x0E, 16)
	res = res + bit.band(imm, 0xFFFF)
	return res
end

--XOR
function fns.mips_xor(dest, src0, src1)
	local res = bit.lshift(src0, 21)
	res = res + bit.lshift(src1, 16)
	res = res + bit.lshift(dest, 11)
	res = res + 0x26
	return res
end

--XORI
function fns.mips_xori(dest, src, imm)
	local res = bit.lshift(0x0E, 26)
	res = res + bit.lshift(src, 21)
	res = res + bit.lshift(dest, 16)
	res = res + bit.band(imm, 0xFFFF)
	return res
end

--NOP
function fns.mips_nop()
	return 0x00000000;
end

local jumpLabels = {}

function printWarnings()
    for k,v in pairs(warnings) do
        print("Warning " .. v.id .. ": " .. v.msg .. " @ " .. v.caller)
    end
end

local function getHexString(value, digits)
    local hex = {"0","1","2","3","4","5","6","7","8","9","A","B","C","D","E","F"}
    local str = ""
    local slen = 0
    while (value ~= 0) do
        str = hex[(value % 16) + 1] .. str
        value = bit.rshift(value, 4)
        slen = slen + 1
    end
    while slen < digits do
        str = "0" .. str
        slen = slen + 1
    end
    return str
end

local function splitString(str, del)
    local list = {}
    for t in string.gmatch(str, "([^" .. del .. "]+)") do
        table.insert(list, t)
    end
    return list
end

local function getRegOrNil(token) -- expects "$" and then a number of reg
	local str 
    if string.byte(token) == 0x24 then -- 0x24 == $
        str = string.sub(token, 2) -- delete the $
    else
        str = token
    end
    
	local reg = registers[string.upper(str)]
	if reg then
		return reg
	elseif tonumber(str) and isreg(tonumber(str)) then
		return tonumber(str)
	else
		return nil
	end
end

local function getHiLoArgument(token)
    local label = string.match(token, "%w%(([%w$_]+)%)")
	return label
end

local function getBaseOffsetOrNil(token)
	local offset, base = string.match(token, "([%xx]+)%(([%w$]+)%)")
	return base, offset
end

local function getJumpLabelAddressOrNil(name)
	for k,v in pairs(jumpLabels) do
		if v.name == name then
			return v.address
		end
	end
	return nil
end

local function assembleLine(line, address)
	local tokens = {}
	local i = 1
	for tok in string.gmatch(line, "[%w$();._#%%]+") do
		tokens[i] = tok
		i = i + 1
	end
    
	-- check for function name
	if tokens[1] == nil then
		throw(errors.NO_COMMAND_FOUND, "No command found in \"" .. tokens[1] .. "\"", "ZASM")
		return -1
	end
    
    -- handle .word
    if string.lower(tokens[1]) == ".word" then
        if tokens[2] and tonumber(tokens[2]) then
            return tonumber(tokens[2])
        else
            warn(warnids.INVALID_FORMAT, "Invalid format for an assembler command! Command skipped!", tokens[1])
        end
    end
    
	local fn_name = "mips_" .. string.lower(tokens[1])
	-- check if the function is valid
	if (fns[fn_name] == nil) then
		throw(errors.INVALID_COMMAND, "Invalid command \"" .. tokens[1] .. "\"", "ZASM")
		return -1
	end
	
	-- prepare args
	local numargs = {}
	i = 2
	j = 1
	while(tokens[i] ~= nil) and (string.byte(tokens[i]) ~= commentChar) do
		local labaddr = getJumpLabelAddressOrNil(tokens[i])
		if labaddr then -- jump label
			numargs[j] = labaddr
        elseif string.sub(tokens[i], 1, 3) == "%hi" or string.sub(tokens[i], 1, 3) == "%lo" then -- load high/low of jump label
            local hiLabel = getHiLoArgument(tokens[i])
            if hiLabel then
                local addr = getJumpLabelAddressOrNil(hiLabel)
                if addr == nil then
                    if tonumber(hiLabel) then 
                        addr = tonumber(hiLabel)
                    else
                        throw(errors.INVALID_VALUE, "Invalid value \"" .. hiLabel .. "\"", tokens[1])
                        return -1
                    end
                end
                
                if string.sub(tokens[i], 1, 3) == "%hi" then
                    numargs[j] = bit.rshift(addr, 16)
                else
                    numargs[j] = bit.band(addr, 0xFFFF)
                end
			else
				throw(errors.INVALID_USE_OF_HI_LO, "Invalid use of %hi/%lo \"" .. tokens[i] .. "\"", tokens[1])
				return -1
			end
		elseif registers[string.upper(tokens[i])] ~= nil or registers[string.upper(string.sub(tokens[i], 2))] ~= nil then -- $ register
			local r = getRegOrNil(tokens[i])
			if r then
				numargs[j] = r
			else
				throw(errors.INVALID_REGISTER, "Invalid base offset pair \"" .. tokens[i] .. "\"", tokens[1])
				return -1
			end
		else -- number
			local b,o = getBaseOffsetOrNil(tokens[i])
			if b and o then
				local off = tonumber(o)
				local bas = getRegOrNil(b)
				if off and bas then
					numargs[j] = bas
					numargs[j+1] = off
					j = j + 1
				else
					throw(errors.INVALID_BASEOFFSET_PAIR, "Invalid base offset pair \"" .. tokens[i] .. "\"", tokens[1])
					return -1
				end
			else
				numargs[j] = tonumber(tokens[i])
				if numargs[j] == nil then
					throw(errors.INVALID_VALUE, "Invalid value \"" .. tokens[i] .. "\"", tokens[1])
					return -1
				end
			end
			
		end
		i = i + 1
		j = j + 1
	end
	
	return fns[fn_name](numargs[1], numargs[2], numargs[3], address)
end

-- note that there must not be code after a jump label "jumplabel: lui $t0, 0x8000" is not allowed
local function resolveJumpLabels(code)
	local addr = 0
	local rom = 0
    local romFile = ""
	local tokens = {}
	local codeLines = {}
	for k,v in ipairs(splitString(code, "\n")) do			
		for tok in string.gmatch(v, "[%w$():;.#_]+") do
			table.insert(tokens, tok)
		end
        if next(tokens) ~= nil then
            if string.lower(tokens[1]) == ".org" then
                if tokens[2] and tonumber("0x" .. tokens[2]) then
                    addr = tonumber("0x" .. tokens[2])
                else
                    warn(warnids.INVALID_FORMAT, "Invalid format for an assembler command! Command skipped!", tokens[1])
                end
            elseif string.lower(tokens[1]) == ".rom" then
                if tokens[2] and tonumber("0x" .. tokens[2]) then
                    rom = tonumber("0x" .. tokens[2])
                    useRom = true
                else
                    warn(warnids.INVALID_FORMAT, "Invalid format for an assembler command! Command skipped!", tokens[1])
                end
            elseif string.lower(tokens[1]) == ".file" then
                if tokens[2] then
                    romFile = tokens[2]
                    useRom = true
                else
                    warn(warnids.INVALID_FORMAT, "Invalid format for an assembler command! Command skipped!", tokens[1])
                end
            elseif tokens[1] and string.sub(tokens[1], -1) == ":" then -- found jump label
                local label = {}
                label.name = string.sub(tokens[1], 1, -2)
                label.address = addr
                print("Found label: " .. label.name .. " @ " .. getHexString(label.address, 8))
                if tokens[2] and string.byte(tokens[2]) ~= commentChar then -- if there is code we need to warn
                    warn(warnids.CODE_AFTER_LABEL, "Code after a label is not allowed! Code skipped!", "ZASM")
                    --addr = addr + 0x04
                end
                table.insert(jumpLabels, label)
            elseif tokens[1] and string.lower(tokens[1]) == ".word" then -- parse line words
                local t = 2
                while tokens[t] do
                    local codeLine = {}
                    codeLine.string = ".word " .. tokens[t]
                    codeLine.address = addr
                    codeLine.rom = rom
                    codeLine.romFile = romFile
                    table.insert(codeLines, codeLine)
                    addr = addr + 0x04
                    rom = rom + 0x04
                    t = t + 1
                end
            elseif tokens[1] and string.byte(tokens[1]) ~= commentChar then -- if not an empty or comment line (and also no jumpLabel line)
                local codeLine = {}
                codeLine.string = v
                codeLine.address = addr
                codeLine.rom = rom
                codeLine.romFile = romFile
                table.insert(codeLines, codeLine)
                addr = addr + 0x04
                rom = rom + 0x04
            end
            tokens = {}
        end
	end
	return codeLines
end

function assemble(code)
	local asm = {}
	local cl = resolveJumpLabels(code)
    print()
    if useRom then
        print("ROM      | RAM      | OPCODE")
        print("------------------------------")
    else
        print("RAM      | OPCODE")
        print("-------------------")
    end
	for k,v in ipairs(cl) do
		local opc = assembleLine(v.string, v.address)
		local asmEntry = {}
		asmEntry.opcode = opc
        asmEntry.ramAddress = v.address
		asmEntry.romAddress = v.rom
        asmEntry.romFile = v.romFile
		if opc >= 0 then
            if useRom then
                print(getHexString(v.rom, 8) .. " | " .. getHexString(v.address, 8) .. " | " .. getHexString(opc, 8))
            else
                print(getHexString(v.address, 8) .. " | " .. getHexString(opc, 8))
            end
		else
			opc = fns.mips_nop()
		end
		table.insert(asm, asmEntry)
	end
    print()
	return asm
end

function assembleFile(file)
	print()
	print("ZASM: assembling file:", file)
    local f = io.open(file, "r")
	if f then
		local content = f:read("*all")
		f:close()
		return assemble(content)
	else
		return nil
	end
end

function assembleString(str)
	print()
	print("ZASM: assembling string:", str)
    return assemble(str)
end

function splitDataWord(opc)
    return bit.rshift(opc, 24), bit.band(bit.rshift(opc, 16), 0xFF), bit.band(bit.rshift(opc, 8), 0xFF), bit.band(opc, 0xFF)
end

function generateHexoPatchFile(file, asm)
    local lastRomFile = ""
    local f = io.open(file, "w")
    if f then
        for k,v in ipairs(asm) do
            if lastRomFile ~= v.romFile then
                f:write(v.romFile .. "\n")
                lastRomFile = v.romFile
            end
            local b3, b2, b1, b0 = splitDataWord(v.opcode)
            f:write(getHexString(v.romAddress, 8) .. " " .. getHexString(b3, 8) .. "\n")
            f:write(getHexString(v.romAddress+1, 8) .. " " .. getHexString(b2, 8) .. "\n")
            f:write(getHexString(v.romAddress+2, 8) .. " " .. getHexString(b1, 8) .. "\n")
            f:write(getHexString(v.romAddress+3, 8) .. " " .. getHexString(b0, 8) .. "\n")
        end
        f:close()
        print("Written patch successfully to", file)
    end
end

function writeOutputFile(outname, outcode)
    local f = io.open(outname, "w")
    local ram = 0
    if f then
        for k,v in ipairs(outcode) do
            while ram ~= v.ramAddress do
                f:write(string.char(0))
                ram = ram + 1
            end
            f:write(string.char(splitDataWord(v.opcode)))
            ram = ram + 4
        end
        f:close()
        print("Written output file", outname, "successfully")
    end
end

function concatTables(t1, t2)
    for k,v in ipairs(t2) do
        table.insert(t1, v)
    end
    return t1
end
    
-- if not using bizhawk, set bit operations
if bit == nil then
    bit = {band = function(a,b) return a & b end, 
           bxor = function(a,b) return a ~ b end,
           bor  = function(a,b) return a ~ b end,
           bnot = function(a) return ~a end,
           rshift = function(a,b) return a >> b end,
           lshift = function(a,b) return a << b end}
end

-- parse arguments
local parsed = "f"
local patchname = ""
local outname = ""
local files = {}
local strings = {}
for a=1, #arg do
    if arg[a] == "-o" then
        parsed = "o"
    elseif arg[a] == "-l" then
        parsed = "l"
    elseif arg[a] == "-p" then
        parsed = "p"
    else
        if parsed == "f" then
            table.insert(files, arg[a])
        elseif parsed == "o" then
            outname = arg[a]
        elseif parsed == "l" then
            table.insert(strings, arg[a])
        elseif parsed == "p" then
            patchname = arg[a]
        end
        parsed = "f"
    end
end

-- assembling
local outcode = {}
for _,s in ipairs(strings) do
    outcode = concatTables(outcode, assembleString(s))
end
for _,f in ipairs(files) do
    local c = assembleFile(f)
    if c ~= nil then
        outcode = concatTables(outcode, c)
    else
        warn(warnids.UNABLE_TO_OPEN_FILE, "Unable to open file!", f)
    end
end
if patchname ~= "" then
    generateHexoPatchFile(patchname, outcode)
end
if outname ~= "" then
    writeOutputFile(outname, outcode)
end

printWarnings()