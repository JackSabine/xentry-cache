#!/usr/bin/python

ONEHOT_WIDTH = 8
BINARY_WIDTH = (ONEHOT_WIDTH - 1).bit_length()

def onehot0_to_binary(onehot0: list[int]) -> list[int]:
    binary = [0 for i in range(BINARY_WIDTH)]

    for i in range(BINARY_WIDTH):
        stride = (2 ** i) + 1
        group_size = (2 ** i)
        init = (2 ** i)

        j = init
        group_count = 0

        binary[i] = 0

        while (j < ONEHOT_WIDTH):
            binary[i] = binary[i] | onehot0[j]
            group_count += 1

            if (group_count == group_size):
                j = j + stride
            else:
                j += 1

    return binary

def main():
    for i in range (ONEHOT_WIDTH):
        onehot0 = [i == j for j in range(ONEHOT_WIDTH)]

        print(onehot0[::-1], end="")
        print(" ==> ", end="")
        print(onehot0_to_binary(onehot0)[::-1], end="")


if __name__ == "__main__":
    main()