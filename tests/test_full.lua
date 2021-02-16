for i = 1, 2 {
    for b = 1, 2 {
        if b == 2 {
            print(b)
        else
            print(i)
        }
    }

    local fn = ( (a,b,c) => {
        print(a, b)

        if (a == 100) {
            print(a)
        }
    } )(1, 20)

}