(*
 *  This file is part of ilLib
 *  Copyright (c)2004-2013 Haxe Foundation
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 *)

open IData;;
open IO;;
open ExtString;;
open ExtList;;

exception Error_message of string

type reader_ctx = {
	fname : string;
	ch : Pervasives.in_channel;
	i : IO.input;
	verbose : bool;
}

let error msg = raise (Error_message msg)

let seek r pos =
	seek_in r.ch pos

let pos r =
	Pervasives.pos_in r.ch

let info r msg =
	if r.verbose then
		print_endline (msg())

let machine_type_of_int i = match i with
	| 0x0 -> TUnknown (* 0 - unmanaged PE files only *)
	| 0x014c -> Ti386 (* 0x014c - i386 *)
	| 0x0162 -> TR3000 (* 0x0162 - R3000 MIPS Little Endian *)
	| 0x0166 -> TR4000 (* 0x0166 - R4000 MIPS Little Endian *)
	| 0x0168 -> TR10000 (* 0x0168 - R10000 MIPS Little Endian *)
	| 0x0169 -> TWCeMipsV2 (* 0x0169 - MIPS Litlte Endian running MS Windows CE 2 *)
	| 0x0184 -> TAlpha (* 0x0184 - Alpha AXP *)
	| 0x01a2 -> TSh3 (* 0x01a2 - SH3 Little Endian *)
	| 0x01a3 -> TSh3Dsp (* 0x01a3 SH3DSP Little Endian *)
	| 0x01a4 -> TSh3e (* 0x01a4 SH3E Little Endian *)
	| 0x01a6 -> TSh4 (* 0x01a6 SH4 Little Endian *)
	| 0x01a8 -> TSh5
	| 0x01c0 -> TArm (* 0x1c0 ARM Little Endian *)
	| 0x01c2 -> TThumb (* 0x1c2 ARM processor with Thumb decompressor *)
	| 0x01c4 -> TArmN (* 0x1c0 ARM Little Endian *)
	| 0xaa64 -> TArm64
	| 0xebc -> TEbc
	| 0x01d3 -> TAm33 (* 0x1d3 AM33 processor *)
	| 0x01f0 -> TPowerPC (* 0x01f0 IBM PowerPC Little Endian *)
	| 0x01f1 -> TPowerPCFP (* 0x01f1 IBM PowerPC with FPU *)
	| 0x0200 -> TItanium64 (* 0x0200 Intel IA64 (Itanium( *)
	| 0x0266 -> TMips16 (* 0x0266 MIPS *)
	| 0x0284 -> TAlpha64 (* 0x0284 Alpha AXP64 *)
	| 0x0366 -> TMipsFpu (* 0x0366 MIPS with FPU *)
	| 0x0466 -> TMipsFpu16 (* 0x0466 MIPS16 with FPU *)
	| 0x0520 -> TTriCore (* 0x0520 Infineon *)
	| 0x8664 -> TAmd64 (* 0x8664 AMD x64 and Intel E64T *)
	| 0x9041 -> TM32R (* 0x9041 M32R *)
	| _ -> assert false

let coff_props_of_int iprops = List.fold_left (fun acc i ->
	if (iprops land i) = i then (match i with
		| 0x1 -> RelocsStripped (* 0x1 *)
		| 0x2 -> ExecutableImage (* 0x2 *)
		| 0x4 -> LineNumsStripped (* 0x4 *)
		| 0x8 -> LocalSymsStripped (* 0x8 *)
		| 0x10 -> AgressiveWsTrim (* 0x10 *)
		| 0x20 -> LargeAddressAware (* 0x20 *)
		| 0x80 -> BytesReversedLO (* 0x80 *)
		| 0x100 -> Machine32Bit (* 0x100 *)
		| 0x200 -> DebugStripped (* 0x200 *)
		| 0x400 -> RemovableRunFromSwap (* 0x400 *)
		| 0x800 -> NetRunFromSwap (* 0x800 *)
		| 0x1000 -> FileSystem (* 0x1000 *)
		| 0x2000 -> FileDll (* 0x2000 *)
		| 0x4000 -> UpSystemOnly (* 0x4000 *)
		| 0x8000 -> BytesReversedHI (* 0x8000 *)
		| _ -> assert false) :: acc
	else
		acc) [] [0x1;0x2;0x4;0x8;0x10;0x20;0x80;0x100;0x200;0x400;0x800;0x1000;0x2000;0x4000;0x8000]

let subsystem_of_int i = match i with
	|  0 -> SUnknown (* 0 *)
	|  1 -> SNative (* 1 *)
	|  2 -> SWGui (* 2 *)
	|  3 -> SWCui (* 3 *)
	|  7 -> SPCui (* 7 *)
	|  9 -> SWCeGui (* 9 *)
	|  10 -> SEfi (* 10 *)
	|  11 -> SEfiBoot (* 11 *)
	|  12 -> SEfiRuntime (* 12 *)
	|  13 -> SEfiRom (* 13 *)
	|  14 -> SXbox (* 14 *)
	| _ -> error ("Unknown subsystem " ^ string_of_int i)

let dll_props_of_int iprops = List.fold_left (fun acc i ->
	if (iprops land i) = i then (match i with
		| 0x0040  -> DDynamicBase (* 0x0040 *)
		| 0x0080  -> DForceIntegrity (* 0x0080 *)
		| 0x0100  -> DNxCompat (* 0x0100 *)
		| 0x0200  -> DNoIsolation (* 0x0200 *)
		| 0x0400  -> DNoSeh (* 0x0400 *)
		| 0x0800  -> DNoBind (* 0x0800 *)
		| 0x2000  -> DWdmDriver (* 0x2000 *)
		| 0x8000  -> DTerminalServer (* 0x8000 *)
		| _ -> assert false) :: acc
	else
		acc) [] [0x40;0x80;0x100;0x200;0x400;0x800;0x2000;0x8000]

let pe_magic_of_int i = match i with
	| 0x10b -> P32
	| 0x107 -> PROM
	| 0x20b -> P64
	| _ -> error ("Unknown PE magic number: " ^ string_of_int i)

let get_dir dir data =
	let idx,name,_ = directory_type_info dir in
	try
		data.(idx)
	with
		| Invalid_argument _ ->
			error (Printf.sprintf "The directory '%s' of index '%i' is required but is missing on this file" name idx)

let read_rva = read_real_i32

let read_pointer is64 i =
	if is64 then read_i64 i else Int64.of_int32 (read_real_i32 i)

let read_coff_header i =
	let machine = machine_type_of_int (read_ui16 i) in
	let nsections = read_ui16 i in
	let stamp = read_real_i32 i in
	let symbol_table_pointer = read_rva i in
	let nsymbols = read_i32 i in
	let optheader_size = read_ui16 i in
	let props = read_ui16 i in
	let props = coff_props_of_int (props) in
	{
		coff_machine = machine;
		coff_nsections = nsections;
		coff_timestamp = stamp;
		coff_symbol_table_pointer = symbol_table_pointer;
		coff_nsymbols = nsymbols;
		coff_optheader_size = optheader_size;
		coff_props = props;
	}

let read_pe_header i size =
	let magic = pe_magic_of_int (read_ui16 i) in
	let major = read_byte i in
	let minor = read_byte i in
	let codesize = read_i32 i in
	let initsize = read_i32 i in
	let uinitsize = read_i32 i in
	let entry_addr = read_rva i in
	let base_code = read_rva i in
	let base_data, read_pointer = match magic with
	| P32 | PROM ->
		read_rva i, read_pointer false
	| P64 ->
		Int32.zero, read_pointer true
	in

	(* COFF Windows extension *)
	let image_base = read_pointer i in
	let section_alignment = read_i32 i in
	let file_alignment = read_i32 i in
	let major_osver = read_ui16 i in
	let minor_osver = read_ui16 i in
	let major_imgver = read_ui16 i in
	let minor_imgver = read_ui16 i in
	let major_subsysver = read_ui16 i in
	let minor_subsysver = read_ui16 i in
	ignore (read_i32 i); (* reserved *)
	let image_size = read_i32 i in
	let headers_size = read_i32 i in
	let checksum = read_real_i32 i in
	let subsystem = subsystem_of_int (read_ui16 i) in
	let dll_props = dll_props_of_int (read_ui16 i) in
	let stack_reserve = read_pointer i in
	let stack_commit = read_pointer i in
	let heap_reserve = read_pointer i in
	let heap_commit = read_pointer i in
	ignore (read_i32 i); (* reserved *)
	let ndata_dir = read_i32 i in
	let data_dirs = Array.make ndata_dir (Int32.zero,Int32.zero) in
	let rec loop n =
		if n < ndata_dir then begin
			let addr = read_rva i in
			let size = read_rva i in
			Array.set data_dirs n (addr,size);
			loop (n+1)
		end
	in
	loop 0;
	{
		pe_magic = magic;
		pe_major = major;
		pe_minor = minor;
		pe_codesize = codesize;
		pe_initsize = initsize;
		pe_uinitsize = uinitsize;
		pe_entry_addr = entry_addr;
		pe_base_code = base_code;
		pe_base_data = base_data;
		pe_image_base = image_base;
		pe_section_alignment = section_alignment;
		pe_file_alignment = file_alignment;
		pe_major_osver = major_osver;
		pe_minor_osver = minor_osver;
		pe_major_imgver = major_imgver;
		pe_minor_imgver = minor_imgver;
		pe_major_subsysver = major_subsysver;
		pe_minor_subsysver = minor_subsysver;
		pe_image_size = image_size;
		pe_headers_size = headers_size;
		pe_checksum = checksum;
		pe_subsystem = subsystem;
		pe_dll_props = dll_props;
		pe_stack_reserve = stack_reserve;
		pe_stack_commit = stack_commit;
		pe_heap_reserve = heap_reserve;
		pe_heap_commit = heap_commit;
		pe_ndata_dir = ndata_dir;
		pe_data_dirs = data_dirs;
	}

let read name ch =
	let i = IO.input_channel ch in
	let r = {
		fname = name;
		ch = ch;
		i = i;
		verbose = true;
	} in
	if read i <> 'M' || read i <> 'Z' then
		error "MZ magic header not found: Is the target file really a PE?";
	seek r 0x3c;
	let pe_sig_offset = read_i32 i in
	seek r pe_sig_offset;
	if really_nread i 4 <> "PE\x00\x00" then
		error "Invalid PE header signature: PE expected";
	let header = read_coff_header i in
	info r (fun () -> coff_header_s header);
	let pe_header = read_pe_header i 0 in
	info r (fun () -> pe_header_s pe_header)



