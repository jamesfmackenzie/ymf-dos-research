// Trace callers of the hardcoded-defaults function (1059:014c) and of each D-DMA
// accessor function, then dump the real entry point's function in full.
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

public class TraceInit extends GhidraScript {

    private void printCallersOf(String label, String addrStr) throws Exception {
        Listing listing = currentProgram.getListing();
        FunctionManager fm = currentProgram.getFunctionManager();
        Address addr = currentProgram.getAddressFactory().getAddress(addrStr);
        println("Callers of " + label + " (" + addr + "):");
        ReferenceIterator refs = currentProgram.getReferenceManager().getReferencesTo(addr);
        boolean any = false;
        while (refs.hasNext()) {
            Reference r = refs.next();
            Address from = r.getFromAddress();
            Function f = fm.getFunctionContaining(from);
            String fname = (f != null) ? f.getName() : "<no function>";
            Instruction ins = listing.getInstructionAt(from);
            String insText = (ins != null) ? ins.toString() : "<no instruction>";
            println("  " + from + "  " + insText + "   [in " + fname + "]");
            any = true;
        }
        if (!any) {
            println("  (no references found)");
        }
        println("");
    }

    @Override
    public void run() throws Exception {
        println("======================================================================");
        println("CALLERS OF THE HARDCODED-DEFAULTS FUNCTION (1059:014c)");
        println("======================================================================");
        printCallersOf("hardcoded-defaults fn", "1059:014c");

        println("======================================================================");
        println("CALLERS OF EACH D-DMA ACCESSOR FUNCTION");
        println("======================================================================");
        printCallersOf("word-count-read",   "1059:0001");
        printCallersOf("address-read",      "1059:0026");
        printCallersOf("status-merge-read", "1059:0036");
        printCallersOf("page-read",         "1059:0056");
        printCallersOf("word-count-write",  "1059:0064");
        printCallersOf("address-write",     "1059:007a");
        printCallersOf("page-write",        "1059:008d");
        printCallersOf("mode-write",        "1059:009f");
        printCallersOf("write-all-masks",   "1059:00b1");
        printCallersOf("sb-status-read(0x7176+0xE)", "1059:00c8");
        printCallersOf("io-dispatcher",     "1059:00d5");

        println("======================================================================");
        println("REAL ENTRY POINT FUNCTION (1059:bcbd) -- creating/locating it");
        println("======================================================================");
        Address entry = currentProgram.getAddressFactory().getAddress("1059:bcbd");
        FunctionManager fm = currentProgram.getFunctionManager();
        Function entryFunc = fm.getFunctionContaining(entry);
        if (entryFunc == null) {
            println("No function at entry yet -- disassembling and creating one.");
            try {
                disassemble(entry);
            } catch (Exception e) {
                println("disassemble threw: " + e);
            }
            try {
                entryFunc = createFunction(entry, "EntryPoint");
            } catch (Exception e) {
                println("createFunction threw: " + e);
            }
        }
        if (entryFunc != null) {
            println("Entry function: " + entryFunc.getName() + " at " + entryFunc.getEntryPoint()
                    + " size=" + entryFunc.getBody().getNumAddresses());
            Listing listing = currentProgram.getListing();
            InstructionIterator iit = listing.getInstructions(entryFunc.getBody(), true);
            int n = 0;
            while (iit.hasNext() && n < 400) {
                Instruction ins = iit.next();
                println(ins.getAddress() + "  " + ins.toString());
                n++;
            }
        } else {
            println("Still no function found/created at entry point.");
            // just dump raw linear disassembly for a chunk regardless
            Listing listing = currentProgram.getListing();
            Address end = currentProgram.getAddressFactory().getAddress("1059:c000");
            InstructionIterator iit = listing.getInstructions(
                    currentProgram.getAddressFactory().getAddressSet(entry, end), true);
            int n = 0;
            while (iit.hasNext() && n < 400) {
                Instruction ins = iit.next();
                println(ins.getAddress() + "  " + ins.toString());
                n++;
            }
        }
    }
}
