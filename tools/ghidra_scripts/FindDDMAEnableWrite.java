// Dump the rest of FUN_1059_a64f (beyond the first 60 instructions already read) looking
// for a write to PCI config offset 0x4C (D-DMA Slave Configuration, CE bit) -- the real
// offset per the YMF724F datasheet, as opposed to 0x40 (Legacy Audio Control / SBEN) which
// turned out to be a different register entirely.
// @category dsdma

import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.FunctionManager;
import ghidra.program.model.listing.Instruction;
import ghidra.program.model.listing.InstructionIterator;
import ghidra.program.model.listing.Listing;

public class FindDDMAEnableWrite extends GhidraScript {

    @Override
    public void run() throws Exception {
        Listing listing = currentProgram.getListing();
        FunctionManager fm = currentProgram.getFunctionManager();
        Address a64f = currentProgram.getAddressFactory().getAddress("1059:a64f");
        Function f = fm.getFunctionContaining(a64f);

        println("Function: " + f.getName() + " size=" + f.getBody().getNumAddresses());
        println("");
        println("======================================================================");
        println("FULL LISTING of FUN_1059_a64f");
        println("======================================================================");
        InstructionIterator iit = listing.getInstructions(f.getBody(), true);
        while (iit.hasNext()) {
            Instruction ins = iit.next();
            println(ins.getAddress() + "  " + ins.toString());
        }

        println("");
        println("======================================================================");
        println("ANY 'MOV DI,0x4c' OR 'MOV DI,0x4C' (PCI BIOS DI=register-offset arg) ANYWHERE");
        println("======================================================================");
        InstructionIterator all = listing.getInstructions(true);
        while (all.hasNext()) {
            Instruction ins = all.next();
            if (!ins.getMnemonicString().equalsIgnoreCase("MOV")) continue;
            if (ins.getNumOperands() < 2) continue;
            ghidra.program.model.lang.Register r = ins.getRegister(0);
            if (r == null || !r.getName().equalsIgnoreCase("DI")) continue;
            ghidra.program.model.scalar.Scalar sc = ins.getScalar(1);
            if (sc == null) continue;
            if (sc.getUnsignedValue() == 0x4c || sc.getUnsignedValue() == 0x4d) {
                Function ff = fm.getFunctionContaining(ins.getAddress());
                println(ins.getAddress() + "  " + ins.toString() + "   [in "
                        + (ff != null ? ff.getName() : "<none>") + "]");
            }
        }
    }
}
