local i;
local fib = {};

fib[0] = 0
fib[1] = 1
for i = 2, 10 {
  fib[i] = fib[i - 2] + fib[i - 1]
  print(fib[i])
}