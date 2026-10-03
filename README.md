# Parameterized DIT FFT Implementation in Verilog

This project implements a parameterized **Decimation-in-Time (DIT) Radix-2 Fast Fourier Transform (FFT)** in Verilog HDL.

---

## Overview

The design computes the Discrete Fourier Transform (DFT) using the Cooley-Tukey Radix-2 Decimation-in-Time algorithm. It accepts serial time-domain input samples, maps them with bit-reversed addressing, computes the butterfly stages using parallel processing units, and buffers the resulting frequency-domain outputs (real and imaginary parts) for streaming readout.

---

## Configurable Parameters

The design is fully parameterized so you can customize bit-widths, maximum transform size, and hardware parallelism directly in the RTL:

| Parameter | Default | Description |
|---|---|---|
| `MAX_STAGES` | `10` | Maximum FFT stage depth (2^10 = 1024 points max). |
| `INPUT_STAGE_WIDTH` | `4` | Bit-width for stage selection register: ceil(log2(MAX_STAGES)). |
| `INPUT_DATA_WIDTH` | `16` | Bit-width of input samples and twiddle factors. |
| `OUTPUT_DATA_WIDTH` | `32` | Bit-width of intermediate stages and output bins. |
| `FRAC_BITS` | `15` | Number of fractional bits for twiddle factors (Q15). |
| `BUTTERFLY_FACTOR` | `6` | Hardware parallelism: 2^BUTTERFLY_FACTOR = 64 parallel butterfly units. |

The active FFT length is also dynamically selectable at runtime via the `input_stage` port (`N = 2^input_stage`, e.g. 8, 16, 64, 1024 points).

---

## Project Structure

```
.
├── rtl/                        # Verilog source files
│   ├── fft.v                   # Top-level FFT module
│   ├── butterfly.v             # Radix-2 butterfly unit
│   ├── fft_input.v             # Input buffer with bit-reversal
│   └── fft_output.v            # Output buffer with handshake
├── rom/
│   └── twiddle_rom.v           # Twiddle factor lookup table
├── script/
│   ├── generate_twiddles.py    # Generates twiddle_rom.v
│   ├── generate_samples.py     # Generates test input samples
│   └── verify_output.py        # Verifies simulation output against golden FFT
└── sim/
    ├── tb_fft.v                # Verilog testbench
    ├── input_samples.txt       # Input test stimulus
    └── output_results.txt      # Simulation output results
```

---

## How to Verify

The verification workflow consists of three straightforward steps:

### 1. Create Input Samples

Run the sample generation script to generate input test data:

```bash
python script/generate_samples.py
```

This creates signed random test samples in `sim/input_samples.txt` (default: 4096 samples = 4 frames of 1024-point FFT). The number of samples and amplitude range can be edited directly in `script/generate_samples.py`.

*(Note: If you change the FFT point size or twiddle width, re-run `python script/generate_twiddles.py` to regenerate `rom/twiddle_rom.v`)*

### 2. Run the Testbench

Compile the RTL and run the simulation using ModelSim (or any standard Verilog simulator):

```powershell
# Compile RTL and testbench
vlog -work work rom/twiddle_rom.v rtl/butterfly.v rtl/fft_input.v rtl/fft_output.v rtl/fft.v sim/tb_fft.v

# Run simulation
vsim -c -lib work tb_fft -do "run -all; quit"
```

The testbench (`sim/tb_fft.v`):
- Loads the samples from `sim/input_samples.txt`.
- Streams them into the FFT core.
- Collects the frequency-domain outputs and saves `<real> <imag>` values to `sim/output_results.txt`.

### 3. Verify Output

Run the verification script to check the simulation output against the analytical golden FFT:

```bash
python script/verify_output.py
```

The script computes an exact Radix-2 FFT in Python, calculates the percentage error relative to the absolute golden values:

```
Max % Error = (max |Hardware - Golden| / max |Golden|) * 100%
```

It prints the error per frame and pass/fail status:

```
Verifying 4 frame(s) of 1024-point FFT...
Frame 1: Max Error = 0.0045% (21.6 LSB), Avg Error = 0.0045% -> PASS
Frame 2: Max Error = 0.0084% (36.0 LSB), Avg Error = 0.0044% -> PASS
Frame 3: Max Error = 0.0061% (25.9 LSB), Avg Error = 0.0044% -> PASS
Frame 4: Max Error = 0.0072% (34.0 LSB), Avg Error = 0.0041% -> PASS
All tests passed!
```
