#+build !freestanding
package arna

import "core:mem/virtual"

virtual_reserve :: virtual.reserve
virtual_commit :: virtual.commit
virtual_decommit :: virtual.decommit
virtual_release :: virtual.release
