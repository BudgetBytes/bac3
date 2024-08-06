module backuper;
import std::io;
import std::io::file;
import std::io::os;
import std::io::path;
import std::collections::list;
import std::time;
import drcli;

const PATHS_FLAG = "-f";
const PATHS_DESC = "File/directory list.";
const EXCLUDE_FLAG = "-e";
const EXCLUDE_DESC = "Exclude list.";
const OUTPUT_FLAG = "-o";
const OUTPUT_DESC = "Output directory.";
const VERBOSE_FLAG = "-v";
const VERBOSE_DESC = "Verbose";

fn bool List(<String>).isExcluded(self, String s) {
    foreach (e : self) {
        if (s.contains(e)) return true;
    }
    return false;
}

fn void! copyFile(Path src, Path dst, Drcli cli) {
    if (cli.userFlags.contains(VERBOSE_FLAG)) {
        io::printfn("INFO: Copying file '%s' to '%s'", src, dst);
    }

    char[] buffer = file::load_temp(src.path_string)!;

    File out = file::open(dst.path_string, "wb")!;

    out.write(buffer)!;
}

fn void! pathWalker(Path src, Path dst, Drcli cli) {

    Path abs = src.absolute()!;

    PathList pathList = path::ls(abs)!;

    foreach (p : pathList) {
        Path! absolute = abs.append(p.path_string);
        if (catch err = absolute) {
            io::eprintfn("ERROR: Could not get absolute path '%s': %s", p.path_string, err);
            continue;
        }
        
        if (cli.userFlags.contains(EXCLUDE_FLAG)) {
            UserFlag excludes = cli.userFlags.getByFlag(EXCLUDE_FLAG)!;
            if (excludes.flagValues.isExcluded(absolute.path_string)) continue;
        }
        
        
        Path! dstBase = dst.append(absolute.basename());
        if (catch err = dstBase) {
            io::eprintfn("ERROR: Could not append '%s': %s", dst, err);
            continue;
        }

        if (path::is_dir(absolute)) {
            if (catch err = path::mkdir(dstBase)) {
                io::eprintfn("ERROR: Could not create directory '%s': %s", dstBase, err);
                continue;
            }
            
            pathWalker(absolute, dstBase, cli)!;
        } else {
            if (catch err = copyFile(absolute, dstBase, cli)) {
                io::eprintfn("ERROR: Could not copy file '%s' to '%s': %s", absolute, dstBase, err);
                continue;
            }
        }
    }
}

fn void! preprocess(String srcStr, String dstStr, Drcli cli) {
    if (!os::native_file_or_dir_exists(srcStr)) {
        io::eprintfn("ERROR: File or directory does not exists: '%s'", srcStr);
        return;
    }
    
    Path src = path::temp_new(srcStr)!;
    
    Path tmp = path::temp_new(dstStr)!;

    Path dst = tmp.append(src.basename())!;

    if (path::is_dir(src)) {
        path::mkdir(dst)!;
    }

    if (catch err = pathWalker(src, dst, cli)) {
        case IoError.FILE_NOT_DIR: {
            copyFile(src, dst, cli)!;
        }
        default: {
            io::eprintfn("ERROR: Failed to pathWalk: '%s'", err);
            return;
        }
    }
}

fn void! startBackup(Drcli cli) {
    

    UserFlag output = cli.userFlags.getByFlag(OUTPUT_FLAG)!;
    String outputDir = output.flagValues.get(0);

    if (cli.userFlags.contains(VERBOSE_FLAG)) {
        io::printfn("INFO: Creating directory %s", outputDir);
    }

    path::mkdir({
        outputDir,
        PathEnv.POSIX
    }, false, MkdirPermissions.NORMAL)!!;

    Time start = time::now();
    
    UserFlag paths = cli.userFlags.getByFlag(PATHS_FLAG)!;
    
    foreach(String pathName : paths.flagValues) {
        
        if (catch err = preprocess(pathName, outputDir, cli)) {
            io::eprintfn("ERROR: Could not preprocess '%s' to '%s': %s", pathName, outputDir, err);
            continue;
        }
    }

    Time end = time::now();
    
    io::printfn("INFO: Program executed in: %dμs", end.diff_us(start));
}

fn void! main(String[] args)
{
    List(<ProgramFlag>) flags;
    ProgramFlag paths = { PATHS_FLAG, PATHS_DESC, true, true };
    ProgramFlag excludes = { EXCLUDE_FLAG, EXCLUDE_DESC, false, true };
    ProgramFlag output = { OUTPUT_FLAG, OUTPUT_DESC, true, true };
    ProgramFlag verbose = { VERBOSE_FLAG, VERBOSE_DESC, false, false};
    flags.push(paths);
    flags.push(excludes);
    flags.push(output);
    flags.push(verbose);

    Drcli cli = drcli::new(flags, args)!;
    
    if (catch err = startBackup(cli)) {
        io::eprintfn("ERROR: Failed to %s", err);
    }
}