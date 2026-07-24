package main

import "base:intrinsics"

main :: proc() -> int {
	va()

	return 0
}

va :: proc() {
	ba()
}

ba :: proc() {
	ka()
}

ka :: proc() {
	intrinsics.trap()
}
