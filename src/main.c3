module backuper;
import std::io;
import std::collections::list;
extern fn void exit(int) @extern("exit");

enum Flags : int (String flag, String description, String example) {
	CONFIG_FILES = { "-c", "File di configurazione in cui sono specificate le path.", "-c configPath.conf" },
	USER_FILES = { "-l", "Lista di file o directory.", "-l file1.txt dir1 file2.txt dir2" },
	VERBOSE = { "-v", "Verbose", "-v"},
}

struct State {
	String programName;
	List(<String>) flags;
	List(<String>) configFiles;
	List(<String>) userFiles;
}

fn void usage(State state) {
	io::printfn("USAGE: %s [OPTIONS]", state.programName);
	io::printn("OPTIONS:");
	io::printfn("\t%s\t%s\tEXAMPLE: %s", Flags.CONFIG_FILES.flag, Flags.CONFIG_FILES.description, Flags.CONFIG_FILES.example);
	io::printfn("\t%s\t%s\tEXAMPLE: %s", Flags.USER_FILES.flag, Flags.USER_FILES.description, Flags.USER_FILES.example);
	io::printfn("\t%s\t%s\tEXAMPLE: %s", Flags.VERBOSE.flag, Flags.VERBOSE.description, Flags.VERBOSE.example);
	exit(1);
}

fn State initState(String[] args) {
	State state = {};
	state.programName = args[0];
	
	if (args.len < 2) {
		usage(state);
	}

	foreach (String arg : args[1..]) {
		switch(arg) {
			case Flags.CONFIG_FILES.flag: {
				state.flags.push(arg);
			}
			case Flags.USER_FILES.flag: {
				state.flags.push(arg);
			}
			default: {
				if (arg.starts_with("-")) {
					io::eprintfn("ERROR: argument not valid: %s", arg);
					usage(state);
				}

				if (state.flags.contains(Flags.CONFIG_FILES.flag)) {
					state.configFiles.push(arg);
				} else if (state.flags.contains(Flags.USER_FILES.flag)) {
					state.userFiles.push(arg);
				} else {
					usage(state);
				}
			}
		}
	}

	return state;
}

fn int main(String[] args)
{
	State state = initState(args);
	
	io::printn(state.flags);
	io::printn(state.configFiles);
	io::printn(state.userFiles);

	return 0;
}
