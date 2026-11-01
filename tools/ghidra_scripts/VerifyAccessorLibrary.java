// Force-disassemble the region at segment 1000, offset 0x591+ (where the ndisasm flat
// pass found what looked like a D-DMA register accessor library) to check whether
// Ghidra's segment-aware disassembler agrees it's real code, or whether it's actually
// data that ndisasm's flat pass misread as plausible-looking instructions.
// @category dsdma

import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Instruction;
import ghidra.program.model.listing.InstructionIterator;
import ghidra.program.model.listing.Listing;

public class VerifyAccessorLibrary extends GhidraScript {

    @Override
    public void run() throws Exception {
        Listing listing = currentProgram.getListing();

        Address start = currentProgram.getAddressFactory().getAddress("1000:0591");
        Address end = currentProgram.getAddressFactory().getAddress("1000:0a00");

        println("======================================================================");
        println("Attempting disassembly at " + start + " (undefined region per auto-analysis)");
        println("======================================================================");

        try {
            disassemble(start);
        } catch (Exception e) {
            println("disassemble() threw: " + e);
        }

        InstructionIterator iit = listing.getInstructions(currentProgram.getAddressFactory()
                .getAddressSet(start, end), true);
        int count = 0;
        while (iit.hasNext()) {
            Instruction ins = iit.next();
            println(ins.getAddress() + "  " + ins.toString());
            count++;
        }
        println("");
        println("Total instructions Ghidra disassembled in " + start + ".." + end + ": " + count);

        if (count == 0) {
            println("");
            println("Nothing disassembled -- trying byte-by-byte probe to see what's there.");
            Address a = start;
            byte[] buf = new byte[32];
            currentProgram.getMemory().getBytes(a, buf);
            StringBuilder sb = new StringBuilder();
            for (byte b : buf) {
                sb.append(String.format("%02x ", b & 0xff));
            }
            println("Raw bytes at " + start + ": " + sb);
        }

        println("");
        println("======================================================================");
        println("RE-SCAN: ADD DX/EDX,<imm> across the WHOLE PROGRAM now that this region");
        println("is actually disassembled by Ghidra (not just ndisasm's flat guess)");
        println("======================================================================");
        java.util.TreeSet<Long> distinctOffsets = new java.util.TreeSet<>();
        int totalIn = 0, totalOut = 0;
        InstructionIterator all = listing.getInstructions(true);
        while (all.hasNext()) {
            Instruction ins = all.next();
            String m = ins.getMnemonicString().toUpperCase();
            if (m.equals("IN")) totalIn++;
            else if (m.equals("OUT")) totalOut++;
            if (!m.equals("ADD") || ins.getNumOperands() < 2) continue;
            ghidra.program.model.lang.Register reg0 = ins.getRegister(0);
            if (reg0 == null) continue;
            String regname = reg0.getName().toUpperCase();
            if (!regname.equals("DX") && !regname.equals("EDX")) continue;
            ghidra.program.model.scalar.Scalar sc = ins.getScalar(1);
            if (sc == null) continue;
            long val = sc.getUnsignedValue();
            println(ins.getAddress() + "  ADD " + regname + ", 0x" + Long.toHexString(val));
            distinctOffsets.add(val);
        }
        StringBuilder sb2 = new StringBuilder();
        for (Long v : distinctOffsets) {
            if (sb2.length() > 0) sb2.append(", ");
            sb2.append("0x").append(Long.toHexString(v));
        }
        println("");
        println("UPDATED distinct immediate offsets added to DX/EDX: [" + sb2 + "]");
        println("UPDATED total IN instructions: " + totalIn);
        println("UPDATED total OUT instructions: " + totalOut);
    }
}
