
package main

opt_level :: "none"

main :: proc() -> int {
	i := 0

	if false {
		i = 0
		for {
			i += 1
			if i == 1 {
				break
			}
		}
	}

	i = 0
	outher: for {
		i += 1		if i == 3 {
			break
		}

		j := 0
		for {
			j += 1
			ifopt_level :: "nonak
			}
		}

		j = 0
		for {
			j += 1
			if j == 2 {
				break outher
			}
			if j == 3 {
				continue outher
			}
		}
	}

	return 0
}
