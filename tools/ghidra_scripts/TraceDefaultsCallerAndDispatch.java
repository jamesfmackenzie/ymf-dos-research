// Is FUN_1059_a64f (caller of the hardcoded-defaults function) itself reachable from the
// real init sequence? And how are the 9 accessor functions actually invoked, given no
// direct CALL references were found to any of them (likely an indirect/table dispatch)?
// @category dsdma

import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.FunctionManager;
import ghidra.program.model.listing.Instruction;
import ghidra.program.model.listing.InstructionIterator;
import ghidra.program.model.listing.Listing;
import ghidra.program.model.symbol.Reference;
import ghidra.program.model.symbol.ReferenceIterator;

public class TraceDefaultsCallerAndDispatch extends GhidraScript {

    @Override
    public void run() throws Exception {
        Listing listing = currentProgram.getListing();
        FunctionManager fm = currentProgram.getFunctionManager();

        println("======================================================================");
        println("WHO CALLS FUN_1059_a64f (the caller of the hardcoded-defaults fn)?");
        println("======================================================================");
        Address a64f = currentProgram.getAddressFactory().getAddress("1059:a64f");
        ReferenceIterator refs = currentProgram.getReferenceManager().getReferencesTo(a64f);
        boolean any = false;
        while (refs.hasNext()) {
            Reference r = refs.next();
            Address from = r.getFromAddress();
            Function f = fm.getFunctionContaining(from);
            String fname = (f != null) ? f.getName() : "<no function>";
            Instruction ins = listing.getInstructionAt(from);
            println("  " + from + "  " + (ins != null ? ins.toString() : "?") + "   [in " + fname + "]");
            any = true;
        }
        if (!any) println("  (no references found -- FUN_1059_a64f appears unreachable by direct call)");

        println("");
        println("======================================================================");
        println("FULL LISTING OF FUN_1059_a64f (first 60 instructions)");
        println("======================================================================");
        Function defaultsCaller = fm.getFunctionContaining(a64f);
        if (defaultsCaller != null) {
            InstructionIterator iit = listing.getInstructions(defaultsCaller.getBody(), true);
            int n = 0;
            while (iit.hasNext() && n < 60) {
                Instruction ins = iit.next();
                println(ins.getAddress() + "  " + ins.toString());
                n++;
            }
        }

        println("");
        println("======================================================================");
        println("SEARCH FOR INDIRECT (REGISTER/TABLE) CALL OR JMP INSTRUCTIONS");
        println("(how the 9 accessor functions might actually get dispatched)");
        println("======================================================================");
        InstructionIterator all = listing.getInstructions(true);
        int count = 0;
        while (all.hasNext()) {
            Instruction ins = all.next();
            String m = ins.getMnemonicString().toUpperCase();
            if (!m.equals("CALL") && !m.equals("JMP")) continue;
            if (ins.getNumOperands() < 1) continue;
            // Skip ones with a plain scalar/address operand (direct calls) -- we want
            // register-indirect or memory-indirect forms.
            if (ins.getRegister(0) != null || ins.getOpObjects(0).length > 1) {
                println(ins.getAddress() + "  " + ins.toString());
                count++;
            }
        }
        println("");
        println("Total indirect CALL/JMP instructions found: " + count);
    }
}
