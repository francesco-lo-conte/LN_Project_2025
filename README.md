# VHDL Memory-Mapped Differential Filter

**Project for the "Logic Networks" Course (A.Y. 2024-2025) at Politecnico di Milano.** 

---

## Project Overview

This VHDL project implements a hardware module that interfaces with a memory to perform a configurable digital filtering operation.
The module reads a 17-byte configuration header and a data sequence (W) from a specified memory address. It then applies a 3rd or 5th-order differential filter, normalizes and saturates the results, and writes the final sequence (R) back to memory. 

The entire design is synchronous, synthesizable, and robustly tested to handle various boundary conditions, consecutive operations, and asynchronous resets. 

## Core Functionality

* **Memory-Mapped Operation:** The module is controlled by a main Finite State Machine (FSM) that orchestrates all memory read/write operations. 
* **Dynamic Configuration:** On start, the module reads a 17-byte preamble from memory containing: 
    * `K` (2 bytes): The length of the input sequence. 
    * `S` (1 byte): A selector to choose between the **Order 3** (LSB='0') or **Order 5** (LSB='1') filter. 
    * `C1-C14` (14 bytes): The 7 coefficients for each of the two filters. 
* **Differential Filter:** The core datapath applies the formula $f^{\prime}(i) = (1/n) \cdot \sum(C_{j} \cdot f[j+i])$. 
* **Boundary Conditions:** Values outside the sequence (at the beginning and end) are treated as zeros. 
* **Approximated Normalization:** The division by $n$ ($n=12$ or $n=60$) is approximated using bit-shifts as specified (e.g., $1/12 \approx 1/16+1/64+1/256+1/1024$). 
* **Truncation Error Correction:** To reduce error on negative numbers, a `+1` correction is added to the result of *each individual shift operation* if the value being shifted is negative. 
* **Saturation:** The final 8-bit result is saturated (clamped) to the 2's complement range of `[-128, +127]` to prevent overflow. 

---

## Hardware Architecture

The design follows a modular **FSM-controlled Datapath** architecture, clearly separating the control logic (FSM) from the data processing units (datapath). This makes the design clean, scalable, and easy to verify.

<img width="1362" height="408" alt="Hardware_acrhitecture" src="https://github.com/user-attachments/assets/e5c4f140-9342-4a19-9b84-966fe254cef6" />

### Datapath Components

The datapath is a 6-cycle pipeline composed of specialized modules: 

1.  **Address Manager:** Generates the correct memory addresses for the FSM. It maintains two separate internal pointers: one for reading data (`w_addr_ptr`) and one for writing results (`r_addr_ptr`). 
2.  **Register Coeff:** A "smart" register that listens to all 14 coefficients being read from memory but only latches the 7 relevant ones based on the `i_filter_select` signal from the FSM. 
3.  **Shift Register:** A 7-word (8-bit each) sliding window. It provides the 7-word input `f[j+i]` to the filter. It is controlled by the FSM's `flush` signal to feed zeros at the end of the sequence, correctly handling the final boundary conditions. 
4.  **Filter:** The core mathematical unit.  It performs the $\sum(C_j \cdot f[j+i])$ weighted sum. To prevent overflow during calculation, it uses a **20-bit internal width** for the accumulator. 
5.  **Normalizer:** The final stage of the pipeline. It takes the 20-bit result from the Filter and performs the multi-step shift-and-add normalization, applies the `+1` error correction, and saturates the value to the final 8-bit output. 

### Control Unit (FSM)

The system is orchestrated by a central Finite State Machine (`fsm.vhd`) that manages the entire process: 

1.  **IDLE:** Waits for the `i_start` signal.
2.  **Preamble Read:** On start, it generates a "soft reset" (`o_datapath_reset`) to clear the datapath components and sequentially reads the 17-byte header (`K`, `S`, `C1-14`). 
3.  **Process & Write Loop:** The FSM enters a main loop, reading one word `W` and writing one result `R` per cycle. It carefully manages the **6-cycle pipeline latency** by waiting for the pipeline to fill before starting to write results.
4.  **Pipeline Flush:** After reading the last word `W(K)`, the FSM continues to run for 6 more cycles, asserting the `o_flush` signal. This pushes zeros into the `Shift_register` to calculate the final 6 boundary values correctly. 
5.  **DONE:** Asserts the `o_done` signal and waits for `i_start` to go low before returning to `IDLE`. 

This design supports **consecutive runs** without requiring a hardware reset (`i_rst`) between operations. 

---

## Synthesis & Verification Results

The module was successfully synthesized and implemented for an **Artix-7 FPGA (xc7a200tfbg484-1)**. 

### Synthesis Report
* **Resource Usage:** 818 LUTs, 238 FFs 
* **Design Quality:** **No latches** were inferred, confirming a robust, fully synchronous design. 
* **Timing:** The design met all timing constraints, with a worst-case negative slack (WNS) of **5.749 ns**. 

### Verification
The module passed a comprehensive test suite, including:
* The official testbench provided by the professor. 
* Custom tests for **positive and negative saturation**. 
* Correct operation of the **Order 5 filter**. 
* A **robustness test** with a long sequence (K=794). 
* A **consecutive run test** (multiple `START` signals without `i_rst`). 
* An **asynchronous reset** test during mid-operation. 
* The **minimum length (K=7)** boundary case. 

---

## How to Use

The top-level VHDL entity is `project_reti_logiche`. 

```vhdl
entity project_reti_logiche is
    port (
        i_clk      : in  std_logic;
        i_rst      : in  std_logic;
        i_start    : in  std_logic;
        i_add      : in  std_logic_vector(15 downto 0);
        o_done     : out std_logic;
        o_mem_addr : out std_logic_vector(15 downto 0);
        i_mem_data : in  std_logic_vector(7 downto 0);
        o_mem_data : out std_logic_vector(7 downto 0);
        o_mem_we   : out std_logic;
        o_mem_en   : out std_logic
    );
end project_reti_logiche;
```

## Author
* **Francesco Lo Conte**
