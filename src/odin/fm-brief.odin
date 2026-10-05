package main

import "core:fmt"
import "core:os"
import "core:strings"
import "core:sys/posix"

cstring_or_exit :: proc(value: string) -> cstring {
	result, err := strings.clone_to_cstring(value, context.allocator)
	if err != nil {
		fmt.eprintln("fm-brief: out of memory")
		os.exit(1)
	}
	return result
}

main :: proc() {
	source_path, err := os.get_absolute_path(#file, context.allocator)
	if err != nil {
		fmt.eprintfln("fm-brief: cannot resolve source path: %v", err)
		os.exit(1)
	}

	source_dir, _ := os.split_path(source_path)
	script_path: string
	script_path, err = os.join_path({source_dir, "..", "..", "bin", "fm-brief.sh"}, context.allocator)
	if err != nil {
		fmt.eprintfln("fm-brief: cannot resolve shell entry point: %v", err)
		os.exit(1)
	}
	script_path, err = os.get_absolute_path(script_path, context.allocator)
	if err != nil {
		fmt.eprintfln("fm-brief: cannot resolve shell entry point: %v", err)
		os.exit(1)
	}
	if !os.exists(script_path) {
		fmt.eprintfln("fm-brief: shell entry point not found: %s", script_path)
		os.exit(1)
	}

	argv := make([]cstring, len(os.args) + 2, context.allocator)
	argv[0] = cstring_or_exit("bash")
	argv[1] = cstring_or_exit(script_path)
	for arg, i in os.args[1:] {
		argv[i + 2] = cstring_or_exit(arg)
	}
	argv[len(argv) - 1] = nil

	if posix.execvp(argv[0], raw_data(argv)) == -1 {
		fmt.eprintfln("fm-brief: could not execute bash: %v", posix.strerror(posix.errno()))
		os.exit(127)
	}
}
