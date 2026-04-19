import numpy as np

DATA_WIDTH = 16
DATA_MASK  = 0xFFFF
BASE_DTYPE = np.uint16
TRUE  = np.uint16(0x5555)
FALSE = np.uint16(0xAAAA)

def save_pattern(data, filename="pattern.dat"):
    data = data.flatten().astype(BASE_DTYPE)
    with open(filename, "w") as f:
        for num in data:
            f.write(f"{num & DATA_MASK:04X}\n")

def gen_random_fp16(shape=1, low_bound=None, high_bound=None):
    if low_bound is None:
        low_bound = np.finfo(np.float16).tiny * (2.0**-10) * 1.05
    if high_bound is None:
        high_bound = np.finfo(np.float16).max * 0.95

    exp_mean = (np.log(low_bound) + np.log(high_bound)) / 2
    exp_sigma = (np.log(high_bound) - np.log(low_bound)) / 6
    
    data = np.exp(np.random.normal(exp_mean, exp_sigma, size=shape))
    data = (np.random.choice([-1, 1], size=shape) * data).astype(np.float16)
    return data.view(BASE_DTYPE)

def to_int(data):
    if DATA_WIDTH == 16:
        return data.view(np.int16)
    else:
        raise NotImplementedError(f"Function to_int is not implemented for DATA_WIDTH = {DATA_WIDTH}")
    
def to_uint(data):
    if DATA_WIDTH == 16:
        return data.view(np.uint16)
    else:
        raise NotImplementedError(f"Function to_uint is not implemented for DATA_WIDTH = {DATA_WIDTH}")

def to_fp(data):
    if DATA_WIDTH == 16:
        return data.view(np.float16)
    else:
        raise NotImplementedError(f"Function to_fp is not implemented for DATA_WIDTH = {DATA_WIDTH}")

def SIMD_ADD(a, b):
    a, b = to_int(a), to_int(b)
    return (a + b).view(BASE_DTYPE)

def SIMD_SUB(a, b):
    a, b = to_int(a), to_int(b)
    return (a - b).view(BASE_DTYPE)

def SIMD_MUL(a, b):
    a, b = to_int(a), to_int(b)
    return (a * b).view(BASE_DTYPE)

def SIMD_LT(a, b):
    a, b = to_int(a), to_int(b)
    return np.where(a < b, TRUE, FALSE).view(BASE_DTYPE)

def SIMD_SLL(a, b):
    a, b = to_int(a), to_uint(b)
    return ((a << (b & 0xF)) & DATA_MASK).astype(BASE_DTYPE).view(BASE_DTYPE)

def SIMD_SRA(a, b):
    a, b = to_int(a), to_uint(b)
    return ((a >> (b & 0xF)) & DATA_MASK).astype(BASE_DTYPE).view(BASE_DTYPE)

def SIMD_NOT(a, b):
    a, b = to_int(a), to_int(b)
    return (~a).view(BASE_DTYPE)

def SIMD_OR(a, b):
    a, b = to_int(a), to_int(b)
    return (a | b).view(BASE_DTYPE)

def SIMD_AND(a, b):
    a, b = to_int(a), to_int(b)
    return (a & b).view(BASE_DTYPE)

def SIMD_XOR(a, b):
    a, b = to_int(a), to_int(b)
    return (a ^ b).view(BASE_DTYPE)

def SIMD_FPADD(a, b):
    a, b = to_fp(a), to_fp(b)
    return (a + b).view(BASE_DTYPE)

def SIMD_FPSUB(a, b):
    a, b = to_fp(a), to_fp(b)
    return (a - b).view(BASE_DTYPE)

def SIMD_FPMUL(a, b):
    a, b = to_fp(a), to_fp(b)
    return (a * b).view(BASE_DTYPE)

def SIMD_FPDIV(a, b):
    a, b = to_fp(a), to_fp(b)
    return (a / b).view(BASE_DTYPE)

def SIMD_FPLT(a, b):
    a, b = to_fp(a), to_fp(b)
    return np.where(a < b, TRUE, FALSE).view(BASE_DTYPE)

SIMD_INST = [
    SIMD_ADD,
    SIMD_SUB,
    SIMD_MUL,
    SIMD_LT,
    SIMD_SLL,
    SIMD_SRA,
    SIMD_NOT,
    SIMD_OR,
    SIMD_AND,
    SIMD_XOR,
    SIMD_FPADD,
    SIMD_FPSUB,
    SIMD_FPMUL,
    SIMD_FPDIV,
    SIMD_FPLT,
    None
]

def SIMD(data_a, data_b):
    INST_LENGTH = 16
    shape_a, shape_b = data_a.shape, data_b.shape
    assert shape_a == shape_b, "Dimensions must match for SIMD"
    shape_z = shape_a
    data_a = data_a.reshape(-1, shape_a[-1])
    data_b = data_b.reshape(-1, shape_b[-1])
    data_z = np.zeros(shape_z, dtype=BASE_DTYPE).reshape(-1, shape_z[-1])
    seq_len, num_unit = data_a.shape[0], data_a.shape[-1]

    def consine_dist(max=1, size=1):
        u = np.random.uniform(0, 1, size=size)
        sample = np.arcsin(u) * max * 2 / np.pi
        return sample

    op_code = np.random.randint(0, 0xF, size=(seq_len, INST_LENGTH), dtype=BASE_DTYPE)
    store_idx = consine_dist(max=0.75*INST_LENGTH, size=op_code.shape[0]).astype(int)
    np.put_along_axis(op_code, INST_LENGTH-1-store_idx[:, None], 0xF, axis=-1)
    rd = np.random.randint(0, 4, size=(seq_len, INST_LENGTH), dtype=BASE_DTYPE)
    rs1 = np.random.randint(0, 4, size=(seq_len, INST_LENGTH), dtype=BASE_DTYPE)
    rs2 = np.random.randint(0, 4, size=(seq_len, INST_LENGTH), dtype=BASE_DTYPE)

    for i in range(seq_len):
        data_rf = np.zeros((4, num_unit), dtype=BASE_DTYPE)
        data_rf[0], data_rf[1] = data_a[i], data_b[i]
        for j in range(16):
            operation = SIMD_INST[op_code[i, j]]
            if operation is not None:
                operand_a = data_rf[rs1[i, j]]
                operand_b = data_rf[rs2[i, j]]
                while np.mean((to_fp(operand_a) == 0) | (to_fp(operand_b) == 0)) > 0.5:
                    rs1[i, j] = np.random.randint(0, 4, dtype=BASE_DTYPE)
                    rs2[i, j] = np.random.randint(0, 4, dtype=BASE_DTYPE)
                    operand_a = data_rf[rs1[i, j]]
                    operand_b = data_rf[rs2[i, j]]
                result = operation(operand_a, operand_b)
                while np.mean(to_fp(result) == 0) > 0.5 or (operation in [SIMD_FPADD, SIMD_FPSUB, SIMD_FPMUL, SIMD_FPDIV] and np.mean(np.isnan(to_fp(result))) > 0.5):
                    op_code[i, j] = np.random.randint(0, 0xF, dtype=BASE_DTYPE)
                    operation = SIMD_INST[op_code[i, j]]
                    result = operation(operand_a, operand_b)
                data_rf[rd[i, j]] = result
            else:
                data_z[i, :] = data_rf[rd[i, j]]
    inst = (op_code << 12) | (rd << 10) | (rs1 << 8) | (rs2 << 6)
    data_z = data_z.reshape(shape_z)
    return data_z.view(BASE_DTYPE), inst.view(BASE_DTYPE)

def GEMM(data_a, data_b):
    ''' data_b has been transposed '''
    shape_a, shape_b = data_a.shape, data_b.shape
    assert shape_a[-1] == shape_b[-1], "Inner dimensions must match for GEMM"
    shape_z = shape_a[:-1] + shape_b[:-1]
    data_a = data_a.reshape(-1, shape_a[-1])
    data_b = data_b.reshape(-1, shape_b[-1])
    data_z = np.zeros(shape_z, dtype=BASE_DTYPE).reshape(np.prod(shape_a[:-1]), np.prod(shape_b[:-1]))

    data_a, data_b = to_fp(data_a), to_fp(data_b)
    for i in range(data_z.shape[0]):
        for j in range(data_z.shape[1]):
            result = np.sum(data_a[i] * data_b[j])
            data_z[i, j] = result.view(BASE_DTYPE)
    data_z = data_z.reshape(shape_z)
    return data_z.view(BASE_DTYPE)


if __name__ == "__main__":
    # Generate random data
    high_bound = ((np.finfo(np.float16).max) ** 0.8)  * 0.95
    data_a = gen_random_fp16((32, 32), high_bound=high_bound)
    data_b = gen_random_fp16((32, 32), high_bound=high_bound)

    print(f"Data_a: {data_a.shape}, {data_a.dtype}")
    print(f"Data_b: {data_b.shape}, {data_b.dtype}")

    data_z_SIMD, inst = SIMD(data_a.reshape(64, 16), data_b.reshape(64, 16))
    print(f"Data_z_SIMD: {data_z_SIMD.shape}, {data_z_SIMD.dtype}")
    print(f"Inst: {inst.shape}, {inst.dtype}")
    op_freq = np.histogram(inst >> 12, bins=range(0, 17), density=True)[0]
    print(f"OP Freq: {np.round(op_freq * 100, 2)}")
    print(f"Zero: {np.mean(to_fp(data_z_SIMD) == 0)}, Inf: {np.mean(np.isinf(to_fp(data_z_SIMD)))}")

    data_z_GEMM = GEMM(data_a, data_b)
    print(f"Data_z_GEMM: {data_z_GEMM.shape}, {data_z_GEMM.dtype}")
    print(f"Zero: {np.mean(to_fp(data_z_GEMM) == 0)}, NaN: {np.mean(np.isnan(to_fp(data_z_GEMM)))}, Inf: {np.mean(np.isinf(to_fp(data_z_GEMM)))}")

    save_pattern(data_a, "data_a.dat")
    save_pattern(data_b, "data_b.dat")
    save_pattern(inst, "inst.dat")
    save_pattern(data_z_SIMD, "data_z_SIMD.dat")
    save_pattern(data_z_GEMM, "data_z_GEMM.dat")
