import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.mem.*;
import java.io.*;
import java.nio.file.*;

// Maps obj2/obj3 (obj1 is the imported raw binary at 0x10000) from capture/setupds_le.
public class AddLeObjects extends GhidraScript {
    @Override
    public void run() throws Exception {
        String dir = "capture/setupds_le/";
        long[] bases = {0x30000, 0x40000};
        String[] names = {"obj2", "obj3"};
        Memory mem = currentProgram.getMemory();
        for (int i = 0; i < 2; i++) {
            if (mem.getBlock(names[i]) != null) continue;
            byte[] b = Files.readAllBytes(Paths.get(dir + names[i] + ".bin"));
            Address a = toAddr(bases[i]);
            MemoryBlock blk = mem.createInitializedBlock(names[i], a, new ByteArrayInputStream(b), b.length, monitor, false);
            blk.setRead(true); blk.setWrite(true); blk.setExecute(false);
        }
        MemoryBlock o1 = mem.getBlocks()[0];
        o1.setExecute(true);
        println("blocks: " + mem.getBlocks().length);
        Address ep = toAddr(0x10000 + 0xF8B0);
        createFunction(ep, "entry");
        disassemble(ep);
    }
}
