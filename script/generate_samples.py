import random

NUM_SAMPLES = 4096
MAX_VAL = 10000

random.seed(45)

with open("sim/input_samples.txt", "w") as f:
    for _ in range(NUM_SAMPLES):
        val = random.randint(-MAX_VAL, MAX_VAL)
        f.write(f"{val}\n")

print(f"Generated {NUM_SAMPLES} samples in sim/input_samples.txt")
