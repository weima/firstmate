package main

import "core:fmt"
import "core:os"

is_space :: proc(value: u8) -> bool {
	return value == ' ' || value == '\t' || value == '\n' || value == '\r' || value == '\v' || value == '\f'
}

heading_level :: proc(line: string, start: int) -> (int, bool) {
	level := 0
	for level < len(line) - start && line[start + level] == '#' {
		level += 1
	}
	if level == 0 || start + level < len(line) && !is_space(line[start + level]) {
		return 0, false
	}
	return level, true
}

append_line :: proc(output: ^[dynamic]u8, line: string) -> bool {
	if _, err := append_elems(output, ..transmute([]u8)line); err != nil {
		return false
	}
	if _, err := append(output, u8('\n')); err != nil {
		return false
	}
	return true
}

parse_heading :: proc(content, heading, mode: string) -> (output: [dynamic]u8, found: bool, ok: bool) {
	bytes := make([dynamic]u8, 0, context.allocator)
	output = nil
	found = false
	ok = true
	target_level := 0
	for target_level < len(heading) && heading[target_level] == '#' {
		target_level += 1
	}

	fenced := false
	fence_marker: u8
	fence_length := 0
	grab := false
	position := 0
	for position < len(content) {
		end := position
		for end < len(content) && content[end] != '\n' {
			end += 1
		}
		line := content[position:end]
		next_position := end + 1
		if end == len(content) {
			next_position = len(content)
		}

		scan_start := 0
		for scan_start < 3 && scan_start < len(line) && line[scan_start] == ' ' {
			scan_start += 1
		}
		marker: u8
		marker_length := 0
		if scan_start < len(line) && (line[scan_start] == '`' || line[scan_start] == '~') {
			marker = line[scan_start]
			for scan_start + marker_length < len(line) && line[scan_start + marker_length] == marker {
				marker_length += 1
			}
		}
		is_fence := marker_length >= 3
		was_fenced := fenced
		if is_fence {
			rest_start := scan_start + marker_length
			if !fenced {
				fenced = true
				fence_marker = marker
				fence_length = marker_length
			} else if marker == fence_marker && marker_length >= fence_length {
				whitespace := true
				for i := rest_start; i < len(line); i += 1 {
					if !is_space(line[i]) {
						whitespace = false
						break
					}
				}
				if whitespace {
					fenced = false
				}
			}
		}

		if !found && !was_fenced && line == heading {
			found = true
			if mode == "present" {
				return nil, true, true
			}
			grab = true
			position = next_position
			continue
		}
		if mode == "present" || !grab {
			position = next_position
			continue
		}
		if is_fence || was_fenced {
			if !append_line(&bytes, line) {
				return bytes, found, false
			}
			position = next_position
			continue
		}

		level, is_heading := heading_level(line, scan_start)
		if is_heading && level <= target_level {
			return bytes, found, true
		}
		if !append_line(&bytes, line) {
			return bytes, found, false
		}
		position = next_position
	}
	return bytes, found, ok
}

read_content :: proc(path: string) -> (content: string, exists: bool, ok: bool) {
	if path == "-" {
		data, err := os.read_entire_file(os.stdin, context.allocator)
		if err != nil {
			return "", true, false
		}
		return transmute(string)data, true, true
	}
	if !os.is_file(path) {
		return "", false, true
	}
	data, err := os.read_entire_file(path, context.allocator)
	if err != nil {
		return "", true, false
	}
	return transmute(string)data, true, true
}

write_output :: proc(output: []u8) {
	if len(output) > 0 {
		fmt.print(transmute(string)output)
	}
}

main :: proc() {
	args := os.args[1:]
	if len(args) != 3 {
		fmt.eprintln("Usage: fm-brief-heading <file|-> <heading> <body|present|task-body|task-present>")
		os.exit(2)
	}

	path, heading, mode := args[0], args[1], args[2]
	if mode != "body" && mode != "present" && mode != "task-body" && mode != "task-present" {
		fmt.eprintln("Usage: fm-brief-heading <file|-> <heading> <body|present|task-body|task-present>")
		os.exit(2)
	}

	content, exists, read_ok := read_content(path)
	if !read_ok {
		fmt.eprintfln("fm-brief-heading: could not read input: %s", path)
		os.exit(2)
	}
	if !exists {
		if mode == "body" || mode == "task-body" {
			os.exit(0)
		}
		os.exit(1)
	}

	if mode == "task-body" || mode == "task-present" {
		task_body, _, task_ok := parse_heading(content, "# Task", "body")
		if !task_ok {
			fmt.eprintln("fm-brief-heading: out of memory")
			os.exit(1)
		}
		task_body_length := len(task_body)
		for task_body_length > 0 && task_body[task_body_length-1] == '\n' {
			task_body_length -= 1
		}
		task_input := make([dynamic]u8, 0, context.allocator)
		if _, err := append_elems(&task_input, ..task_body[:task_body_length]); err != nil {
			fmt.eprintln("fm-brief-heading: out of memory")
			os.exit(1)
		}
		if _, err := append(&task_input, u8('\n')); err != nil {
			fmt.eprintln("fm-brief-heading: out of memory")
			os.exit(1)
		}
		body, found, parse_ok := parse_heading(transmute(string)task_input[:], heading, "body")
		if !parse_ok {
			fmt.eprintln("fm-brief-heading: out of memory")
			os.exit(1)
		}
		if mode == "task-present" {
			if !found {
				os.exit(1)
			}
			os.exit(0)
		}
		write_output(body[:])
		os.exit(0)
	}

	output, found, parse_ok := parse_heading(content, heading, mode)
	if !parse_ok {
		fmt.eprintln("fm-brief-heading: out of memory")
		os.exit(1)
	}
	if mode == "present" {
		if !found {
			os.exit(1)
		}
		os.exit(0)
	}
	write_output(output[:])
}
