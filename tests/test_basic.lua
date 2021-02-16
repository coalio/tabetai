local a = 10

function aHandler() {
    print('This is the best')
    return (a,b) => {
        print(a)
    }
}

if (true) {
    print(true)
}

aHandler()(a)