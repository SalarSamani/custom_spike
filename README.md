# custom SPIKE(RISC-V) supports scalable MMU

This project includes custom modifications to both Spike and OpenOCD to support my experimental MMU configuration for RISC-V. These changes were necessary to properly test and debug MMU behavior in a riscv32 environment. The provided build scripts will compile these modified versions so you can reproduce the same setup seamlessly.

This repository contains:

- Scripts to build the RISC-V GCC/Newlib toolchain for **riscv32**.
- Build scripts for both **Spike** and **OpenOCD** (modified version).
- A simple test that configures the **MMU** and allows debugging.

## Building the Environment

After cloning, you can build the environment using the following commands:

```bash
bash scripts/build_toolchain_initial.sh
bash scripts/build_toolchain_newlib.sh
bash scripts/build_toolchain_final.sh
bash scripts/build_spike.sh
bash scripts/build_openocd.sh
```

Then source the environment:

```bash
source scripts/setup_env.sh
```

## Running the Test

Navigate to the test directory and run the debug script:

```bash
cd test/rv32ima/startup/
./run_debug.sh
```
