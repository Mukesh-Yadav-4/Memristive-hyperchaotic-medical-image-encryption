# GitHub Release Content Plan
### Repository: `memristive-hyperchaotic-medical-image-encryption`
**Author:** Yash  
**Document Purpose:** Pre-release audit of repository artifacts, licensing, provenance, and release hygiene.

---

## 1. Repository Inventory and Size Analysis

* **Total Project Size:** ~8.39 MB
* **Total File Count:** 37 files across 5 directories
* **Directory Breakdown:**
  * `core/`: 3 files (~14.25 KB) — Core MATLAB algorithmic engines
  * `hardware_stm32/`: 10 files (~152.4 KB) — Embedded C source, startup assembly, build scripts, compiled binaries
  * `image_dataset/`: 8 files (~4.83 MB) — Clinical test images across multiple diagnostic modalities
  * `outputs/`: 10 files (~3.52 MB) — Generated figures, LaTeX tables, markdown summaries, and `.mat` packages
  * Root Directory: 5 files (~40 KB) — Top-level MATLAB run scripts and `README.md`
  * `docs/`: 2 files (~22 KB) — Pre-release content plan and STM32 HIL claim verification report

---

## 2. Recommended File Inclusion / Exclusion Strategy

### 2.1 Files Recommended for GitHub Tracking
The following source code, configuration, and documentation files constitute the permanent repository codebase:

| Category | File Path | Rationale |
|:---|:---|:---|
| **Root Execution** | `step1_encrypt_medical_image.m` | Primary sender encryption node |
| **Root Execution** | `step2_decrypt_medical_image.m` | Primary receiver decryption & lossless audit node |
| **Root Execution** | `step3_security_audit.m` | Cryptanalytic evaluation suite |
| **Root Execution** | `run_full_benchmark.m` | Multi-model benchmarking automation |
| **Core Engines** | `core/m4dchs_engine.m` | M-4DCHS RK4 keystream generation engine |
| **Core Engines** | `core/scramble_engine.m` | Modular permutation engine (4 scrambling schemes) |
| **Core Engines** | `core/diffusion_engine.m` | Dual-mode CBC diffusion engine (HIL + software) |
| **Firmware Source** | `hardware_stm32/Src/main.c` | Bare-metal ARM Cortex-M4 FPU firmware |
| **Firmware Source** | `hardware_stm32/Src/syscalls.c` | Newlib POSIX runtime stubs |
| **Firmware Source** | `hardware_stm32/Src/sysmem.c` | Heap memory management stub |
| **Firmware Source** | `hardware_stm32/Startup/startup_stm32g474retx.s` | Vector table & early FPU initialization |
| **Firmware Source** | `hardware_stm32/STM32G474RETX_FLASH.ld` | Flash/RAM memory layout linker script |
| **Firmware Source** | `hardware_stm32/Inc/` | Embedded peripheral and register header files |
| **Build Tools** | `hardware_stm32/build_firmware.bat` | 1-click GNU ARM toolchain compiler script |
| **Build Tools** | `hardware_stm32/flash_firmware.bat` | 1-click ST-LINK CLI programming script |
| **Documentation** | `README.md` | Primary technical monograph & research overview |
| **Documentation** | `docs/GITHUB_RELEASE_CONTENT_PLAN.md` | Pre-release content and licensing audit |
| **Documentation** | `docs/STM32_HIL_CLAIM_VERIFICATION.md` | Forensic verification report evaluating physical STM32 HIL execution claim |

### 2.2 Files Recommended for Exclusion (`.gitignore`)
The following files should be excluded from git version control:

| File / Pattern | Reason for Exclusion | Alternative Distribution |
|:---|:---|:---|
| `hardware_stm32/m4dchs_stm32.elf` | Compiled binary executable (~56 KB) | Rebuildable via `build_firmware.bat` or attach to GitHub Releases |
| `hardware_stm32/m4dchs_stm32.bin` | Raw compiled binary image (~2.8 KB) | Rebuildable via `build_firmware.bat` or attach to GitHub Releases |
| `hardware_stm32/m4dchs_stm32.map` | Linker memory map file (~82 KB) | Generated artifact during compilation |
| `outputs/encrypted_package.mat` | Binary MATLAB data package (~328 KB) | Generated dynamically when running `step1` |
| `outputs/cipher_image.png` | Transient generated cipher image | Generated dynamically during execution |
| `outputs/decrypted_image.png` | Transient generated decrypted image | Generated dynamically during execution |
| `outputs/scrambled_image.png` | Transient generated permuted image | Generated dynamically during execution |
| `*.asv`, `*.m~` | MATLAB editor auto-save files | Local editor cache |
| `.DS_Store`, `Thumbs.db` | OS-specific folder preview metadata | Local OS cache |

> **Note on Documentation Figures:**  
> Key publication figures (`step1_encryption_results.png`, `step2_decryption_results.png`, `step3_security_audit_results.png`, `benchmark_comparison.png`) and tabular summaries (`benchmark_summary.md`, `benchmark_table.tex`) may optionally be retained in `outputs/` so that markdown preview links render correctly in GitHub.

---

## 3. Data Provenance and License Review

Before publishing the repository publicly, the following files require provenance verification:

### 3.1 Medical Image Dataset (`image_dataset/`)
All diagnostic modalities must be confirmed to be open-access, de-identified research assets free of Protected Health Information (PHI) under HIPAA Safe Harbor rules:

| Filename | Inferred Modality | Recommended Source Verification |
|:---|:---|:---|
| `brain_mri_kaggle.tif` | Axial T1/T2 Brain MRI | Verify Kaggle dataset license (e.g., CC0 or CC-BY 4.0; e.g., Sartorius/BraTS subsets). |
| `brain_mri.jpg` | High-Contrast Brain MRI | Verify source attribution / open clinical repository. |
| `Breast_cancer_img.png` | Histopathology scan | Check compatibility with BreaKHis / open pathology dataset licenses. |
| `eye_image.png` | Retinal Fundus photography | Check compatibility with DRIVE / STARE / MESSIDOR open databases. |
| `eye_image2.png` | Retinal Fundus photography | Check compatibility with open retinal databases. |
| `skin_lesion.jpg` | Dermoscopy lesion | Check compatibility with ISIC (International Skin Imaging Collaboration) archive. |
| `esophegus_image.jpg` | Endoscopic scan | Check compatibility with open endoscopy imaging datasets (e.g., Kvasir). |
| `skull_image2.jpg` | Skull X-Ray / CT scan | Check open clinical radiography source. |

### 3.2 Firmware Files (`hardware_stm32/`)
* `Startup/startup_stm32g474retx.s` and `STM32G474RETX_FLASH.ld`:
  * Distributed by STMicroelectronics under the Apache 2.0 or BSD 3-Clause license.
  * Retain original STMicroelectronics copyright notices at the top of these files.

---

## 4. Key Management and Metadata Audit

Chaos-based stream ciphers and research scripts frequently contain hardcoded parameters:

1. **Master Secret Key (`K_master`):**
   * Defined in `step1_encrypt_medical_image.m` and `run_full_benchmark.m` as `0.314159265358979`.
   * **Audit Finding:** This is an academic test parameter used for demonstration purposes. It does not represent a production secret or credential.
2. **Session Key in `.mat` Package:**
   * `outputs/encrypted_package.mat` stores `session_key` derived via SHA-256 digest folding.
   * **Recommendation:** Exclude `encrypted_package.mat` from git tracking to prevent stale session keys in git history.
3. **Hardcoded Machine Paths:**
   * Ensure all scripts use relative paths (`fileparts(mfilename('fullpath'))`) rather than absolute paths (`C:\Users\YASH\...`).
   * The current scripts dynamically compute `script_dir = fileparts(mfilename('fullpath'))` and `addpath(fullfile(script_dir, 'core'))`, ensuring portable cross-platform execution.
4. **Hardware COM Port Identifier:**
   * Defaulted to `'COM10'` on Windows. Users on Linux/macOS or different USB ports should be prompted to configure their specific device path (`/dev/ttyACM0` or `COMx`).

---

## 5. Recommended `.gitignore` File

The following `.gitignore` should be placed in the repository root prior to staging:

```gitignore
# ==============================================================================
# Git Ignore Rules for memristive-hyperchaotic-medical-image-encryption
# ==============================================================================

# --- Operating System Artifacts ---
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db
[Dd]esktop.ini

# --- MATLAB Artifacts ---
*.asv
*.m~
*.slxc
*.mex*
*.mat~
slprj/
sfprj/

# --- Compiled Embedded Firmware Artifacts ---
hardware_stm32/*.elf
hardware_stm32/*.bin
hardware_stm32/*.hex
hardware_stm32/*.map
hardware_stm32/*.o
hardware_stm32/*.su
hardware_stm32/*.d
hardware_stm32/Debug/
hardware_stm32/Release/

# --- Transient Data & Key Packages ---
outputs/encrypted_package.mat
outputs/cipher_image.png
outputs/decrypted_image.png
outputs/scrambled_image.png

# --- IDE / Editor Configurations ---
.vscode/
.idea/
*.swp
*~
```

---

## 6. Pre-Release Checklist

Before creating a GitHub release tag (e.g., `v1.0.0`):

- [x] Code files verified for clean execution and zero syntax errors.
- [x] `README.md` verified with accurate academic terminology, clear scoping, and no unsubstantiated security claims.
- [x] Hardware FPU initialization verified in startup assembly (`startup_stm32g474retx.s`).
- [x] Exact reconstruction verified in MATLAB for benchmark images (Brain MRI, Retinal scan) and physically validated on STM32 HIL for the tested 256 × 256 × 3 Brain MRI image (0 mismatched pixels, $\text{MSE} \equiv 0.00000000$; exact pixel equality confirms lossless reconstruction).
- [x] Forensic verification report created in `docs/STM32_HIL_CLAIM_VERIFICATION.md` detailing physical HIL metrics (12.24 s encryption, 13.35 s decryption, 256 scanlines, 196,608 payload bytes, 0 dropped frames, $\text{MSE} = 0$, 0 mismatched pixels).
- [x] Scoping boundaries explicitly stated: HIL functional correctness confirms transmission reliability and mathematical reversibility, but does not prove formal cryptographic security.
- [x] MATLAB prerequisites accurately stated as MATLAB R2020b or later with functions required by the selected scripts.
- [ ] Confirm open-access license permissions for the 8 medical test images in `image_dataset/`.
- [ ] Create repository `.gitignore` adhering to Section 5.
- [ ] Attach pre-compiled `m4dchs_stm32.bin` and `m4dchs_stm32.elf` as GitHub Release Assets rather than committing them directly into git history.
