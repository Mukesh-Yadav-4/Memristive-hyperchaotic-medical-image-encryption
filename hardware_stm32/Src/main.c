/**
 * ============================================================================
 * EMBEDDED MEMRISTIVE 4D HYPERCHAOTIC ACCELERATOR (M-4DCHS)
 * Target Hardware: STM32G474RE Nucleo (ARM Cortex-M4 @ 170 MHz + Hardware FPU)
 * Project: Hardware-in-the-Loop Medical Image Cryptosystem
 * Author: Yash (Research Portfolio - OIST Internship Application)
 * ============================================================================
 *
 * Dynamical Equations (4-Dimensional Memristive Hyperchaos):
 *   dx/dt = a*(y - x) + w
 *   dy/dt = c*x - x*z + d*y
 *   dz/dt = x*y - b*z
 *   dw/dt = -r*x - k*(alpha + 3*beta*x^2)*w
 *
 * Parameters:
 *   a = 15.81, b = 2.76, c = 86.03, d = -9.07, r = 10.79
 *   k = 0.05, alpha = 0.8, beta = 0.02
 *
 * Communications:
 *   USART2 (PA2 TX, PA3 RX) @ 921,600 baud
 *   Sync Word: 'M4DC' (0x4344344D)
 *   Status LED: LD2 Green on PA5 (Toggles during crypto stream)
 * ============================================================================
 */

#include <stdint.h>
#include <math.h>

/* ================= HARDWARE REGISTER MAP (STM32G474RE) ================= */
#define RCC_BASE            0x40021000UL
#define RCC_AHB2ENR         (*(volatile uint32_t *)(RCC_BASE + 0x4CUL))
#define RCC_APB1ENR1        (*(volatile uint32_t *)(RCC_BASE + 0x58UL))

#define GPIOA_BASE          0x48000000UL
#define GPIOA_MODER         (*(volatile uint32_t *)(GPIOA_BASE + 0x00UL))
#define GPIOA_ODR           (*(volatile uint32_t *)(GPIOA_BASE + 0x14UL))
#define GPIOA_AFRL          (*(volatile uint32_t *)(GPIOA_BASE + 0x20UL))

#define USART2_BASE         0x40004400UL
#define USART2_CR1          (*(volatile uint32_t *)(USART2_BASE + 0x00UL))
#define USART2_BRR          (*(volatile uint32_t *)(USART2_BASE + 0x0CUL))
#define USART2_ISR          (*(volatile uint32_t *)(USART2_BASE + 0x1CUL))
#define USART2_ICR          (*(volatile uint32_t *)(USART2_BASE + 0x20UL))
#define USART2_RDR          (*(volatile uint32_t *)(USART2_BASE + 0x24UL))
#define USART2_TDR          (*(volatile uint32_t *)(USART2_BASE + 0x28UL))

#define SCB_CPACR           (*(volatile uint32_t *)0xE000ED88UL)

/* USART Status Flags */
#define USART_ISR_TXE       (1UL << 7)
#define USART_ISR_RXNE      (1UL << 5)
#define USART_ISR_ORE       (1UL << 3)
#define USART_ICR_ORECF     (1UL << 3)

#define MAX_LINE_BYTES      4096
static uint8_t ks_buffer[MAX_LINE_BYTES];

/* ================= M-4DCHS DYNAMICAL PARAMETERS ================= */
#define M4DCHS_A            15.81f
#define M4DCHS_B            2.76f
#define M4DCHS_C            86.03f
#define M4DCHS_D            (-9.07f)
#define M4DCHS_R            10.79f
#define M4DCHS_K            0.05f
#define M4DCHS_ALPHA        0.8f
#define M4DCHS_BETA         0.02f
#define M4DCHS_DT           0.001f

static float s_x, s_y, s_z, s_w;
static float dt, dt_half, dt_sixth;

/* Derivative calculation */
static inline void m4dchs_derivatives(float x, float y, float z, float w,
                                     float *dx, float *dy, float *dz, float *dw) {
    *dx = M4DCHS_A * (y - x) + w;
    *dy = M4DCHS_C * x - x * z + M4DCHS_D * y;
    *dz = x * y - M4DCHS_B * z;
    *dw = -M4DCHS_R * x - M4DCHS_K * (M4DCHS_ALPHA + 3.0f * M4DCHS_BETA * x * x) * w;
}

/* 4th-Order Runge-Kutta Step & Keystream Extraction */
static inline uint8_t m4dchs_step_and_get_keystream(void) {
    // Quantization from dual state (x + y)
    float abs_val = fabsf((s_x + s_y) * 1.0e6f);
    uint8_t ks = (uint8_t)(((uint32_t)floorf(abs_val)) & 0xFF);

    float dx1, dy1, dz1, dw1;
    m4dchs_derivatives(s_x, s_y, s_z, s_w, &dx1, &dy1, &dz1, &dw1);

    float x2 = s_x + dt_half * dx1;
    float y2 = s_y + dt_half * dy1;
    float z2 = s_z + dt_half * dz1;
    float w2 = s_w + dt_half * dw1;
    float dx2, dy2, dz2, dw2;
    m4dchs_derivatives(x2, y2, z2, w2, &dx2, &dy2, &dz2, &dw2);

    float x3 = s_x + dt_half * dx2;
    float y3 = s_y + dt_half * dy2;
    float z3 = s_z + dt_half * dz2;
    float w3 = s_w + dt_half * dw2;
    float dx3, dy3, dz3, dw3;
    m4dchs_derivatives(x3, y3, z3, w3, &dx3, &dy3, &dz3, &dw3);

    float x4 = s_x + dt * dx3;
    float y4 = s_y + dt * dy3;
    float z4 = s_z + dt * dz3;
    float w4 = s_w + dt * dw3;
    float dx4, dy4, dz4, dw4;
    m4dchs_derivatives(x4, y4, z4, w4, &dx4, &dy4, &dz4, &dw4);

    s_x += dt_sixth * (dx1 + 2.0f * dx2 + 2.0f * dx3 + dx4);
    s_y += dt_sixth * (dy1 + 2.0f * dy2 + 2.0f * dy3 + dy4);
    s_z += dt_sixth * (dz1 + 2.0f * dz2 + 2.0f * dz3 + dz4);
    s_w += dt_sixth * (dw1 + 2.0f * dw2 + 2.0f * dw3 + dw4);

    return ks;
}

/* Initialization with 500-step transient burn-in */
static inline void m4dchs_init(float key) {
    s_x = 1.0f + key;
    s_y = 1.0f + key;
    s_z = 20.0f + key * 5.0f;
    s_w = 0.5f + key;
    dt = M4DCHS_DT;
    dt_half = 0.5f * dt;
    dt_sixth = dt / 6.0f;

    for (uint32_t step = 0; step < 500; step++) {
        float dx1, dy1, dz1, dw1;
        m4dchs_derivatives(s_x, s_y, s_z, s_w, &dx1, &dy1, &dz1, &dw1);

        float x2 = s_x + dt_half * dx1;
        float y2 = s_y + dt_half * dy1;
        float z2 = s_z + dt_half * dz1;
        float w2 = s_w + dt_half * dw1;
        float dx2, dy2, dz2, dw2;
        m4dchs_derivatives(x2, y2, z2, w2, &dx2, &dy2, &dz2, &dw2);

        float x3 = s_x + dt_half * dx2;
        float y3 = s_y + dt_half * dy2;
        float z3 = s_z + dt_half * dz2;
        float w3 = s_w + dt_half * dw2;
        float dx3, dy3, dz3, dw3;
        m4dchs_derivatives(x3, y3, z3, w3, &dx3, &dy3, &dz3, &dw3);

        float x4 = s_x + dt * dx3;
        float y4 = s_y + dt * dy3;
        float z4 = s_z + dt * dz3;
        float w4 = s_w + dt * dw3;
        float dx4, dy4, dz4, dw4;
        m4dchs_derivatives(x4, y4, z4, w4, &dx4, &dy4, &dz4, &dw4);

        s_x += dt_sixth * (dx1 + 2.0f * dx2 + 2.0f * dx3 + dx4);
        s_y += dt_sixth * (dy1 + 2.0f * dy2 + 2.0f * dy3 + dy4);
        s_z += dt_sixth * (dz1 + 2.0f * dz2 + 2.0f * dz3 + dz4);
        s_w += dt_sixth * (dw1 + 2.0f * dw2 + 2.0f * dw3 + dw4);
    }
}

/* ================= HARDWARE PERIPHERAL INITIALIZATION ================= */
void Hardware_Init(void) {
    // 1. Enable clocks for GPIOA and USART2
    RCC_AHB2ENR  |= (1UL << 0);   // GPIOAEN
    RCC_APB1ENR1 |= (1UL << 17);  // USART2EN

    // 2. Configure PA2 (TX) and PA3 (RX) as Alternate Function (AF7)
    GPIOA_MODER &= ~((3UL << 4) | (3UL << 6));
    GPIOA_MODER |=  ((2UL << 4) | (2UL << 6));

    GPIOA_AFRL &= ~((0xFUL << 8) | (0xFUL << 12));
    GPIOA_AFRL |=  ((7UL << 8) | (7UL << 12));

    // 3. Configure PA5 (LD2 Green LED) as General Purpose Output
    GPIOA_MODER &= ~(3UL << 10);
    GPIOA_MODER |=  (1UL << 10);
    GPIOA_ODR   &= ~(1UL << 5);   // Off initially

    // 4. Set Baud Rate = 921600 (Assuming default 16 MHz HSI clock: 16000000 / 921600 ≈ 17)
    USART2_BRR = 17;

    // 5. Enable Transmitter, Receiver, and USART
    USART2_CR1 = (1UL << 3) | (1UL << 2) | (1UL << 0);
}

static inline uint8_t UART2_ReadByte(void) {
    if (USART2_ISR & USART_ISR_ORE) {
        USART2_ICR = USART_ICR_ORECF;
    }
    while (!(USART2_ISR & USART_ISR_RXNE));
    return (uint8_t)(USART2_RDR & 0xFF);
}

static inline void UART2_WriteByte(uint8_t data) {
    while (!(USART2_ISR & USART_ISR_TXE));
    USART2_TDR = data;
}

/* ================= MAIN APPLICATION ENTRY ================= */
int main(void) {
    // Enable Hardware Floating Point Unit (Coprocessor CP10 & CP11 Full Access)
    SCB_CPACR |= ((3UL << 20) | (3UL << 22));
    __asm volatile ("dsb");
    __asm volatile ("isb");

    Hardware_Init();

    while (1) {
        // Sliding window synchronization detector: waits for 'M', '4', 'D', 'C' (0x4344344D)
        uint32_t sync = 0;
        while (sync != 0x4344344DUL) {
            sync = (sync >> 8) | (((uint32_t)UART2_ReadByte()) << 24);
        }

        // Read 4-byte payload size N (uint32 little-endian)
        uint32_t N = 0;
        N |= ((uint32_t)UART2_ReadByte()) << 0;
        N |= ((uint32_t)UART2_ReadByte()) << 8;
        N |= ((uint32_t)UART2_ReadByte()) << 16;
        N |= ((uint32_t)UART2_ReadByte()) << 24;

        // Read 4-byte key (IEEE-754 single float little-endian)
        union {
            float f;
            uint8_t b[4];
        } key_u;
        key_u.b[0] = UART2_ReadByte();
        key_u.b[1] = UART2_ReadByte();
        key_u.b[2] = UART2_ReadByte();
        key_u.b[3] = UART2_ReadByte();

        // Extract command mode from bit 31 of N (0 = Encrypt, 1 = Decrypt)
        uint32_t is_decrypt = (N & 0x80000000UL) ? 1 : 0;
        uint32_t line_len   = N & 0x7FFFFFFFUL;

        // Initialize M-4DCHS hyperchaotic system on Cortex-M4 FPU
        m4dchs_init(key_u.f);
        uint8_t prev_cipher = 0x5A; // Initial vector (IV)

        // Precompute keystream for the scanline into high-speed SRAM
        uint32_t ks_len = (line_len <= MAX_LINE_BYTES) ? line_len : MAX_LINE_BYTES;
        for (uint32_t i = 0; i < ks_len; i++) {
            ks_buffer[i] = m4dchs_step_and_get_keystream();
        }

        // Toggle LED on each scanline processed
        GPIOA_ODR ^= (1UL << 5);

        // Send 'OK' Handshake acknowledge to host
        UART2_WriteByte('O');
        UART2_WriteByte('K');

        // CBC wire-rate stream cipher
        if (is_decrypt) {
            for (uint32_t i = 0; i < line_len; i++) {
                uint8_t rx = UART2_ReadByte();
                uint8_t s = (i < MAX_LINE_BYTES) ? ks_buffer[i] : m4dchs_step_and_get_keystream();
                uint8_t tx = rx ^ s ^ prev_cipher;
                prev_cipher = rx; // Inverse CBC feedback: incoming ciphertext
                UART2_WriteByte(tx);
            }
        } else {
            for (uint32_t i = 0; i < line_len; i++) {
                uint8_t rx = UART2_ReadByte();
                uint8_t s = (i < MAX_LINE_BYTES) ? ks_buffer[i] : m4dchs_step_and_get_keystream();
                uint8_t tx = rx ^ s ^ prev_cipher;
                prev_cipher = tx; // Forward CBC feedback: outgoing ciphertext
                UART2_WriteByte(tx);
            }
        }

        // Keep LED illuminated on scanline completion
        GPIOA_ODR |= (1UL << 5);
    }
}
