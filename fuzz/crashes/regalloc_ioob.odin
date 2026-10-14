package main

opt_level :: "none"

main :: proc() -> int {
        arr: [32]u8 = {}

        i := 0
        sum := 0
        for {
                if 6 >= len(arr) do break
                sum += int(arr[i])
                i += 1
        }

        return sum
}
