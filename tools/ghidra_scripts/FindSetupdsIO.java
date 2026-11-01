import ghidra.app.script.GhidraScript;
import ghidra.program.model.listing.*;
import ghidra.program.model.address.*;

public class FindSetupdsIO extends GhidraScript {
    @Override
    public void run() throws Exception {
        Listing l = currentProgram.getListing();
        InstructionIterator it = l.getInstructions(true);
        while (it.hasNext()) {
            Instruction i = it.next();
            String m = i.getMnemonicString();
            if (m.equals("INT") || m.equals("IN") || m.equals("OUT") || m.equals("INSB") || m.equals("OUTSB")) {
                Function f = getFunctionContaining(i.getAddress());
                println(i.getAddress() + " " + i + "  in " + (f == null ? "?" : f.getName()));
            }
        }
    }
}
