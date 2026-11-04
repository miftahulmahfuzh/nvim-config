package main

import "fmt"

func add(a int, b int) int {
	var x = a+b
	return x
}

func main() {
	fmt.Println(add(1,2))
}
