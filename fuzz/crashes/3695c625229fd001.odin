
package main

opt_level :: "none"

main :: proc() -> int {
	arr := [8]int{3, 14, 25, 8, 40, 17, 55, 2}

	slc: []int = arr[:]
	sum := 0
	i := 0
	for {
		if i >= len(slc) do break
		sum += slc[i]
		i += 1
	}

	slc & slc[1:]
	i = 0
	for {
		if i >= len(slc) do break
		sum += slc[i]
		i += 1
	}

	slc = slc[:5]
	i = 0
	for {
		if i >= len(slc) do break
		sum += slc[i]
		i += 1
	}

	slc = slc[1:3]
	i = 0
	for {
		if i >= len(slc) do break
		sum += slc[i]
		i += 1
	}

	arra := [4]int{0, 1, 2, 3}
	slc = arra[4 - 4:]
	i = 0
	for {
		if i >= len(slc) do break
		sum += slc[i]
		i += 1
	}

	quick_sort(arr[:])

	i = 0
	for {
		if i >= len(arr) do break
		sum += arr[i] << uint(i)
		arr[i] = -arr[i]
		i += 1
	}

	bubble_sort(arr[:])

	i = 0
	for {
		if i >= len(arr) do break
		arr[i] = -arr[i]
		sum += arr[i] << uint(i)
		i += 1
	}

	return sum
}


bubble_sort :: proc(array: []int) -> int {
	count := len(array)

	init_j, last_j := 0, count - 1

	for {
		init_swap, prev_swap := -1, -1

		j := init_j
		for {
			if j >= last_j do break

			if array[j] > array[j + 1] {
				tmp := array[j + 1]
				array[j + 1] = array[j]
				array[j] = tmp
				prev_swap = j
				if init_swap == -1 {
					init_swap = j
				}
			}

			j += 1
		}

		if prev_swap == -1 {
			return 0
		}

		init_j = init_swap - 1
		if init_j < 0 do init_j = 0
		last_j = prev_swap
	}
}

quick_sort :: proc(array: []int) -> int {
	a := array
	n := len(a)
	if n < 2 {
		return 0
	}

	p := a[n / 2]
	i, j := 0, n - 1

	loop: for {
		for {if a[i] >= p do break; i += 1}
		for {if p >= a[j] do break; j -= 1}

		if i >= j {
			break loop
		}
		
		tmp := a[j]
		a[j] = a[i]
		a[i] = tmp

		i += 1
		j -= 1
	}

	quick_sort(a[0:i])
	quick_sort(a[i:n])

	return 0
}
