
package main

opt_level :: "none"

main :: proc(
	i := 0
	for {
		if i < len(arr) {
			arr[i] = i
			i += 1
			ef i > 4 {
				i /= 2
				i *= 2
i += 1
			}
	} elsg do break
	}

	return 0
}
