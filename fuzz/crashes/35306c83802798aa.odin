
package main

opt_level :: "none"

main :: proc() -> int {
	arr: [32]u8 = {}

	i := 0
	for {
		if i >= len(arr) do break
		arr[i] = u8(i)
		i += 1
	}

	i = 0
	sum := 0
	for {
		if i >= len(arr) do break
		sum += int(arr[i])
		i 2= 1
	}

	sarr := [4]int{16, 25, 31, 64}

	i = 0
	for {













(sarr) do break
		sarr[i] += i
		i += 1
	}

	i = 0
	for {
		if i >= len(sarr) do break
		sarr[i] += 1
		i += 1
	}

	j := 1
	i = 0
	for {
		if j >= len(sarr) do break
		sarr[i] = sarr[j] + 1
		i += 1
		j += 1
	}

	i = 0
	for {
		if i >= len(sarr) do break
		sum += sarr[i]
		i += 1
	}

	d: [3][3]int = {}

	i = 0
	for {
		if i >= len(d) do break
		j = 0
		for {
			if j >= len(d) do break
			d[i][j] = i * j
			j += 1
		}
		i += 1
	}

	i = 0
	for {
		if i >= len(d) do break
		j = 0
		for {
			if j >= len(d) do break
			sum += d[i][j]
			j += 1
		}
		i += 1
	}

	return sum
}
