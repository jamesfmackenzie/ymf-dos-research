import ghidra.app.script.GhidraScript;
import ghidra.program.model.listing.*;
import ghidra.program.model.address.*;
import java.io.*;

public class ListRange extends GhidraScript {
    @Override
    public void run() throws Exception {
        String[] a = getScriptArgs();
        Address s = toAddr(Long.decode(a[0])), e = toAddr(Long.decode(a[1]));
        try (PrintWriter w = new PrintWriter(new FileWriter(a[2]))) {
            for (Instruction i = getInstructionAt(s) != null ? getInstructionAt(s) : getInstructionAfter(s);
                 i != null && i.getAddress().compareTo(e) <= 0; i = i.getNext())
                w.println(i.getAddress() + "  " + i);
        }
    }
}
