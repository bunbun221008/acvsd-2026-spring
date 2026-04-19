import numpy as np

# (SIZE, length, start_addr)
PARTITION = {
    1024: [[0, 128,  8], [0, 64, 16], [0, 32, 32], [0, 16, 64], [0, 8, 128]],
     512: [[0, 128,  4], [0, 64,  8], [0, 32, 16], [0, 16, 32], [0, 8,  64], [0, 4, 128]],
     256: [[0, 128,  2], [0, 64,  4], [0, 32,  8], [0, 16, 16], [0, 8,  32], [0, 4,  64], [0, 2, 128]],
     128: [[0, 128,  1], [0, 64,  2], [0, 32,  4], [0, 16,  8], [0, 8,  16], [0, 4,  32], [0, 2,  64], [0, 1,  128]],
      64: [[0,  64,  1], [0, 32,  2], [0, 16,  4], [0,  8,  8], [0, 4,  16], [0, 2,  32], [0, 1,  64]],
      32: [[0,  32,  1], [0, 16,  2], [0,  8,  4], [0,  4,  8], [0, 2,  16], [0, 1,  32]],
      16: [[0,  16,  1], [0,  8,  2], [0,  4,  4], [0,  2,  8], [0, 1,  16]],
}

class Node:
    def __init__(self, size):
        self.size = size
        self.left = None
        self.right = None

    def isleaf(self):
        return self.left is None and self.right is None
    
    def split(self):
        self.left = Node(self.size//2)
        self.right = Node(self.size//2)

    def select(self):
        idx = np.random.choice(list(range(len(PARTITION[self.size]))))
        return PARTITION[self.size][idx].copy()

class Tree:
    def __init__(self, size):
        self.size = size
        self.root = Node(size)
        self.all_nodes = [self.root]

        cur_node = self.root
        while cur_node.size > 16:
            cur_node.split()
            self.all_nodes.append(cur_node.left)
            self.all_nodes.append(cur_node.right)
            cur_node = cur_node.right

    def shuffle(self, round=20):
        for node in np.random.choice(self.all_nodes, size=round, replace=True):
            node.left, node.right = node.right, node.left

    def traverse(self):
        sequence = []
        def dive(node):
            nonlocal sequence
            if node.isleaf():
                sequence.append(node)
                return
            else:
                dive(node.left)
                dive(node.right)
                return
        dive(self.root)
        return sequence


def gen_address(filename="address.dat"):
    address = []

    cur_addr = 0
    forest = [Tree(1024) for _ in range(6)]
    for tree in forest:
        tree.shuffle()
        seq = tree.traverse()
        for node in seq:
            address.append(node.select())
            address[-1][0] = cur_addr
            cur_addr += node.size
            if (address[-1][0] % address[-1][1] != 0):
                print("Error")

    address = np.array(address)
    address[:, 1] = np.log2(address[:, 1]).astype(int)
    pattern = (address[:, 0] << 14) | (address[:, 1] << 10) | address[:, 2]

    with open(filename, "w") as f:
        for num in pattern:
            f.write(f"{num & 0xFFFFFFF:07X}\n")

if __name__ == "__main__":
    gen_address("addr_i.dat")
    gen_address("addr_o.dat")
