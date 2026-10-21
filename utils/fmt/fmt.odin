package local_fmt

import "base:intrinsics"
import core_fmt "core:fmt"

NO_FMT :: #config(NO_FMT, false)

when !NO_FMT {
	assertf :: core_fmt.assertf
	panicf :: core_fmt.panicf
	when ODIN_OS != .Freestanding {
		println :: core_fmt.println
		printfln :: core_fmt.printfln
		eprintln :: core_fmt.eprintln
	}
	wprint :: core_fmt.wprint
	wprintln :: core_fmt.wprintln
	wprintf :: core_fmt.wprintf
	Info :: core_fmt.Info
	User_Formatter :: core_fmt.User_Formatter
	set_user_formatters :: core_fmt.set_user_formatters
	register_user_formatter :: core_fmt.register_user_formatter
} else {
	println :: discard_6
	eprintln :: discard_6
	printfln :: discard_6
	panicf :: trap_discard_6

	when ODIN_DISABLE_ASSERT {
		// COMPILER BUG: disabled generic overloads fail resolution, unlike a single generic procedure.
		@(disabled = true)
		assertf :: #force_inline proc(
			condition: bool,
			format: string,
			a: $A = 0,
			b: $B = 0,
			c: $C = 0,
			d: $D = 0,
			e: $E = 0,
		) {}
	} else {
		assertf :: proc {
			assertf_0,
			assertf_1,
			assertf_2,
			assertf_3,
			assertf_4,
			assertf_5,
		}

		assertf_0 :: #force_inline proc(condition: bool, _: string) {
			if !condition do intrinsics.trap()
		}
		assertf_1 :: #force_inline proc(condition: bool, _: string, _: $A) {
			assertf_0(condition, "")
		}
		assertf_2 :: #force_inline proc(condition: bool, _: string, _: $A, _: $B) {
			assertf_0(condition, "")
		}
		assertf_3 :: #force_inline proc(
			condition: bool,
			_: string,
			_: $A,
			_: $B,
			_: $C,
		) {
			assertf_0(condition, "")
		}
		assertf_4 :: #force_inline proc(
			condition: bool,
			_: string,
			_: $A,
			_: $B,
			_: $C,
			_: $D,
		) {
			assertf_0(condition, "")
		}
		assertf_5 :: #force_inline proc(
			condition: bool,
			_: string,
			_: $A,
			_: $B,
			_: $C,
			_: $D,
			_: $E,
		) {
			assertf_0(condition, "")
		}
	}

	@(disabled = true)
	discard_6 :: #force_inline proc(
		_: $F = 0,
		_: $A = 0,
		_: $B = 0,
		_: $C = 0,
		_: $D = 0,
		_: $E = 0,
	) {}

	@(disabled = true)
	trap_discard_6 :: #force_inline proc(
		_: $F = 0,
		_: $A = 0,
		_: $B = 0,
		_: $C = 0,
		_: $D = 0,
		_: $E = 0,
	) -> ! {intrinsics.trap()}
}
