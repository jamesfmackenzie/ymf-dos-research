import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.*;
import ghidra.program.model.listing.*;
import ghidra.program.model.address.*;
import ghidra.program.model.symbol.*;
import java.util.*;
import java.io.*;

public class DecompSetupds extends GhidraScript {
    @Override
    public void run() throws Exception {
        String[] args = getScriptArgs();
        DecompInterface di = new DecompInterface();
        di.openProgram(currentProgram);
        Set<Function> done = new LinkedHashSet<>();
        for (String s : args) {
            Address a = toAddr(Long.decode(s));
            Function f = getFunctionContaining(a);
            if (f == null) { disassemble(a); f = createFunction(a, null); }
            if (f == null) { println("NO FUNC at " + s); continue; }
            if (!done.add(f)) continue;
            println("==== " + f.getName() + " @ " + f.getEntryPoint() + " (via " + s + ")");
            if (s.startsWith("callers:")) continue;
            DecompileResults r = di.decompileFunction(f, 60, monitor);
            try (PrintWriter w = new PrintWriter(new FileWriter("capture/decomp/" + f.getName() + ".c"))) { w.println(r.decompileCompleted() ? r.getDecompiledFunction().getC() : "decompile failed"); }
            Set<String> callers = new TreeSet<>();
            for (Reference ref : getReferencesTo(f.getEntryPoint())) {
                Function c = getFunctionContaining(ref.getFromAddress());
                callers.add(ref.getFromAddress() + (c == null ? "" : "(" + c.getName() + ")"));
            }
            println("CALLERS: " + callers);
        }
    }
}
