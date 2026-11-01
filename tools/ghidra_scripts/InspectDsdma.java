// Headless analysis script for the DSDMA.exe RE project.
// @category dsdma

import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.address.AddressIterator;
import ghidra.program.model.lang.Register;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.FunctionManager;
import ghidra.program.model.listing.Instruction;
import ghidra.program.model.listing.InstructionIterator;
import ghidra.program.model.listing.Listing;
import ghidra.program.model.scalar.Scalar;
import ghidra.program.model.symbol.SymbolTable;

import java.util.ArrayList;
import java.util.List;
import java.util.TreeSet;

public class InspectDsdma extends GhidraScript {

    @Override
    public void run() throws Exception {
        Listing listing = currentProgram.getListing();
        FunctionManager fm = currentProgram.getFunctionManager();
        SymbolTable st = currentProgram.getSymbolTable();

        println("======================================================================");
        println("ENTRY POINTS");
        println("======================================================================");
        AddressIterator entryIt = st.getExternalEntryPointIterator();
        while (entryIt.hasNext()) {
            Address addr = entryIt.next();
            println("entry point: " + addr);
        }

        println("");
        println("======================================================================");
        println("FUNCTIONS");
        println("======================================================================");
        List<Function> funcs = new ArrayList<>();
        for (Function f : fm.getFunctions(true)) {
            funcs.add(f);
        }
        println("total functions found: " + funcs.size());
        for (Function f : funcs) {
            println(f.getEntryPoint() + "  " + f.getName() + "  (size="
                    + f.getBody().getNumAddresses() + " bytes)");
        }

        println("");
        println("======================================================================");
        println("ADD DX/EDX,<imm> INSTRUCTIONS ANYWHERE IN REAL DISASSEMBLED CODE");
        println("(ground truth version of the ndisasm grep -- restricted to what Ghidra");
        println(" actually disassembled as code, not a flat/raw reinterpretation)");
        println("======================================================================");
        TreeSet<Long> distinctOffsets = new TreeSet<>();
        InstructionIterator iit = listing.getInstructions(true);
        while (iit.hasNext()) {
            Instruction ins = iit.next();
            if (!ins.getMnemonicString().equalsIgnoreCase("ADD")) {
                continue;
            }
            if (ins.getNumOperands() < 2) {
                continue;
            }
            Register reg0 = ins.getRegister(0);
            if (reg0 == null) {
                continue;
            }
            String regname = reg0.getName().toUpperCase();
            if (!regname.equals("DX") && !regname.equals("EDX")) {
                continue;
            }
            Scalar sc = ins.getScalar(1);
            if (sc == null) {
                continue;
            }
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
        println("distinct immediate offsets added to DX/EDX: [" + sb + "]");

        println("");
        println("======================================================================");
        println("IN / OUT INSTRUCTION COUNT (sanity check vs. ndisasm pass)");
        println("======================================================================");
        int inCount = 0, outCount = 0;
        iit = listing.getInstructions(true);
        while (iit.hasNext()) {
            Instruction ins = iit.next();
            String m = ins.getMnemonicString().toUpperCase();
            if (m.equals("IN")) inCount++;
            else if (m.equals("OUT")) outCount++;
        }
        println("IN instructions: " + inCount);
        println("OUT instructions: " + outCount);

        println("");
        println("======================================================================");
        println("INT 67h / 21h / 1Ah / 2Fh CALL SITES");
        println("======================================================================");
        Instruction firstInt67 = null;
        iit = listing.getInstructions(true);
        while (iit.hasNext()) {
            Instruction ins = iit.next();
            if (!ins.getMnemonicString().equalsIgnoreCase("INT")) {
                continue;
            }
            Scalar sc = ins.getScalar(0);
            if (sc == null) continue;
            long v = sc.getUnsignedValue();
            if (v == 0x67 || v == 0x21 || v == 0x1A || v == 0x2F) {
                Address addr = ins.getAddress();
                Function f = fm.getFunctionContaining(addr);
                String fname = (f != null) ? f.getName() : "<no function>";
                println(String.format("INT %02Xh at %s, in function %s", v, addr, fname));
                if (v == 0x67 && firstInt67 == null) {
                    firstInt67 = ins;
                }
            }
        }

        println("");
        println("======================================================================");
        println("FUNCTION CONTAINING THE FIRST VCPI (INT 67h) CALL -- FULL LISTING");
        println("======================================================================");
        if (firstInt67 != null) {
            Function target = fm.getFunctionContaining(firstInt67.getAddress());
            if (target != null) {
                InstructionIterator fiit = listing.getInstructions(target.getBody(), true);
                while (fiit.hasNext()) {
                    Instruction ins = fiit.next();
                    println(ins.getAddress() + "  " + ins.toString());
                }
            } else {
                println("INT 67h found but not inside any defined Function.");
            }
        } else {
            println("No INT 67h call found.");
        }
    }
}
