// Explicitly disassemble each remaining undefined accessor-function start address
// (Ghidra's auto-analysis missed these because they don't use a PUSH BP/MOV BP,SP
// prologue, unlike the write-accessors it did find), then do a final, complete
// whole-program rescan for ADD DX/EDX,<imm> and IN/OUT counts.
// @category dsdma

import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.lang.Register;
import ghidra.program.model.listing.Instruction;
import ghidra.program.model.listing.InstructionIterator;
import ghidra.program.model.listing.Listing;
import ghidra.program.model.scalar.Scalar;

import java.util.TreeSet;

public class FillGapsAndRescan extends GhidraScript {

    @Override
    public void run() throws Exception {
        Listing listing = currentProgram.getListing();
        String[] seeds = {
            "1059:0026", // address-read accessor (ndisasm blob offset 0x5B6)
            "1059:0036", // status-merge-read accessor (ndisasm blob offset 0x5C6)
            "1059:0056", // page-read accessor (ndisasm blob offset 0x5E6)
            "1059:00c8", // "+0xE" SB-status-port read (ndisasm blob offset 0x658)
            "1059:00d5", // dispatcher-looking code right after it (ndisasm blob offset 0x665)
        };

        for (String s : seeds) {
            Address a = currentProgram.getAddressFactory().getAddress(s);
            println("Disassembling at " + a + " ...");
            try {
                disassemble(a);
            } catch (Exception e) {
                println("  threw: " + e);
            }
        }

        println("");
        println("======================================================================");
        println("Listing 1059:0000 .. 1059:0110 after filling gaps");
        println("======================================================================");
        Address start = currentProgram.getAddressFactory().getAddress("1059:0000");
        Address end = currentProgram.getAddressFactory().getAddress("1059:0110");
        InstructionIterator iit = listing.getInstructions(
                currentProgram.getAddressFactory().getAddressSet(start, end), true);
        while (iit.hasNext()) {
            Instruction ins = iit.next();
            println(ins.getAddress() + "  " + ins.toString());
        }

        println("");
        println("======================================================================");
        println("FINAL WHOLE-PROGRAM RESCAN");
        println("======================================================================");
        TreeSet<Long> distinctOffsets = new TreeSet<>();
        int totalIn = 0, totalOut = 0;
        InstructionIterator all = listing.getInstructions(true);
        while (all.hasNext()) {
            Instruction ins = all.next();
            String m = ins.getMnemonicString().toUpperCase();
            if (m.equals("IN")) totalIn++;
            else if (m.equals("OUT")) totalOut++;
            if (!m.equals("ADD") || ins.getNumOperands() < 2) continue;
            Register reg0 = ins.getRegister(0);
            if (reg0 == null) continue;
            String regname = reg0.getName().toUpperCase();
            if (!regname.equals("DX") && !regname.equals("EDX")) continue;
            Scalar sc = ins.getScalar(1);
            if (sc == null) continue;
            long val = sc.getUnsignedValue();
            println(ins.getAddress() + "  ADD " + regname + ", 0x" + Long.toHexString(val));
            distinctOffsets.add(val);
        }
        StringBuilder sb = new StringBuilder();
        for (Long v : distinctOffsets) {
            if (sb.length() > 0) sb.append(", ");
            sb.append("0x").append(Long.toHexString(v));
        }
        println("");
        println("FINAL distinct immediate offsets added to DX/EDX: [" + sb + "]");
        println("FINAL total IN instructions: " + totalIn);
        println("FINAL total OUT instructions: " + totalOut);
    }
}
