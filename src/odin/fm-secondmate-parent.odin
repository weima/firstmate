package main

import "core:fmt"
import "core:os"

Parsed_Parent :: struct {
	route:       string,
	parent_home: string,
	parent_host: string,
}

parse_parent_record :: proc(path: string) -> (Parsed_Parent, bool) {
	info, stat_err := os.lstat(path, context.allocator)
	if stat_err != nil {
		return Parsed_Parent{}, false
	}
	defer os.file_info_delete(info, context.allocator)
	if info.type != .Regular {
		return Parsed_Parent{}, false
	}

	bytes, read_err := os.read_entire_file(path, context.allocator)
	if read_err != nil {
		return Parsed_Parent{}, false
	}
	for b in bytes {
		if b == 0 {
			return Parsed_Parent{}, false
		}
	}

	content := transmute(string)bytes
	schema: string
	route: string
	parent_home: string
	parent_host: string
	schema_count := 0
	route_count := 0
	parent_home_count := 0
	parent_host_count := 0
	start := 0
	for i := 0; i <= len(content); i += 1 {
		if i < len(content) && content[i] != '\n' {
			continue
		}
		line := content[start:i]
		if len(line) >= 7 && line[:7] == "schema=" {
			schema_count += 1
			schema = line[7:]
		} else if len(line) >= 6 && line[:6] == "route=" {
			route_count += 1
			route = line[6:]
		} else if len(line) >= 12 && line[:12] == "parent_home=" {
			parent_home_count += 1
			parent_home = line[12:]
		} else if len(line) >= 12 && line[:12] == "parent_host=" {
			parent_host_count += 1
			parent_host = line[12:]
		}
		start = i + 1
	}

	if schema_count != 1 || route_count != 1 || schema != "fm-secondmate-parent.v1" {
		return Parsed_Parent{}, false
	}
	switch route {
	case "local":
		if parent_home_count != 1 || parent_host_count != 0 || len(parent_home) == 0 || parent_home[0] != '/' {
			return Parsed_Parent{}, false
		}
	case "remote":
		if parent_home_count != 0 {
			return Parsed_Parent{}, false
		}
	case:
		return Parsed_Parent{}, false
	}

	parsed := Parsed_Parent{route = route, parent_home = parent_home, parent_host = parent_host}
	return parsed, true
}

main :: proc() {
	args := os.args[1:]
	if len(args) != 1 {
		fmt.eprintln("Usage: fm-secondmate-parent <record-file>")
		os.exit(2)
	}
	parsed, valid := parse_parent_record(args[0])
	if !valid {
		os.exit(1)
	}
	fmt.printf("route=%s\nparent_home=%s\nparent_host=%s\n", parsed.route, parsed.parent_home, parsed.parent_host)
}
