import std.stdio;
import std.file;
import std.process;
import std.algorithm;
import std.regex;
import std.path;
import std.getopt;
import std.uni;
import std.array;

enum WorkDirectory = "lua";

auto exec(string program, string[] args)
{
    return ([program] ~ args).execute(null, Config.none, size_t.max, WorkDirectory);
}

void main(string[] args)
{
    bool verbose = false;
    bool exclude = false;
    auto helpInformation = args.getopt(
        "verbose|v", "Always print test stage output", &verbose,
        "exclude|e", "Exclude the given test", &exclude
    );

    string filter;
    if (args.length > 1)
        filter = args[$-1];

    struct Test
    {
        string name;
        string location;
        string runtime = "runtime.lua";
    }

    Test[] tests;
    foreach (location; WorkDirectory.dirEntries("test*.d", SpanMode.shallow))
    {
        Test test;
        test.name = location.baseName.stripExtension[4..$];
        test.location = location.baseName;

        auto captures = location.readText.matchFirst(`//!RUNTIME: (.*)`);
        if (captures)
            test.runtime = captures[1];

        tests ~= test;
    }

    bool runStep(string step, string filename, string[] args)
    {
        auto ret = filename.exec(args);
        write("\033[1m");
        write(step);
        write("\033[0m");
        write(": ");
        if (ret.status == 0)
        {
            write("\033[92m");
            writeln("OK");
            write("\033[0m");
            if (verbose)
                writeln(ret.output);
        }
        else
        {
            write("\033[91m");
            writeln("Failed");
            write("\033[0m");
            writeln(ret.output);
            return false;
        }
        return true;
    }

    auto selectedTests = tests;
    if (exclude)
        selectedTests = tests.filter!(a => !a.name.toLower.canFind(filter)).array();
    else
        selectedTests = tests.filter!(a => a.name.toLower.canFind(filter)).array();

    foreach (test; selectedTests)
    {
        writeln("===> ", "\033[4m", test.name, "\033[0m", " <===");
        if (!runStep("Compilation", "../src/dmd", ["-lua", test.location]))
            return;

        if (!runStep("Syntax Check", "luac", ["-p", test.location.setExtension("lua")]))
            return;

        if (!runStep("Run", "lua", [test.runtime, test.location.stripExtension]))
            return;

        writeln();
    }
}
