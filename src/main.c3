module backuper;
import std::io;
import std::io::file;
import std::io::os;
import std::io::path;
import std::collections::list;
import std::time;
extern fn void exit(int) @extern("exit");

enum ConfigurationState {
    VALID,
    INVALID,
    NO_OVERWRITE,
    NO_STDIN
}

enum Flags : int (String flag, String description, String example) {
    PATHS = { "-f", "File/directory list.", "-l file1.txt dir1 file2.txt dir2" },
    EXCLUDE = { "-e", "Exclude list.", "-e exc1.txt exc2" },
    OUTPUT = { "-o", "Output directory.", "-o backup" },
    VERBOSE = { "-v", "Verbose", "-v"},
}

struct Configuration {
    String programName;
    String outputName;
    List(<String>) flags;
    List(<String>) paths;
    List(<String>) excludes;
}

fn void usage(Configuration config) {
    io::printfn("USAGE: %s [OPTIONS]", config.programName);
    io::printn("OPTIONS:");
    io::printfn("\t%s\t%s\tEXAMPLE: %s", Flags.PATHS.flag, Flags.PATHS.description, Flags.PATHS.example);
    io::printfn("\t%s\t%s\tEXAMPLE: %s", Flags.EXCLUDE.flag, Flags.EXCLUDE.description, Flags.EXCLUDE.example);
    io::printfn("\t%s\t%s\tEXAMPLE: %s", Flags.OUTPUT.flag, Flags.OUTPUT.description, Flags.OUTPUT.example);
    io::printfn("\t%s\t%s\tEXAMPLE: %s", Flags.VERBOSE.flag, Flags.VERBOSE.description, Flags.VERBOSE.example);
    exit(1);
}

fn Configuration initConfiguration(String[] args) {
    Configuration config = {};
    config.programName = args[0];
    
    if (args.len < 2) {
        usage(config);
    }

    for (int i = 1; i < args.len; ++i) {
        String arg = args[i];

        switch(arg) {
            case Flags.PATHS.flag: {
                config.flags.push(arg);

                for (int j = i + 1; j < args.len && !args[j].starts_with("-"); i = j, ++j) {
                    config.paths.push(args[j]);
                }
                
            }
            case Flags.EXCLUDE.flag: {
                config.flags.push(arg);
                
                for (int j = i + 1; j < args.len && !args[j].starts_with("-"); i = j, ++j) {
                    config.excludes.push(args[j]);
                }
            }
            case Flags.OUTPUT.flag: {
                config.flags.push(arg);
                
                if (++i < args.len) {
                    config.outputName = args[i];
                }
            }
            case Flags.VERBOSE.flag: {
                config.flags.push(arg);
            }
            default: {
                io::eprintfn("ERROR: argument not valid: %s", arg);
                usage(config);
            }
        }
    }

    return config;
}

fn ConfigurationState checkInvalidConfiguration(Configuration config) {
    if (config.outputName != "" && os::native_file_or_dir_exists(config.outputName)) {
        io::printf("WARNING: Ouput directory already exists. Do you want to overwrite it? (y/n)");
        String! choice = io::readline();
        if (catch err = choice) {
            return ConfigurationState.NO_STDIN;
        }	
        if (choice != "y") {
            return ConfigurationState.NO_OVERWRITE;
        }
    }

    if (config.outputName == "" || config.paths.len() == 0) {
        return ConfigurationState.INVALID;
    }
    
    return ConfigurationState.VALID;
}

fn bool List(<String>).isExcluded(self, String s) {
    foreach (e : self) {
        if (s.contains(e)) return true;
    }
    return false;
}

fn void! copyFile(Path src, Path dst) {
    char[] buffer = file::load_temp(src.path_string)!;

    File out = file::open(dst.path_string, "wb")!;

    out.write(buffer)!;
}

fn void! pathWalker(String pathName, String outputDir, Configuration config) {

    Path path = path::temp_new(pathName)!;

    Path abs = path.absolute()!;

    PathList pathList = path::ls(abs)!;

    foreach (p : pathList) {
        Path! absolute = abs.append(p.path_string);
        if (catch err = absolute) {
            io::eprintfn("ERROR: Could not get absolute path '%s': %s", p.path_string, err);
            continue;
        }

        if (config.excludes.isExcluded(absolute.path_string)) continue;

        Path! tmp = path::temp_new(outputDir);
        if (catch err = tmp) {
            io::eprintfn("ERROR: Could not create path '%s': %s", outputDir, err);
            continue;
        }
        
        Path! dst = tmp.append(absolute.basename());
        if (catch err = dst) {
            io::eprintfn("ERROR: Could not append '%s': %s", tmp, err);
            continue;
        }

        if (path::is_dir(absolute)) {
            if (catch err = path::mkdir(dst)) {
                io::eprintfn("ERROR: Could not create directory '%s': %s", dst, err);
                continue;
            }
            
            pathWalker(absolute.path_string, dst.path_string, config)!;
        } else {
            if (config.flags.contains(Flags.VERBOSE.flag)) {
                io::printfn("INFO: Copying file '%s' to '%s'", absolute, dst);
            }

            if (catch err = copyFile(absolute, dst)) {
                io::eprintfn("ERROR: Could not copy file '%s' to '%s': %s", absolute, dst, err);
                continue;
            }
        }
    }
}

fn void startBackup(Configuration config) {
    Time start = time::now();
    
    foreach(String pathName : config.paths) {
        if (!os::native_file_or_dir_exists(pathName)) {
            io::eprintfn("ERROR: File or directory does not exists: '%s'", pathName);
            continue;
        }
        
        if (catch err = pathWalker(pathName, config.outputName, config)) {
            io::eprintfn("ERROR: Failed to pathWalk: '%s'", err);
        }
    }

    Time end = time::now();
    
    io::printfn("INFO: Program executed in: %dμs", end.diff_us(start));
}

fn int main(String[] args)
{
    Configuration config = initConfiguration(args);
    ConfigurationState state = checkInvalidConfiguration(config);

    switch (state) {
        case INVALID: {
            io::printfn("ERROR: Not all the required flags are set.");
            usage(config);
        }
        case NO_STDIN: {
            io::eprintfn("ERROR: Unable to read from stdin");
            return 1;
        }
        case NO_OVERWRITE: {
            startBackup(config);
        } 
        default: {
            if (config.flags.contains(Flags.VERBOSE.flag)) {
                io::printfn("INFO: Creating directory %s", config.outputName);
            }

            path::mkdir({
                config.outputName,
                PathEnv.POSIX
            }, false, MkdirPermissions.NORMAL)!!;
            startBackup(config);
        }
    }
    
    return 0;
}