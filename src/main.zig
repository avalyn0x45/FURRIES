//! FURRIES: Frickin UnReadable Ridiculous language Including Erroneous Syntax
//! Copyright (C) 2025 Avalyn Baldyga
//!
//! This program is free software: you can redistribute it and/or modify
//! it under the terms of the GNU General Public License as published by
//! the Free Software Foundation, either version 3 of the License, or
//! (at your option) any later version.
//!
//! This program is distributed in the hope that it will be useful,
//! but WITHOUT ANY WARRANTY; without even the implied warranty of
//! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//! GNU General Public License for more details.
//!
//! You should have received a copy of the GNU General Public License
//! along with this program.  If not, see <https://www.gnu.org/licenses/>.

const std = @import("std");

pub const Statement = struct {
    var_name: []const u8,
    function: []const u8,
    inputs: [][]const u8,
    text: []const u8,
    allocator: std.mem.Allocator,
    pub fn parse(text: []const u8, allocator: std.mem.Allocator) !Statement {
        errdefer std.debug.print("Error parsing statement: {s}\n", .{text});
        var inputs = std.ArrayList([]const u8).init(allocator);
        var split_it = std.mem.splitAny(u8, text, &std.ascii.whitespace);
        const var_name = split_it.next() orelse return error.InvalidStatement;
        const function = split_it.next() orelse return error.InvalidStatement;
        while (split_it.next()) |input| {
            try inputs.append(input);
        }
        return .{
            .var_name = var_name,
            .function = function,
            .inputs = try inputs.toOwnedSlice(),
            .text = text,
            .allocator = allocator,
        };
    }
    pub fn free(self: Statement) void {
        self.allocator.free(self.inputs);
    }
    pub fn format(
        self: Statement,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.print("{s} {s}", .{ self.var_name, self.function });
        for (self.inputs) |input| {
            try writer.print(" {s}", .{input});
        }
        try writer.writeAll(";");
    }
};

pub const Builtin = enum {
    data,
    bytes,
    @"()",
    end,
    @"=",
    @"+=",
    @"-=",
    @"&=",
    @"|=",
    @"^=",
    external,
};

pub const Register = enum(u8) {
    eax,
    ebx,
    ecx,
    edx,
    esi,
    edi,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();
    var stdout_bw = std.io.bufferedWriter(stdout);
    defer stdout_bw.flush() catch @panic("Could not flush STDOUT.");
    const bw = stdout_bw.writer();

    var statements = std.ArrayList(Statement).init(allocator);
    var vars = std.StringHashMap(u32).init(allocator);
    var data = std.StringHashMap([]const u8).init(allocator);
    var globals = std.ArrayList([]const u8).init(allocator);
    var text = std.ArrayList(u8).init(allocator);
    const tw = text.writer();
    var regs: [6]?[]const u8 = undefined;
    @memset(&regs, null);

    try vars.put("_", 0xFFFFFFFF);

    while (true) {
        const statement_text = stdin.readUntilDelimiterAlloc(allocator, ';', 8192) catch break;
        const trimmed_statement = std.mem.trim(u8, statement_text, &std.ascii.whitespace);
        try statements.append(try Statement.parse(trimmed_statement, allocator));
    }

    for (statements.items, 1..) |statement, ln| (catchblock: {
        const opt_builtin = std.meta.stringToEnum(Builtin, statement.function);
        if (opt_builtin == .external) {
            try vars.put(statement.var_name, 0xFFFFFFFF);
            continue;
        }
        
        var existing = vars.get(statement.var_name) != null;
        if (statement.var_name[0] == '$') existing = true;

        if (!existing and opt_builtin != .@"()") {
            try vars.put(statement.var_name, vars.count());
        }

        defer {
            if (opt_builtin == null and statement.var_name[0] != '$')
                regs[0] = statement.var_name;
            if (std.mem.eql(u8, statement.var_name, "_")) regs[0] = null;
        }

        const builtin = opt_builtin orelse {
            if (!existing)
                try data.put(statement.var_name, "0");
            blk: {
                try tw.print("movl %eax, {s}\n", .{regs[0] orelse break :blk});
            }
            if (!std.mem.eql(u8, "_", statement.var_name))
                try tw.print("movl {s}, %eax\n", .{statement.var_name});
            for (statement.inputs, 1..) |input, reg| {
                try tw.print("movl {s}, %{s}\n", .{ input, @tagName(@as(Register, @enumFromInt(reg))) });
            }
            try tw.print("call {s}\n", .{statement.function});
            continue;
        };
        switch (builtin) {
            .data => {
                if (existing) break :catchblock error.DataNameTaken;
                //try directive.append('$');
                var string_al = std.ArrayList(u8).init(allocator);
                try string_al.appendSlice(".asciz \"");
                for (statement.inputs, 1..) |segment, i| {
                    try string_al.appendSlice(segment);
                    if (i < statement.inputs.len)
                        try string_al.append(' ');
                }
                try string_al.append('"');
                try data.put(statement.var_name, string_al.items);
            },
            .bytes => {
                if (existing) break :catchblock error.DataNameTaken;
                try data.put(
                    statement.var_name,
                    try std.fmt.allocPrint(
                        allocator,
                        ".fill {s}, 1, {s}",
                        .{ statement.inputs[0], statement.inputs[1] },
                    ),
                );
            },
            .@"()" => {
                try globals.append(statement.var_name);
                @memset(&regs, null);
                try tw.print("{s}:\nendbr32\n", .{statement.var_name});
                for (statement.inputs, 1..) |input, i| {
                    if (vars.get(input) == null) {
                        try data.put(input, "0");
                    }
                    try tw.print("movl %{s}, {s}\n", .{ @tagName(@as(Register, @enumFromInt(i))), input });
                }
                try vars.put(statement.var_name, 0xFFFFFFFF);
            },
            .end => {
                blk: {
                    try tw.print("movl %eax, {s}\n", .{regs[0] orelse break :blk});
                }
                if (!std.mem.eql(u8, "_", statement.var_name))
                    try tw.print("movl {s}, %eax\n", .{statement.var_name});
                try tw.print("ret\n", .{});
            },
            .@"=" => {
                if (!existing)
                    try data.put(statement.var_name, "0");
                try tw.print("movl %eax, {s}\nmovl {s}, %eax\nmovl %eax, {s}\n", .{
                    regs[0] orelse "%eax",
                    statement.inputs[0],
                    statement.var_name,
                });
                regs[0] = statement.var_name;
            },
            .@"+=" => {
                try tw.print("movl %eax, {s}\nmovl {s}, %eax\nmovl {s}, %ebx\naddl %ebx, %eax\n", .{ regs[0] orelse "%eax", statement.var_name, statement.inputs[0] });
                regs[1] = statement.inputs[0];
            },
            .@"-=" => {
                try tw.print("movl %eax, {s}\nmovl {s}, %eax\nmovl {s}, %ebx\nsubl %ebx, %eax\n", .{ regs[0] orelse "%eax", statement.var_name, statement.inputs[0] });
                regs[1] = statement.inputs[0];
            },
            .@"&=" => {
                try tw.print("movl %eax, {s}\nmovl {s}, %eax\nmovl {s}, %ebx\nandl %ebx, %eax\n", .{ regs[0] orelse "%eax", statement.var_name, statement.inputs[0] });
                regs[1] = statement.inputs[0];
            },
            .@"|=" => {
                try tw.print("movl %eax, {s}\nmovl {s}, %eax\nmovl {s}, %ebx\norl %ebx, %eax\n", .{ regs[0] orelse "%eax", statement.var_name, statement.inputs[0] });
                regs[1] = statement.inputs[0];
            },
            .@"^=" => {
                try tw.print("movl %eax, {s}\nmovl {s}, %eax\nmovl {s}, %ebx\nxorl %ebx, %eax\n", .{ regs[0] orelse "%eax", statement.var_name, statement.inputs[0] });
                regs[1] = statement.inputs[0];
            },
            .external => {},
        }
    } catch |e| {
        std.debug.print("Error while parsing line {d} |{s}|\n", .{ ln, statement.text });
        return e;
    });

    for (globals.items) |global| {
        try bw.print(".globl {s}\n", .{global});
    }
    try bw.print(".text\n{s}", .{text.items});
    try bw.writeAll(".data\n");
    var data_it = data.iterator();
    while (data_it.next()) |kv| {
        if (kv.value_ptr.*[0] == '.') {
            try bw.print("{s}: {s}\n", .{ kv.key_ptr.*, kv.value_ptr.* });
        } else {
            try bw.print("{s}: .long {s}\n", .{ kv.key_ptr.*, kv.value_ptr.* });
        }
    }
}
