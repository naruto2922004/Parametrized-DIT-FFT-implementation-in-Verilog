import math
import cmath
import os

# Settings
INPUT_FILE = "sim/input_samples.txt"
OUTPUT_FILE = "sim/output_results.txt"
N = 1024
MAX_ERROR_PCT = 1.0  # Max acceptable % error threshold

if not os.path.exists(INPUT_FILE) and os.path.exists("../sim/input_samples.txt"):
    INPUT_FILE = "../sim/input_samples.txt"
    OUTPUT_FILE = "../sim/output_results.txt"

# Radix-2 FFT
def fft(x):
    n = len(x)
    if n <= 1:
        return x
    even = fft(x[0::2])
    odd = fft(x[1::2])
    t = [cmath.exp(-2j * math.pi * k / n) * odd[k] for k in range(n // 2)]
    return [even[k] + t[k] for k in range(n // 2)] + [even[k] - t[k] for k in range(n // 2)]

# Read input samples
with open(INPUT_FILE, "r") as f:
    inputs = [int(line.strip()) for line in f if line.strip() and not line.startswith("#")]

# Read simulation output
hw_out = []
with open(OUTPUT_FILE, "r") as f:
    for line in f:
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split()
        if len(parts) >= 2:
            hw_out.append(complex(int(parts[0]), int(parts[1])))

num_frames = len(hw_out) // N
print(f"Verifying {num_frames} frame(s) of {N}-point FFT...")

all_pass = True
for f in range(num_frames):
    x = inputs[f * N : (f + 1) * N]
    hw = hw_out[f * N : (f + 1) * N]
    golden = fft(x)

    # Absolute values and errors
    abs_golden = [abs(g) for g in golden]
    errors = [abs(h - g) for h, g in zip(hw, golden)]
    max_err = max(errors)
    peak_val = max(abs_golden)

    # % error from absolute value
    max_pct_err = (max_err / peak_val * 100) if peak_val > 0 else 0
    avg_pct_err = (sum(errors) / sum(abs_golden) * 100) if sum(abs_golden) > 0 else 0

    status = "PASS" if max_pct_err <= MAX_ERROR_PCT else "FAIL"
    if status == "FAIL":
        all_pass = False

    print(f"Frame {f + 1}: Max Error = {max_pct_err:.4f}% ({max_err:.1f} LSB), Avg Error = {avg_pct_err:.4f}% -> {status}")

if all_pass:
    print("All tests passed!")
else:
    print("Some tests failed.")